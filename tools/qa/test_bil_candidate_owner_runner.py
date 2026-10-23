"""The candidate adapter cannot alter the original engine or broaden branches."""
import tempfile
from pathlib import Path
import unittest
from contextlib import contextmanager
import os
from unittest.mock import patch

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


class CandidateRuntimeFingerprintTests(unittest.TestCase):
    def runtime_assets(self):
        return tuple(line.strip()[2:] for line in
                     (Path(__file__).resolve().parents[2] / 'pubspec.yaml').read_text(
                         encoding='utf-8-sig').splitlines()
                     if line.strip().startswith('- artifacts/workout_media/'))

    @contextmanager
    def fixture(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            assets = self.runtime_assets()
            self.assertTrue(assets, 'Exercise the real declared runtime assets')
            names = (*assets, 'lib/main.dart', 'build/generated.json',
                     'artifacts/unrelated/output.json',
                     'artifacts/workout_media_copy/output.json')
            for name in names:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(name.encode())
            with patch.object(candidate.owner, 'ROOT', root), patch.object(
                    candidate.owner, 'git', return_value='\n'.join(names)):
                yield root, assets, names

    def test_each_declared_runtime_asset_mutation_changes_fingerprint(self):
        with self.fixture() as (root, assets, _):
            baseline = candidate.source_inputs()
            self.assertTrue(set(assets).issubset(baseline))
            fingerprint = candidate.owner.fingerprint(baseline)
            for relative in assets:
                with self.subTest(asset=relative):
                    path = root / relative
                    original = path.read_bytes()
                    path.write_bytes(original + b' changed runtime data')
                    current = candidate.source_inputs()
                    self.assertEqual({key for key in current
                                      if current[key] != baseline[key]}, {relative})
                    self.assertNotEqual(candidate.owner.fingerprint(current), fingerprint)
                    path.write_bytes(original)
            self.assertEqual(candidate.source_inputs(), baseline)

    def test_build_and_unrelated_artifacts_do_not_enter_or_change_fingerprint(self):
        with self.fixture() as (root, assets, names):
            before = candidate.source_inputs()
            self.assertEqual(set(before), set(assets) | {'lib/main.dart'})
            for relative in set(names) - set(before):
                (root / relative).write_bytes(b'generated output changed')
            self.assertEqual(candidate.source_inputs(), before)
            deleted = root / assets[0]
            deleted.unlink()
            self.assertNotEqual(candidate.owner.fingerprint(candidate.source_inputs()),
                                candidate.owner.fingerprint(before))

    def test_analysis_selector_preserves_original_scope_for_other_branches(self):
        with self.fixture() as (_, assets, _):
            self.assertTrue(set(assets).issubset(candidate.analysis_inputs(candidate.BRANCH)))
            self.assertEqual(candidate.analysis_inputs(candidate.owner.ALLOWED_BRANCH),
                             candidate._original_inputs())

    def test_runtime_provenance_and_original_handoff_are_frozen_without_other_reports(self):
        with self.fixture() as (root, assets, names):
            additional = (
                'artifacts/workout_media/cloudflare_runtime_v2/runtime_object_plan_v2.json',
                'docs/qa_next/BIL_20261022_SMART_PLAN_RELEASE_QA.md',
                'docs/qa_next/unrelated-progress-report.md',
            )
            for name in additional:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(name.encode())
            with patch.object(candidate.owner, 'git', return_value='\n'.join((*names, *additional))):
                self.assertEqual(set(candidate.source_inputs()),
                                 set(assets) | {'lib/main.dart', *additional[:2]})

    def test_workflow_analysis_commands_detect_real_runtime_asset_change(self):
        workflow = (Path(__file__).resolve().parents[2] /
                    '.github/workflows/bil_owner_comprehensive_validation.yml').read_text(
                        encoding='utf-8-sig')
        commands = [line.split('python -c "', 1)[1].rsplit('"', 1)[0]
                    for line in workflow.splitlines() if 'python -c "' in line and
                    ('analysis-inputs.json' in line)]
        self.assertEqual(len(commands), 2)
        self.assertTrue(all('analysis_inputs(' in line for line in commands))
        with self.fixture() as (root, assets, _), patch.dict(
                os.environ, {'GITHUB_REF_NAME': candidate.BRANCH}):
            output = root / 'build/qa/owner-github-comprehensive'
            output.mkdir(parents=True)
            old_cwd = Path.cwd()
            try:
                os.chdir(root)
                exec(compile(commands[0], '<actual workflow analysis freeze>', 'exec'), {})
                exec(compile(commands[1], '<actual workflow analysis readback>', 'exec'), {})
                path = root / assets[0]
                path.write_bytes(path.read_bytes() + b' changed during analysis')
                with self.assertRaisesRegex(AssertionError, 'Source changed during analysis'):
                    exec(compile(commands[1], '<actual workflow analysis readback>', 'exec'), {})
            finally:
                os.chdir(old_cwd)

    def test_candidate_main_installs_same_input_scope_after_original_hash_guard(self):
        with self.fixture() as (_, assets, names):
            def git(*args):
                if args == ('rev-parse', 'HEAD'):
                    return 'a' * 40
                if args == ('branch', '--show-current'):
                    return candidate.BRANCH
                self.assertEqual(args, ('ls-files', '-co', '--exclude-standard'))
                return '\n'.join(names)
            def run_owner():
                self.assertIs(candidate.owner.inputs, candidate.source_inputs)
                self.assertEqual(candidate.owner.inputs(),
                                 candidate.analysis_inputs(candidate.BRANCH))
                self.assertTrue(set(assets).issubset(candidate.owner.inputs()))
                return 0
            with patch.object(candidate.owner, 'inputs'), patch.object(
                    candidate.owner, 'ALLOWED_BRANCH'), patch.object(
                    candidate.owner, 'root_test_command'), patch.object(
                    candidate.owner, 'git', side_effect=git), patch.object(
                    candidate.owner, 'main', side_effect=run_owner), patch.object(
                    candidate.subprocess, 'run') as ancestry, patch.dict(os.environ):
                self.assertEqual(candidate.main(), 0)
                self.assertEqual(ancestry.call_count, 2)


if __name__ == '__main__':
    unittest.main()
