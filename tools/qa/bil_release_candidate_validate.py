"""Frozen iOS38/Android33 local candidate validation. No commit, push or upload.

Preserves the original owner root command and security guards. One combined
source manifest covers Smart Plan, incident repairs and preparation workflows.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import bil_owner_full_test_runner as owner

ROOT = Path(__file__).resolve().parents[2]
BRANCH = 'codex/bil-release-ios38-android33-20261022'
SOURCE_BASE = '937aea673c2e9c0bec15ef988131d58f96bf5afe'
PROTECTED = '31554b3e078667a38bd3c53aa105f5f1d2a4dc96'


def snapshot():
    result = owner.inputs()
    for name in owner.git('ls-files', '-co', '--exclude-standard').splitlines():
        path = ROOT / name
        if path.is_file() and (name.startswith('docs/qa_next/BIL_20261022_SMART_PLAN_') or name.startswith('artifacts/workout_media/')):
            result[name] = owner.digest(path)
    return result


def main():
    os.environ['BIL_CAPTURE_SMART_PLAN_GOLDENS'] = '1'
    os.environ['BIL_CAPTURE_COMMUNITY_REPORT'] = '1'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expect-head', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--manual-sync-proof', type=Path)
    parser.add_argument('--reported-account-proof', type=Path)
    args = parser.parse_args()
    if owner.git('branch', '--show-current') != BRANCH:
        raise RuntimeError('Release candidate requires its authorized independent branch')
    if owner.git('rev-parse', 'HEAD') != args.expect_head:
        raise RuntimeError('unexpected HEAD')
    subprocess.run(['git', 'merge-base', '--is-ancestor', PROTECTED, SOURCE_BASE], cwd=ROOT, check=True)
    subprocess.run(['git', 'merge-base', '--is-ancestor', SOURCE_BASE, args.expect_head], cwd=ROOT, check=True)
    resources = owner.resources()
    if resources['ram_available_bytes'] is None or resources['ram_available_bytes'] < 4*1024**3:
        raise RuntimeError('At least 4 GiB available RAM is required')
    if resources['disk_free_bytes'] < 5*1024**3:
        raise RuntimeError('At least 5 GiB free disk is required')
    folder = ROOT / 'build' / 'release-ios38-android33' / ('frozen-' + time.strftime('%Y%m%d-%H%M%S'))
    folder.mkdir(parents=True)
    bootstrap = {'status': 'freezing-source', 'head': args.expect_head, 'branch': BRANCH,
                 'builds': {'ios': 38, 'android': 33}, 'stages': [], 'root_test_counts': {}}
    owner.atomic_json(folder / 'status.json', bootstrap)
    owner.atomic_json(folder.parent / 'latest.json', {'run_directory': folder.name})
    try:
        frozen = snapshot()
    except Exception as error:
        owner.atomic_json(folder / 'status.json', {**bootstrap, 'status': 'failed', 'error': str(error)})
        raise
    state = {'schema': 'bil.release-candidate.validation.v1', 'head': args.expect_head,
             'branch': BRANCH, 'source_base': SOURCE_BASE, 'feature_handoff': '4f9b1025b041cb3530a304480ad5a7f1592b51bc', 'builds': {'ios': 38, 'android': 33}, 'protected_base': PROTECTED,
             'source_fingerprint': owner.fingerprint(frozen), 'resources': resources,
             'status': 'planned', 'stages': [], 'root_test_counts': {},
             'not_proven': ['native device and simulator behavior', 'live staged cloud RPCs',
                            'store forms and signed iOS38/Android33', 'TestFlight38 acceptance and Google Play state']}
    owner.atomic_json(folder / 'source-manifest.json', frozen)
    owner.atomic_json(folder / 'status.json', state)
    owner.atomic_json(folder.parent / 'latest.json', {'run_directory': folder.name})
    print(str(folder), flush=True)
    if not args.run:
        return 0
    if args.manual_sync_proof is None or args.reported_account_proof is None:
        owner.atomic_json(folder / 'status.json', {**state, 'status': 'failed',
            'release_ready': False, 'error': 'Actual manual-sync and reported-account restoration proofs are required before final validation'})
        raise RuntimeError('Actual manual-sync and reported-account restoration proofs are required before final validation')

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
    changed = set(owner.git('diff', '--name-only', SOURCE_BASE).splitlines())
    changed.update(owner.git('diff', '--name-only', PROTECTED, SOURCE_BASE).splitlines())
    changed.update(owner.git('ls-files', '--others', '--exclude-standard').splitlines())
    changed_dart = sorted(name for name in changed if name.endswith('.dart'))
    deno = shutil.which('deno')
    if not deno:
        raise RuntimeError('Deno is required; backend tests cannot be skipped')
    try:
        stage('manual-sync-live-proof', [sys.executable, 'tools/qa/bil_manual_sync_evidence.py',
            '--proof', str(args.manual_sync_proof.resolve()),
            '--reported-account-proof', str(args.reported_account_proof.resolve())])
        for offset in range(0, len(changed_dart), 40):
            stage('format-' + str(offset//40+1), [str(dart), 'format', '--output=none', '--set-exit-if-changed', *changed_dart[offset:offset+40]])
        stage('release-controller-guards', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tools/qa', '-p', 'test_bil_release*.py', '-v'])
        stage('candidate-identity-guards', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tools/qa', '-p', 'test_bil_candidate*.py', '-v'])
        stage('offline-apk-producer-guards', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tools/qa', '-p', 'test_bil_mobsf*.py', '-v'])
        stage('release-tool-regressions', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tool/release', '-p', 'test_*.py', '-v'])
        stage('public-policy-regressions', ['node', '--test', 'tool/release/public_policy_pages.test.mjs',
            'tool/release/bilhealth_site_worker.test.mjs', 'tool/release/merge_site_associations.test.mjs'])
        for number, audit in (
            (11, 'epic11_localization_audit'),
            (12, 'epic12_security_audit'),
            (13, 'epic13_commerce_audit'),
            (14, 'epic14_release_audit'),
            (16, 'epic16_release_audit'),
        ):
            stage('source-audit-epic' + str(number), [str(dart), 'tool/' + audit + '.dart'])
        stage('architecture-guard', [*flutter_cmd, 'test', '--no-pub', '--reporter=expanded',
            'test/architecture_source_file_size_guard_test.dart', 'test/epic3_scope_coverage_audit_test.dart'])
        stage('feature-and-boundaries', [*flutter_cmd, 'test', '--no-pub', '--concurrency=2', '--reporter=expanded',
            '--dart-define=BIL_SMART_PLAN_CLOUD_ENABLED=true', 'test/features/smart_plan', 'test/app_router_plan_navigation_guard_test.dart',
            'test/features/wellness/recipe_release_repository_test.dart',
            'test/localization/smart_plan_25_locale_test.dart',
            'test/features/intelligence_center/ai_coach_safety_report_service_test.dart',
            'test/features/intelligence_center/ai_coach_report_confirmation_capture_test.dart',
            'test/shared/widgets/bil_premium_ai_consent_sheet_test.dart'])
        stage('startup-cloud-and-storage', [*flutter_cmd, 'test', '--no-pub', '--concurrency=2', '--reporter=expanded',
            'test/features/cloud_platform', 'test/features/startup', 'test/startup_state_test.dart',
            'test/features/wellness/bil_workout_routines_page_test.dart',
            'test/app/bootstrap_health_storage_retry_test.dart', 'test/app/services/health_storage_privacy_test.dart',
            'test/data/database/local_database_scope_test.dart'])
        stage('store-ownership-guards', [deno, 'test', '--allow-read', '--allow-env', '--allow-net',
            'supabase/functions/verify-store-purchase/apple_subscription_lifecycle_test.ts',
            'supabase/functions/verify-store-purchase/google_play_subscription_lifecycle_test.ts'])
        stage('coach-context-and-policy', [*flutter_cmd, 'test', '--no-pub', '--concurrency=2', '--reporter=expanded',
            'test/features/intelligence_center/coach_context_category_isolation_test.dart',
            'test/features/intelligence_center/coach_decision_memory_retention_test.dart',
            'test/features/intelligence_center/coach_context_food_provider_test.dart',
            'test/features/intelligence_center/coach_body_model_context_test.dart',
            'test/features/intelligence_center/coach_context_lifecycle_contract_test.dart',
            'test/features/intelligence_center/coach_today_context_parity_test.dart',
            'test/features/intelligence_center/coach_memory_owner_sync_test.dart',
            'test/features/intelligence_center/coach_memory_sync_protocol_test.dart',
            'test/launch_readiness/apple_release_boundary_contract_test.dart',
            'test/launch_readiness/apple_privacy_closure_contract_test.dart'])
        stage('coach-server', [deno, 'test', '--allow-read', '--allow-env', '--allow-net',
            'supabase/functions/ai-coach'])
        stage('local-sql-rls-adversarial', [deno, 'test', '--allow-read', '--allow-env', '--allow-net', 'supabase/tests/smart_plan_sync_local_test.ts'])
        stage('full-analysis', [str(dart), 'analyze', '--fatal-infos'])
        # Same two-worker, unsharded, assertions-enabled root test scope and public
        # media smoke scope as the owner's original runner. Its branch guards
        # are left intact; this feature has its own explicit guard above.
        # Keep per-test timeout protection on this independent feature runner.
        root_command = [arg for arg in owner.root_test_command(dart, tool) if arg != '--ignore-timeouts']
        root_command.append('--dart-define=BIL_SMART_PLAN_CLOUD_ENABLED=true')
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
    with owner.ExclusiveRun(ROOT / 'build' / 'release-ios38-android33' / 'exclusive.lock'):
        raise SystemExit(main())
