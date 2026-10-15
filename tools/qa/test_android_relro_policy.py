"""Exercise the shipping AAB verifier, without building or signing an app."""
import importlib.util
from pathlib import Path
import sys
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "tool/release/verify_android_16k_alignment.py"
SPEC = importlib.util.spec_from_file_location("bil_android_alignment", SCRIPT)
gate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gate
SPEC.loader.exec_module(gate)
LOAD = "LOAD 0x0 0x0 0x0 0x1000 0x1000 R E 0x4000\n"


class RelroPolicyTest(unittest.TestCase):
    def test_aligned_load_cannot_hide_unaligned_relro(self):
        with self.assertRaises(gate.GateError):
            gate._load_alignments(
                LOAD + "GNU_RELRO 0xcfaf0 0xdfaf0 0xdfaf0 0x1510 0x1510 R 0x1",
                library="synthetic.so",
            )

    def test_aligned_relro_passes(self):
        self.assertEqual(gate._load_alignments(
            LOAD + "GNU_RELRO 0xcfaf0 0xdfaf0 0xdfaf0 0x1510 0x510 R 0x1",
            library="synthetic.so"), [0x4000])

    def test_no_relro_is_explicitly_permitted(self):
        self.assertEqual(gate._load_alignments(LOAD, library="synthetic.so"), [0x4000])

    def test_malformed_relro_fails_closed(self):
        for row in ("GNU_RELRO truncated", "GNU_RELRO 0x0 0x0 0x0 0x0 unknown R 0x1"):
            with self.subTest(row=row), self.assertRaises(gate.GateError):
                gate._load_alignments(LOAD + row, library="synthetic.so")

    def test_each_relro_range_is_checked(self):
        with self.assertRaises(gate.GateError):
            gate._load_alignments(
                LOAD + "GNU_RELRO 0x0 0x0 0x0 0x4000 0x4000 R 0x1\n"
                "GNU_RELRO 0x0 0x0 0x0 0x1000 0x1000 R 0x1",
                library="synthetic.so",
            )


if __name__ == "__main__":
    unittest.main()
