"""The final gate cannot accept old source, partial sync or uncleared fixtures."""
from copy import deepcopy
import hashlib
from pathlib import Path
import tempfile
import unittest

import bil_manual_sync_evidence as gate


class SyncEvidenceGuards(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        paths = [
            'lib/features/cloud_platform/services/cloud_manual_sync_service.dart',
            'lib/features/cloud_platform/services/durable_offline_first_cloud_platform.dart',
            'lib/features/cloud_platform/services/app_database_cloud_inbox_applier.dart',
            'lib/features/cloud_platform/domain/cloud_sync_models.dart',
            'lib/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart',
            'tools/qa/flutter/manual_sync_live_e2e_test.dart',
            'tools/qa/manual_sync_crypto_bridge.mjs',
            'tools/qa/run_manual_sync_live_e2e.py',
        ]
        hashes = {}
        for name in paths:
            file = self.root / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b'synthetic source')
            hashes[name] = hashlib.sha256(file.read_bytes()).hexdigest()
        stages = []
        for label, completed in gate.STAGES.items():
            stages.append({'stage': label, 'completed': completed, 'pending': 0,
                'conflicts': 0, 'ledger': {'dead_letters': 0, 'outbox': 0},
                'last_success': '2026-10-23T12:00:00Z' if completed else None,
                'reason': 'cloud_sync_decrypt_failed' if label == 'c-aes-authentication-failure' else None,
                'exchanges': [{'protocol': 1, 'status': 200}]})
        self.proof = {'schema': 'bil.manual-sync-live.v1', 'status': 'PASS',
            'project': 'tgmanzhqulksykhslrzb', 'flutter_exit': 0,
            'cleanup_verified': True, 'source_sha256': hashes,
            'service': {'status': 'PASS', 'stages': stages,
                'canonical_key_matches_across_devices': True,
                'account_isolation': True, 'real_crypto_encryptions': 210,
                'real_crypto_decryptions': 630},
            'cleanup': {'auth_users': 0, 'sessions': 0, 'key_refs': 0,
                'vault_secrets': 0, 'owned_table_counts': ['0', 0]},
            'owned_columns_inventoried': 2}

    def test_complete_current_evidence_is_accepted(self):
        self.assertEqual(gate.verify(self.proof, self.root)['status'], 'PASS')

    def test_changed_source_is_rejected(self):
        name = next(iter(self.proof['source_sha256']))
        (self.root / name).write_bytes(b'edited source')
        with self.assertRaisesRegex(ValueError, 'Source changed'):
            gate.verify(self.proof, self.root)

    def test_zero_exit_alone_cannot_hide_partial_sync(self):
        self.proof['service']['stages'][0]['completed'] = False
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            gate.verify(self.proof, self.root)

    def test_retained_outbox_cannot_be_called_success(self):
        self.proof['service']['stages'][0]['ledger']['outbox'] = 103
        with self.assertRaisesRegex(ValueError, 'partial sync'):
            gate.verify(self.proof, self.root)

    def test_every_independent_cleanup_count_must_be_zero(self):
        for field in ('auth_users', 'sessions', 'key_refs', 'vault_secrets'):
            with self.subTest(field=field):
                proof = deepcopy(self.proof)
                proof['cleanup'][field] = 1
                with self.assertRaisesRegex(ValueError, 'residue'):
                    gate.verify(proof, self.root)

    def test_inventory_cannot_silently_omit_tables(self):
        self.proof['cleanup']['owned_table_counts'].pop()
        with self.assertRaisesRegex(ValueError, 'inventory'):
            gate.verify(self.proof, self.root)

    def test_corrupt_page_must_stop_after_one_v1_request(self):
        corrupt = next(s for s in self.proof['service']['stages']
                       if s['stage'] == 'c-aes-authentication-failure')
        corrupt['exchanges'] *= 20
        with self.assertRaisesRegex(ValueError, 'Corrupt page'):
            gate.verify(self.proof, self.root)

    def test_real_crypto_and_cross_device_key_witness_are_required(self):
        self.proof['service']['real_crypto_decryptions'] = 0
        with self.assertRaisesRegex(ValueError, 'cipher'):
            gate.verify(self.proof, self.root)

    def reported(self):
        paths = [
            'lib/features/cloud_platform/services/app_database_cloud_inbox_applier.dart',
            'lib/data/database/app_database.dart',
            'lib/data/database/connection/database_connection_native.dart',
            'lib/features/cloud_platform/services/supabase_startup_cloud_profile_reader.dart',
        ]
        hashes = {}
        for name in paths:
            file = self.root / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b'synthetic source')
            hashes[name] = hashlib.sha256(file.read_bytes()).hexdigest()
        return {'schema': 'bil.reported-accounts.sqlite-readonly.v1', 'status': 'PASS',
            'read_only': True, 'server_mutations': 0,
            'legacy_source_sha': '937aea673c2e9c0bec15ef988131d58f96bf5afe',
            'source_sha256': hashes, 'cases': [
                {'account_index': index, 'source_version': 'current', 'status': 'PASS',
                 'base_records': 4, 'health_values_and_dates_equal': True,
                 'initial': {'conflicts': 0, 'unsupported': 0},
                 'repeat': {'applied': 0, 'acknowledged': 4, 'conflicts': 0, 'unsupported': 0},
                 'v2_snapshots_applied': 3} for index in (0, 1)]}

    def test_exact_reported_account_proofs_are_accepted(self):
        self.assertEqual(gate.verify_reported_accounts(self.reported(), self.root)['result'], 'PASS')

    def test_success_on_disposable_accounts_does_not_accept_reported_conflicts(self):
        proof = self.reported()
        proof['cases'][1]['repeat']['conflicts'] = 1
        with self.assertRaisesRegex(ValueError, 'conflicts'):
            gate.verify_reported_accounts(proof, self.root)

    def test_only_one_reported_account_is_insufficient(self):
        proof = self.reported()
        proof['cases'].pop()
        with self.assertRaisesRegex(ValueError, 'Both reported'):
            gate.verify_reported_accounts(proof, self.root)

    def test_changed_account_restore_source_invalidates_proof(self):
        proof = self.reported()
        (self.root / next(iter(proof['source_sha256']))).write_bytes(b'edited')
        with self.assertRaisesRegex(ValueError, 'Source changed'):
            gate.verify_reported_accounts(proof, self.root)


if __name__ == '__main__':
    unittest.main()
