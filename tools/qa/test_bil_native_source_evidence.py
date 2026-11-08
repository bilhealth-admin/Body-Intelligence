"""Real ZIP and metadata negative fixtures; no CI/device/signing acceptance."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import shutil
import stat
import tempfile
import unittest
from unittest import mock
import zipfile

import bil_native_source_evidence as gate

ROOT = Path(__file__).resolve().parents[2]
BRANCH = 'codex/bil43-android35-verified-20261108'
SHA, TREE = 'a' * 40, 'b' * 40
CRYPTO_DRIVER = b"// Copyright 2014 The Flutter Authors. All rights reserved.\n// Use of this source code is governed by a BSD-style license that can be\n// found in the LICENSE file.\n\nimport 'package:integration_test/integration_test_driver.dart';\n\nFuture<void> main() => integrationDriver(writeResponseOnFailure: true);\n"


class Fixture:
    def __init__(self, folder, device='iphone'):
        self.device, self.path = device, Path(folder) / (device + '.zip')
        self.names = gate.native_runner_test_names(ROOT)
        self.pins = gate.native_source_pins(ROOT, device)
        self.run = {'id': 101 if device == 'iphone' else 102, 'run_attempt': 1,
            'head_sha': SHA, 'head_branch': BRANCH, 'repository': {'id': 42, 'full_name': gate.REPOSITORY},
            'path': f'.github/workflows/bil39_{device}_native.yml', 'event': 'push',
            'status': 'completed', 'conclusion': 'success'}
        self.run['html_url'] = f'https://github.com/{gate.REPOSITORY}/actions/runs/{self.run["id"]}'
        self.attempt = {**self.run, 'run_started_at': '2026-11-08T00:00:00Z', 'updated_at': '2026-11-08T00:02:00Z'}
        self.jobs = [{'id': 1001, 'name': gate.native_job_name(device), 'run_id': self.run['id'],
            'run_attempt': 1, 'head_sha': SHA, 'status': 'completed', 'conclusion': 'success'}]
        self.meta = {'id': 201 if device == 'iphone' else 202, 'expired': False,
            'name': f'bil-native-{device}-{SHA}-r{self.run["id"]}-a1',
            'workflow_run': {'id': self.run['id'], 'head_sha': SHA, 'head_branch': BRANCH, 'repository_id': 42},
            'created_at': '2026-11-08T00:01:00Z'}
        provenance = {'schema': 'bil.native-source-reusable.v1', 'application_source_sha': SHA,
            'application_source_tree': TREE, 'repository': gate.REPOSITORY,
            'caller_workflow': self.run['path'],
            'caller_workflow_ref': gate.REPOSITORY + '/' + self.run['path'] + '@refs/heads/' + BRANCH,
            'caller_ref': 'refs/heads/' + BRANCH, 'reusable_workflow': gate.REUSABLE,
            'run_id': str(self.run['id']), 'run_attempt': '1', 'device': device, 'qa_harness_build': 39,
            'source_scope_hashes': self.pins, 'signed_artifact_acceptance': False, 'physical_device_acceptance': False}
        self.files = {'controller-provenance.json': self.encode(provenance),
            'crypto-driver.dart': CRYPTO_DRIVER, 'unused-crc-fixture.txt': b'UNUSED_CRC_VALUE'}
        scopes = []
        for kind in gate.SCOPES:
            label = device + '-' + kind
            log = b'00:01 +8: All tests passed!\n'
            result = {'label': label + '-drive', 'raw_returncode': 0, 'effective_returncode': 0,
                'timed_out': False, 'supervisor_error': None, 'launch_error': None,
                'first_test_after_seconds': 1, 'terminal_summary_after_seconds': 2,
                'native_failure_summary_seen': False, 'output_complete': True,
                'native_summary': log.decode().strip(), 'output_sha256': gate.digest(log)}
            raw = self.encode(result)
            self.files[label + '.log'], self.files[label + '-drive-result.json'] = log, raw
            scopes.append({'kind': kind, 'result_sha256': gate.digest(raw), 'log_sha256': gate.digest(log),
                'summary': result['native_summary']})
        summary = {'totalTestCount': len(self.names), 'passedTests': len(self.names),
            'failedTests': 0, 'skippedTests': 0, 'testNames': sorted(self.names)}
        self.files['runner-tests/runner-tests-result.json'] = self.encode({'status': 'PASS', 'build_number': '39',
            'source_test_sha256': self.pins['ios/RunnerTests/RunnerTests.swift'], 'summary': summary})
        self.files['runner-tests/runner-tests-summary.json'] = self.encode({
            'totalTestCount': len(self.names), 'passedTests': len(self.names), 'failedTests': 0,
            'skippedTests': 0, 'expectedFailures': 0})
        self.files['runner-tests/runner-tests.log'] = ('\n'.join(
            "Test Case '-[RunnerTests.RunnerTests " + name + "]' passed (0.01 seconds)."
            for name in sorted(self.names))).encode()
        self.files['native-complete-result.json'] = self.encode({'schema': 'bil39.single-device-native.v1',
            'source_sha': SHA, 'device': device, 'status': 'PASS', 'scopes': scopes, 'xctest': summary})

    @staticmethod
    def encode(value):
        return json.dumps(value, sort_keys=True).encode()

    def edit(self, name, transform):
        value = json.loads(self.files[name]); transform(value); self.files[name] = self.encode(value)

    def write(self, extra=(), corrupt=False):
        with zipfile.ZipFile(self.path, 'w', compression=zipfile.ZIP_STORED) as archive:
            for name, value in self.files.items():
                archive.writestr(name, value)
            for name, value in extra:
                archive.writestr(name, value)
        if corrupt:
            raw = self.path.read_bytes().replace(b'UNUSED_CRC_VALUE', b'CORRUPTCRC_VALUE', 1)
            self.path.write_bytes(raw)
        self.meta.update(size_in_bytes=self.path.stat().st_size, digest='sha256:' + gate.digest(self.path.read_bytes()))

    def validate(self):
        return gate.validate_native_artifact(self.run, self.jobs, self.meta, self.path,
            device=self.device, source_sha=SHA, source_tree=TREE, source_branch=BRANCH,
            source_scope_hashes=self.pins, expected_runner_names=self.names, source_root=ROOT, attempt=self.attempt)


class NativeEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bil-native-evidence-')
        self.addCleanup(self.temp.cleanup)

    def fixture(self, device='iphone'):
        return Fixture(self.temp.name, device)

    def test_both_real_zip_targets_with_all_scopes_and_named_xctest_are_required(self):
        rows = []
        for device in gate.DEVICES:
            fixture = self.fixture(device); fixture.write(); rows.append(fixture.validate())
        proof = gate.require_native_pair(rows, source_sha=SHA, source_tree=TREE)
        self.assertEqual(proof['devices'], ['iphone', 'ipad'])
        self.assertTrue(all(row['xctest']['passedTests'] == 8 for row in rows))
        for invalid in ([], rows[:1], [rows[0], rows[0]], [rows[0], {**rows[1], 'source_sha': 'e90e04890d5c322cfd8b3554ff1f03fb3165414c'}]):
            with self.subTest(count=len(invalid)), self.assertRaises(ValueError):
                gate.require_native_pair(invalid, source_sha=SHA, source_tree=TREE)

    def test_failed_skipped_missing_duplicate_foreign_or_pending_jobs_fail_closed(self):
        for kind in ('failure', 'skipped', 'missing', 'duplicate', 'foreign', 'pending', 'old_attempt'):
            fixture = self.fixture(); fixture.write()
            if kind == 'missing': fixture.jobs = []
            elif kind == 'duplicate': fixture.jobs += [deepcopy(fixture.jobs[0])]
            elif kind == 'foreign': fixture.jobs[0]['head_sha'] = 'd' * 40
            elif kind == 'pending': fixture.jobs[0]['status'] = 'in_progress'
            elif kind == 'old_attempt': fixture.jobs[0]['run_attempt'] = 2
            else: fixture.jobs[0]['conclusion'] = kind
            with self.subTest(kind=kind), self.assertRaises(ValueError): fixture.validate()

    def test_old_source_foreign_repo_expired_artifact_and_wrong_current_attempt_fail_closed(self):
        mutations = [lambda f: f.run.update(head_sha='e90e04890d5c322cfd8b3554ff1f03fb3165414c'),
            lambda f: f.run['repository'].update(full_name='other/repository'),
            lambda f: f.meta['workflow_run'].update(repository_id=99),
            lambda f: f.meta.update(expired=True), lambda f: f.attempt.update(run_attempt=2),
            lambda f: f.meta.update(name=f.meta['name'].replace('-a1', '-a0')),
            lambda f: f.meta.update(created_at='2026-11-07T23:59:59Z'),
            lambda f: f.meta.update(created_at='2026-11-08T00:02:01Z'),
            lambda f: f.meta.update(digest='sha256:' + '0' * 64), lambda f: f.meta.update(size_in_bytes=1),
            lambda f: f.run.update(conclusion='failure'), lambda f: f.run.update(event='pull_request')]
        for index, mutate in enumerate(mutations):
            fixture = self.fixture(); fixture.write(); mutate(fixture)
            with self.subTest(index=index), self.assertRaises(ValueError): fixture.validate()

    def test_actual_zip_crc_is_verified_even_for_an_unused_member(self):
        fixture = self.fixture(); fixture.write(corrupt=True)
        with self.assertRaises(ValueError): fixture.validate()

    def test_unsafe_duplicate_symlink_and_absolute_zip_paths_are_rejected(self):
        link = zipfile.ZipInfo('unsafe-link'); link.external_attr = (stat.S_IFLNK | 0o777) << 16
        backslash = zipfile.ZipInfo('backslash')
        # Windows ZipInfo normalizes string inputs before writing. Set the
        # actual archived bytes explicitly so this is an unsafe ZIP fixture.
        backslash.filename = backslash.orig_filename = 'back\\slash'
        extras = [[('../escape', b'x')], [('/absolute', b'x')], [('C:/escape', b'x')],
            [(backslash, b'x')], [(link, b'outside')], [('controller-provenance.json', b'{}')]]
        for index, extra in enumerate(extras):
            fixture = self.fixture()
            with mock.patch('warnings.warn'): fixture.write(extra=extra)
            with self.subTest(index=index), self.assertRaises(ValueError): fixture.validate()

    def test_archive_member_total_and_expansion_resource_caps_are_enforced(self):
        fixture = self.fixture(); fixture.write()
        for name, bound in [('MAX_ARCHIVE', 1), ('MAX_MEMBER', 1), ('MAX_MEMBERS', 1), ('MAX_EXPANDED', 1)]:
            with self.subTest(cap=name), mock.patch.object(gate, name, bound), self.assertRaises(ValueError): fixture.validate()

    def test_missing_scope_incomplete_drive_and_untied_logs_cannot_be_success(self):
        mutations = [lambda f: f.files.pop('native-complete-result.json'),
            lambda f: f.edit('native-complete-result.json', lambda v: v['scopes'].pop()),
            lambda f: f.edit('native-complete-result.json', lambda v: v.update(device='ipad')),
            lambda f: f.edit('iphone-system-crypto-drive-result.json', lambda v: v.update(timed_out=True)),
            lambda f: f.edit('iphone-native-settings-drive-result.json', lambda v: v.update(output_complete=False)),
            lambda f: f.files.update({'iphone-feature-splashes.log': b'00:01 +8: All tests passed!\nFOREIGN'}),
            lambda f: f.files.update({'crypto-driver.dart': b'Unreviewed driver'})]
        for index, mutate in enumerate(mutations):
            fixture = self.fixture(); mutate(fixture); fixture.write()
            with self.subTest(index=index), self.assertRaises(ValueError): fixture.validate()

    def test_provenance_cannot_borrow_another_source_target_or_declared_registry(self):
        changes = [{'application_source_sha': 'e90e04890d5c322cfd8b3554ff1f03fb3165414c'},
            {'device': 'ipad'}, {'application_source_tree': 'f' * 40}, {'source_scope_hashes': {}},
            {'repository': 'other/repository'}, {'run_attempt': '2'}, {'signed_artifact_acceptance': True}]
        for index, change in enumerate(changes):
            fixture = self.fixture(); fixture.edit('controller-provenance.json', lambda v: v.update(change)); fixture.write()
            with self.subTest(index=index), self.assertRaises(ValueError): fixture.validate()

    def test_xctest_requires_every_declared_original_and_new_name_without_skip_or_duplicate(self):
        changes = [{'passedTests': 5, 'totalTestCount': 5}, {'skippedTests': 1}, {'failedTests': 1},
            {'testNames': sorted(gate.ORIGINAL_TEST_NAMES)}, {'testNames': ['testForeign'] * 8}]
        for index, change in enumerate(changes):
            fixture = self.fixture()
            fixture.edit('runner-tests/runner-tests-result.json', lambda v: v['summary'].update(change)); fixture.write()
            with self.subTest(index=index), self.assertRaises(ValueError): fixture.validate()

    def test_xctest_count_receipt_cannot_hide_foreign_missing_or_duplicate_actual_execution(self):
        for kind in ('foreign', 'missing', 'duplicate'):
            fixture = self.fixture()
            name = 'runner-tests/runner-tests.log'
            if kind == 'foreign': fixture.files[name] = fixture.files[name].replace(b'RunnerTests.RunnerTests', b'ForeignTests.RunnerTests')
            elif kind == 'missing': fixture.files[name] = fixture.files[name].splitlines()[0]
            else: fixture.files[name] += b'\n' + fixture.files[name].splitlines()[0]
            fixture.write()
            with self.subTest(kind=kind), self.assertRaises(ValueError): fixture.validate()


class WorkflowContractTests(unittest.TestCase):
    def test_actual_both_callers_use_same_commit_and_all_current_tests(self):
        for device in gate.DEVICES:
            proof = gate.validate_native_workflow_contract(ROOT, device, BRANCH)
            self.assertEqual(proof['job_name'], gate.native_job_name(device))
            self.assertTrue(gate.ORIGINAL_TEST_NAMES.issubset(proof['runner_test_names']))
            self.assertGreaterEqual(len(proof['runner_test_names']), 8)

    def test_floating_ref_wrong_device_or_optional_caller_is_not_an_equivalent_lane(self):
        original = (ROOT / '.github/workflows/bil39_iphone_native.yml').read_text()
        mutations = [original.replace('./' + gate.REUSABLE, 'other/repo/' + gate.REUSABLE + '@main'),
            original.replace('device: iphone', 'device: ipad'),
            original.replace('    uses:', '    if: false\n    uses:'),
            original.replace('  push:\n', '  push:\n    paths: [lib/**]\n')]
        for index, source in enumerate(mutations):
            with tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                for name in gate.native_source_paths('iphone') + ['.github/scripts/bil_native_bounded_command.py']:
                    target = root / name; target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(ROOT / name, target)
                (root / '.github/workflows/bil39_iphone_native.yml').write_text(source)
                with self.subTest(index=index), self.assertRaises(ValueError):
                    gate.validate_native_workflow_contract(root, 'iphone', BRANCH)


if __name__ == '__main__': unittest.main()
