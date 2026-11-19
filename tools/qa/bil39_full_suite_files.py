"""Partition whole Flutter files; verify all eight actual execution receipts."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

from bil39_flutter_event_receipt import EXPECTED_SKIP

ROOT = Path(__file__).resolve().parents[2]

# Reviewed failed/cancelled history is immutable scheduling configuration only.
# The exact pin makes plan and strict verification use identical tracked bytes,
# without changing the plan schema or the three-member execution artifact.
RUNTIME_HISTORY_PATH = ROOT / 'tools/qa/bil39_full_suite_runtime_history.json'
RUNTIME_HISTORY_SHA256 = '59705757c29499b4e01524c32a3ee79f2e8807bec41734a7875a506e4660f2eb'
HISTORY_POLICY = {'minimum_default_ms': 60000, 'p95_multiplier': 2,
                  'partial_multiplier': 2, 'censored_margin_ms': 60000}
ARGV_BUDGET = 26000


def _sha(value, size):
    return isinstance(value, str) and re.fullmatch('[a-f0-9]{' + str(size) + '}', value) is not None


def _test_path(value):
    if (not isinstance(value, str) or not value.startswith('test/') or
            not value.endswith('_test.dart') or '\\' in value or
            any(ord(character) < 32 for character in value)):
        return False
    path = PurePosixPath(value)
    return (not path.is_absolute() and path.as_posix() == value and
            not any(part in {'.', '..'} for part in path.parts))


def _validate_runtime_history(document):
    if (not isinstance(document, dict) or set(document) !=
            {'schema', 'qualification', 'provenance', 'policy', 'files'} or
            document['schema'] != 'bil39.full-file-runtime-history.v1' or
            document['qualification'] != 'HISTORICAL_FAILED_CANCELLED_SCHEDULING_ONLY' or
            document['policy'] != HISTORY_POLICY):
        raise ValueError('Invalid non-qualifying runtime history document')
    provenance = document['provenance']
    if (not isinstance(provenance, dict) or set(provenance) !=
            {'source_sha', 'controller_sha', 'run_id', 'inventory_sha256',
             'source_data_sha256', 'environment', 'artifacts'} or
            not _sha(provenance['source_sha'], 40) or
            not _sha(provenance['controller_sha'], 40) or
            not _sha(provenance['inventory_sha256'], 64) or
            not _sha(provenance['source_data_sha256'], 64) or
            type(provenance['run_id']) is not int or provenance['run_id'] <= 0):
        raise ValueError('Invalid historical source/run provenance')
    environment = provenance['environment']
    if (not isinstance(environment, dict) or set(environment) !=
            {'platform', 'flutter', 'suite_concurrency', 'jobs'} or
            environment['platform'] != 'windows-latest' or
            not isinstance(environment['flutter'], str) or
            not re.fullmatch(r'\d+\.\d+\.\d+', environment['flutter']) or
            type(environment['suite_concurrency']) is not int or
            environment['suite_concurrency'] != 1 or
            type(environment['jobs']) is not int or environment['jobs'] != 8):
        raise ValueError('Invalid historical scheduling environment')
    parts = provenance['artifacts']
    if not isinstance(parts, list) or len(parts) != environment['jobs']:
        raise ValueError('Historical artifact coverage is incomplete')
    indexed = {}
    for row in parts:
        if (not isinstance(row, dict) or set(row) !=
                {'index', 'archive_sha256', 'plan_sha256', 'outcome',
                 'receipt_present', 'protocol_done', 'planned_files', 'started_files'} or
                type(row['index']) is not int or row['index'] not in range(8) or
                row['index'] in indexed or not _sha(row['archive_sha256'], 64) or
                not _sha(row['plan_sha256'], 64) or
                type(row['planned_files']) is not int or row['planned_files'] < 1 or
                type(row['started_files']) is not int or
                not 0 <= row['started_files'] <= row['planned_files'] or
                type(row['receipt_present']) is not bool or
                type(row['protocol_done']) is not bool or
                not isinstance(row['outcome'], str) or
                row['outcome'] not in {'FAIL', 'CANCELLED'}):
            raise ValueError('Invalid historical artifact provenance')
        closed = row['outcome'] == 'FAIL'
        if (row['receipt_present'] is not closed or row['protocol_done'] is not closed or
                (closed and row['started_files'] != row['planned_files'])):
            raise ValueError('Historical failure/cancellation closure is inconsistent')
        indexed[row['index']] = row
    if (len({row['archive_sha256'] for row in parts}) != len(parts) or
            len({row['plan_sha256'] for row in parts}) != len(parts)):
        raise ValueError('Historical artifact or plan provenance is duplicated')
    records = document['files']
    if not isinstance(records, list) or not records:
        raise ValueError('Historical runtime file inventory is empty')
    files, folded, classified = {}, set(), Counter()
    for row in records:
        if (not isinstance(row, dict) or set(row) !=
                {'path', 'source_sha256', 'part', 'observation_class',
                 'elapsed_ms', 'elapsed_lower_bound_ms'} or
                not _test_path(row['path']) or not _sha(row['source_sha256'], 64) or
                type(row['part']) is not int or row['part'] not in indexed or
                row['path'].casefold() in folded):
            raise ValueError('Invalid, duplicate or colliding historical test path/hash')
        kind = row['observation_class']
        elapsed, lower = row['elapsed_ms'], row['elapsed_lower_bound_ms']
        if not isinstance(kind, str):
            raise ValueError('Invalid historical observation class')
        if kind in {'complete_file_in_closed_shard', 'closed_started_tests_in_cancelled_shard'}:
            valid = type(elapsed) is int and elapsed >= 0 and lower is None
        elif kind == 'censored_active_file':
            valid = elapsed is None and type(lower) is int and lower >= 0
        elif kind == 'not_started':
            valid = elapsed is None and lower is None
        else:
            valid = False
        part_closed = indexed[row['part']]['outcome'] == 'FAIL'
        if not valid or (kind == 'complete_file_in_closed_shard') != part_closed:
            raise ValueError('Historical observation class/duration does not match closure')
        folded.add(row['path'].casefold())
        files[row['path']] = row
        classified[row['part'], kind] += 1
    for index, row in indexed.items():
        complete = classified[index, 'complete_file_in_closed_shard']
        partial = classified[index, 'closed_started_tests_in_cancelled_shard']
        censored = classified[index, 'censored_active_file']
        unstarted = classified[index, 'not_started']
        if (complete + partial + censored + unstarted != row['planned_files'] or
                complete + partial + censored != row['started_files'] or censored > 1):
            raise ValueError('Historical file coverage differs from its artifact plan')
    hashes = {name: row['source_sha256'] for name, row in files.items()}
    if hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest() != provenance['inventory_sha256']:
        raise ValueError('Historical file inventory digest differs from provenance')
    completed = sorted(row['elapsed_ms'] for row in files.values()
                       if row['observation_class'] == 'complete_file_in_closed_shard')
    if not completed:
        raise ValueError('Historical default needs completed file observations')
    p95 = completed[(95 * len(completed) + 99) // 100 - 1]
    return {'records': files, 'default_ms': max(HISTORY_POLICY['minimum_default_ms'],
                                               HISTORY_POLICY['p95_multiplier'] * p95)}


def _unique_json_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('Duplicate runtime history JSON key')
        value[key] = item
    return value


def _load_runtime_history():
    path = RUNTIME_HISTORY_PATH
    path.resolve().relative_to(ROOT.resolve())
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 2 * 1024 * 1024:
        raise ValueError('Invalid tracked runtime history file')
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != RUNTIME_HISTORY_SHA256:
        raise ValueError('Tracked runtime history differs from its reviewed SHA256 pin')
    return _validate_runtime_history(json.loads(raw.decode('utf-8'), object_pairs_hook=_unique_json_object))


def _runtime_weights(files, history):
    result = {}
    default = history['default_ms']
    for name, digest in files.items():
        row = history['records'].get(name)
        weight = default
        if row is not None:
            kind = row['observation_class']
            if kind not in ('complete_file_in_closed_shard',
                            'closed_started_tests_in_cancelled_shard',
                            'censored_active_file', 'not_started'):
                raise ValueError('Unknown historical runtime weight class')
            # Durations describe only the exact tested bytes. A changed source
            # gets the reviewed default, not an obsolete heavy-file estimate.
            if digest != row['source_sha256']:
                result[name] = default
                continue
            if kind == 'complete_file_in_closed_shard':
                weight = max(1, row['elapsed_ms'])
            elif kind == 'closed_started_tests_in_cancelled_shard':
                weight = max(default, HISTORY_POLICY['partial_multiplier'] * row['elapsed_ms'])
            elif kind == 'censored_active_file':
                weight = max(default, row['elapsed_lower_bound_ms'] + HISTORY_POLICY['censored_margin_ms'])
        result[name] = weight
    return result


def _lpt_partitions(files, weights, total):
    if (not isinstance(files, dict) or not isinstance(weights, dict) or
            type(total) is not int or not 1 <= total <= 64 or len(files) < total or
            set(files) != set(weights) or
            any(not _test_path(name) or not _sha(digest, 64) for name, digest in files.items()) or
            len({name.casefold() for name in files}) != len(files) or
            any(type(weight) is not int or weight < 1 for weight in weights.values())):
        raise ValueError('Invalid exact-source runtime assignment inputs')
    bins = [[] for _ in range(total)]
    loads, costs = [0] * total, [0] * total
    for name in sorted(files, key=lambda value: (-weights[value], value)):
        cost = len(name) + 3
        feasible = [index for index in range(total) if costs[index] + cost <= ARGV_BUDGET]
        if not feasible:
            raise ValueError('Complete file partition exceeds the reviewed argv budget')
        index = min(feasible, key=lambda value: (loads[value], costs[value], value))
        bins[index].append(name)
        loads[index] += weights[name]
        costs[index] += cost
    if any(not values for values in bins):
        raise ValueError('An empty complete-suite runtime partition cannot execute')
    return [sorted(values) for values in bins]


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
    if (not re.fullmatch('[a-f0-9]{40}', sha) or type(total) is not int or
            type(index) is not int or not 1 <= total <= 64 or
            not 0 <= index < total or len(files) < total):
        raise ValueError('Invalid exact-source file partition')
    names = sorted(files)
    weights = _runtime_weights(files, _load_runtime_history())
    selected = _lpt_partitions(files, weights, total)[index]
    # Invoke Dart directly, not flutter.bat/cmd.exe's 8191-character command.
    # Leave ample room below Windows CreateProcess's 32767-character ceiling.
    if sum(len(name) + 3 for name in selected) > ARGV_BUDGET:
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
    selection = artifacts / 'artifact-selection.json'
    return {'schema': 'bil39.full-file-coverage.v1', 'status': 'PASS',
            'source_sha': sha, 'shards': sorted(seen), 'test_files': len(files),
            'inventory_sha256': plan(files, sha=sha, index=0, total=total)['inventory_sha256'],
            'counts': dict(counts), 'duplicate_files': 0, 'missing_files': 0,
            'artifact_selection': json.loads(selection.read_text(encoding='utf-8')) if selection.is_file() else None,
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
