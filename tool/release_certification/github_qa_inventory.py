"""Read-only inventory of repository QA and actual GitHub attempts, never approval."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess


FAMILIES = {
    'source_format_analysis': ['verify.yml', 'bil_owner_comprehensive_validation.yml'],
    'full_flutter_and_regressions': ['bil_owner_comprehensive_validation.yml', 'bil_sapphire_history_qa.yml'],
    'golden_localization_rtl_accessibility': ['bil_extended_prebuild_coverage.yml', 'bil_golden_failure_diagnosis.yml'],
    'android_ios_native_deeplink_and_lifecycle': ['bil_rc_mobile_test_build.yml'],
    'android_api26_to36_boot': ['bil_android_isolated_emulator_smoke.yml'],
    'native_crypto_permissions_ui_and_splashes': ['bil_codeql_security_extended.yml'],
    'healthkit_and_platform_health': ['bil_healthkit_cloud_simulator.yml', 'build18_health_responsive_tests.yml'],
    'coach_text_voice_metering_and_vision': ['bil_live_service_contracts.yml', 'build18_ai_coach_full_tests.yml'],
    'barcode_photo_and_two_account_cloud_rls': ['bil_rc_mobile_test_build.yml'],
    'live_translation_deletion_and_media_streaming': ['bil_live_service_contracts.yml'],
    'purchase_refund_revoke_expiry_and_recovery': ['bil_store_lifecycle_adversarial_contracts.yml', 'bil_admin_revoke_verified_free_targeted.yml'],
    'postgres_migrations_rpc_rls_and_concurrency': ['bil_codeql_security_extended.yml', 'bil_independent_remaining_qa_20261016.yml'],
    'sast_codeql_semgrep_and_offline_mobsf': ['bil_codeql_security_extended.yml'],
    'dependency_security_and_release_certification': ['bil_final_release_certification.yml'],
    'google_apple_policy_android_lint_sdk_privacy': ['bil_apple_google_policy_gate.yml'],
    'reviewer_auth_and_entitlement_access': ['bil_reviewer_access_preflight.yml'],
    'signed_ios37_and_android33_artifact_contracts': ['bil_ios_signed_release.yml', 'bil_android_release_candidate.yml'],
    'independent_web_mfa_finance_moderation_contracts': ['bil_independent_admin_compatibility.yml'],
    'deployed_web_api_auth_and_exact_cors': ['bil_live_service_contracts.yml'],
}


def command(*args):
    return subprocess.check_output(args, text=True, encoding='utf-8').strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repo = 'bilhealth-admin/Body-Intelligence'
    branch = command('git', 'branch', '--show-current')
    head = command('git', 'rev-parse', 'HEAD')
    pages = json.loads(command('gh', 'api', '--paginate', '--slurp',
                               f'repos/{repo}/actions/workflows?per_page=100'))
    workflows = [row for page in pages for row in page['workflows']]
    runs = json.loads(command('gh', 'run', 'list', '--repo', repo, '--branch', branch,
                             '--limit', '200', '--json', 'databaseId,workflowName,status,conclusion,headSha,url'))
    local = sorted(p.name for p in Path('.github/workflows').iterdir() if p.suffix in ('.yml', '.yaml'))
    families = {name: [{'file': path, 'exists_in_candidate': path in local,
                       'github_registered': any(w['path'].endswith('/' + path) for w in workflows)}
                      for path in paths] for name, paths in FAMILIES.items()}
    document = {
        'utc': datetime.now(timezone.utc).isoformat(), 'branch': branch, 'local_head': head,
        'local_worktree_dirty': bool(command('git', 'status', '--porcelain')),
        'scope': 'Repository QA catalog and raw attempts; existence or dispatch is not test success or store acceptance',
        'families': families, 'local_workflows': local, 'remote_workflows': workflows,
        'all_recent_branch_attempts': runs,
        'head_attempt_counts': dict(Counter(r['conclusion'] or r['status'] for r in runs if r['headSha'] == head)),
        'external_gates_not_replaced_by_ci': [
            'Apple/Google reviewer decisions and accurate Console declarations',
            'Real StoreKit/Google Play sandbox transactions require an authorized store test session',
            'Physical hardware-only Health/BLE/App Attest behavior when simulator support is unavailable',
        ],
        'historical_operator_workflows': 'Source-patch, branch-finalizer and store-upload jobs are not additional test types; never dispatch them as QA',
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(document, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps({'families': len(families), 'local_workflows': len(local),
                      'remote_workflows': len(workflows), 'recent_attempts': len(runs),
                      'head_attempt_counts': document['head_attempt_counts'],
                      'local_worktree_dirty': document['local_worktree_dirty']}))


if __name__ == '__main__':
    main()
