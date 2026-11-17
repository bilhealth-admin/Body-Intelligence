import json
import unittest

import bil_macro_goal_generated_checks as checks


class OwnedBaselineOutputChecks(unittest.TestCase):
    def setUp(self):
        self.good = {'seed': 20261015, 'generated_cases': 10000,
                     'checks': 380014, 'result': 'PASS'}
        self.uri = 'http://127.0.0.1:12345/SYNTHETIC_TEST_ONLY/'
        self.banner = 'The Dart VM service is listening on ' + self.uri + '\n'

    @staticmethod
    def fresh():
        return {'observed': None, 'result_phase': None}

    def test_pass_before_vm_banner_survives_banner_and_tail(self):
        state = self.fresh()
        lines = iter([json.dumps(self.good) + '\n', self.banner, 'normal owned tail\n'])
        self.assertEqual(checks._read_until_vm_banner(lines, state), self.uri)
        for line in lines:
            checks._capture_baseline_output(line, state, 'after_vm_banner')
        result, safe = checks._baseline_outcome(0, state)
        self.assertEqual(result, self.good)
        self.assertEqual(safe['result_phase'], 'before_vm_banner')
        self.assertNotIn('observed', safe)
        self.assertNotIn('http', json.dumps(safe))

    def test_normal_pass_after_vm_banner_remains_supported(self):
        state = self.fresh()
        lines = iter([self.banner, json.dumps(self.good) + '\n'])
        self.assertEqual(checks._read_until_vm_banner(lines, state), self.uri)
        for line in lines:
            checks._capture_baseline_output(line, state, 'after_vm_banner')
        result, safe = checks._baseline_outcome(0, state)
        self.assertEqual(result, self.good)
        self.assertEqual(safe['result_phase'], 'after_vm_banner')

    def test_valid_json_cannot_override_nonzero_child_exit(self):
        state = self.fresh()
        checks._capture_baseline_output(json.dumps(self.good), state, 'before_vm_banner')
        result, safe = checks._baseline_outcome(65, state)
        self.assertIsNone(result)
        self.assertTrue(safe['valid_result_seen'])
        self.assertEqual(safe['baseline_exit_code'], 65)

    def test_zero_exit_without_owned_valid_result_does_not_pass(self):
        result, safe = checks._baseline_outcome(0, self.fresh())
        self.assertIsNone(result)
        self.assertFalse(safe['valid_result_seen'])

    def test_missing_banner_is_not_invented_by_a_pass_json(self):
        state = self.fresh()
        self.assertIsNone(checks._read_until_vm_banner(iter([json.dumps(self.good)]), state))
        self.assertEqual(state['observed'], self.good)

    def test_wrong_seed_case_count_result_and_boolean_counter_are_not_pass(self):
        for changed in [{'seed': 1}, {'generated_cases': 9999}, {'result': 'FAIL'},
                        {'checks': True}, {'checks': 0}, {'checks': -1}]:
            with self.subTest(changed=changed):
                state = self.fresh()
                checks._capture_baseline_output(json.dumps({**self.good, **changed}), state,
                                                'after_vm_banner')
                self.assertIsNone(checks._baseline_outcome(0, state)[0])

    def test_malformed_or_foreign_json_does_not_emit_raw_values(self):
        state = self.fresh()
        checks._capture_baseline_output('{bad json secret-shaped data', state, 'before_vm_banner')
        checks._capture_baseline_output(json.dumps({'url': self.uri, 'result': 'PASS'}), state,
                                        'after_vm_banner')
        self.assertIsNone(checks._baseline_outcome(0, state)[0])
        safe = checks._baseline_outcome(0, state)[1]
        self.assertTrue(safe['malformed_json_seen'])
        self.assertTrue(safe['unexpected_json_seen'])
        self.assertNotIn(self.uri, json.dumps(safe))
        self.assertNotIn('secret-shaped', json.dumps(safe))

    def test_extra_owned_json_fields_are_not_retained_or_emitted(self):
        state = self.fresh()
        checks._capture_baseline_output(json.dumps({**self.good, 'url': self.uri}), state,
                                        'before_vm_banner')
        result, safe = checks._baseline_outcome(0, state)
        self.assertEqual(result, self.good)
        self.assertNotIn(self.uri, json.dumps({'result': result, 'safe': safe}))

    def test_known_assertion_and_format_failure_have_only_fixed_codes(self):
        state = self.fresh()
        checks._capture_baseline_output('Bad state: bil-generated-check: percent sum', state,
                                        'after_vm_banner')
        checks._capture_baseline_output('FormatException: Invalid energy allocation.', state,
                                        'after_vm_banner')
        result, safe = checks._baseline_outcome(255, state)
        self.assertIsNone(result)
        self.assertEqual(safe['harness_assertion_code'], 'PERCENT_SUM')
        self.assertEqual(safe['format_exception_code'], 'INVALID_ENERGY_ALLOCATION')

    def test_unknown_failure_message_is_hashed_and_withheld(self):
        state = self.fresh()
        checks._capture_baseline_output('Bad state: bil-generated-check: ' + self.uri, state,
                                        'after_vm_banner')
        checks._capture_baseline_output('FormatException: ' + self.uri, state,
                                        'after_vm_banner')
        result, safe = checks._baseline_outcome(255, state)
        self.assertIsNone(result)
        self.assertEqual(safe['harness_assertion_code'], 'UNKNOWN_ASSERTION_WITHHELD')
        self.assertEqual(safe['format_exception_code'], 'UNKNOWN_FORMAT_MESSAGE_WITHHELD')
        self.assertNotIn(self.uri, json.dumps(safe))
        self.assertEqual(len(safe['harness_assertion_sha256']), 64)


if __name__ == '__main__':
    unittest.main(verbosity=2)
