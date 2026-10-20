import subprocess
import tempfile
import unittest
from pathlib import Path

from check_native_watch_unchanged import (
    REVIEWED_GUIDANCE, REVIEWED_PRIVACY_DECLARATIONS, SIGNAL_PAGE, WatchBoundaryChanged, verify,
)


class NativeWatchGuardTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Synthetic Guard Test')
        self.git('config', 'user.email', 'synthetic@example.invalid')
        self.git('config', 'core.autocrlf', 'false')
        self.write(SIGNAL_PAGE, 'class _MeasuredSignalCard { final live = 1; }\nclass _SignalHistoryCard {}\n')
        self.write('ios/Runner/Watch.swift', 'let watch = 1\n')
        self.write('android/app/src/main/Watch.kt', 'val watch = 1\n')
        self.write('lib/features/dashboard/widgets/watch_card.dart', 'const live = 1;\n')
        self.write('lib/features/global_platform/health_data/health.dart', 'const value = 1;\n')
        for path in REVIEWED_PRIVACY_DECLARATIONS:
            self.write(path, '<plist>original privacy declaration</plist>\n')
        for path in REVIEWED_GUIDANCE:
            self.write(path, 'const oldGuide = 1;\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'synthetic original boundary')
        self.baseline = self.git('rev-parse', 'HEAD').strip()
        self.reviewed = {}
        for path in REVIEWED_GUIDANCE:
            self.write(path, 'const reviewedGuide = 2;\n')
            self.reviewed[path] = self.git('hash-object', '--path=' + path, '--', path).strip()
        self.reviewed_privacy = {}
        for path in REVIEWED_PRIVACY_DECLARATIONS:
            self.write(path, '<plist>reviewed Analytics disclosure</plist>\n')
            self.reviewed_privacy[path] = self.git('hash-object', '--path=' + path, '--', path).strip()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.repo, stderr=subprocess.PIPE).decode()

    def write(self, name, content):
        target = self.repo / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content.encode('utf-8'))

    def check(self):
        verify(self.repo, self.baseline, self.reviewed, self.reviewed_privacy)

    def test_reviewed_guidance_passes_without_rebasing_native_boundary(self):
        self.check()

    def test_future_change_to_each_reviewed_guide_fails(self):
        for path in self.reviewed:
            with self.subTest(path=path):
                self.write(path, 'const unreviewedGuide = 3;\n')
                with self.assertRaisesRegex(WatchBoundaryChanged, 'Reviewed guidance changed'):
                    self.check()
                self.write(path, 'const reviewedGuide = 2;\n')

    def test_reviewed_privacy_passes_without_rebasing_native_boundary(self):
        self.check()
        for path in self.reviewed_privacy:
            self.assertEqual(self.git('show', self.baseline + ':' + path), '<plist>original privacy declaration</plist>\n')

    def test_future_privacy_declaration_change_fails(self):
        for path in self.reviewed_privacy:
            with self.subTest(path=path):
                self.write(path, '<plist>unreviewed privacy declaration</plist>\n')
                with self.assertRaisesRegex(WatchBoundaryChanged, 'Reviewed privacy declaration changed'):
                    self.check()

    def test_missing_reviewed_privacy_declaration_fails(self):
        for path in self.reviewed_privacy:
            with self.subTest(path=path):
                (self.repo / path).unlink()
                with self.assertRaisesRegex(WatchBoundaryChanged, 'Reviewed privacy declaration missing'):
                    self.check()

    def test_untracked_other_privacy_declaration_fails(self):
        self.write('ios/Runner/UnreviewedPrivacy.xcprivacy', '<plist>unreviewed new disclosure</plist>\n')
        with self.assertRaisesRegex(WatchBoundaryChanged, 'Protected native/health/dashboard paths changed'):
            self.check()

    def test_native_watch_change_fails(self):
        self.write('ios/Runner/Watch.swift', 'let watch = 2\n')
        with self.assertRaises(WatchBoundaryChanged):
            self.check()

    def test_android_native_change_fails(self):
        self.write('android/app/src/main/Watch.kt', 'val watch = 2\n')
        with self.assertRaises(WatchBoundaryChanged):
            self.check()

    def test_dashboard_live_value_change_fails(self):
        self.write('lib/features/dashboard/widgets/watch_card.dart', 'const live = 2;\n')
        with self.assertRaises(WatchBoundaryChanged):
            self.check()

    def test_health_data_change_fails(self):
        self.write('lib/features/global_platform/health_data/health.dart', 'const value = 2;\n')
        with self.assertRaises(WatchBoundaryChanged):
            self.check()

    def test_measured_card_change_fails(self):
        self.write(SIGNAL_PAGE, 'class _MeasuredSignalCard { final live = 2; }\nclass _SignalHistoryCard {}\n')
        with self.assertRaisesRegex(WatchBoundaryChanged, 'Live Watch/current-value card changed'):
            self.check()

    def test_untracked_native_file_fails(self):
        self.write('ios/Runner/Unreviewed.swift', 'let newValue = 2\n')
        with self.assertRaises(WatchBoundaryChanged):
            self.check()

    def test_history_only_change_does_not_reclassify_current_values(self):
        self.write(SIGNAL_PAGE, 'class _MeasuredSignalCard { final live = 1; }\nclass _SignalHistoryCard { final history = 2; }\n')
        self.check()


if __name__ == '__main__':
    unittest.main()
