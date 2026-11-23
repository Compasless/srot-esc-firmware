# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from firmware_equivalence import verify
from srot import ROOT
from build import build_plan


class RefactorTests(unittest.TestCase):
    def test_active_source_preserves_all_conditional_assembly_paths(self):
        result = verify()
        self.assertEqual(result["active_source_files"], 60)
        self.assertEqual(result["renamed_code_and_data_labels"], 535)
        self.assertGreater(result["assembly_statements_compared"], 13000)

    def test_build_uses_active_compasless_firmware(self):
        _, _, commands = build_plan("A_H_5_48", "C:/Keil")
        self.assertEqual(commands[0][1], "src/SrotEsc.asm")

    def assert_mutation_rejected(self, name, old, new):
        content = (ROOT / "src" / name).read_text()
        self.assertIn(old, content)
        with self.assertRaisesRegex(ValueError, "Assembly changed"):
            verify({name:content.replace(old, new, 1)})

    def test_changed_default_is_rejected(self):
        self.assert_mutation_rejected("config/defaults.inc",
                                      "DEFAULT_PGM_DIRECTION EQU 1",
                                      "DEFAULT_PGM_DIRECTION EQU 3")

    def test_changed_instruction_is_rejected(self):
        self.assert_mutation_rejected("core/startup.asm",
                                      "mov  SP, #Srot_stack", "mov  SP, #0")

    def test_changed_configurator_identity_is_rejected(self):
        self.assert_mutation_rejected("storage/eeprom_image.inc",
                                      '"Bluejay (.0)    "', '"SROT ESC (.0)   "')

    def test_change_in_alternate_target_branch_is_rejected(self):
        self.assert_mutation_rejected("hal/register_offsets.inc",
                                      "MCU_TYPE == MCU_BB51", "MCU_TYPE == MCU_BB2")

    def test_changed_service_order_is_rejected(self):
        content = (ROOT / "src/core/services.inc").read_text()
        old = "$include (interrupts\\vectors.asm)"
        self.assertIn(old,content)
        with self.assertRaises(ValueError):
            verify({"core/services.inc":content.replace(old,"",1)})

    def test_comment_edit_preserves_equivalence(self):
        content = (ROOT / "src/core/startup.asm").read_text()
        self.assertEqual(verify({"core/startup.asm":"; maintained by Compasless\n"+content})[
            "canonical_assembly_sha256"], verify()["canonical_assembly_sha256"])


if __name__ == "__main__":
    unittest.main()
