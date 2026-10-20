"""Tests for capture's wider source envelope; approved Pods tests stay unchanged."""
import copy
import unittest

import verify_native_store_capture as m

DERIVED = ('ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig',
           'ios/Runner.xcodeproj/project.pbxproj', 'ios/Runner.xcworkspace/contents.xcworkspacedata')


class FullCaptureSourceEnvelopeTests(unittest.TestCase):
    def setUp(self):
        rows = [{'file': p, 'kind': 'file', 'gitMode': '100644', 'gitBlobSha': '1' * 40,
                 'executable': False, 'sha256': '2' * 64}
                for p in [*DERIVED, 'lib/main.dart', 'ios/Runner/BILSystemCryptoBridge.swift',
                          'assets/data/catalog.json', 'tool/release/sanitize.dart', 'test/example_test.dart']]
        self.initial = {key: str(i) for i, key in enumerate(m.BINDINGS)}
        self.initial.update(phase='checkout', initialTrackedCheckoutClean=True, trackedFiles=rows)
        self.actual = copy.deepcopy(self.initial)
        for row in self.actual['trackedFiles']:
            if row['file'] in DERIVED:
                row['sha256'] = '3' * 64

    def check(self):
        return m.assert_source_delta(self.initial, self.actual, DERIVED)

    def test_exact_four_byte_changes_retain_full_inventory(self):
        before, after = self.check()
        self.assertEqual(len(before), 9)
        self.assertEqual(set(before), set(after))

    def test_assets_tools_dart_swift_and_tests_remain_protected(self):
        for path in [row['file'] for row in self.actual['trackedFiles'] if row['file'] not in DERIVED]:
            with self.subTest(path=path):
                value = copy.deepcopy(self.actual)
                next(row for row in value['trackedFiles'] if row['file'] == path)['sha256'] = '4' * 64
                with self.assertRaises(ValueError):
                    m.assert_source_delta(self.initial, value, DERIVED)

    def test_missing_dirty_checkout_proof_rejected(self):
        for field, value in [('phase', 'before'), ('initialTrackedCheckoutClean', False)]:
            initial = copy.deepcopy(self.initial)
            initial[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                m.assert_source_delta(initial, self.actual, DERIVED)

    def test_source_tree_controller_workflow_and_run_bound(self):
        for field in m.BINDINGS:
            actual = copy.deepcopy(self.actual)
            actual[field] = 'changed'
            with self.subTest(field=field), self.assertRaises(ValueError):
                m.assert_source_delta(self.initial, actual, DERIVED)

    def test_missing_or_duplicate_original_file_rejected(self):
        actual = copy.deepcopy(self.actual)
        actual['trackedFiles'].pop()
        with self.assertRaises(ValueError):
            m.assert_source_delta(self.initial, actual, DERIVED)
        actual = copy.deepcopy(self.actual)
        actual['trackedFiles'].append(copy.deepcopy(actual['trackedFiles'][0]))
        with self.assertRaises(ValueError):
            m.assert_source_delta(self.initial, actual, DERIVED)

    def test_partial_derived_changes_fail_before_capture(self):
        self.actual['trackedFiles'][0]['sha256'] = '2' * 64
        with self.assertRaises(ValueError):
            self.check()

    def test_derived_source_cannot_change_mode_symlink_or_git_blob(self):
        for key, value in [('executable', True), ('kind', 'symlink'),
                           ('gitMode', '100755'), ('gitBlobSha', '5' * 40)]:
            actual = copy.deepcopy(self.actual)
            actual['trackedFiles'][0][key] = value
            with self.subTest(field=key), self.assertRaises(ValueError):
                m.assert_source_delta(self.initial, actual, DERIVED)


if __name__ == '__main__':
    unittest.main()
