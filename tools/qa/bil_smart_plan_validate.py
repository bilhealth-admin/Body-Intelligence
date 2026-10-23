"""Feature-38 validation only. No push, merge, deployment or store operations.

The release owner's original integration runner remains unchanged. This runner
accepts only the independent Smart Plan branch, pins HEAD and content before
execution and invalidates results on any source change. No retries or shards.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

import bil_owner_full_test_runner as owner

ROOT = Path(__file__).resolve().parents[2]
BRANCH = 'codex/bil-smart-plan-v38-20261022'
HANDOFF = '4f9b1025b041cb3530a304480ad5a7f1592b51bc'
PROTECTED = '31554b3e078667a38bd3c53aa105f5f1d2a4dc96'


def snapshot():
    result = owner.inputs()
    for name in owner.git('ls-files', '-co', '--exclude-standard').splitlines():
        path = ROOT / name
        if path.is_file() and (name.startswith('docs/qa_next/BIL_20261022_SMART_PLAN_') or name.startswith('artifacts/workout_media/')):
            result[name] = owner.digest(path)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expect-head', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    if owner.git('branch', '--show-current') != BRANCH:
        raise RuntimeError('Smart Plan requires its authorized independent branch')
    if owner.git('rev-parse', 'HEAD') != args.expect_head:
        raise RuntimeError('unexpected HEAD')
    subprocess.run(['git', 'merge-base', '--is-ancestor', PROTECTED, HANDOFF], cwd=ROOT, check=True)
    subprocess.run(['git', 'merge-base', '--is-ancestor', HANDOFF, args.expect_head], cwd=ROOT, check=True)
    resources = owner.resources()
    if resources['ram_available_bytes'] is None or resources['ram_available_bytes'] < 4*1024**3:
        raise RuntimeError('At least 4 GiB available RAM is required')
    if resources['disk_free_bytes'] < 5*1024**3:
        raise RuntimeError('At least 5 GiB free disk is required')
    frozen = snapshot()
    folder = ROOT / 'build' / 'smart-plan-v38' / ('frozen-' + time.strftime('%Y%m%d-%H%M%S'))
    folder.mkdir(parents=True)
    state = {'schema': 'bil.smart-plan.validation.v1', 'head': args.expect_head,
             'branch': BRANCH, 'handoff': HANDOFF, 'protected_base': PROTECTED,
             'source_fingerprint': owner.fingerprint(frozen), 'resources': resources,
             'status': 'planned', 'stages': [], 'root_test_counts': {},
             'not_proven': ['native device and simulator behavior', 'live staged cloud RPCs',
                            'store forms and signed build38', 'TestFlight38 acceptance']}
    owner.atomic_json(folder / 'source-manifest.json', frozen)
    owner.atomic_json(folder / 'status.json', state)
    print(str(folder), flush=True)
    if not args.run:
        return 0

    def stable():
        if owner.git('rev-parse', 'HEAD') != args.expect_head or owner.git('branch', '--show-current') != BRANCH or snapshot() != frozen:
            raise RuntimeError('Frozen source changed; results invalid')

    def stage(name, command, *, json_tests=False):
        stable()
        entry = {'name': name, 'status': 'running', 'started_at': owner.utc(), 'command': command}
        state['status'] = name
        state['stages'].append(entry)
        owner.atomic_json(folder / 'status.json', state)
        counts = Counter()
        done = False
        with (folder / (name + '.log')).open('w', encoding='utf8', buffering=1) as log:
            process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding='utf8', errors='replace')
            for line in process.stdout:
                log.write(line)
                if json_tests:
                    try:
                        event = json.loads(line)
                    except (ValueError, TypeError):
                        continue
                    if event.get('type') == 'testDone' and not event.get('hidden'):
                        counts['skipped' if event.get('skipped') else event.get('result', 'unknown')] += 1
                    if event.get('type') == 'error':
                        counts['error_events'] += 1
                    if event.get('type') == 'done':
                        done = event.get('success') is True
                    state['root_test_counts'] = dict(counts)
                    owner.atomic_json(folder / 'status.json', state)
            code = process.wait()
        stable()
        entry.update(exit_code=code, finished_at=owner.utc(), status='pass' if code == 0 and (not json_tests or (done and counts['success'] > 0 and all(value == 0 for key,value in counts.items() if key != 'success'))) else 'fail')
        if json_tests:
            entry['counts'] = dict(counts)
            entry['done_success'] = done
        owner.atomic_json(folder / 'status.json', state)
        if entry['status'] != 'pass':
            raise RuntimeError(name + ' failed; see retained log')

    flutter = Path(args.flutter).resolve()
    dart = flutter.parent / 'cache/dart-sdk/bin/dart.exe'
    tool = flutter.parent / 'cache/flutter_tools.snapshot'
    flutter_cmd = [str(dart), str(tool)]
    changed = set(owner.git('diff', '--name-only', HANDOFF).splitlines())
    changed.update(owner.git('diff', '--name-only', PROTECTED, HANDOFF).splitlines())
    changed.update(owner.git('ls-files', '--others', '--exclude-standard').splitlines())
    changed_dart = sorted(name for name in changed if name.endswith('.dart'))
    deno = shutil.which('deno')
    if not deno:
        raise RuntimeError('Deno is required; backend tests cannot be skipped')
    try:
        for offset in range(0, len(changed_dart), 40):
            stage('format-' + str(offset//40+1), [str(dart), 'format', '--output=none', '--set-exit-if-changed', *changed_dart[offset:offset+40]])
        stage('architecture-guard', [*flutter_cmd, 'test', '--no-pub', '--reporter=expanded',
            'test/architecture_source_file_size_guard_test.dart'])
        stage('feature-and-boundaries', [*flutter_cmd, 'test', '--no-pub', '--concurrency=2', '--reporter=expanded',
            'test/features/smart_plan', 'test/app_router_plan_navigation_guard_test.dart',
            'test/features/intelligence_center/ai_coach_safety_report_service_test.dart',
            'test/features/intelligence_center/ai_coach_report_confirmation_capture_test.dart',
            'test/shared/widgets/bil_premium_ai_consent_sheet_test.dart'])
        stage('coach-context-and-policy', [*flutter_cmd, 'test', '--no-pub', '--concurrency=2', '--reporter=expanded',
            'test/features/intelligence_center/coach_context_category_isolation_test.dart',
            'test/features/intelligence_center/coach_context_food_provider_test.dart',
            'test/features/intelligence_center/coach_body_model_context_test.dart',
            'test/features/intelligence_center/coach_context_lifecycle_contract_test.dart',
            'test/features/intelligence_center/coach_today_context_parity_test.dart',
            'test/launch_readiness/apple_release_boundary_contract_test.dart',
            'test/launch_readiness/apple_privacy_closure_contract_test.dart'])
        stage('coach-server', [deno, 'test', '--allow-read', '--allow-env', '--allow-net',
            'supabase/functions/ai-coach/server_test.ts', 'supabase/functions/ai-coach/smart_plan_tools_test.ts'])
        stage('local-sql-rls-adversarial', [deno, 'test', '--allow-read', '--allow-env', '--allow-net', 'supabase/tests/smart_plan_sync_local_test.ts'])
        stage('full-analysis', [*flutter_cmd, 'analyze', '--no-pub'])
        # Same two-worker, unsharded, assertions-enabled root test scope and public
        # media smoke scope as the owner's original runner. Its branch guards
        # are left intact; this feature has its own explicit guard above.
        # Keep per-test timeout protection on this independent feature runner.
        root_command = [arg for arg in owner.root_test_command(dart, tool) if arg != '--ignore-timeouts']
        stage('root-suite', root_command, json_tests=True)
        state['status'] = 'local_validation_passed'
        state['release_ready'] = False
    except Exception as error:
        state['status'] = 'failed'
        state['error'] = str(error)
        state['release_ready'] = False
        owner.atomic_json(folder / 'status.json', state)
        print(str(error), file=sys.stderr, flush=True)
        return 1
    owner.atomic_json(folder / 'status.json', state)
    print(json.dumps(state, ensure_ascii=True), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
