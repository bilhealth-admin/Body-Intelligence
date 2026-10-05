"""Run the existing portable selection, preserving all published exclusions.

Runs only on an isolated GitHub runner. Native device/provider testing is not
represented by this script. No secrets, server mutation, or packaging steps.
"""
import importlib.util
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path.cwd()
OUT = pathlib.Path('/tmp/bil-next-regression')
OUT.mkdir(parents=True, exist_ok=True)
shard = int(os.environ['BIL_QA_SHARD'])
if shard not in range(4):
    raise ValueError('Exactly four fixed test shards are supported')
spec = importlib.util.spec_from_file_location(
    'portable', ROOT / 'tool/release/run_portable_release_tests.py')
portable = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portable)
all_files, selected = portable.discover_tests()
policy = portable.load_code_only_policy()
policy.discover()
selected = [p for p in selected if p not in policy.NOT_RUN]
performance, remaining = portable.partition_tests(selected)
mixed = {p: pattern for p, pattern in policy.MIXED_NAMES.items() if p in remaining}
tasks = [{'path': p, 'name': None} for p in remaining if p not in mixed]
tasks += [{'path': p, 'name': pattern} for p, pattern in mixed.items()]
partitions = [tasks[i::4] for i in range(4)]
assert len({t['path'] for group in partitions for t in group}) == len(remaining)
assert sorted(t['path'] for group in partitions for t in group) == sorted(remaining)
plan = {
    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'shard': shard, 'all_discovered_files': all_files, 'selected_files': selected,
    'excluded_files': sorted(set(all_files) - set(selected)),
    'name_filters': mixed, 'assigned': partitions[shard],
    'performance_ran_in_prerequisite': performance,
    'device_e2e': False, 'reference_parity': False,
}
(OUT / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n')
cmd = [*policy.flutter_test_command(portable.resolve_flutter_executable()),
       '--timeout', '30s']
results = []
paths = [t['path'] for t in partitions[shard] if t['name'] is None]
for batch in portable.partition_test_batches(cmd, paths):
    code = subprocess.run([*cmd, *batch], check=False).returncode
    results.append({'paths': batch, 'exit_code': code})
for task in partitions[shard]:
    if task['name'] is not None:
        code = subprocess.run([*cmd, task['path'], '--name', task['name']],
                              check=False).returncode
        results.append({'paths': [task['path']], 'name': task['name'],
                        'exit_code': code})
(OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
print('Executed files:', sum(len(r['paths']) for r in results), flush=True)
sys.exit(int(any(r['exit_code'] != 0 for r in results)))
