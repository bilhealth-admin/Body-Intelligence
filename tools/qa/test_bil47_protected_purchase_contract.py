"""Independent version47 pin/context negatives; no live API or SDK calls."""
import copy
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
import bil40_internal_build_ci as historical
import bil47_protected_purchase_contract as gate

ROOT = Path(__file__).resolve().parents[2]
SHA = 'a' * 40
OTHER = 'b' * 40

def push(event='push'):
    return {'BIL_PURCHASE_EVENT_NAME': event,
            'BIL_PURCHASE_SOURCE_BRANCH': gate.SOURCE_BRANCH,
            'BIL_PURCHASE_SOURCE_SHA': SHA,
            'BIL_PURCHASE_REF': 'refs/heads/' + gate.SOURCE_BRANCH,
            'BIL_PURCHASE_REF_NAME': gate.SOURCE_BRANCH,
            'BIL_PURCHASE_HEAD_REF': '', 'BIL_PURCHASE_HEAD_SHA': '',
            'BIL_PURCHASE_HEAD_REPOSITORY': '', 'BIL_PURCHASE_EVENT_SHA': SHA}

def pr():
    result = push('pull_request')
    result.update(BIL_PURCHASE_REF='refs/pull/17/merge',
                  BIL_PURCHASE_REF_NAME='17/merge',
                  BIL_PURCHASE_HEAD_REF=gate.SOURCE_BRANCH,
                  BIL_PURCHASE_HEAD_REPOSITORY=gate.REPOSITORY,
                  BIL_PURCHASE_HEAD_SHA=SHA, BIL_PURCHASE_EVENT_SHA=OTHER)
    return result

class ProtectedPurchase47Test(unittest.TestCase):
    def test_exact_fixed_contract_and_historical_gate_are_distinct(self):
        self.assertEqual(dict(historical.PROTECTED), dict(gate.HISTORICAL44))
        self.assertEqual(gate.PROTECTED47[gate.STORE],
                         'da3c7dde8a1f9807345eb03e58c148874cfa8deb')
        self.assertEqual(gate.PROTECTED47[gate.PRESS],
                         '653d424ddb6cca8adeb0d394f5c8f8866da3792d')
        gate.validate_observed(dict(gate.PROTECTED47))

    def test_missing_extra_paths_old_arbitrary_and_sentinels_fail(self):
        values = [None, {}, {gate.STORE: gate.PROTECTED47[gate.STORE]},
                  {**gate.PROTECTED47, 'extra.dart': 'c' * 40}]
        for blob in (gate.HISTORICAL44[gate.STORE], '0' * 40, '1' * 40,
                     'REVIEWED_FINAL47_DYNAMIC_COMPONENTS_GIT_BLOB_REQUIRED',
                     gate.PROTECTED47[gate.STORE].upper()):
            values.append({**gate.PROTECTED47, gate.STORE: blob})
        for value in values:
            with self.subTest(value=value), self.assertRaises(ValueError):
                gate.validate_observed(value)

    def test_press_feedback_stays_mandatory(self):
        for value in ('f' * 40, '', None, True):
            with self.subTest(value=value), self.assertRaises(ValueError):
                gate.validate_observed({**gate.PROTECTED47, gate.PRESS: value})

    def test_no_checkout_derived_expected_pin_or_optional_override(self):
        with self.assertRaises(TypeError):
            gate.PROTECTED47[gate.STORE] = 'f' * 40
        with self.assertRaises(TypeError):
            gate.validate_observed(dict(gate.PROTECTED47), expected={})

    def test_exact_push_and_dispatch_contexts(self):
        self.assertEqual(gate.source_context(push()), SHA)
        self.assertEqual(gate.source_context(push('workflow_dispatch')), SHA)

    def test_actual_pr_head_is_selected_not_base_branch_or_merge_ref(self):
        self.assertEqual(gate.source_context(pr()), SHA)
        value = pr();value['BIL_PURCHASE_SOURCE_BRANCH'] = 'main'
        with self.assertRaises(ValueError):
            gate.source_context(value)

    def test_wrong_branch_tag_missing_context_and_unknown_event_fail(self):
        mutations = [('BIL_PURCHASE_SOURCE_BRANCH', 'codex/bil44-android36-verified-20261115'),
                     ('BIL_PURCHASE_SOURCE_BRANCH', gate.SOURCE_BRANCH + '-suffix'),
                     ('BIL_PURCHASE_SOURCE_SHA', 'SOURCE_SHA_REQUIRED'),
                     ('BIL_PURCHASE_EVENT_SHA', OTHER),
                     ('BIL_PURCHASE_REF', 'refs/tags/' + gate.SOURCE_BRANCH),
                     ('BIL_PURCHASE_REF_NAME', 'main'),
                     ('BIL_PURCHASE_HEAD_REF', gate.SOURCE_BRANCH),
                     ('BIL_PURCHASE_EVENT_NAME', 'pull_request_target')]
        for key, value in mutations:
            bad = push();bad[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                gate.source_context(bad)
        with self.assertRaises(ValueError):
            gate.source_context({})

    def test_pr_fork_wrong_head_or_synthetic_context_fail(self):
        mutations = [('BIL_PURCHASE_HEAD_REPOSITORY', 'other/Body-Intelligence'),
                     ('BIL_PURCHASE_HEAD_REF', 'main'),
                     ('BIL_PURCHASE_HEAD_SHA', OTHER),
                     ('BIL_PURCHASE_REF', 'refs/heads/' + gate.SOURCE_BRANCH),
                     ('BIL_PURCHASE_REF_NAME', 'wrong/merge')]
        for key, value in mutations:
            bad = pr();bad[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                gate.source_context(bad)

    def test_wrong_checkout_and_dirty_source_stop_before_reading_pins(self):
        for results in ([OTHER], [SHA, ' M changed.dart']):
            with self.subTest(results=results), patch.object(gate, 'git', side_effect=results), \
                 patch.object(gate, 'validate_observed') as pins, self.assertRaises(ValueError):
                gate.verify47(ROOT, pr())
            pins.assert_not_called()

    def test_actual_working_files_equal_fixed47_contract(self):
        observed = {p: subprocess.check_output(['git', 'hash-object', p],
                    cwd=ROOT, text=True).strip() for p in gate.PROTECTED47}
        gate.validate_observed(observed)

    def test_crystal_routes_exact47_and_preserves_historical_literals(self):
        workflow = (ROOT / '.github/workflows/bil39-crystal.yml').read_text(encoding='utf-8')
        self.assertEqual(workflow.count('if [[ "$BIL_PURCHASE_SOURCE_BRANCH" == "' + gate.SOURCE_BRANCH + '" ]]; then'), 1)
        self.assertEqual(workflow.count('python3 tools/qa/bil47_protected_purchase_contract.py'), 1)
        self.assertIn('BIL_PURCHASE_SOURCE_BRANCH: ${{ github.event.pull_request.head.ref || github.ref_name }}', workflow)
        self.assertIn('BIL_PURCHASE_SOURCE_SHA: ${{ github.event.pull_request.head.sha || github.sha }}', workflow)
        for path, expected in gate.HISTORICAL44.items():
            self.assertEqual(workflow.count('test "$(git hash-object ' + path + ')" = "' + expected + '"'), 1)

if __name__ == '__main__':
    unittest.main()
