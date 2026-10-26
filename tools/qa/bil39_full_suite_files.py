"""Partition whole Flutter files; verify all eight actual execution receipts."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess

from bil39_flutter_event_receipt import EXPECTED_SKIP

ROOT = Path(__file__).resolve().parents[2]


def inventory(root: Path) -> dict[str, str]:
    root = root.resolve()
    result = {}
    folded = set()
    for path in sorted((root / 'test').rglob('*_test.dart')):
        path.resolve().relative_to(root)
        name = path.relative_to(root).as_posix()
        if (not path.is_file() or path.is_symlink() or
                any(ord(character) < 32 for character in name) or name.casefold() in folded):
            raise ValueError('Invalid or colliding complete-suite test path')
        folded.add(name.casefold())
        result[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    if not result:
        raise ValueError('The complete Flutter test inventory is empty')
    return result


def plan(files: dict[str, str], *, sha: str, index: int, total: int) -> dict:
    if (not re.fullmatch('[a-f0-9]{40}', sha) or not 1 <= total <= 64 or
            not 0 <= index < total or len(files) < total):
        raise ValueError('Invalid exact-source file partition')
    names = sorted(files)
    selected = names[index::total]
    # Invoke Dart directly, not flutter.bat/cmd.exe's 8191-character command.
    # Leave ample room below Windows CreateProcess's 32767-character ceiling.
    if sum(len(name) + 3 for name in selected) > 26000:
        raise ValueError('Complete file partition exceeds the reviewed argv budget')
    digest = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
    return {'schema': 'bil39.full-file-partition.v1', 'source_sha': sha,
            'index': index, 'total': total, 'inventory_sha256': digest,
            'inventory_count': len(names), 'files': selected,
            'selected_hashes': {name: files[name] for name in selected}}


def verify(root: Path, artifact_root: Path, *, sha: str, total: int) -> dict:
    files = inventory(root)
    artifacts = artifact_root.resolve()
    plans = sorted(artifacts.rglob('plan.json'))
    if len(plans) != total:
        raise ValueError('A complete-suite file partition is missing or duplicated')
    seen = set()
    observed = []
    counts = Counter()
    recorded_skips = 0
    for path in plans:
        path.resolve().relative_to(artifacts)
        if path.is_symlink():
            raise ValueError('Refusing a symlinked file-partition receipt')
        current = json.loads(path.read_text(encoding='utf-8-sig'))
        index = current.get('index')
        if type(index) is not int or index in seen:
            raise ValueError('Invalid or duplicate complete-suite shard index')
        expected = plan(files, sha=sha, index=index, total=total)
        if current != expected:
            raise ValueError('File partition differs from exact checked-out sources')
        receipt_path = path.with_name('receipt.json')
        receipt_path.resolve().relative_to(artifacts)
        if receipt_path.is_symlink():
            raise ValueError('Refusing a symlinked execution receipt')
        receipt = json.loads(receipt_path.read_text(encoding='utf-8-sig'))
        executed = receipt.get('files')
        if not isinstance(executed, dict) or set(executed) != set(current['files']):
            raise ValueError('Actual executed files differ from the complete-suite file partition')
        outcomes = receipt.get('counts', {})
        skips = receipt.get('skips', [])
        if (not isinstance(skips, list) or outcomes.get('skip', 0) != len(skips) or
                any((value.get('name'), value.get('reason')) != EXPECTED_SKIP for value in skips)):
            raise ValueError('A complete-suite skip is not the separately executed live range check')
        recorded_skips += len(skips)
        if (receipt.get('source_sha') != sha or receipt.get('status') != 'PASS' or
                receipt.get('process_exit') != 0 or receipt.get('protocol_success') is not True or
                receipt.get('error_events') != 0 or receipt.get('in_progress') or
                receipt.get('unexpected_skips') or outcomes.get('success', 0) <= 0 or
                outcomes.get('failure', 0) != 0 or outcomes.get('error', 0) != 0):
            raise ValueError('Complete-suite execution is not a genuine exact-source PASS')
        seen.add(index)
        observed.extend(current['files'])
        counts.update(outcomes)
    if (seen != set(range(total)) or Counter(observed) != Counter(files.keys()) or
            recorded_skips > 1):
        raise ValueError('Complete-suite coverage has a missing or repeated test file')
    return {'schema': 'bil39.full-file-coverage.v1', 'status': 'PASS',
            'source_sha': sha, 'shards': sorted(seen), 'test_files': len(files),
            'inventory_sha256': plan(files, sha=sha, index=0, total=total)['inventory_sha256'],
            'counts': dict(counts), 'duplicate_files': 0, 'missing_files': 0,
            'scope': 'All host Flutter test files; native and live-cloud evidence remain separate'}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--index', type=int)
    parser.add_argument('--total', type=int, default=8)
    parser.add_argument('--verify', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if head != args.source_sha:
        raise ValueError('Complete-suite checkout differs from the expected SHA')
    if args.verify is not None:
        report = verify(ROOT, args.verify, sha=head, total=args.total)
    elif args.index is not None:
        report = plan(inventory(ROOT), sha=head, index=args.index, total=args.total)
    else:
        raise ValueError('A file-partition index or coverage verification is required')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'source_sha': head, 'index': report.get('index'),
                      'files': len(report.get('files', [])), 'status': report.get('status', 'PLANNED')}))


if __name__ == '__main__':
    main()
