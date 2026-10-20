import argparse
import contextlib
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import json
import shutil
from unittest.mock import patch

from native_source_receipt import collect
import bil_cocoapods_derived_proof as derived

FIXTURES = Path(__file__).resolve().parent


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
            elif argv[1] == "diff" and "--name-only" in argv:
                raw = b"ios/Runner/AppDelegate.swift\0"
            elif argv[1] == "diff" and "--no-ext-diff" in argv:
                raw = b"diff --git a/ios/Runner.xcodeproj/project.pbxproj b/ios/Runner.xcodeproj/project.pbxproj\n-old\n+new\n"
            elif argv[1] == "show":
                raw = b"// actual fixture\n"
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

    def test_initial_checkout_receipt_and_dirty_tooling_metadata_never_waive_change(self):
        with self.fixture() as args:
            args.phase = "checkout"
            initial = collect(args, run=self.runner(args))
            self.assertEqual(initial["phase"], "checkout")
            args.phase = "before"
            with self.assertRaisesRegex(ValueError, "TRACKED_INPUTS_CHANGED"):
                collect(args, run=self.runner(args, dirty=True))
            import json
            dirty = json.loads((Path(args.output) / "native-source-before-dirty.json").read_text())
            self.assertFalse(dirty["tracked_native_inputs_clean"])
            self.assertEqual(dirty["changed_tracked_inputs"][0]["path"], "ios/Runner/AppDelegate.swift")
            self.assertEqual(len(dirty["changed_tracked_inputs"][0]["working_sha256"]), 64)
            self.assertFalse((Path(args.output) / "native-source-before.json").exists())

    def test_validated_generation_preserves_git_source_and_actual_generated_hashes(self):
        with self.fixture() as args:
            for path in derived.DERIVED_PATHS:
                target = Path(path)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((FIXTURES / "fixtures/original" / path).read_bytes())
            originals = {path: Path(path).read_bytes() for path in derived.DERIVED_PATHS}
            originals.update({path: Path(path).read_bytes() for path in ("lib/main.dart", "ios/Runner/AppDelegate.swift")})
            def runner(argv, **kwargs):
                if argv[1] == "show":
                    return subprocess.CompletedProcess(argv, 0, originals[argv[2].split(":", 1)[1]], b"")
                if argv[1] == "ls-tree":
                    raw = b"".join(b"100644 blob " + hashlib.sha1(b"blob " + str(len(value)).encode() + b"\0" + value).hexdigest().encode() + b"\t" + key.encode() + b"\0" for key, value in originals.items())
                    return subprocess.CompletedProcess(argv, 0, raw, b"")
                if argv[1] == "diff" and "--name-only" in argv:
                    return subprocess.CompletedProcess(argv, 0, b"\0".join(path.encode() for path in derived.DERIVED_PATHS) + b"\0", b"")
                if argv[1] == "diff" and "--no-ext-diff" not in argv:
                    return subprocess.CompletedProcess(argv, int(args.phase != "checkout"), b"", b"")
                return self.runner(args)(argv, **kwargs)
            args.phase = "checkout"
            initial = collect(args, run=runner)
            args.phase = "before"
            args.derived_contract = str(FIXTURES / "cocoapods-derived-contract.json")
            for path in derived.DERIVED_PATHS:
                Path(path).write_bytes((FIXTURES / "fixtures/generated" / path).read_bytes())
            Path("ios/Pods").mkdir()
            for path in ("ios/Podfile.lock", "ios/Pods/Manifest.lock"):
                Path(path).write_text("PODS:\n  - SDK (1.0)\nCOCOAPODS: 1.16.2\n")
            toolchain = {"cocoapods_version": "1.16.2", "flutter_version": "3.44.6", "ruby_version": "ruby3",
                         "xcode_version": "Xcode26.6", "xcodeproj_version": "1.27.0", "pod_executable_sha256": "a" * 64}
            (Path(args.output) / "cocoapods-toolchain.json").write_text(json.dumps(toolchain))
            with patch("native_source_receipt.validate", side_effect=lambda a, b, c: derived.validate(a, b, c, require_plutil=False)):
                before = collect(args, run=runner)
                self.assertEqual(before["schema"], "bil.qa.frozen-native-source.v2")
                self.assertFalse(before["tracked_native_inputs_clean"])
                self.assertTrue(before["derived_build_proof"]["initial_checkout_clean"])
                self.assertEqual(before["derived_build_proof"]["unchanged_tracked_input_count"], 2)
                self.assertNotEqual(before["working_inputs_fingerprint"], initial["working_inputs_fingerprint"])
                self.assertEqual(before["derived_build_proof"]["initial_source_fingerprint"], initial["working_inputs_fingerprint"])
                args.phase = "after"
                after = collect(args, run=runner)
                self.assertTrue(after["before_after_inputs_identical"])
                self.assertEqual(after["inputs"], before["inputs"])
                Path("lib/main.dart").write_text("unreviewed\n")
                with self.assertRaisesRegex(ValueError, "Unreviewed source"):
                    collect(args, run=runner)

    def test_derived_proof_not_available_to_android_or_checkout_mutation(self):
        with self.fixture() as args:
            args.derived_contract = "reviewed-contract.json"
            args.language = "java-kotlin"
            with self.assertRaisesRegex(ValueError, "limited to the Swift"):
                collect(args, run=self.runner(args))
            args.language = "swift"
            args.phase = "checkout"
            with self.assertRaisesRegex(ValueError, "TRACKED_INPUTS_CHANGED"):
                collect(args, run=self.runner(args, dirty=True))


if __name__ == "__main__":
    unittest.main()
