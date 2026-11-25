# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import sys
import json
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from asm_frontend import Expression, Frontend
from build import verify_image, verify_protected_source
from firmware_checks import check_policy
from mcs51_check import Machine, listing_symbols
from srot import ROOT, parse_hex, select_target
from test_integrity import record, EOF

def encode(memory):
    return "\n".join([record(address, 0, bytes([value])) for address, value in sorted(memory.items())] + [EOF])

class CompiledFirmwareTests(unittest.TestCase):
    def setUp(self):
        self.data=(ROOT/"tests/fixtures/SROT_A_H_5_48_v0.4.0.hex").read_bytes()
        self.target=select_target("A_H_5_48")[1]

    def test_compiled_fixture_matches_verified_3d_image(self):
        self.assertGreater(verify_image(self.data,self.target)["flash_bytes"],5000)

    def test_correctly_checksummed_control_code_corruption_is_rejected(self):
        memory=parse_hex(self.data)
        memory[0x100] ^= 1
        with self.assertRaisesRegex(ValueError,"fingerprint"):
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
        with self.assertRaisesRegex(ValueError,"fingerprint"):
            verify_image(encode(memory),self.target)

class Fixed3DPolicyTests(unittest.TestCase):
    def setUp(self):
        self.memory = parse_hex((ROOT/"tests/fixtures/SROT_A_H_5_48_v0.4.0.hex").read_bytes())
        self.symbols = json.loads((ROOT/"tests/fixtures/SROT_A_H_5_48_v0.4.0.symbols.json").read_text())

    def test_saved_settings_commands_throttle_halves_and_reversal(self):
        check_policy(self.memory, self.symbols, exhaustive=True)

    def test_protected_hardware_and_control_modules_match_previous_release(self):
        verify_protected_source()

    def test_saved_mode_override_is_rejected_by_execution_checks(self):
        machine = Machine(self.memory, self.symbols)
        start = machine.address("Srot_decode_settings")
        self.memory[start + 3] = 1  # Corrupt the normalization immediate to a legacy mode.
        with self.assertRaisesRegex(ValueError, "retained legacy setting"):
            check_policy(self.memory, self.symbols)

    def test_corrupted_3d_half_selection_is_rejected_by_execution_checks(self):
        machine = Machine(self.memory, self.symbols)
        self.memory[machine.address("Srot_t1_int_normal_range")] = 0xD3  # SETB C replaces CLR C.
        with self.assertRaisesRegex(ValueError, "throttle"):
            check_policy(self.memory, self.symbols)

class InstructionSubsetTests(unittest.TestCase):
    def run_code(self, code):
        machine = Machine(dict(enumerate(code)), {})
        machine.run(0)
        return machine

    def test_borrow_and_carry_are_applied_in_unsigned_subtraction(self):
        machine = self.run_code([0x74, 0, 0xD3, 0x94, 0, 0x22])
        self.assertEqual(machine.a, 255)
        self.assertEqual(machine.carry, 1)

    def test_register_banks_and_indirect_upper_ram_are_separate_from_sfr(self):
        machine = self.run_code([0x75, 0xD0, 8, 0x78, 0xE0, 0x76, 0x37, 0x74, 0x45, 0x22])
        self.assertEqual(machine.ram[8], 0xE0)
        self.assertEqual(machine.ram[0xE0], 0x37)
        self.assertEqual(machine.a, 0x45)

    def test_unknown_opcode_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "Unsupported checked opcode"):
            self.run_code([0xA5])

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
