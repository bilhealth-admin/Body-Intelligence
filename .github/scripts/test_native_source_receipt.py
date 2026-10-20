import argparse
import contextlib
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from native_source_receipt import collect


class NativeSourceReceiptTests(unittest.TestCase):
    @contextlib.contextmanager
    def fixture(self):
        with tempfile.TemporaryDirectory() as root:
            previous = Path.cwd()
            os.chdir(root)
            try:
                Path("lib").mkdir()
                Path("lib/main.dart").write_text("void main() {}\n")
                Path("ios/Runner").mkdir(parents=True)
                Path("ios/Runner/AppDelegate.swift").write_text("// actual fixture\n")
                args = argparse.Namespace(phase="before", language="swift", source_head="a"*40,
                    source_tree="b"*40, output="artifacts/qa/frozen-native-source")
                env = {"GITHUB_SHA": "c"*40, "GITHUB_RUN_ID": "123", "UNRELATED_SECRET": "not-in-receipt"}
                with patch.dict(os.environ, env):
                    yield args
            finally:
                os.chdir(previous)

    def runner(self, args, *, dirty=False, wrong_tree=False, empty=False):
        def run(argv, **kwargs):
            if argv[1:3] == ["rev-parse", "HEAD"]:
                raw = (args.source_head + "\n").encode()
            elif argv[1:3] == ["rev-parse", "HEAD^{tree}"]:
                raw = (("d"*40 if wrong_tree else args.source_tree) + "\n").encode()
            elif argv[1] == "diff":
                return subprocess.CompletedProcess(argv, int(dirty), b"", b"")
            elif argv[1] == "ls-tree":
                raw = b"" if empty else b"100644 blob " + b"e"*40 + b"\tlib/main.dart\0" + b"100644 blob " + b"f"*40 + b"\tios/Runner/AppDelegate.swift\0"
            else:
                raise AssertionError(argv)
            return subprocess.CompletedProcess(argv, 0, raw, b"")
        return run

    def test_exact_before_after_source_bytes_and_controller_are_distinct(self):
        with self.fixture() as args:
            before = collect(args, run=self.runner(args))
            args.phase = "after"
            after = collect(args, run=self.runner(args))
            self.assertEqual(before["application_source_sha"], "a"*40)
            self.assertEqual(before["controller_sha"], "c"*40)
            self.assertTrue(after["before_after_inputs_identical"])
            self.assertEqual(before["working_inputs_fingerprint"], after["working_inputs_fingerprint"])
            self.assertEqual(len(before["inputs"]), 2)
            self.assertNotIn("not-in-receipt", str(after))

    def test_wrong_tree_dirty_source_and_empty_inventory_rejected(self):
        for fault in ("tree", "dirty", "empty"):
            with self.subTest(fault=fault), self.fixture() as args:
                with self.assertRaises(ValueError):
                    collect(args, run=self.runner(args, wrong_tree=fault=="tree", dirty=fault=="dirty", empty=fault=="empty"))

    def test_working_file_change_during_native_execution_rejected(self):
        with self.fixture() as args:
            collect(args, run=self.runner(args))
            Path("lib/main.dart").write_text("changed during test\n")
            args.phase = "after"
            with self.assertRaisesRegex(ValueError, "inputs changed"):
                collect(args, run=self.runner(args))

    def test_native_inputs_cannot_become_symlinks(self):
        with self.fixture() as args:
            Path("lib/main.dart").unlink()
            Path("lib/main.dart").symlink_to("../ios/Runner/AppDelegate.swift")
            with self.assertRaisesRegex(ValueError, "symlinked"):
                collect(args, run=self.runner(args))


if __name__ == "__main__":
    unittest.main()
