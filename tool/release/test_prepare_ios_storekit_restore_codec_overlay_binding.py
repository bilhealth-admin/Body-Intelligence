"""Actual generated-SPM binding regressions; no SDK or real PUB_CACHE.

The existing41 tests remain a separate suite. This file composes their owned
filesystem fixture without inheriting or accidentally rerunning its tests.
POSIX atomic replacement executes only on actual POSIX; Windows junction
cases prove read-only success/rejection and safe refusal of non-atomic writes.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

import test_prepare_ios_storekit_restore_codec_overlay as original

H = original.H
PLUGIN = original.PLUGIN


class NativeBindingActualTests(unittest.TestCase):
    def setUp(self):
        self.fixture = original.OverlayActualTests(methodName='runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)

    def tearDown(self):
        self.fixture.tearDown()

    def snapshot(self):
        f = self.fixture
        aliases = f.project / 'ios/Flutter/ephemeral/Packages/.packages'
        links = {}
        if aliases.is_dir():
            for child in aliases.iterdir():
                if child.is_symlink() or getattr(child, 'is_junction', lambda: False)():
                    links[child.name] = os.readlink(child)
        return original.tree(f.project), original.tree(f.source), links

    def reject_unchanged(self, function):
        before = self.snapshot()
        with self.assertRaises(ValueError):
            function()
        self.assertEqual(self.snapshot(), before, 'Rejection must not mutate any source, overlay, metadata or alias')

    def remove_fixture_alias(self):
        f = self.fixture
        assert f.native_alias.parent == f.project / 'ios/Flutter/ephemeral/Packages/.packages'
        assert f.project.resolve().is_relative_to(f.base.resolve())
        if os.name == 'nt':
            self.assertTrue(f.native_alias.is_junction())
            os.rmdir(f.native_alias)  # This test owns this exact junction only.
        else:
            self.assertTrue(f.native_alias.is_symlink())
            f.native_alias.unlink()

    def ready(self):
        f = self.fixture
        result = f.prepare()
        if os.name == 'nt':
            f.make_native_graph(target=f.destination / H.NATIVE_PACKAGE)
        return result

    def verify(self):
        return H.prepare(self.fixture.project, verify_native_binding=True)

    def test_strict_correct_binding_is_read_only_and_reports_actual_hash(self):
        self.ready()
        f = self.fixture
        before = self.snapshot()
        result = self.verify()
        self.assertEqual(result['status'], 'verified-native-binding')
        self.assertEqual(result['native_binding']['native_swift_sha256'], original.AFTER)
        self.assertEqual(result['native_binding']['status'], 'verified')
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(original.tree(f.source), f.cache_manifest)

    def test_strict_cli_uses_actual_read_only_path(self):
        self.ready()
        before = self.snapshot()
        run = subprocess.run([
            sys.executable, '-B', str(original.HELPER), '--project-root',
            str(self.fixture.project), '--verify-native-binding',
        ], capture_output=True, text=True, timeout=20)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(json.loads(run.stdout)['status'], 'verified-native-binding')
        self.assertEqual(self.snapshot(), before)

    def test_json_correct_but_old_native_alias_fails_before_xcode_without_writes(self):
        self.ready()
        f = self.fixture
        self.remove_fixture_alias()
        f.junction(f.native_alias, f.source / H.NATIVE_PACKAGE)
        f.assert_bound()  # This is the actual053 false-positive state.
        self.reject_unchanged(self.verify)

    @unittest.skipUnless(os.name == 'nt', 'Actual Windows junction refusal case')
    def test_windows_stale_junction_prepare_refuses_non_atomic_swap_and_preserves(self):
        self.ready()
        f = self.fixture
        self.remove_fixture_alias()
        f.junction(f.native_alias, f.source / H.NATIVE_PACKAGE)
        self.reject_unchanged(f.prepare)

    @unittest.skipIf(os.name == 'nt', 'Atomic symlink replacement requires actual POSIX CI')
    def test_posix_original_native_alias_rebound_atomically_only_its_link(self):
        f = self.fixture
        before_manifest = f.native_manifest.read_bytes()
        other = os.readlink(f.other_native_alias)
        original_native = f.native_alias.resolve()
        self.assertEqual(original_native, (f.source / H.NATIVE_PACKAGE).resolve())
        result = f.prepare()
        self.assertEqual(result['native_binding']['status'], 'rebound')
        self.assertEqual(f.native_alias.resolve(), (f.destination / H.NATIVE_PACKAGE).resolve())
        self.assertEqual(f.native_manifest.read_bytes(), before_manifest)
        self.assertEqual(os.readlink(f.other_native_alias), other)
        f.assert_other_overlays()
        self.assertEqual(original.tree(f.source), f.cache_manifest)
        before = self.snapshot()
        self.assertEqual(f.prepare()['status'], 'already-prepared')
        self.assertEqual(self.snapshot(), before)

    def test_new_overlay_basename_alias_is_allowed_and_verified(self):
        self.ready()
        f = self.fixture
        old_name = f.native_alias.name
        self.remove_fixture_alias()
        f.native_alias = f.native_alias.with_name(PLUGIN)
        f.junction(f.native_alias, f.destination / H.NATIVE_PACKAGE)
        f.native_manifest.write_text(
            f.native_manifest.read_text(encoding='utf-8').replace(old_name, PLUGIN),
            encoding='utf-8',
        )
        self.assertEqual(self.verify()['status'], 'verified-native-binding')

    def test_duplicate_named_dependency_is_rejected_read_only(self):
        self.ready()
        f = self.fixture
        text = f.native_manifest.read_text(encoding='utf-8')
        entry = '  .package(name: "in_app_purchase_storekit", path: "../.packages/' + f.native_alias.name + '"),\n'
        f.native_manifest.write_text(text.replace('])', entry + '])'), encoding='utf-8')
        self.reject_unchanged(self.verify)
        fresh = original.OverlayActualTests(methodName='runTest')
        fresh.setUp()
        self.addCleanup(fresh.doCleanups)
        self.addCleanup(fresh.tearDown)
        if os.name == 'nt':
            fresh.make_native_graph()
        before_manifest = fresh.native_manifest.read_text(encoding='utf-8')
        duplicate = '  .package(name: "in_app_purchase_storekit", path: "../.packages/' + fresh.native_alias.name + '"),\n'
        fresh.native_manifest.write_text(before_manifest.replace('])', duplicate + '])'), encoding='utf-8')
        before = original.tree(fresh.project), original.tree(fresh.source), os.readlink(fresh.native_alias)
        with self.assertRaisesRegex(ValueError, 'exact_one_named_storekit_spm_dependency_required'):
            fresh.prepare()
        self.assertFalse(fresh.destination.exists(), 'Native preflight error must not leave a half-initialized overlay')
        self.assertEqual((original.tree(fresh.project), original.tree(fresh.source), os.readlink(fresh.native_alias)), before)

    def test_missing_named_dependency_is_rejected_read_only(self):
        self.ready()
        f = self.fixture
        f.native_manifest.write_text(f.native_manifest.read_text(encoding='utf-8').replace(
            'name: "in_app_purchase_storekit"', 'name: "not_the_storekit_plugin"'), encoding='utf-8')
        self.reject_unchanged(self.verify)

    def test_anonymous_duplicate_storekit_path_cannot_evade_named_cardinality(self):
        self.ready()
        f = self.fixture
        text = f.native_manifest.read_text(encoding='utf-8')
        entry = '  .package(path: "../.packages/' + f.native_alias.name + '"),\n'
        f.native_manifest.write_text(text.replace('])', entry + '])'), encoding='utf-8')
        self.reject_unchanged(self.verify)

    def test_commented_dependency_cannot_authorize_missing_actual_entry(self):
        self.ready()
        f = self.fixture
        f.native_manifest.write_text(
            '// .package(name: "in_app_purchase_storekit", path: "../.packages/' + f.native_alias.name + '")\n'
            'let package = Package(name: "empty", dependencies: [])\n', encoding='utf-8')
        self.reject_unchanged(self.verify)

    def test_nested_comment_is_ignored_while_real_entry_is_preserved(self):
        self.ready()
        f = self.fixture
        text = f.native_manifest.read_text(encoding='utf-8')
        f.native_manifest.write_text('/* outer /* .package(name: "in_app_purchase_storekit", path: "bad") */ outer */\n' + text, encoding='utf-8')
        self.assertEqual(self.verify()['status'], 'verified-native-binding')

    def test_absolute_escape_and_foreign_alias_paths_reject_without_writes(self):
        self.ready()
        f = self.fixture
        text = f.native_manifest.read_text(encoding='utf-8')
        for bad in ['/tmp/foreign', '../../.packages/' + PLUGIN, '../.packages/foreign', '../.packages/' + PLUGIN + '/../escape']:
            with self.subTest(bad=bad):
                f.native_manifest.write_text(text.replace('../.packages/' + f.native_alias.name, bad), encoding='utf-8')
                self.reject_unchanged(self.verify)

    def test_nonliteral_storekit_path_is_not_executed_or_accepted(self):
        self.ready()
        f = self.fixture
        f.native_manifest.write_text(f.native_manifest.read_text(encoding='utf-8').replace(
            '"../.packages/' + f.native_alias.name + '"', 'arbitraryExpression()'), encoding='utf-8')
        self.reject_unchanged(self.verify)

    def test_foreign_native_target_cannot_borrow_overlay_json_proof(self):
        self.ready()
        f = self.fixture
        foreign = f.base / 'foreign-native'
        f.make_package(foreign)
        self.remove_fixture_alias()
        f.junction(f.native_alias, foreign / H.NATIVE_PACKAGE)
        self.reject_unchanged(self.verify)

    def test_regular_directory_cannot_stand_in_for_generated_link(self):
        self.ready()
        f = self.fixture
        self.remove_fixture_alias()
        f.native_alias.mkdir()
        self.reject_unchanged(self.verify)

    def test_intermediate_target_alias_cannot_hide_a_second_reparse_point(self):
        self.ready()
        f = self.fixture
        bridge = f.base / 'native-target-bridge'
        f.junction(bridge, f.destination / H.NATIVE_PACKAGE)
        self.remove_fixture_alias()
        f.junction(f.native_alias, bridge)
        self.reject_unchanged(self.verify)

    def test_missing_alias_rejected_without_generating_or_repairing_it(self):
        self.ready()
        self.remove_fixture_alias()
        self.reject_unchanged(self.verify)

    def test_missing_manifest_rejected_without_generating_it(self):
        self.ready()
        self.fixture.native_manifest.unlink()
        self.reject_unchanged(self.verify)

    def test_escaped_managed_alias_directory_rejects_before_resolution(self):
        self.ready()
        f = self.fixture
        aliases = f.native_alias.parent
        backup = aliases.with_name('owned-fixture-aliases-backup')
        assert aliases.resolve().is_relative_to(f.base.resolve())
        aliases.rename(backup)
        f.junction(aliases, backup)
        self.reject_unchanged(self.verify)

    def test_native_source_drift_rejects_even_with_existing_marker(self):
        self.ready()
        file = self.fixture.destination / original.REL
        file.write_bytes(file.read_bytes() + b'\n// drift')
        self.reject_unchanged(self.verify)

    def test_stale_native_atomic_temp_is_never_deleted_or_overwritten(self):
        self.ready()
        f = self.fixture
        temp = f.native_alias.with_name(f.native_alias.name + '.bil-storekit-codec-new')
        temp.write_bytes(b'Preserve an unknown existing temp')
        self.reject_unchanged(self.verify)
        self.reject_unchanged(f.prepare)

    def test_strict_mode_never_invokes_any_metadata_writer(self):
        self.ready()
        before = self.snapshot()
        real = H.atomic_json
        def forbidden(*args, **kwargs):
            raise AssertionError('Read-only native verification invoked a writer')
        H.atomic_json = forbidden
        try:
            self.assertEqual(self.verify()['status'], 'verified-native-binding')
        finally:
            H.atomic_json = real
        self.assertEqual(self.snapshot(), before)


def load_tests(loader, tests, pattern):
    suite = loader.loadTestsFromTestCase(NativeBindingActualTests)
    if suite.countTestCases() != 22:
        raise RuntimeError('Expected exactly22 native binding regressions')
    return suite


if __name__ == '__main__':
    unittest.main(verbosity=2)
