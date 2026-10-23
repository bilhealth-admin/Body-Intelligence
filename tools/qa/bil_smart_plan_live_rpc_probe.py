"""Actual deployed RPC roundtrips over twelve source-generated Flutter plans.

Reuses the established disposable account/grant/logout/delete lifecycle. Only
synthetic fixture records are written. No migration, real-user action or Gemini
request is made. Full payload equality is required after an independent read.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import bil_release_coach_live_probe as lifecycle

ROOT = lifecycle.ROOT
BODY = ROOT / 'tool/release/smart_plan_live_rpc_body.ps1'
EXTRA_TABLES = {
    'auth_identities': ('auth.identities', 'user_id'),
    'store_subscriptions': ('public.bil_subscriptions', 'owner_id'),
    'entitlements': ('public.bil_entitlements', 'owner_id'),
    'store_audit_owner_links': ('public.bil_store_entitlement_audit', 'owner_id'),
    'smart_plan_state': ('public.bil_smart_plan_sync_state', 'owner_id'),
    'smart_plan_consent': ('bil_smart_plan_private.consent', 'owner_id'),
}


def script_for(fixtures: Path, cli: str | None = None) -> str:
    fixtures = fixtures.resolve()
    if not fixtures.is_relative_to(ROOT / 'build') or not fixtures.is_file():
        raise ValueError('Only source-generated ignored build fixtures are accepted')
    original = lifecycle.script_for('today', cli)
    prefix, tail = original.split('  $requestId = ', 1)
    prefix = prefix[:prefix.index('  [void](Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/bil_record_consent"')]
    suffix = tail[tail.index('\n}\ncatch {\n  $probeFailed = $true'):]
    source = prefix + "  $planFixturePath = '" + str(fixtures).replace("'", "''") + "'\n" + BODY.read_text(encoding='utf8') + suffix
    columns = list(EXTRA_TABLES)
    sql = ','.join(f"(select count(*) from {table} where {owner}='$userId') as {name}"
                   for name, (table, owner) in EXTRA_TABLES.items())
    marker = " as consents\") -RequiredColumns"
    if source.count(marker) != 1:
        raise ValueError('Cleanup SQL inventory boundary changed')
    source = source.replace(marker, ' as consents,' + sql + '") -RequiredColumns')
    marker = "'feedback','consents')"
    if source.count(marker) != 2:
        raise ValueError('Cleanup typed columns boundary changed')
    source = source.replace(marker, "'feedback','consents'," + ','.join("'" + name + "'" for name in columns) + ')')
    marker = '([decimal]$cleanup.consents -eq 0)'
    source = source.replace(marker, marker + ' -and\n          ' + ' -and\n          '.join(f'([decimal]$cleanup.{name} -eq 0)' for name in columns))
    source = source.replace('ConvertTo-Json -Depth 8\n', 'ConvertTo-Json -Depth 100\n')
    source = source.replace('$result.cascade_clean = $cascadeClean',
        '$result.cascade_clean = $cascadeClean\n$result.user_linked_cleanup_counts = $cleanup')
    if '/functions/v1/ai-coach' in source or 'p_purpose' in source:
        raise ValueError('Plan RPC probe must not call or consent to Gemini')
    return source


def validate(response: dict) -> list[dict]:
    for key in ('success', 'session_revoked', 'user_deleted', 'cascade_clean', 'no_gemini_calls', 'no_diary_actions'):
        if response.get(key) is not True:
            raise ValueError('Actual execution or cleanup missing: ' + key)
    assertions = response.get('assertions', {})
    cleanup = response.get('user_linked_cleanup_counts', {})
    if len(cleanup) != 16 or any(type(v) not in (int, float) or v != 0 for v in cleanup.values()):
        raise ValueError('Actual sixteen-table owner cleanup readback is incomplete')
    required = {'consent_required', 'all_twelve_actual_rpc_readbacks', 'foreign_owner_payload_denied',
                'two_writer_conflict_preserved', 'duplicate_revision_replay_denied',
                'tombstone_prevents_stale_resurrection', 'revocation_and_reconsent_preserve_deletion'}
    if set(assertions) != required or not all(v is True for v in assertions.values()):
        raise ValueError('Incomplete actual RPC assertions')
    cases = response.get('roundtrips', [])
    expected = {(h, f) for h in ('week', 'month', 'threeMonths', 'sixMonths') for f in ('training', 'nutrition', 'combined')}
    if len(cases) != 12 or {(c.get('horizon'), c.get('focus')) for c in cases} != expected:
        raise ValueError('Actual twelve-plan inventory is incomplete')
    for case in cases:
        if case.get('sent') != case.get('received') or case.get('sent') != case.get('write_payload'):
            raise ValueError('Actual complete payload readback mismatch')
        if case['received'].get('horizon') != case['horizon'] or case['received'].get('focus') != case['focus']:
            raise ValueError('Actual plan focus/duration does not match its case')
    for kind in ('active', 'completed'):
        if response.get(kind + '_sent') != response.get(kind + '_received'):
            raise ValueError('Actual journal/status readback mismatch: ' + kind)
    return [{'horizon': c['horizon'], 'focus': c['focus'], 'status': 'PASS',
             'days': len(c['received']['days']), 'cloud_revision': c['cloud_revision'],
             'payload_sha256': hashlib.sha256(json.dumps(c['received'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()}
            for c in cases]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixtures', type=Path, default=ROOT / 'build/qa_live_smart_plan_fixtures.json')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--supabase-cli')
    parser.add_argument('--powershell', default=shutil.which('pwsh'))
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    if not args.run:
        print(json.dumps({'status': 'PLANNED', 'network_calls': 0}))
        return 0
    if not args.powershell:
        raise RuntimeError('PowerShell is required; live validation cannot be skipped')
    source = script_for(args.fixtures, args.supabase_cli)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    script = args.output.with_suffix('.generated.ps1')
    script.write_bytes(source.encode('utf8'))
    completed = subprocess.run([args.powershell, '-NoProfile', '-File', str(script)],
        cwd=ROOT, capture_output=True, text=True, encoding='utf8', errors='replace')
    args.output.with_suffix('.stdout.log').write_text(completed.stdout, encoding='utf8')
    args.output.with_suffix('.stderr.log').write_text(completed.stderr, encoding='utf8')
    report = {'schema': 'bil.smart-plan.live-rpc.v1', 'status': 'FAIL',
              'script_sha256': hashlib.sha256(source.encode()).hexdigest(),
              'fixtures_sha256': hashlib.sha256(args.fixtures.read_bytes()).hexdigest(),
              'scope': 'Real authenticated RPC writers and exact independent readbacks; not a physical-device test or diary execution.'}
    try:
        if completed.returncode:
            raise ValueError('Actual live RPC probe failed; cleanup diagnostics retained')
        actual = json.loads(completed.stdout.lstrip('\ufeff'))
        report['cases'] = validate(actual)
        report.update(status='PASS', assertions=actual['assertions'], session_revoked=True,
                      disposable_user_deleted=True, user_linked_residue_zero=True,
                      cleanup_inventoried_tables=len(actual['user_linked_cleanup_counts']),
                      user_linked_cleanup_counts=actual['user_linked_cleanup_counts'], no_real_user_changes=True)
    except (ValueError, TypeError, KeyError) as error:
        report['failure'] = str(error)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps({'status': report['status'], 'actual_plan_cases': len(report.get('cases', []))}))
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
