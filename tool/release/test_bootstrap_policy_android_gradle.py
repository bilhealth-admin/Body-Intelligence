import tempfile
import unittest
from pathlib import Path

from bootstrap_policy_android_gradle import prepare


class BootstrapTest(unittest.TestCase):
    def test_clean_checkout_and_repeat_preserve_pins_and_existing_files(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            android, flutter, sdk = root / "android", root / "flutter", root / "sdk"
            properties = android / "gradle/wrapper/gradle-wrapper.properties"
            properties.parent.mkdir(parents=True)
            pinned = b"distributionUrl=pinned\r\ndistributionSha256Sum=verified\r\n"
            properties.write_bytes(pinned)
            for relative in ("gradlew", "gradlew.bat", "gradle/wrapper/gradle-wrapper.jar"):
                source = flutter / "bin/cache/artifacts/gradle_wrapper" / relative
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_bytes(relative.encode())
            (android / "local.properties").write_text("custom.setting=keep\nflutter.sdk=old\n")
            prepare(android, flutter, sdk)
            self.assertEqual(properties.read_bytes(), pinned)
            self.assertTrue((android / "gradle/wrapper/gradle-wrapper.jar").is_file())
            (android / "gradlew").write_text("existing")
            prepare(android, flutter, sdk)
            self.assertEqual((android / "gradlew").read_text(), "existing")
            local = (android / "local.properties").read_text()
            self.assertIn("custom.setting=keep", local)
            self.assertEqual(local.count("flutter.sdk="), 1)
            self.assertIn(f"sdk.dir={sdk.as_posix()}", local)

    def test_missing_cached_wrapper_fails_closed(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            properties = root / "android/gradle/wrapper/gradle-wrapper.properties"
            properties.parent.mkdir(parents=True)
            properties.write_text("pinned")
            with self.assertRaises(FileNotFoundError):
                prepare(root / "android", root / "flutter", root / "sdk")
            self.assertEqual(properties.read_text(), "pinned")


if __name__ == "__main__":
    unittest.main()
