import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('delivery_controller', Path(__file__).with_name('controller.py'))
controller = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(controller)


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'app'
        self.app.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.app)], check=True)
        for name, value in (('user.email', 'offline@example.invalid'), ('user.name', 'Offline control')):
            subprocess.run(['git', '-C', str(self.app), 'config', name, value], check=True)
        (self.app / 'lib').mkdir()
        (self.app / 'lib/main.dart').write_text('void main() {}\n')
        (self.app / 'integration_test').mkdir()
        (self.app / 'integration_test/native_feature_splashes_test.dart').write_text('void main() {}\n')
        subprocess.run(['git', '-C', str(self.app), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.app), 'commit', '-qm', 'fixture'], check=True)
        self.head = controller.git(self.app, 'rev-parse', 'HEAD')
        self.tree = controller.git(self.app, 'rev-parse', 'HEAD^{tree}')

    def assert_source(self):
        return controller.assert_source(self.app, self.head, self.tree)

    def test_clean_frozen_source_accepted(self):
        self.assertEqual(self.assert_source()['protected_tracked_diff'], [])

    def test_wrong_head_or_tree_blocks(self):
        for head, tree in (('0' * 40, self.tree), (self.head, '0' * 40)):
            with self.assertRaises(ValueError):
                controller.assert_source(self.app, head, tree)

    def test_staged_and_unstaged_shipping_changes_block(self):
        (self.app / 'lib/main.dart').write_text('void main() { print(1); }\n')
        with self.assertRaises(ValueError):
            self.assert_source()
        subprocess.run(['git', '-C', str(self.app), 'add', 'lib/main.dart'], check=True)
        with self.assertRaises(ValueError):
            self.assert_source()

    def test_original_integration_test_change_blocks(self):
        (self.app / 'integration_test/native_feature_splashes_test.dart').write_text('void main() { return; }\n')
        with self.assertRaises(ValueError):
            self.assert_source()

    def test_only_explicit_untracked_wrapper_targets_allowed(self):
        (self.app / controller.WRAPPER_TARGET).write_text('diagnostic wrapper')
        self.assert_source()
        (self.app / 'lib/injected.dart').write_text('injected shipping code')
        with self.assertRaises(ValueError):
            self.assert_source()

    def test_controlled_invocation_changes_exactly_one_target(self):
        old = '--driver=original.dart --target=integration_test/native_feature_splashes_test.dart --timeout1200\n'
        new = controller.controlled_script(old, 'a' * 40, 'b' * 64)
        self.assertIn('--target=' + controller.WRAPPER_TARGET, new)
        self.assertIn('--driver=original.dart', new)
        self.assertIn('--timeout1200', new)
        replaced = new.replace('--target=' + controller.WRAPPER_TARGET +
                               ' --dart-define=BIL_DIAGNOSTIC_CONTROLLER_HEAD=' + 'a' * 40 +
                               ' --dart-define=BIL_DIAGNOSTIC_WRAPPER_SHA256=' + 'b' * 64,
                               '--target=integration_test/native_feature_splashes_test.dart')
        self.assertEqual(replaced, old)

    def test_missing_duplicate_target_and_injected_identity_block(self):
        target = '--target=integration_test/native_feature_splashes_test.dart'
        for text in ('no target', target + target):
            with self.assertRaises(ValueError):
                controller.controlled_script(text, 'a' * 40, 'b' * 64)
        with self.assertRaises(ValueError):
            controller.controlled_script(target, 'x; touch injected', 'b' * 64)

    def test_original_failure_survives_even_guard_and_diagnostic_failure(self):
        self.assertEqual(controller.final_status(7, False, False), 7)
        self.assertEqual(controller.final_status(0, False, True), 1)
        self.assertEqual(controller.final_status(0, True, False), 1)
        self.assertEqual(controller.final_status(0, True, True), 0)

    def test_failed_native_process_still_checks_source_and_keeps_original_exit(self):
        output = Path(self.temp.name) / 'outside-output'
        output.mkdir()
        (self.app / controller.WRAPPER_TARGET).write_text('wrapper')
        script = output / 'controlled-native-script.sh'
        script.write_text('original command')
        receipt = {'wrapper_sha256': controller.sha(self.app / controller.WRAPPER_TARGET),
                   'controller_head': 'a' * 40,
                   'controlled_script_sha256': controller.sha(script)}
        controller.write_json(output / 'controller-provenance.json', receipt)
        metadata = self.app / controller.OUT_REL / 'feature-splashes/native-metadata.json'
        controller.write_json(metadata, {'scenes': [{'suite_frame_delivery_diagnostic': {
            'app_source': controller.APP_SOURCE, 'app_tree': controller.APP_TREE,
            'controller_source': receipt['controller_head'], 'compile_target': controller.WRAPPER_TARGET,
            'max_frames': 10000, 'max_events': 64,
            'wrapper_sha256': receipt['wrapper_sha256'], 'classification': 'DIAGNOSTIC_ONLY',
            'frames_truncated': False, 'events_truncated': False}}]})
        process = SimpleNamespace(terminate=lambda: None, wait=lambda timeout=10: None, kill=lambda: None)
        with patch.object(controller, 'assert_source', side_effect=[{}, ValueError('post-run source changed')]) as guard, \
             patch.object(controller, 'snapshot_environment'), \
             patch.object(controller.subprocess, 'Popen', return_value=process), \
             patch.object(controller.subprocess, 'run', return_value=SimpleNamespace(returncode=7)):
            status = controller.run_original(self.app, output)
        self.assertEqual(status, 7)
        self.assertEqual(guard.call_count, 2)
        saved = json.loads((output / 'controller-provenance.json').read_text())
        self.assertEqual(saved['original_native_exit_status'], 7)
        self.assertFalse(saved['post_source_guard_passed'])
        self.assertTrue(saved['diagnostic_complete'])
        self.assertFalse(saved['native_release_certification'])

    def test_bundle_copies_raw_bytes_omits_binary_and_records_digest(self):
        output = Path(self.temp.name) / 'outside-output'
        output.mkdir()
        raw = b'{"frame_number":1820,"source":"raw"}\n'
        (output / 'raw.json').write_bytes(raw)
        (output / 'image.png').write_bytes(b'binary')
        controller.bundle(self.app, output)
        self.assertEqual((output / 'upload/raw.json').read_bytes(), raw)
        self.assertFalse((output / 'upload/image.png').exists())
        index = json.loads((output / 'upload/diagnostic-upload-index.json').read_text())
        self.assertEqual(index['files'][0]['sha256'], hashlib.sha256(raw).hexdigest())

    def test_bundle_size_cap_blocks(self):
        output = Path(self.temp.name) / 'outside-output'
        output.mkdir()
        with (output / 'too-large.log').open('wb') as file:
            file.truncate(11 * 1024 * 1024)
        with self.assertRaises(ValueError):
            controller.bundle(self.app, output)


if __name__ == '__main__':
    unittest.main()
