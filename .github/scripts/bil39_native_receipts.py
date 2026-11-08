"""Require real terminal results for every scope on one exact-source device."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

from bil_ios_runner_tests import expected_tests, verified_summary

KINDS = ('system-crypto', 'native-settings', 'feature-splashes')


def verify(root, *, label, sha, source_root=None):
    root = Path(root).resolve()
    if label not in ('iphone', 'ipad') or not re.fullmatch('[a-f0-9]{40}', sha):
        raise ValueError('One exact-source native device is required')
    rows = []
    for kind in KINDS:
        path = root / f'{label}-{kind}-drive-result.json'
        log = root / f'{label}-{kind}.log'
        if path.is_symlink() or log.is_symlink():
            raise ValueError('Native evidence cannot be symlinked')
        value = json.loads(path.read_text(encoding='utf-8'))
        if (value.get('label') != f'{label}-{kind}-drive' or
                value.get('effective_returncode') != 0 or value.get('raw_returncode') != 0 or
                value.get('timed_out') is not False or value.get('supervisor_error') is not None or
                value.get('launch_error') is not None or value.get('first_test_after_seconds') is None or
                value.get('terminal_summary_after_seconds') is None or
                value.get('native_failure_summary_seen') is not False or
                not re.fullmatch(r'\d{1,2}:\d{2}(?:\.\d+)? \+\d+: All tests passed[.!]',
                                 value.get('native_summary') or '') or
                value.get('output_complete') is not True or
                hashlib.sha256(log.read_bytes()).hexdigest() != value.get('output_sha256')):
            raise ValueError('Missing, incomplete or failed actual native execution: ' + kind)
        rows.append({'kind': kind, 'result_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'log_sha256': value['output_sha256'], 'summary': value['native_summary']})
    source_root = (Path(source_root) if source_root else Path(__file__).resolve().parents[2]).resolve()
    source = source_root / 'ios/RunnerTests/RunnerTests.swift'
    if (source.is_symlink() or not source.is_file() or not source.resolve().is_relative_to(source_root)):
        raise ValueError('Actual regular RunnerTests source is required')
    names = expected_tests(source.read_text(encoding='utf-8'))
    xctest = root / 'runner-tests/runner-tests-result.json'
    summary = root / 'runner-tests/runner-tests-summary.json'
    execution_log = root / 'runner-tests/runner-tests.log'
    if any(path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root)
           for path in (xctest, summary, execution_log)):
        raise ValueError('Actual regular XCTest result, summary and named execution log are required')
    value = json.loads(xctest.read_text(encoding='utf-8'))
    actual = verified_summary(summary.read_text(encoding='utf-8'), execution_log.read_text(encoding='utf-8'), names)
    if (value.get('status') != 'PASS' or value.get('build_number') != '39' or
            value.get('source_test_sha256') != hashlib.sha256(source.read_bytes()).hexdigest() or
            any(type(value.get('summary', {}).get(key)) is not int for key in
                ('totalTestCount', 'passedTests', 'failedTests', 'skippedTests')) or
            value.get('summary') != actual):
        raise ValueError('Every original and newly declared actual named RunnerTest must pass on this source')
    return {'schema': 'bil39.single-device-native.v1', 'source_sha': sha, 'device': label,
            'status': 'PASS', 'scopes': rows, 'xctest': value['summary'],
            'scope': 'Actual simulator tests; signed IPA and physical-device acceptance remain separate'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--label', choices=('iphone', 'ipad'), required=True)
    parser.add_argument('--source-sha', required=True)
    args = parser.parse_args()
    if subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip() != args.source_sha:
        raise ValueError('Native checkout source differs')
    result = verify(args.root, label=args.label, sha=args.source_sha)
    (args.root / 'native-complete-result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'device': args.label, 'status': result['status'], 'source_sha': args.source_sha}))


if __name__ == '__main__':
    main()
