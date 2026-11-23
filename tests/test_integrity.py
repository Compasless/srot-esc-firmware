# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from srot import assets, image_digest, parse_hex, select_target, sha256, verify_reference
from build import build_plan


def record(address, kind, payload=b""):
    body = bytes([len(payload), address >> 8, address & 255, kind]) + payload
    return ":" + (body + bytes([-sum(body) & 255])).hex().upper()


EOF = ":00000001FF"


class IntelHexTests(unittest.TestCase):
    def test_known_intel_record(self):
        image = parse_hex(":10010000214601360121470136007EFE09D2190140\n" + EOF)
        self.assertEqual(len(image), 16)
        self.assertEqual(image[0x100], 0x21)
        self.assertEqual(image[0x10f], 0x01)

    def test_corrupt_checksum_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Checksum"):
            parse_hex(record(0, 0, b"\x01")[:-2] + "00\n" + EOF)

    def test_truncated_record_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "length"):
            parse_hex(":0200000001FD\n" + EOF)

    def test_missing_eof_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "EOF"):
            parse_hex(record(0, 0, b"\x01"))

    def test_record_after_eof_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "after EOF"):
            parse_hex(record(0, 0, b"\x01") + "\n" + EOF + "\n" + record(1, 0, b"\x02"))

    def test_conflicting_address_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            parse_hex(record(0, 0, b"\x01") + "\n" + record(0, 0, b"\x02") + "\n" + EOF)

    def test_extended_linear_address(self):
        image = parse_hex("\n".join([record(0, 4, b"\x00\x01"), record(2, 0, b"\xab"), EOF]))
        self.assertEqual(image, {0x10002:0xab})

    def test_extended_segment_address(self):
        image = parse_hex("\n".join([record(0, 2, b"\x12\x34"), record(2, 0, b"\xab"), EOF]))
        self.assertEqual(image, {0x12342:0xab})

    def test_malformed_extended_address_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "extended"):
            parse_hex(record(1, 4, b"\x00\x01") + "\n" + EOF)

    def test_unknown_record_type_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            parse_hex(record(0, 6) + "\n" + EOF)

    def test_address_boundary_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "boundary"):
            parse_hex(record(0xffff, 0, b"\x01\x02") + "\n" + EOF)

    def test_internal_whitespace_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "characters"):
            parse_hex(":01 00000001FE\n" + EOF)

    def test_record_chunking_does_not_change_image_digest(self):
        first = parse_hex(record(0, 0, b"\x01\x02") + "\n" + EOF)
        second = parse_hex("\n".join([record(1, 0, b"\x02"), record(0, 0, b"\x01"), EOF]))
        self.assertEqual(image_digest(first), image_digest(second))

    def test_reference_file_fingerprint_is_enforced(self):
        data = (record(0, 0, b"\x01") + "\n" + EOF + "\n").encode()
        expected = {"size":len(data), "sha256":sha256(data)}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.hex"
            path.write_bytes(data)
            self.assertEqual(verify_reference(path, expected)["flash_bytes"], 1)
            path.write_bytes(data.replace(b"01FE", b"02FD"))
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                verify_reference(path, expected)


class TargetTests(unittest.TestCase):
    def test_release_manifest_has_exact_unique_targets(self):
        records = assets()
        self.assertEqual(len(records), 1008)
        self.assertEqual(len({r["target"] for r in records.values()}), 1008)
        self.assertEqual({r["mcu"] for r in records.values()}, {"H","X"})

    def test_exact_target_and_filename_resolve_to_same_record(self):
        filename, info = select_target("A_H_5_48")
        self.assertEqual(filename, "A_H_5_48_v0.21.0.hex")
        self.assertEqual(select_target(filename), (filename, info))

    def test_nonexistent_layout_or_family_is_rejected(self):
        for target in ("A_L_5_48", "ZZ_H_5_48", "A_H_999_48", "../A_H_5_48", "A_X_5_120"):
            with self.subTest(target=target), self.assertRaises(ValueError):
                select_target(target)

    def test_multi_letter_layout_uses_upstream_numeric_code(self):
        _,_,commands = build_plan("OA_H_5_48", "C:/Keil_v5/C51/BIN")
        self.assertIn("DEFINE(ESCNO=27)", commands[0])
        self.assertIn("DEFINE(PWM_FREQ=1)", commands[0])

    def test_bb51_build_uses_correct_mcu_define(self):
        _,_,commands = build_plan("A_X_5_24", "C:/Keil_v5/C51/BIN")
        self.assertIn("DEFINE(MCU_TYPE=2)", commands[0])
        self.assertIn("DEFINE(PWM_FREQ=0)", commands[0])
        self.assertEqual(len(commands), 3)


if __name__ == "__main__":
    unittest.main()
