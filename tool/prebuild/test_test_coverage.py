import unittest
from verify_code_tests import file_outcomes
from run_gate import ROOT


class FileCoverageTest(unittest.TestCase):
    def test_completed_failure_preserves_only_the_actual_file_failure(self):
        record = {'command':['test/a_test.dart','test/b_test.dart'], 'status':'FAIL'}
        log = (f'00:00 +0: loading {ROOT.as_posix()}/test/a_test.dart\n'
               f'00:01 +1: loading {ROOT.as_posix()}/test/b_test.dart\n'
               f'00:02 +1 -1: {ROOT.as_posix()}/test/b_test.dart: case [E]\n'
               'Some tests failed.')
        self.assertEqual(file_outcomes(record, log), {'test/a_test.dart':'PASS','test/b_test.dart':'FAIL'})

    def test_missing_load_or_completion_never_counts_as_coverage(self):
        record = {'command':['test/a_test.dart','test/b_test.dart'], 'status':'FAIL'}
        with self.assertRaises(ValueError):
            file_outcomes(record, 'Some tests failed.')
        with self.assertRaises(ValueError):
            file_outcomes(record, f'00:02 +0 -1: {ROOT.as_posix()}/test/b_test.dart: case [E]\nSome tests failed.')
        record['status'] = 'PASS'
        with self.assertRaises(ValueError):
            file_outcomes(record, 'Started but never completed')


if __name__ == '__main__':
    unittest.main()
