"""Rollback audits must fail closed and always perform independent residue I/O."""
import json
from pathlib import Path
import unittest

import bil_release_cloud_e2e as audit

SOURCE = '''-- BEGIN SEGMENT PRECHECK
select 'precheck';
-- END SEGMENT PRECHECK
-- BEGIN SEGMENT TRANSACTION
begin;
select 'transaction';
rollback;
-- END SEGMENT TRANSACTION
-- BEGIN SEGMENT RESIDUE
select 'residue';
-- END SEGMENT RESIDUE
'''


def clean():
    return {'zero_synthetic_rows': True, 'inventoried_table_count': 1,
            'table_counts': [{'table_name': 'synthetic.fixture', 'synthetic_rows': 0}]}


def passed():
    return {'transaction_result': 'PASS', 'exact_failure': None,
            'completed_assertions': {'foreign_owner_denied': True}, 'completed_assertion_count': 1}


class RollbackAuditTest(unittest.TestCase):
    def test_all_real_audits_keep_three_segments_and_rollback(self):
        self.assertEqual(len(audit.SQL_FILES), 7)
        self.assertIn('tool/release/coach_memory_sync_production_rollback_e2e.sql', audit.SQL_FILES)
        for name in audit.SQL_FILES:
            with self.subTest(name=name):
                audit.segments((audit.ROOT / name).read_text(encoding='utf-8-sig'))

    def test_actual_three_independent_queries_and_assertions(self):
        calls = []
        def query(sql):
            calls.append(sql)
            return json.dumps({'rows': [passed() if 'transaction' in sql else clean()]})
        result = audit.execute(SOURCE, query)
        self.assertEqual(len(calls), 3)
        self.assertEqual(result['status'], 'PASS')
        self.assertTrue(result['residue_verified'])

    def test_failed_malformed_or_incomplete_transaction_always_queries_residue(self):
        for outcome in ('FAIL', 'UNKNOWN', 'malformed', 'timeout', 'missing_assertions', 'false_assertion'):
            with self.subTest(outcome=outcome):
                calls = []
                def query(sql):
                    calls.append(sql)
                    if 'transaction' not in sql:
                        return json.dumps([clean()])
                    if outcome == 'timeout':
                        raise TimeoutError('synthetic timeout')
                    if outcome == 'malformed':
                        return 'not JSON'
                    row = passed()
                    if outcome == 'missing_assertions':
                        del row['completed_assertions']
                    elif outcome == 'false_assertion':
                        row['completed_assertions']['foreign_owner_denied'] = False
                    else:
                        row['transaction_result'] = outcome
                    return json.dumps([row])
                with self.assertRaises((ValueError, TimeoutError)):
                    audit.execute(SOURCE, query)
                self.assertIn('residue', calls[-1])

    def test_nonzero_missing_or_string_counts_are_not_clean(self):
        for update in ({'zero_synthetic_rows': False}, {'inventoried_table_count': 2},
                       {'inventoried_table_count': True}, {'inventoried_table_count': '1'},
                       {'table_counts': []}, {'table_counts': [{'table_name': 'x', 'synthetic_rows': 1}]}):
            with self.subTest(update=update), self.assertRaises(ValueError):
                audit.inventory(clean() | update)

    def test_false_or_partial_assertions_never_pass(self):
        for update in ({'exact_failure': {}}, {'completed_assertion_count': 2},
                       {'completed_assertion_count': True}, {'completed_assertions': {}},
                       {'completed_assertions': {'a': 'true'}}, {'transaction_result': 'PARTIAL'}):
            with self.subTest(update=update), self.assertRaises(ValueError):
                audit.assertions(passed() | update)

    def test_residue_failure_prevents_success(self):
        def query(sql):
            if 'transaction' in sql:
                return json.dumps([passed()])
            return json.dumps([clean() | ({'zero_synthetic_rows': False} if 'residue' in sql else {})])
        with self.assertRaises(ValueError):
            audit.execute(SOURCE, query)

    def test_commit_ddl_and_duplicate_segments_are_rejected_before_any_io(self):
        for source in (SOURCE.replace('rollback;', 'commit;'), SOURCE + SOURCE,
                       SOURCE.replace("select 'transaction';", 'create table synthetic_forbidden(id int);')):
            with self.subTest(source=source), self.assertRaises(ValueError):
                audit.segments(source)


if __name__ == '__main__':
    unittest.main()
