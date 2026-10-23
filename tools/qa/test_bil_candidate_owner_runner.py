"""The candidate adapter cannot alter the original engine or broaden branches."""
import tempfile
from pathlib import Path
import unittest

import bil_candidate_owner_runner as candidate


class CandidateOwnerRunnerTest(unittest.TestCase):
    def test_original_engine_bytes_are_preserved(self):
        candidate.verify_original(Path(candidate.owner.__file__))

    def test_altered_original_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'runner.py'
            path.write_text('changed engine', encoding='utf8')
            with self.assertRaisesRegex(RuntimeError, 'changed'):
                candidate.verify_original(path)

    def test_unrelated_branches_cannot_use_candidate_profile(self):
        for branch in ('main', 'integration/bil-qa-media-policy-20261011', 'arbitrary'):
            with self.subTest(branch=branch), self.assertRaises(RuntimeError):
                candidate.verify_branch(branch, 'source')
        candidate.verify_branch(candidate.BRANCH, 'source')

    def test_detached_source_requires_exact_ci_identity(self):
        candidate.verify_branch('', 'source', candidate.BRANCH, 'source')
        for ref, head in ((candidate.BRANCH, 'other'), ('main', 'source'), (None, None)):
            with self.subTest(ref=ref, head=head), self.assertRaises(RuntimeError):
                candidate.verify_branch('', 'source', ref, head)

    def test_only_explicit_cloud_capability_changes_original_root_scope(self):
        original = candidate._original_command('dart', 'snapshot')
        actual = candidate.root_command('dart', 'snapshot')
        self.assertEqual(actual[:-1], original)
        self.assertEqual(actual[-1], '--dart-define=BIL_SMART_PLAN_CLOUD_ENABLED=true')
        self.assertIn('--concurrency=2', actual)
        self.assertIn('--dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true', actual)


if __name__ == '__main__':
    unittest.main()
