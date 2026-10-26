import json
import unittest
from bil39_flutter_event_receipt import summarize, EXPECTED_SKIP


def events(*, result='success', skipped=False, name='actual behavior', reason=None, done=True):
    return [json.dumps(event) for event in [
        {'type': 'suite', 'suite': {'id': 1, 'path': 'C:/qa/test/example_test.dart'}},
        {'type': 'testStart', 'test': {'id': 2, 'suiteID': 1, 'name': name,
                                     'metadata': {'skipReason': reason}}},
        {'type': 'testDone', 'testID': 2, 'result': result, 'skipped': skipped, 'hidden': False},
        {'type': 'done', 'success': done},
    ]]


class ActualEventReceiptTest(unittest.TestCase):
    def test_actual_completed_success_is_required(self):
        report = summarize(events(), 'a'*40, 0)
        self.assertEqual('PASS', report['status'])
        self.assertEqual({'success': 1}, report['files']['test/example_test.dart'])

    def test_failed_process_cannot_inherit_protocol_success(self):
        self.assertEqual('FAIL', summarize(events(), 'a'*40, 1)['status'])

    def test_failed_test_blocks_even_with_a_forged_successful_done(self):
        self.assertEqual('FAIL', summarize(events(result='failure'), 'a'*40, 0)['status'])

    def test_missing_final_protocol_event_or_empty_log_is_not_pass(self):
        for sample in [events()[:-1], [], ['Flutter tool exited']]:
            self.assertEqual('FAIL', summarize(sample, 'a'*40, 0)['status'])

    def test_unknown_skips_block_acceptance(self):
        report = summarize(events(skipped=True, reason='TODO'), 'a'*40, 0)
        self.assertEqual('FAIL', report['status'])
        self.assertEqual(1, len(report['unexpected_skips']))

    def test_live_optin_is_disclosed_as_skip_never_counted_as_passed(self):
        report = summarize(events(skipped=True, name=EXPECTED_SKIP[0], reason=EXPECTED_SKIP[1]), 'a'*40, 0)
        self.assertEqual(0, report['counts']['success'])
        self.assertEqual(1, report['counts']['skip'])
        self.assertFalse(report['unexpected_skips'])
        self.assertEqual('FAIL', report['status'], 'An all-skipped job is not execution proof')


if __name__ == '__main__':
    unittest.main()
