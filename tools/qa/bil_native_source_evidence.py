"""Strict same-commit, single-device native evidence for future release gates.

Only authenticated metadata and the actual original ZIP are inputs. This
verifies synthetic source QA, never signed-build or physical-device approval.
No network, credentials, device operation or artifact extraction occurs here.
"""
from __future__ import annotations

from datetime import datetime
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import zipfile

REPOSITORY = 'bilhealth-admin/Body-Intelligence'
REUSABLE = '.github/workflows/bil39_ios_native_reusable.yml'
DEVICES = ('iphone', 'ipad')
SCOPES = ('system-crypto', 'native-settings', 'feature-splashes')
MAX_ARCHIVE = 1024 * 1024 * 1024
MAX_MEMBER = 256 * 1024 * 1024
MAX_MEMBERS = 20000
MAX_EXPANDED = 4 * 1024 * 1024 * 1024
CRYPTO_DRIVER_SHA256 = '919ffcd34b13d8fa70a772645eb5eda3bc25b6283d3261f83fe18efe7ec1d623'
ORIGINAL_TEST_NAMES = frozenset({
    'testAppAttestKeyStoreKeepsAccountsIsolated',
    'testAppAttestKeyStoreMigratesLegacyAccountsOneAtATime',
    'testAppAttestLegacyEntrySurvivesFailedKeychainMigration',
    'testAppAttestKeyStoreDeletesOnlyTheExpectedAccountKey',
    'testAppAttestDiscardCannotResurrectAnOlderLegacyKey',
})


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def native_job_name(device):
    require(device in DEVICES, 'One exact native device is required')
    return f'native / Native iOS source QA ({device})'


def native_source_paths(device):
    require(device in DEVICES, 'One exact native device is required')
    return [REUSABLE, f'.github/workflows/bil39_{device}_native.yml',
        '.github/scripts/bil39_ios_native_integration.sh',
        '.github/scripts/bil39_native_receipts.py',
        '.github/scripts/bil39_simulator_vm_attach.py', '.github/scripts/bil_ios_runner_tests.py',
        'integration_test/system_crypto_bridge_integration_test.dart',
        'integration_test/native_settings_polish_test.dart',
        'integration_test/native_feature_splashes_test.dart',
        'test_driver/native_settings_capture_driver.dart',
        'test_driver/native_feature_splashes_driver.dart', 'ios/RunnerTests/RunnerTests.swift']


def native_source_pins(root, device):
    root = Path(root).resolve(strict=True)
    values = {}
    for name in native_source_paths(device):
        path = root / name
        require(path.is_file() and not path.is_symlink()
            and path.resolve().is_relative_to(root), 'Native source must be a regular checkout file')
        values[name] = digest(path.read_bytes())
    return values


def _native_runner_registry(root):
    root = Path(root).resolve(strict=True)
    script = root / '.github/scripts/bil_ios_runner_tests.py'
    require(script.is_file() and not script.is_symlink(), 'Actual XCTest runner source required')
    spec = importlib.util.spec_from_file_location('bound_native_xctest_registry_' + digest(script.read_bytes()), script)
    module = importlib.util.module_from_spec(spec)
    sys.path.insert(0, str(script.parent))
    try:
        spec.loader.exec_module(module)
    finally:
        sys.path.pop(0)
    return module


def native_runner_test_names(root):
    """Reuse the actual runner's Swift declaration registry, not another regex."""
    root = Path(root).resolve(strict=True)
    module = _native_runner_registry(root)
    names = module.expected_tests((root / 'ios/RunnerTests/RunnerTests.swift').read_text())
    require(ORIGINAL_TEST_NAMES.issubset(names), 'All five original native security tests required')
    return names


def validate_native_workflow_contract(root, device, branch):
    """Fail closed on unreviewed caller layout or a floating reusable ref."""
    require(device in DEVICES and re.fullmatch(r'[A-Za-z0-9_./-]+', branch or ''),
        'An exact source branch and target are required')
    root = Path(root)
    caller = (root / f'.github/workflows/bil39_{device}_native.yml').read_text()
    reusable = (root / REUSABLE).read_text()
    push = re.search(r'^  push:\n(.*?)(?=^  [A-Za-z_]|^\S)', caller, re.M | re.S)
    require(push is not None and not re.search(r'^    (?:paths(?:-ignore)?|branches-ignore):',
        push[1], re.M), 'Native release push may not omit source paths')
    branches = re.search(r'^    branches: \[([^\]\n]+)\]$', push[1], re.M)
    require(branches is not None and branch in [value.strip() for value in branches[1].split(',')],
        'Both native source callers must select the approved push branch')
    jobs = caller.split('\njobs:\n', 1)[1]
    require(re.findall(r'^  ([\w-]+):$', jobs, re.M) == ['native']
        and re.findall(r'^    uses: (.+)$', jobs, re.M) == ['./' + REUSABLE]
        and re.findall(r'^      device: (.+)$', jobs, re.M) == [device]
        and not re.search(r'^    (?:if|steps|runs-on|strategy|secrets):', jobs, re.M),
        'Literal same-commit caller target and mandatory native job required')
    require('  workflow_call:\n' in reusable
        and '          ref: ${{ github.sha }}\n' in reusable
        and '          persist-credentials: false\n' in reusable
        and '    runs-on: macos-26\n' in reusable
        and '    timeout-minutes: 100\n' in reusable
        and '        run: bash .github/scripts/bil39_ios_native_integration.sh\n' in reusable
        and 'steps.device_guard.outcome' in reusable
        and not any(value in caller + reusable for value in ('continue-on-error', 'secrets: inherit', '@main')),
        'Reviewed native isolation, source identity and failure controls required')
    pins = native_source_pins(root, device)
    return {'device': device, 'job_name': native_job_name(device), 'source_scope_hashes': pins,
        'runner_test_names': sorted(native_runner_test_names(root))}


def _timestamp(value):
    require(isinstance(value, str), 'Explicit artifact attempt timestamp required')
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    require(result.utcoffset() is not None, 'Explicit timestamp timezone required')
    return result


def _archive_members(archive):
    # Reuses the reviewed native ZIP path/symlink/encryption/member checks.
    # Fixed bounded budgets replace the historical artifact-ID size exception.
    result = {}
    infos = archive.infolist()
    require(len(infos) <= MAX_MEMBERS, 'Native ZIP member count exceeds resource cap')
    require(sum(item.file_size for item in infos) <= MAX_EXPANDED,
        'Native ZIP expanded size exceeds resource cap')
    seen = set()
    for item in infos:
        path = PurePosixPath(item.filename)
        require(item.orig_filename == item.filename and '\\' not in item.orig_filename
            and not path.is_absolute() and '..' not in path.parts
            and not re.match(r'^[A-Za-z]:', item.filename)
            and str(path) == item.filename.rstrip('/') and not (item.flag_bits & 1)
            and stat.S_IFMT(item.external_attr >> 16) != stat.S_IFLNK,
            'Unsafe native ZIP member')
        require(item.filename not in seen and item.file_size <= MAX_MEMBER,
            'Duplicate or oversized native ZIP member')
        seen.add(item.filename)
        if not item.is_dir():
            result[item.filename] = item
    require(archive.testzip() is None, 'Native ZIP CRC verification failed')
    return result


def validate_native_artifact(run, jobs, meta, archive_path, *, device, source_sha,
        source_tree, source_branch, source_scope_hashes, expected_runner_names, source_root, attempt):
    require(device in DEVICES and re.fullmatch('[a-f0-9]{40}', source_sha or '')
        and re.fullmatch('[a-f0-9]{40}', source_tree or ''), 'Exact native source SHA/tree required')
    require(isinstance(source_scope_hashes, dict)
        and set(source_scope_hashes) == set(native_source_paths(device))
        and all(re.fullmatch('[a-f0-9]{64}', value or '') for value in source_scope_hashes.values()),
        'All actual current native source hashes required')
    require(isinstance(expected_runner_names, (set, frozenset, list, tuple))
        and len(expected_runner_names) == len(set(expected_runner_names))
        and ORIGINAL_TEST_NAMES.issubset(expected_runner_names)
        and all(re.fullmatch(r'test[A-Za-z0-9_]+', name) for name in expected_runner_names),
        'Every actual declared native XCTest name is required')
    require(source_scope_hashes == native_source_pins(source_root, device)
        and set(expected_runner_names) == native_runner_test_names(source_root),
        'Native expected registry must come from the actual current checkout')
    run_id, run_attempt = run.get('id'), run.get('run_attempt')
    caller = f'.github/workflows/bil39_{device}_native.yml'
    url = f'https://github.com/{REPOSITORY}/actions/runs/{run_id}'
    require(type(run_id) is int and run_id > 0 and type(run_attempt) is int and run_attempt > 0
        and run.get('head_sha') == source_sha and run.get('head_branch') == source_branch
        and run.get('repository', {}).get('full_name') == REPOSITORY
        and type(run['repository'].get('id')) is int and run['repository']['id'] > 0
        and run.get('path') == caller and run.get('event') == 'push'
        and run.get('status') == 'completed' and run.get('conclusion') == 'success'
        and run.get('html_url') == url, 'Exact successful native source run required')
    require(isinstance(jobs, list) and jobs and len({job.get('id') for job in jobs}) == len(jobs),
        'Complete distinct native job inventory required')
    require(all(job.get('run_id') == run_id and job.get('run_attempt') == run_attempt
        and job.get('head_sha') == source_sha
        and job.get('status') == 'completed' and job.get('conclusion') == 'success' for job in jobs),
        'Every native job must actually succeed on the current source')
    require(len([job for job in jobs if job.get('name') == native_job_name(device)]) == 1,
        'Exact composed caller/reusable native job required')
    require(attempt.get('id') == run_id and attempt.get('run_attempt') == run_attempt
        and attempt.get('head_sha') == source_sha and attempt.get('status') == 'completed'
        and attempt.get('conclusion') == 'success', 'Authenticated current attempt required')
    require(meta.get('expired') is False and type(meta.get('id')) is int and meta['id'] > 0
        and meta.get('name') == f'bil-native-{device}-{source_sha}-r{run_id}-a{run_attempt}'
        and meta.get('workflow_run', {}).get('id') == run_id
        and meta['workflow_run'].get('head_sha') == source_sha
        and meta['workflow_run'].get('head_branch') == source_branch
        and meta['workflow_run'].get('repository_id') == run['repository']['id']
        and _timestamp(attempt.get('run_started_at')) <= _timestamp(meta.get('created_at'))
        <= _timestamp(attempt.get('updated_at')),
        'Current non-expired target artifact and exact attempt window required')
    path = Path(archive_path)
    require(path.is_file() and not path.is_symlink() and type(meta.get('size_in_bytes')) is int
        and 0 < path.stat().st_size == meta['size_in_bytes'] <= MAX_ARCHIVE,
        'Exact bounded original native ZIP required')
    with path.open('rb') as stream:
        actual_digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    require(meta.get('digest') == 'sha256:' + actual_digest, 'Native original ZIP digest mismatch')
    try:
        with zipfile.ZipFile(path) as archive:
            members = _archive_members(archive)
            def raw(name):
                matches = [key for key in members if key == name or key.endswith('/' + name)]
                require(len(matches) == 1, 'Missing or ambiguous actual native evidence member')
                member = members[matches[0]]
                return archive.read(member)
            def document(name):
                body = raw(name)
                require(len(body) <= 1024 * 1024, 'Native JSON exceeds cap')
                return json.loads(body)
            provenance = document('controller-provenance.json')
            require(provenance.get('schema') == 'bil.native-source-reusable.v1'
                and provenance.get('application_source_sha') == source_sha
                and provenance.get('application_source_tree') == source_tree
                and provenance.get('repository') == REPOSITORY
                and provenance.get('caller_workflow') == caller
                and provenance.get('caller_workflow_ref') == REPOSITORY + '/' + caller + '@refs/heads/' + source_branch
                and provenance.get('caller_ref') == 'refs/heads/' + source_branch
                and provenance.get('reusable_workflow') == REUSABLE
                and provenance.get('run_id') == str(run_id) and provenance.get('run_attempt') == str(run_attempt)
                and provenance.get('device') == device and provenance.get('qa_harness_build') == 39
                and provenance.get('source_scope_hashes') == source_scope_hashes
                and provenance.get('signed_artifact_acceptance') is False
                and provenance.get('physical_device_acceptance') is False,
                'Native actual source/caller/target/provenance mismatch')
            complete = document('native-complete-result.json')
            scopes = complete.get('scopes', [])
            require(complete.get('schema') == 'bil39.single-device-native.v1'
                and complete.get('source_sha') == source_sha and complete.get('device') == device
                and complete.get('status') == 'PASS' and len(scopes) == 3
                and {row.get('kind') for row in scopes} == set(SCOPES), 'All actual native scopes required')
            for kind in SCOPES:
                name = f'{device}-{kind}'
                result_raw, log = raw(name + '-drive-result.json'), raw(name + '.log')
                result = json.loads(result_raw)
                row = next(row for row in scopes if row['kind'] == kind)
                require(result.get('label') == name + '-drive' and result.get('raw_returncode') == 0
                    and result.get('effective_returncode') == 0 and result.get('timed_out') is False
                    and result.get('supervisor_error') is None and result.get('launch_error') is None
                    and result.get('first_test_after_seconds') is not None
                    and result.get('terminal_summary_after_seconds') is not None
                    and result.get('native_failure_summary_seen') is False and result.get('output_complete') is True
                    and re.fullmatch(r'\d{1,2}:\d{2}(?:\.\d+)? \+\d+: All tests passed[.!]', result.get('native_summary') or '')
                    and digest(log) == result.get('output_sha256') == row.get('log_sha256')
                    and digest(result_raw) == row.get('result_sha256')
                    and result.get('native_summary') == row.get('summary'), 'Native actual drive/log proof mismatch')
            xctest = document('runner-tests/runner-tests-result.json')
            expected_summary = {'totalTestCount': len(expected_runner_names),
                'passedTests': len(expected_runner_names), 'failedTests': 0, 'skippedTests': 0}
            require(xctest.get('status') == 'PASS' and xctest.get('build_number') == '39'
                and xctest.get('source_test_sha256') == source_scope_hashes.get('ios/RunnerTests/RunnerTests.swift')
                and all(type(xctest.get('summary', {}).get(key)) is int
                    and xctest['summary'][key] == value for key, value in expected_summary.items())
                and len(xctest.get('summary', {}).get('testNames', [])) == len(expected_runner_names)
                and set(xctest['summary']['testNames']) == set(expected_runner_names)
                and complete.get('xctest') == xctest['summary'],
                'Every actual named XCTest must pass without failure, duplicate or skip')
            named_execution = _native_runner_registry(source_root).verified_summary(
                raw('runner-tests/runner-tests-summary.json').decode('utf-8'),
                raw('runner-tests/runner-tests.log').decode('utf-8'), set(expected_runner_names))
            require(named_execution == xctest['summary'],
                'Actual archived XCTest summary and exact named execution log required')
            require(digest(raw('crypto-driver.dart')) == CRYPTO_DRIVER_SHA256,
                'Actual pinned Flutter integration crypto driver required')
            return {'status': 'EXACT_SOURCE_NATIVE_SIMULATOR_PASS', 'device': device,
                'source_sha': source_sha, 'source_tree': source_tree, 'run_id': run_id,
                'run_attempt': run_attempt, 'artifact_id': meta['id'], 'artifact_digest': meta['digest'],
                'scopes': scopes, 'xctest': xctest['summary'], 'signed_artifact_acceptance': False,
                'physical_device_acceptance': False}
    except (zipfile.BadZipFile, EOFError, KeyError, TypeError, AttributeError, json.JSONDecodeError) as error:
        raise ValueError('Invalid native ZIP or evidence structure') from error


def require_native_pair(rows, *, source_sha, source_tree):
    require(isinstance(rows, list) and len(rows) == 2 and {row.get('device') for row in rows} == set(DEVICES)
        and len({row.get('run_id') for row in rows}) == 2
        and len({row.get('artifact_id') for row in rows}) == 2,
        'Both distinct native device runs and artifacts are mandatory')
    require(all(row.get('status') == 'EXACT_SOURCE_NATIVE_SIMULATOR_PASS'
        and row.get('source_sha') == source_sha and row.get('source_tree') == source_tree
        and row.get('signed_artifact_acceptance') is False
        and row.get('physical_device_acceptance') is False for row in rows),
        'Both native results must match the final source without claiming signed acceptance')
    return {'status': 'BOTH_EXACT_SOURCE_NATIVE_TARGETS_PASS', 'source_sha': source_sha,
        'source_tree': source_tree, 'devices': list(DEVICES), 'native_results': rows}
