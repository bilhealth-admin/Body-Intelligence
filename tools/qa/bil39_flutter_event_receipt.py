"""Retain actual exact-source Flutter outcomes; never manufacture a PASS."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess

from bil_owner_full_test_runner import Ledger, generated_comparison

EXPECTED_SKIP = (
    'live public BIL stream supports pinned native range delivery',
    'Explicit BIL_LIVE_WORKOUT_STREAM_CHECK opt-in required.',
)


def summarize(lines, source_sha, test_exit):
    ledger = Ledger()
    for line in lines:
        try:
            event = json.loads(line)
        except ValueError:
            continue  # Flutter tool/build-hook messages are not test events.
        if isinstance(event, dict):
            ledger.event(event)
    snapshot = ledger.snapshot()
    files = {}
    skipped = []
    for key, outcome in ledger.outcomes.items():
        test = ledger.tests[key]
        file = ledger.file_for(test)
        if file:
            files.setdefault(file, Counter())[outcome] += 1
        if outcome == 'skip':
            skipped.append({'name': test.get('name'),
                            'reason': test.get('metadata', {}).get('skipReason'),
                            'file': file})
    unexpected = [item for item in skipped if (item['name'], item['reason']) != EXPECTED_SKIP]
    passed = (test_exit == 0 and snapshot['protocol_success'] is True
              and snapshot['counts']['success'] > 0 and not snapshot['in_progress']
              and snapshot['counts']['failure'] == 0 and snapshot['counts']['error'] == 0
              and snapshot['error_events'] == 0 and not unexpected)
    return {'schema': 'bil39.flutter.actual-events.v1', 'source_sha': source_sha,
            'status': 'PASS' if passed else 'FAIL', 'process_exit': test_exit,
            **snapshot, 'files': {name: dict(counts) for name, counts in sorted(files.items())},
            'skips': skipped, 'unexpected_skips': unexpected,
            'expected_skip_boundary': 'The read-only public range check runs separately with explicit opt-in. It is not counted as passed here.',
            'scope': 'Real Flutter unit/widget execution, not a native device or signed-artifact claim'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--log', type=Path, required=True)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--test-exit', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.source_sha):
        raise ValueError('Exact source SHA required')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    if head != args.source_sha:
        raise ValueError('Runner checkout differs from expected source')
    changed = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD'], text=True).splitlines()
    if any(not generated_comparison(name) for name in changed):
        raise ValueError('Tracked source changed during test execution')
    report = summarize(args.log.read_text(encoding='utf-8-sig', errors='replace').splitlines(),
                       args.source_sha, args.test_exit)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'source_sha': args.source_sha,
                      'counts': report['counts'], 'unexpected_skips': len(report['unexpected_skips'])}))
    raise SystemExit(report['status'] != 'PASS')
