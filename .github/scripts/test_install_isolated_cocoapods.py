import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("isolated_pods", Path(__file__).with_name("install_isolated_cocoapods.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class IsolatedCocoaPodsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {"RUNNER_TEMP": str(self.root), "GITHUB_ENV": str(self.root / "env"),
                    "GITHUB_PATH": str(self.root / "path"), "PATH": "/runner/ruby/bin",
                    "GEM_HOME": "/existing/global", "GEM_PATH": "/existing/global"}
        self.calls = []
        self.probe_version = "1.16.2"
        self.executable_version = "1.16.2"
        self.escape_dependency = False
        self.fail_install = False

    def fake_run(self, args, **kwargs):
        self.calls.append((args, kwargs))
        env = kwargs["env"]
        if "install" in args:
            if self.fail_install:
                raise subprocess.CalledProcessError(1, args)
            return SimpleNamespace(stdout="", returncode=0)
        if "-e" in args:
            home = Path(env["GEM_HOME"])
            value = {"cocoapods_version": self.probe_version, "xcodeproj_version": "1.28.1",
                     "cocoapods_gem_path": str(home / "gems/cocoapods-1.16.2"),
                     "xcodeproj_gem_path": "/existing/global/xcodeproj" if self.escape_dependency else str(home / "gems/xcodeproj-1.28.1"),
                     "resolved_gems": [{"name": "cocoapods", "version": self.probe_version}, {"name": "xcodeproj", "version": "1.28.1"}]}
            return SimpleNamespace(stdout=json.dumps(value), returncode=0)
        return SimpleNamespace(stdout=self.executable_version + "\n", returncode=0)

    def install(self):
        with patch.object(module.shutil, "which", side_effect=lambda x, **_: "/runner/ruby/bin/" + x):
            return module.install(self.root / "receipt.json", run=self.fake_run, environ=self.env)

    def test_exact_version_and_fresh_isolation_without_global_mutation(self):
        before = dict(self.env)
        receipt = self.install()
        self.assertEqual(before, self.env)
        args, options = self.calls[0]
        self.assertEqual(args[:6], ["/runner/ruby/bin/gem", "--norc", "install", "cocoapods", "--version", "1.16.2"])
        self.assertIn("--clear-sources", args)
        self.assertIn("https://rubygems.org", args)
        self.assertEqual(options["timeout"], 600)
        self.assertTrue(Path(options["env"]["GEM_HOME"]).is_relative_to(self.root))
        self.assertEqual(options["env"]["GEM_HOME"], options["env"]["GEM_PATH"])
        self.assertNotIn("/existing/global", options["env"]["GEM_PATH"])
        shim = next(self.root.glob("bil-cocoapods-*/bin/pod"))
        self.assertIn("gem 'cocoapods', '=1.16.2'", shim.read_text())
        self.assertIn("Gem.bin_path('cocoapods', 'pod', '=1.16.2')", shim.read_text())
        self.assertEqual(receipt["xcodeproj_version"], "1.28.1")
        self.assertFalse(receipt["global_gem_directories_modified"])
        self.assertIn("GEM_PATH=", (self.root / "env").read_text())

    def test_observed_runner_pod117_remains_rejected(self):
        self.probe_version = "1.17.0"
        with self.assertRaisesRegex(ValueError, "Exact CocoaPods"):
            self.install()
        self.assertFalse((self.root / "env").exists())

    def test_executable_selection_mismatch_blocks_publication(self):
        self.executable_version = "1.17.0"
        with self.assertRaisesRegex(ValueError, "pod executable"):
            self.install()
        self.assertFalse((self.root / "path").exists())

    def test_preinstalled_xcodeproj_escape_blocks_publication(self):
        self.escape_dependency = True
        with self.assertRaisesRegex(ValueError, "escaped"):
            self.install()
        self.assertFalse((self.root / "env").exists())

    def test_install_failure_does_not_export_selection(self):
        self.fail_install = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.install()
        self.assertFalse((self.root / "env").exists())
        self.assertEqual(len(self.calls), 1)

    def test_missing_or_multiline_job_path_is_rejected(self):
        self.env["GITHUB_ENV"] += "\ninjected=value"
        with self.assertRaisesRegex(ValueError, "safe GitHub"):
            self.install()
        self.assertEqual(self.calls, [])

    def test_active_bundler_is_rejected(self):
        self.env["BUNDLE_GEMFILE"] = "/unreviewed/Gemfile"
        with self.assertRaisesRegex(ValueError, "Bundler"):
            self.install()


if __name__ == "__main__":
    unittest.main()
