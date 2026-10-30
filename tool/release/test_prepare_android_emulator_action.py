"""Offline identity/one-line patch controls; fixture Git responses are explicit fakes."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import prepare_android_emulator_action as prepare


def hashes(data):
    return (hashlib.sha256(data).hexdigest(),
            hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest())


class PrepareAndroidActionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.action = self.root / prepare.OWNED
        self.action.mkdir(parents=True)
        (self.action / '.git').mkdir()
        (self.action / 'node_modules').mkdir()
        (self.action / 'lib').mkdir()
        self.sources = {'action.yml': b'runs:\n  main: lib/main.js\n',
                        'lib/main.js': b'require("./emulator-manager");\n',
                        'lib/emulator-manager.js': b'prefix\n' + prepare.MENU + b'suffix\n'}
        for name, data in self.sources.items():
            (self.action / name).write_bytes(data)
        helper = self.root / 'tool/release/android_emulator_unlock.py'
        helper.parent.mkdir(parents=True); helper.write_text('# fixture only\n')
        self.head = self.peeled = prepare.COMMIT
        self.object_type = 'tag'
        self.origin = 'https://github.com/ReactiveCircus/android-emulator-runner'
        self.dirty = self.ignored = ''
        for patcher in [mock.patch.object(prepare, 'ROOT', self.root),
                        mock.patch.object(prepare, 'PINNED_FILES', {k: hashes(v) for k, v in self.sources.items()}),
                        mock.patch.object(prepare, 'git', side_effect=self.git)]:
            patcher.start(); self.addCleanup(patcher.stop)

    def git(self, path, *args):
        self.assertEqual(path, self.action)
        return {('rev-parse', '--show-toplevel'): self.action.as_posix(),
                ('rev-parse', 'HEAD'): self.head,
                ('cat-file', '-t', prepare.PIN): self.object_type,
                ('rev-parse', prepare.PIN + '^{commit}'): self.peeled,
                ('remote', 'get-url', 'origin'): self.origin,
                ('status', '--porcelain', '--untracked-files=all'): self.dirty,
                ('ls-files', '--others', '--ignored', '--exclude-standard'): self.ignored}[args]

    def call(self):
        return prepare.prepare(prepare.OWNED, prepare.evidence_relative(34), api_level=34)

    def assert_unchanged(self):
        self.assertEqual((self.action / 'lib/emulator-manager.js').read_bytes(), self.sources['lib/emulator-manager.js'])

    def test_only_the_one_menu_statement_changes_and_paths_use_argv(self):
        result = self.call()
        original = self.sources['lib/emulator-manager.js']
        actual = (self.action / 'lib/emulator-manager.js').read_bytes()
        self.assertEqual(result['replacements'], 1)
        self.assertEqual(result['action_pin_object'], prepare.PIN)
        self.assertEqual(result['action_commit'], prepare.COMMIT)
        self.assertEqual(result['expected_api'], 34)
        self.assertNotIn(prepare.MENU, actual)
        self.assertIn(b"await exec.exec('python3', [", actual)
        self.assertIn(b"'--serial', `emulator-${port}`", actual)
        self.assertIn(b"'--expected-api', \"34\"", actual)
        self.assertEqual(actual.splitlines()[0], original.splitlines()[0])
        self.assertEqual(actual.splitlines()[-1], original.splitlines()[-1])
        self.assertEqual(len(actual.splitlines()), len(original.splitlines()))
        self.assertEqual(hashlib.sha256(actual).hexdigest(), result['patched_sha256'])
        for name in ('action.yml', 'lib/main.js'):
            self.assertEqual((self.action / name).read_bytes(), self.sources[name])

    def test_wrong_head_origin_dirty_or_ignored_files_prevent_any_write(self):
        for field, value in [('head', '0' * 40), ('peeled', '1' * 40), ('object_type', 'commit'),
                             ('origin', 'https://evil.invalid/action'),
                             ('dirty', ' M lib/main.js'), ('ignored', 'ignored.js')]:
            with self.subTest(field=field), mock.patch.object(self, field, value):
                with self.assertRaises(ValueError): self.call()
                self.assert_unchanged()

    def test_any_critical_file_hash_mismatch_prevents_patch(self):
        for name in self.sources:
            with self.subTest(name=name):
                path = self.action / name; original = path.read_bytes()
                path.write_bytes(original + b'corruption')
                with self.assertRaisesRegex(ValueError, 'identity mismatch'): self.call()
                path.write_bytes(original)
                self.assert_unchanged()

    def test_missing_or_multiple_menu_lines_are_refused_even_with_matching_fixture_hash(self):
        path = self.action / 'lib/emulator-manager.js'
        for source in [b'no menu\n', prepare.MENU * 2]:
            path.write_bytes(source)
            fixture_hashes = {k: hashes(source if k == 'lib/emulator-manager.js' else v) for k, v in self.sources.items()}
            with mock.patch.object(prepare, 'PINNED_FILES', fixture_hashes):
                with self.assertRaisesRegex(ValueError, 'exactly one'): self.call()
            self.assertEqual(path.read_bytes(), source)

    def test_global_cache_or_other_checkout_cannot_be_patched(self):
        with self.assertRaisesRegex(ValueError, 'owned emulator'):
            prepare.prepare(Path('artifacts/../_actions/cache'), prepare.evidence_relative(34), api_level=34)
        self.assert_unchanged()

    def test_symlink_path_is_refused(self):
        original = Path.is_symlink
        with mock.patch.object(Path, 'is_symlink', lambda value: value == self.action or original(value)):
            with self.assertRaisesRegex(ValueError, 'symlinked'): self.call()
        self.assert_unchanged()

    def test_action_must_have_its_own_git_directory_and_existing_dependencies(self):
        (self.action / '.git').rmdir(); (self.action / '.git').write_text('gitdir: elsewhere')
        with self.assertRaisesRegex(ValueError, 'separate owned'): self.call()
        self.assert_unchanged()
        (self.action / '.git').unlink(); (self.action / '.git').mkdir()
        (self.action / 'node_modules').rmdir()
        with self.assertRaisesRegex(ValueError, 'original checked-in dependencies'): self.call()
        self.assert_unchanged()

    def test_a_second_preparation_is_not_an_implicit_patch_retry(self):
        self.call()
        after = (self.action / 'lib/emulator-manager.js').read_bytes()
        with self.assertRaisesRegex(ValueError, 'identity mismatch'): self.call()
        self.assertEqual((self.action / 'lib/emulator-manager.js').read_bytes(), after)

    def test_each_matrix_api_is_bound_into_the_single_replacement_and_evidence_path(self):
        for api in (26, 29, 33, 34, 35, 36):
            with self.subTest(api=api):
                (self.action / 'lib/emulator-manager.js').write_bytes(self.sources['lib/emulator-manager.js'])
                result = prepare.prepare(prepare.OWNED, prepare.evidence_relative(api), api_level=api)
                patched = (self.action / 'lib/emulator-manager.js').read_bytes()
                self.assertEqual(result['expected_api'], api)
                self.assertIn(f"'--expected-api', \"{api}\"".encode(), patched)
                self.assertIn(f'api-{api}'.encode(), patched)
                self.assertEqual(len(patched.splitlines()), len(self.sources['lib/emulator-manager.js'].splitlines()))

    def test_unsupported_api_or_mismatched_evidence_is_refused_before_patching(self):
        for api in (25, 27, 37, -1, True, '34', None):
            with self.subTest(api=api), self.assertRaises(ValueError):
                prepare.prepare(prepare.OWNED, Path('artifacts/release/android_emulator_smoke/api-34'), api_level=api)
            self.assert_unchanged()
        with self.assertRaisesRegex(ValueError, 'owned emulator'):
            prepare.prepare(prepare.OWNED, prepare.evidence_relative(34), api_level=29)
        self.assert_unchanged()


if __name__ == '__main__':
    unittest.main()
