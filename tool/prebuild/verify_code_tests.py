"""Verify current host-test coverage without erasing earlier failed attempts.

A failed batch clears only the files with recorded failures; other files must
have actually loaded and the runner must have finished. A partial name-filtered
rerun cannot clear a whole-file failure. Skips are reported separately.
"""
from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
import re

from run_gate import EVIDENCE, ROOT


def file_outcomes(record: dict, log: str) -> dict[str, str]:
    command = record['command']
    paths = [p.replace('\\', '/') for p in command if p.endswith('_test.dart')]
    if not paths:
        return {}
    if record['status'] == 'PASS':
        if 'All tests passed!' not in log:
            raise ValueError('Missing completed Flutter success marker')
        return {path: 'PASS' for path in paths}
    if record['status'] != 'FAIL' or 'Some tests failed.' not in log:
        raise ValueError('Incomplete Flutter batch cannot clear any file')
    failures = {path for path in paths if re.search(
        r'^\d+:\d+[^\n]*' + re.escape(path) + r'[^\n]*\[E\]', log, re.M)}
    if not failures:
        raise ValueError('Failed batch lacks identifiable file failures')
    for path in paths:
        if f'loading {ROOT.as_posix()}/{path}' not in log:
            raise ValueError(f'File did not load: {path}')
    return {path: 'FAIL' if path in failures else 'PASS' for path in paths}


def main() -> int:
    plan = json.loads((EVIDENCE / 'final_test_plan.json').read_text(encoding='utf-8'))
    expected = set(plan['ordinary']) | set(plan['mixed_name_filters'])
    results = []
    for path in EVIDENCE.glob('final_flutter_*.json'):
        item = json.loads(path.read_text(encoding='utf-8'))
        if isinstance(item, dict) and 'command' in item:
            results.append(item)
    latest = {}
    for item in sorted(results, key=lambda r: r['started_at']):
        command = item['command']
        selected = command[command.index('--name') + 1] if '--name' in command else None
        log = Path(item['log']).read_text(encoding='utf-8', errors='replace').replace('\\', '/')
        outcomes = file_outcomes(item, log)
        for path, status in outcomes.items():
            if path not in expected or selected != plan['mixed_name_filters'].get(path):
                continue
            finished = dt.datetime.fromisoformat(item['finished_at']).timestamp()
            stale = (ROOT / path).stat().st_mtime > finished
            # This service changed after the first full commerce batch. Every
            # direct test consumer must be re-run after its final source change.
            if 'verified_store_purchase_service' in (ROOT / path).read_text(encoding='utf-8'):
                stale |= (ROOT / 'lib/features/commerce/services/verified_store_purchase_service.dart').stat().st_mtime > finished
            latest[path] = {'status': 'FAIL' if stale else status,
                            'gate': item['name'], 'log': Path(item['log']).name,
                            'stale': stale}
    missing = sorted(expected - latest.keys())
    failed = {path: value for path, value in latest.items() if value['status'] != 'PASS'}
    output = {'status': 'FAIL' if missing or failed else 'PASS',
              'covered_files': len(latest), 'expected_files': len(expected),
              'missing': missing, 'failed_or_stale': failed,
              'files': latest, 'NOT RUN': plan['NOT RUN'],
              'mixed_filters': plan['mixed_name_filters'],
              'note': 'Runner-native platform skips are not PASS; review skip evidence separately.'}
    (EVIDENCE / 'final_code_test_coverage.json').write_text(json.dumps(output, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: output[key] for key in ('status','covered_files','expected_files','missing','failed_or_stale')}, indent=2))
    return int(bool(missing or failed))


if __name__ == '__main__':
    raise SystemExit(main())
