# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from asm_frontend import Expression, Frontend
from build import verify_image
from srot import ROOT, parse_hex, select_target
from test_integrity import record, EOF

def encode(memory):
    return "\n".join([record(address, 0, bytes([value])) for address, value in sorted(memory.items())] + [EOF])

class CompiledFirmwareTests(unittest.TestCase):
    def setUp(self):
        self.data=(ROOT/"tests/fixtures/SROT_A_H_5_48_v0.3.0.hex").read_bytes()
        self.target=select_target("A_H_5_48")[1]

    def test_compiled_fixture_has_only_declared_changes(self):
        self.assertGreater(verify_image(self.data,self.target)["flash_bytes"],5000)

    def test_correctly_checksummed_control_code_corruption_is_rejected(self):
        memory=parse_hex(self.data)
        memory[0x100] ^= 1
        with self.assertRaisesRegex(ValueError,"beyond the declared"):
            verify_image(encode(memory),self.target)

    def test_wrong_layout_is_rejected(self):
        with self.assertRaisesRegex(ValueError,"layout tag"):
            verify_image(self.data,select_target("B_H_5_48")[1])

    def test_direction_regression_is_rejected(self):
        memory=parse_hex(self.data)
        memory[0x1A0B]=1
        with self.assertRaisesRegex(ValueError,"Reversible"):
            verify_image(encode(memory),self.target)

    def test_bootloader_corruption_is_rejected(self):
        memory=parse_hex(self.data)
        memory[max(memory)] ^= 1
        with self.assertRaisesRegex(ValueError,"beyond the declared"):
            verify_image(encode(memory),self.target)

class FrontendTests(unittest.TestCase):
    def expand(self,text):
        with tempfile.TemporaryDirectory() as folder:
            Path(folder,"main.asm").write_text(text,encoding="ascii")
            return Frontend(folder,{}).compile("main.asm")

    def test_clock_expressions_keep_more_than_sixteen_bits(self):
        self.assertEqual(Expression({}).evaluate("24500000 / 1000"),24500)
        self.assertEqual(Expression({}).evaluate("(49000000 / 1000000) SHL 2"),196)

    def test_custom_layout_switch_uses_logical_not(self):
        result=self.expand("$set (CUSTOM_LED)\n$if NOT CUSTOM_LED\nDB 1\n$else\nDB 2\n$endif\nEND")
        self.assertIn("DB 2",result)
        self.assertNotIn("DB 1",result)

    def test_custom_pin_alias_overrides_base(self):
        result=self.expand("P EQU 128\nPIN EQU 1\nALIAS EQU P.PIN\nALIAS EQU P.7\nsetb ALIAS\nEND")
        self.assertEqual(result.count("ALIAS EQU"),1)
        self.assertIn("ALIAS EQU 135",result)

    def test_macro_local_labels_are_unique_per_invocation(self):
        result=self.expand("m MACRO value\nLOCAL again\nagain:\nmov A,#value\nsjmp again\nENDM\nm 1\nm 2\nEND")
        self.assertIn("L_1_again:",result)
        self.assertIn("L_2_again:",result)

if __name__=="__main__":
    unittest.main()
