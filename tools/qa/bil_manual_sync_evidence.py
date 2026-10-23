"""Reject missing, partial, dirty-source or unclean actual sync evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
STAGES = {
    'a-upload-all-data': True, 'b-restore-empty-sqlite': True,
    'b-idempotent-repeat-after-reopen': True,
    'a-response-lost-after-real-commit': False, 'a-resume-preserved-outbox': True,
    'b-pull-after-commit-response-loss': True, 'c-aes-authentication-failure': False,
    'c-retry-authentic-page': True, 'a-offline-preserves-data': False,
    'a-real-consent-denial': False, 'a-consent-regranted': True,
    'b-account-cannot-use-a-local-store': False,
}


def verify(proof, root=ROOT):
    if (proof.get('schema') != 'bil.manual-sync-live.v1' or proof.get('status') != 'PASS'
            or proof.get('project') != 'tgmanzhqulksykhslrzb'
            or type(proof.get('flutter_exit')) is not int or proof['flutter_exit'] != 0
            or proof.get('cleanup_verified') is not True):
        raise ValueError('Actual manual sync or independent cleanup did not pass')
    hashes = proof.get('source_sha256', {})
    mandatory = {
        'lib/features/cloud_platform/services/cloud_manual_sync_service.dart',
        'lib/features/cloud_platform/services/durable_offline_first_cloud_platform.dart',
        'lib/features/cloud_platform/services/app_database_cloud_inbox_applier.dart',
        'lib/features/cloud_platform/domain/cloud_sync_models.dart',
        'lib/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart',
        'tools/qa/flutter/manual_sync_live_e2e_test.dart',
        'tools/qa/manual_sync_crypto_bridge.mjs',
        'tools/qa/run_manual_sync_live_e2e.py',
    }
    if not mandatory.issubset(hashes):
        raise ValueError('Actual sync source binding is incomplete')
    for name, digest in hashes.items():
        path = (root / name).resolve()
        if not path.is_relative_to(root.resolve()) or not re.fullmatch('[a-f0-9]{64}', digest):
            raise ValueError('Invalid evidence source identity')
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError('Source changed after actual sync proof: ' + name)
    service = proof.get('service', {})
    stages = service.get('stages', [])
    if (service.get('status') != 'PASS' or len(stages) != len(STAGES)
            or {s.get('stage'): s.get('completed') for s in stages} != STAGES
            or any(type(s.get('completed')) is not bool for s in stages)
            or service.get('canonical_key_matches_across_devices') is not True
            or service.get('account_isolation') is not True
            or service.get('real_crypto_encryptions', 0) < 203
            or service.get('real_crypto_decryptions', 0) < 203):
        raise ValueError('Actual restore, retry, cipher or ownership proof is incomplete')
    for stage in stages:
        ledger = stage.get('ledger', {})
        if ledger.get('dead_letters') != 0:
            raise ValueError('Dead letters were not reconciled')
        if stage['completed'] and (stage.get('pending') != 0 or stage.get('conflicts') != 0
                or ledger.get('outbox') != 0 or not stage.get('last_success')):
            raise ValueError('A partial sync was accepted as success')
    corrupt = next(s for s in stages if s['stage'] == 'c-aes-authentication-failure')
    if (corrupt.get('reason') != 'cloud_sync_decrypt_failed'
            or len([e for e in corrupt.get('exchanges', []) if e.get('protocol') == 1]) != 1
            or corrupt.get('last_success') is not None):
        raise ValueError('Corrupt page repeated or changed the last-success time')
    cleanup = proof.get('cleanup', {})
    counts = cleanup.get('owned_table_counts', [])
    if len(counts) != proof.get('owned_columns_inventoried') or not counts:
        raise ValueError('Independent owned-table inventory is incomplete')
    counts = counts + [cleanup.get(k) for k in ('auth_users', 'sessions', 'key_refs', 'vault_secrets')]
    if any(not (type(n) is int and n == 0 or type(n) is str and n == '0') for n in counts):
        raise ValueError('Synthetic account, session, key or data residue remains')
    return {'status': 'PASS', 'stages': len(stages), 'source_files': len(hashes),
            'owned_columns_inventoried': proof['owned_columns_inventoried'],
            'physical_device_proved': False}


def verify_reported_accounts(proof, root=ROOT):
    if (proof.get('schema') != 'bil.reported-accounts.sqlite-readonly.v1'
            or proof.get('status') != 'PASS' or proof.get('read_only') is not True
            or type(proof.get('server_mutations')) is not int or proof['server_mutations'] != 0
            or proof.get('legacy_source_sha') != '937aea673c2e9c0bec15ef988131d58f96bf5afe'):
        raise ValueError('Reported-account compatibility is not a read-only actual PASS')
    current = [v for v in proof.get('cases', []) if v.get('source_version') == 'current']
    if len(current) != 2 or {v.get('account_index') for v in current} != {0, 1}:
        raise ValueError('Both reported account snapshots must be verified')
    for case in current:
        initial, repeat = case.get('initial', {}), case.get('repeat', {})
        if (case.get('status') != 'PASS' or case.get('health_values_and_dates_equal') is not True
                or type(case.get('base_records')) is not int or case['base_records'] <= 0
                or initial.get('conflicts') != 0 or initial.get('unsupported') != 0
                or repeat.get('conflicts') != 0 or repeat.get('unsupported') != 0
                or repeat.get('applied') != 0 or repeat.get('acknowledged') != case['base_records']
                or type(case.get('v2_snapshots_applied')) is not int or case['v2_snapshots_applied'] <= 0):
            raise ValueError('Reported account lost values, failed restoration or retained replay conflicts')
    mandatory = {
        'lib/features/cloud_platform/services/app_database_cloud_inbox_applier.dart',
        'lib/data/database/app_database.dart',
        'lib/data/database/connection/database_connection_native.dart',
        'lib/features/cloud_platform/services/supabase_startup_cloud_profile_reader.dart',
    }
    hashes = proof.get('source_sha256', {})
    if set(hashes) != mandatory:
        raise ValueError('Reported-account source binding is incomplete')
    for name, digest in hashes.items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
            raise ValueError('Source changed after reported-account restoration: ' + name)
    return {'reported_accounts': len(current), 'result': 'PASS', 'physical_device_proved': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--proof', type=Path, required=True)
    parser.add_argument('--reported-account-proof', type=Path, required=True)
    args = parser.parse_args()
    result = verify(json.loads(args.proof.read_text(encoding='utf8')))
    result.update(verify_reported_accounts(json.loads(args.reported_account_proof.read_text(encoding='utf8'))))
    print(json.dumps(result))


if __name__ == '__main__':
    main()
