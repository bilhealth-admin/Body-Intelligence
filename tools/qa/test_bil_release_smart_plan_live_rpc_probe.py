import copy
from pathlib import Path
import unittest
import bil_smart_plan_live_rpc_probe as probe


class LivePlanRpcProbeTests(unittest.TestCase):
    def result(self):
        cases = []
        for horizon in ('week', 'month', 'threeMonths', 'sixMonths'):
            for focus in ('training', 'nutrition', 'combined'):
                payload = {'horizon': horizon, 'focus': focus, 'days': []}
                cases.append(dict(horizon=horizon, focus=focus, sent=payload, received=payload,
                                  write_payload=payload, cloud_revision=len(cases)+1))
        return dict(success=True, session_revoked=True, user_deleted=True, cascade_clean=True,
            no_gemini_calls=True, no_diary_actions=True, roundtrips=cases,
            user_linked_cleanup_counts={str(i): 0 for i in range(16)},
            active_sent={'status': 'active'}, active_received={'status': 'active'},
            completed_sent={'completed': True}, completed_received={'completed': True},
            assertions={key: True for key in ('consent_required', 'all_twelve_actual_rpc_readbacks',
                'foreign_owner_payload_denied', 'two_writer_conflict_preserved',
                'duplicate_revision_replay_denied', 'tombstone_prevents_stale_resurrection',
                'revocation_and_reconsent_preserve_deletion')})

    def test_exact_twelve_combinations_and_payload_equality_are_mandatory(self):
        self.assertEqual(len(probe.validate(self.result())), 12)
        for mode in ('missing', 'duplicate', 'mismatch', 'wrong_focus', 'journal'):
            response = copy.deepcopy(self.result())
            if mode == 'missing': response['roundtrips'].pop()
            elif mode == 'duplicate': response['roundtrips'][-1] = response['roundtrips'][0]
            elif mode == 'mismatch': response['roundtrips'][0]['received'] = {'overwritten': True}
            elif mode == 'wrong_focus': response['roundtrips'][0]['focus'] = 'combined'
            else: response['completed_received'] = {'completed': False}
            with self.assertRaises(ValueError): probe.validate(response)

    def test_cleanup_and_every_actual_assertion_must_be_true(self):
        for key in ('success', 'session_revoked', 'user_deleted', 'cascade_clean', 'no_gemini_calls', 'no_diary_actions'):
            response = self.result()
            response[key] = False
            with self.assertRaises(ValueError): probe.validate(response)
        response = self.result()
        response['assertions']['foreign_owner_payload_denied'] = False
        with self.assertRaises(ValueError): probe.validate(response)

    def test_source_reuses_cleanup_and_inventories_all_new_owner_tables(self):
        # Use a small temporary ignored fixture only to inspect script construction.
        path = probe.ROOT / 'build/qa_probe_guard_fixture.json'
        path.parent.mkdir(exist_ok=True)
        path.write_text('{}', encoding='utf8')
        try:
            source = probe.script_for(path)
            self.assertNotIn('/functions/v1/ai-coach', source)
            self.assertNotIn('bil_record_consent', source)
            self.assertIn('Invoke-BilAuthAdminUserCreateWithRecovery', source)
            self.assertIn('finally {', source)
            self.assertIn('auth/v1/admin/users/$userId', source)
            self.assertIn('supabase@2.121.0', source)
            for name, (table, owner) in probe.EXTRA_TABLES.items():
                self.assertIn(f"from {table} where {owner}='$userId'", source)
                self.assertIn(f'([decimal]$cleanup.{name} -eq 0)', source)
        finally:
            path.unlink()

    def test_arbitrary_non_build_inputs_are_rejected(self):
        with self.assertRaises(ValueError): probe.script_for(Path(__file__))


if __name__ == '__main__':
    unittest.main()
