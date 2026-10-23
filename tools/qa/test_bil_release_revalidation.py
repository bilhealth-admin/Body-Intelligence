"""Controller fault injection and offline helper contracts; no live service I/O."""
import argparse
from contextlib import ExitStack, nullcontext
import importlib.util
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import urllib.request
from unittest.mock import Mock, patch


SPEC = importlib.util.spec_from_file_location(
    'release_revalidation', Path(__file__).with_name('bil_release_revalidation.py'))
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
HEAD = 'a' * 40
NEW_HEAD = 'b' * 40
OTHER_HEAD = 'c' * 40
FILE = 'test/synthetic_test.dart'


def protocol(*, result='success', skipped=False, done=True):
    url = 'file:///G:/synthetic/test/synthetic_test.dart'
    rows = [
        {'type': 'suite', 'suite': {'id': 1, 'path': url}},
        {'type': 'testStart', 'test': {'id': 1, 'suiteID': 1, 'name': 'loading ' + url}},
        {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': True, 'skipped': False},
        {'type': 'testStart', 'test': {'id': 2, 'suiteID': 1, 'name': 'synthetic behavior'}},
        {'type': 'testDone', 'testID': 2, 'result': result, 'hidden': False, 'skipped': skipped},
    ]
    if done:
        rows.append({'type': 'done', 'success': True})
    return [json.dumps(row) for row in rows]


class PureControllerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(release, 'ROOT', self.root))
        # Any missed mocking fails safely instead of starting commands/network.
        self.stack.enter_context(patch.object(release.subprocess, 'check_output', side_effect=AssertionError('Unexpected subprocess capture')))
        self.stack.enter_context(patch.object(release.subprocess, 'run', side_effect=AssertionError('Unexpected subprocess run')))
        self.stack.enter_context(patch.object(release.subprocess, 'Popen', side_effect=AssertionError('Unexpected subprocess Popen')))
        self.stack.enter_context(patch.object(release.time, 'sleep'))

    def log(self, lines):
        path = self.root / 'synthetic.jsonl'
        path.write_bytes(('\n'.join(lines) + '\n').encode('utf-8'))
        return path

    def assert_protocol_rejected(self, lines):
        try:
            result = release.test_result(self.log(lines), [FILE], 0)
        except (RuntimeError, ValueError, TypeError, KeyError):
            return
        self.assertIs(result['accepted'], False)

    def controller(self, *, lanes=None):
        control = release.Controller.__new__(release.Controller)
        control.args = argparse.Namespace(publish=True, ci_timeout_hours=1, expect_head=HEAD)
        control.plan = {'workflows': lanes or [], 'focused': [FILE], 'goldens': [FILE]}
        control.out = self.root / 'evidence'
        control.out.mkdir(exist_ok=True)
        control.head, control.branch = HEAD, ''
        control.frozen = {'lib/synthetic.dart': 'frozen-digest'}
        control.reviewed = ['lib/synthetic.dart']
        control.state = {'label': 'synthetic', 'phase': 'local_pass', 'stages': [],
                         'source_fingerprint': 'synthetic-fingerprint', 'local_pass': True,
                         'all_ci_pass': False, 'accepted': False}
        control.child = None
        control.stable = Mock()
        return control

    @staticmethod
    def lane(number):
        return {'lane_id': f'scope-{number}', 'workflow_id': number,
                'workflow': f'synthetic-{number}.yml', 'inputs': {},
                'required_jobs': ['Actual QA'], 'reason': 'Synthetic bounded test'}

    def fake_ci(self, control, *, initial_remote=HEAD, drift_after_first=False, post_error=None,
                final_override=None, jobs_override=None, initial_rows=None):
        posts, calls = [], []
        remote = [initial_remote]

        def git(*args):
            calls.append(('git', args))
            if args[:2] == ('ls-remote', 'origin'):
                return remote[0] + '\trefs/heads/' + release.BRANCH
            if args == ('rev-parse', 'HEAD'):
                return HEAD
            if args == ('branch', '--show-current'):
                return ''
            raise AssertionError(('unexpected git', args))

        def gh(endpoint, *, method=None, fields=None):
            calls.append(('gh', endpoint, method))
            if endpoint.endswith('/dispatches') and method == 'POST':
                number = int(endpoint.split('/')[2])
                journal = json.loads((control.out / 'github-state').read_text(encoding='utf-8'))
                self.assertEqual(journal['runs'][-1]['status'], 'dispatch_intent')
                self.assertEqual(journal['runs'][-1]['lane']['workflow_id'], number)
                posts.append(number)
                if drift_after_first:
                    remote[0] = OTHER_HEAD
                if post_error:
                    raise post_error
                return None
            if endpoint.startswith('actions/workflows/') and '/runs?' in endpoint:
                number = int(endpoint.split('/')[2])
                rows = list(initial_rows or []) + ([] if number not in posts else [{
                    'id': 1000 + number, 'workflow_id': number,
                    'head_sha': HEAD, 'head_branch': release.BRANCH,
                    'event': 'workflow_dispatch', 'created_at': '9999-01-01T00:00:00Z',
                    'html_url': f'https://github.com/synthetic/runs/{1000 + number}',
                    'status': 'completed', 'conclusion': 'success',
                }])
                return {'workflow_runs': rows, 'total_count': len(rows)}
            if endpoint.startswith('actions/runs/') and '/jobs?' in endpoint:
                return {'total_count': 1, 'jobs': jobs_override if jobs_override is not None else [{'name': 'Actual QA', 'status': 'completed', 'conclusion': 'success'}]}
            if endpoint.startswith('actions/runs/') and '?' not in endpoint:
                number = int(endpoint.split('/')[2]) - 1000
                run = {'id': 1000 + number, 'workflow_id': number,
                       'head_sha': HEAD, 'head_branch': release.BRANCH, 'event': 'workflow_dispatch',
                       'created_at': '9999-01-01T00:00:00Z',
                       'html_url': f'https://github.com/synthetic/runs/{1000 + number}',
                       'status': 'completed', 'conclusion': 'success'}
                run = next((dict(row) for row in initial_rows or [] if row['id'] == 1000 + number), run)
                return final_override(run) if final_override else run
            raise AssertionError(('unexpected gh', endpoint, method, fields))

        control.gh = gh
        return git, posts, calls

    def test_complete_protocol_requires_process_zero_and_all_files(self):
        log = self.log(protocol())
        self.assertTrue(release.test_result(log, [FILE], 0)['accepted'])
        self.assertFalse(release.test_result(log, [FILE], 1)['accepted'])
        self.assertFalse(release.test_result(log, [FILE, 'test/missing_test.dart'], 0)['accepted'])

    def test_failure_skip_missing_done_and_error_are_not_pass(self):
        for rows in [protocol(result='failure'), protocol(skipped=True), protocol(done=False),
                     protocol() + [json.dumps({'type': 'error', 'testID': 2, 'error': 'actual failure'})]]:
            with self.subTest(rows=rows):
                self.assert_protocol_rejected(rows)

    def test_unknown_raw_output_cannot_be_silently_discarded_into_pass(self):
        self.assert_protocol_rejected(protocol() + ['FATAL: unexpected test harness output'])

    def test_truncated_protocol_cannot_be_silently_discarded_into_pass(self):
        self.assert_protocol_rejected(protocol() + ['{"type":"error","error":'])

    def test_malformed_event_cannot_be_silently_discarded_into_pass(self):
        rows = protocol()
        rows.insert(-1, json.dumps({'type': 'testDone', 'result': 'failure'}))
        self.assert_protocol_rejected(rows)

    def test_unknown_event_and_invalid_test_outcome_are_not_protocol_pass(self):
        for event in [{'type': 'unknownFailure', 'message': 'failure'},
                      {'type': 'testDone', 'testID': 2, 'result': 'unexpected', 'hidden': False, 'skipped': False},
                      {'type': 'testDone', 'testID': 2, 'result': 'success', 'hidden': False, 'skipped': 'false'}]:
            with self.subTest(event=event):
                rows = protocol()
                if event['type'] == 'testDone':
                    rows[-2] = json.dumps(event)
                else:
                    rows.insert(-1, json.dumps(event))
                self.assert_protocol_rejected(rows)

    def test_known_json_print_diagnostic_does_not_invent_failure(self):
        rows = protocol()
        rows.insert(-1, json.dumps({'type': 'print', 'testID': 2, 'message': 'SQLITE_FIXTURE_DIAGNOSTIC synthetic local fixture diagnostic'}))
        self.assertTrue(release.test_result(self.log(rows), [FILE], 0)['accepted'])

    def test_known_raw_shell_fixture_diagnostics_are_counted_and_accepted(self):
        labels = [
            'before-real-write', 'cleanup-complete', 'cleanup-start',
            'connectivity-close', 'initialize', 'mount',
            'native-owner-bindings-ready', 'real-write-finished',
            'sdk-close', 'sdk-ready', 'sqlite-a-close', 'sqlite-b-close',
            'watchers-delivered',
        ]
        rows = protocol()
        diagnostics = [
            'Shell: SQLITE_FIXTURE_DIAGNOSTIC ' + label for label in labels
        ] + [
            'Shell: SQLite performance fixture: meals=10 materialized_aggregate_rows=52 aggregate_selects=78 milliseconds=258',
            'Shell: SQLite performance fixture: meals=100 materialized_aggregate_rows=701 aggregate_selects=711 milliseconds=1313',
        ]
        rows[-1:-1] = diagnostics
        result = release.test_result(self.log(rows), [FILE], 0)
        self.assertIs(result['accepted'], True)
        self.assertEqual(result['malformed_protocol_lines'], [])
        self.assertEqual(result['recognized_shell_diagnostics'], {
            'sqlite_fixture_lifecycle': 13,
            'sqlite_performance_fixture': 2,
        })

    def test_unknown_or_post_terminal_shell_output_remains_rejected(self):
        for rows in [
            protocol() + ['Shell: SQLITE_FIXTURE_DIAGNOSTIC unexpected-state'],
            protocol() + ['Shell: SQLite performance fixture: meals=1000 materialized_aggregate_rows=1 aggregate_selects=1 milliseconds=1'],
            protocol() + ['Shell: unexpected test harness output'],
            protocol() + ['Shell: SQLITE_FIXTURE_DIAGNOSTIC initialize'],
        ]:
            with self.subTest(rows=rows):
                self.assert_protocol_rejected(rows)

    def test_standard_json_group_event_between_loading_and_test_does_not_invent_failure(self):
        rows = protocol()
        rows.insert(3, json.dumps({'type': 'group', 'group': {
            'id': 3, 'suiteID': 1, 'parentID': None, 'name': 'synthetic behavior group',
            'metadata': {'skip': False, 'skipReason': None}, 'testCount': 1,
            'line': 1, 'column': 1, 'url': 'file:///G:/synthetic/test/synthetic_test.dart'}}))
        self.assertTrue(release.test_result(self.log(rows), [FILE], 0)['accepted'])

    def test_batches_preserve_every_complete_file_once(self):
        files = [f'test/synthetic_{i:03}_test.dart' for i in range(30)]
        groups = release.batches(['dart', 'snapshot', 'test', '--no-pub'], files, limit=140)
        self.assertGreater(len(groups), 1)
        self.assertEqual([name for group in groups for name in group], files)
        self.assertFalse(any('--update-goldens' in value for group in groups for value in group))

    def package_config(self, *dependencies, self_root='../'):
        config = self.root / '.dart_tool/package_config.json'
        config.parent.mkdir(exist_ok=True)
        (self.root / 'lib').mkdir(exist_ok=True)
        rows = [{'name': 'body_intelligence_log', 'rootUri': self_root, 'packageUri': 'lib/'}]
        rows.extend(dependencies)
        config.write_text(json.dumps({'configVersion': 2, 'packages': rows}), encoding='utf-8')
        return config

    def test_discovery_accepts_relative_roots_and_encoded_external_file_cache_without_trailing_slash(self):
        relative = self.root / '.dart_tool/relative package'
        (relative / 'lib').mkdir(parents=True)
        with tempfile.TemporaryDirectory(prefix='external pub cache ') as cache:
            hosted = Path(cache) / 'hosted package-1.0.0'
            (hosted / 'lib').mkdir(parents=True)
            self.package_config(
                {'name': 'relative', 'rootUri': 'relative%20package/', 'packageUri': 'lib/'},
                {'name': 'hosted', 'rootUri': hosted.as_uri(), 'packageUri': 'lib/'})
            result = release.validate_package_discovery(self.root)
        self.assertEqual(result['package_count'], 3)
        self.assertEqual(result['project_root'], str(self.root.resolve()))

    def test_discovery_rejects_missing_generated_override_root(self):
        self.package_config({'name': 'simple_barcode_scanner',
                             'rootUri': 'bil_release_plugin_overrides/simple_barcode_scanner/',
                             'packageUri': 'lib/'})
        with self.assertRaisesRegex(ValueError, 'simple_barcode_scanner rootUri directory is missing'):
            release.validate_package_discovery(self.root)

    def test_discovery_accepts_legitimate_assets_only_dependency_without_library(self):
        dependency = self.root / '.dart_tool/font_assets'
        dependency.mkdir(parents=True)
        (dependency / 'assets').mkdir()
        self.package_config({'name': 'font_assets', 'rootUri': 'font_assets/', 'packageUri': 'lib/'})
        self.assertEqual(release.validate_package_discovery(self.root)['package_count'], 2)

    def test_discovery_requires_actual_scanner_entrypoint_only_when_requested(self):
        dependency = self.root / '.dart_tool/scanner'
        (dependency / 'lib').mkdir(parents=True)
        self.package_config({'name': 'simple_barcode_scanner', 'rootUri': 'scanner/', 'packageUri': 'lib/'})
        required = {'simple_barcode_scanner': 'simple_barcode_scanner.dart'}
        with self.assertRaisesRegex(ValueError, 'Required package entrypoint is missing'):
            release.validate_package_discovery(self.root, required_entrypoints=required)
        (dependency / 'lib/simple_barcode_scanner.dart').write_text('// actual package entrypoint\n')
        self.assertEqual(release.validate_package_discovery(
            self.root, required_entrypoints=required)['package_count'], 2)

    def test_discovery_requires_own_project_library(self):
        self.package_config()
        (self.root / 'lib').rmdir()
        with self.assertRaisesRegex(ValueError, 'body_intelligence_log package library directory is missing'):
            release.validate_package_discovery(self.root)

    def test_discovery_rejects_copied_project_self_root_even_when_old_tree_exists(self):
        with tempfile.TemporaryDirectory(prefix='old copied worktree ') as old:
            (Path(old) / 'lib').mkdir()
            self.package_config(self_root=Path(old).as_uri())
            with self.assertRaisesRegex(ValueError, 'current worktree'):
                release.validate_package_discovery(self.root)

    def test_discovery_rejects_nonlocal_root_and_library_uris(self):
        for field in ('rootUri', 'packageUri'):
            with self.subTest(field=field):
                dependency = {'name': 'dependency', 'rootUri': '../', 'packageUri': 'lib/'}
                dependency[field] = 'https://invalid.example/package/'
                self.package_config(dependency)
                with self.assertRaisesRegex(ValueError, 'local file URI'):
                    release.validate_package_discovery(self.root)

    def test_discovery_requires_unique_names_and_current_project_entry(self):
        for dependency in ({'name': 'body_intelligence_log', 'rootUri': '../', 'packageUri': 'lib/'},
                           {'name': None, 'rootUri': '../', 'packageUri': 'lib/'}):
            with self.subTest(dependency=dependency):
                self.package_config(dependency)
                with self.assertRaisesRegex(ValueError, 'missing or duplicate name'):
                    release.validate_package_discovery(self.root)
        config = self.package_config()
        config.write_text(json.dumps({'configVersion': 2, 'packages': [
            {'name': 'unrelated', 'rootUri': '../', 'packageUri': 'lib/'}]}), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'current worktree'):
            release.validate_package_discovery(self.root)

    def test_source_change_blocks_later_stage(self):
        with patch.object(release.owner, 'inputs', return_value={'lib/synthetic.dart': 'mutated'}), \
             patch.object(release, 'git', return_value=HEAD):
            with self.assertRaisesRegex(RuntimeError, 'Source changed'):
                release.assert_source({'lib/synthetic.dart': 'frozen'}, HEAD, '')

    def test_remote_move_blocks_publishing_before_stage_or_commit(self):
        with patch.object(release, 'assert_source'), \
             patch.object(release, 'git', return_value=OTHER_HEAD + '\trefs/heads/integration'):
            with self.assertRaisesRegex(RuntimeError, 'Remote moved'):
                release.assert_publishable(frozen={}, head=HEAD, branch='', expected_remote=HEAD, reviewed_paths=[])

    def test_false_local_pass_never_attempts_commit_or_push(self):
        control = self.controller()
        control.state['local_pass'] = False
        with self.assertRaisesRegex(RuntimeError, 'local'):
            control.publish()

    def test_commit_tree_changed_by_hook_cannot_publish_untested_blob(self):
        control = self.controller()
        path = self.root / control.reviewed[0]
        path.parent.mkdir(parents=True)
        path.write_bytes(b'TESTED WORKTREE CONTENT')
        control.frozen = {control.reviewed[0]: hashlib.sha256(path.read_bytes()).hexdigest()}
        commands = []
        committed = [False]

        def raw_git(command, **kwargs):
            if command[:4] == ['git', 'ls-tree', '-r', '-z']:
                return b'100644 blob ' + b'1' * 40 + b'\tlib/synthetic.dart\0'
            if command == ['git', 'hash-object', '--stdin-paths']:
                return b'2' * 40 + b'\n'
            raise AssertionError(('unmocked raw Git source operation', command))

        def run(command, **kwargs):
            commands.append(command)
            if command[:2] == ['git', 'commit']:
                committed[0] = True
            return subprocess.CompletedProcess(command, 0)

        def git(*args):
            if args[:2] == ('ls-remote', 'origin'):
                pushed = any(command[:2] == ['git', 'push'] for command in commands)
                return (NEW_HEAD if pushed else HEAD) + '\trefs/heads/' + release.BRANCH
            if args == ('diff', '--cached', '--name-only'):
                return '\n'.join(control.reviewed)
            if args == ('rev-parse', 'HEAD'):
                return NEW_HEAD if committed[0] else HEAD
            if args[:1] in [('show',), ('ls-tree',), ('cat-file',)]:
                return 'UNTESTED INDEX CONTENT'
            if args == ('rev-parse', 'HEAD^'):
                return HEAD
            if args == ('status', '--porcelain'):
                return ''
            raise AssertionError(('unmocked source operation', args))

        with patch.object(release, 'assert_publishable'), patch.object(release, 'git', side_effect=git), \
             patch.object(release.subprocess, 'run', side_effect=run), \
             patch.object(release.subprocess, 'check_output', side_effect=raw_git), \
             patch.object(release.owner, 'inputs', return_value=control.frozen):
            try:
                control.publish()
            except RuntimeError:
                pass
        self.assertFalse(any(command[:2] == ['git', 'push'] for command in commands),
                         'A commit hook changed the index blob but the unchanged worktree was treated as identical source')
        self.assertTrue(committed[0], 'The mutation must be exercised after commit, not rejected by an unrelated mock')

    def test_committed_blob_check_accepts_exact_working_bytes_and_tree_only(self):
        path = self.root / 'lib/synthetic.dart'
        path.parent.mkdir()
        path.write_bytes(b'tested bytes\n')
        frozen = {'lib/synthetic.dart': hashlib.sha256(path.read_bytes()).hexdigest()}
        blob = b'1' * 40
        with patch.object(release.subprocess, 'check_output', side_effect=[
                b'100644 blob ' + blob + b'\tlib/synthetic.dart\0', blob + b'\n']) as raw:
            release.verify_commit_inputs(frozen)
        self.assertEqual(raw.call_count, 2)
        self.assertEqual(raw.call_args.kwargs['input'], b'"lib/synthetic.dart"\n')

    def test_working_bytes_mutated_after_test_cannot_be_promoted_by_matching_git_blob(self):
        path = self.root / 'lib/synthetic.dart'
        path.parent.mkdir()
        path.write_bytes(b'untested bytes\n')
        with patch.object(release.subprocess, 'check_output', return_value=
                          b'100644 blob ' + b'1' * 40 + b'\tlib/synthetic.dart\0'):
            with self.assertRaisesRegex(RuntimeError, 'working file changed'):
                release.verify_commit_inputs({'lib/synthetic.dart': hashlib.sha256(b'tested bytes\n').hexdigest()})

    def test_remote_drift_before_dispatch_does_not_send_any_post(self):
        control = self.controller(lanes=[self.lane(11)])
        git, posts, _ = self.fake_ci(control, initial_remote=OTHER_HEAD)
        with patch.object(release, 'git', side_effect=git):
            with self.assertRaises(RuntimeError):
                control.ci()
        self.assertEqual(posts, [])

    def test_post_dispatch_drift_blocks_the_next_independent_dispatch(self):
        control = self.controller(lanes=[self.lane(11), self.lane(22)])
        git, posts, _ = self.fake_ci(control, drift_after_first=True)
        with patch.object(release, 'git', side_effect=git):
            with self.assertRaises(RuntimeError):
                control.ci()
        self.assertEqual(posts, [11])

    def test_unknown_post_outcome_has_durable_intent_before_error(self):
        control = self.controller(lanes=[self.lane(11)])
        git, posts, _ = self.fake_ci(control, post_error=TimeoutError('ambiguous response, possible server acceptance'))
        with patch.object(release, 'git', side_effect=git):
            with self.assertRaises((RuntimeError, TimeoutError)):
                control.ci()
        self.assertEqual(posts, [11])
        contents = '\n'.join(path.read_text(encoding='utf-8') for path in control.out.iterdir() if path.is_file())
        self.assertIn('11', contents)
        self.assertIn('dispatch_outcome_unknown', contents)
        self.assertIn('intent_utc', contents)

    def test_dispatch_binds_first_run_before_next_profile_post(self):
        control = self.controller(lanes=[self.lane(11), self.lane(22)])
        git, posts, calls = self.fake_ci(control)
        with patch.object(release, 'git', side_effect=git):
            control.ci()
        first_post = calls.index(('gh', 'actions/workflows/11/dispatches', 'POST'))
        second_post = calls.index(('gh', 'actions/workflows/22/dispatches', 'POST'))
        self.assertTrue(any(call[:2] == ('gh', 'actions/workflows/11/runs?per_page=100')
                            for call in calls[first_post + 1:second_post]))
        self.assertEqual(posts, [11, 22])

    @staticmethod
    def push_run(**updates):
        return dict({'id': 900, 'workflow_id': 11, 'head_sha': HEAD, 'head_branch': release.BRANCH,
                     'event': 'push', 'created_at': '9999-01-01T00:00:00Z',
                     'html_url': 'https://github.com/synthetic/runs/900',
                     'status': 'completed', 'conclusion': 'success'}, **updates)

    def test_one_fresh_exact_source_push_run_is_reused_without_duplicate_post(self):
        control = self.controller(lanes=[dict(self.lane(11), reuse_push_run=True)])
        control.state['push_started_utc'] = '2026-10-20T00:00:00+00:00'
        git, posts, _ = self.fake_ci(control, initial_rows=[self.push_run()])
        with patch.object(release, 'git', side_effect=git):
            control.ci()
        self.assertEqual(posts, [])
        self.assertIs(control.state.get('all_ci_pass'), True)
        self.assertIs(control.state.get('accepted'), False)
        entry = json.loads((control.out / 'github-state').read_text(encoding='utf-8'))['runs'][0]
        self.assertEqual(entry['bound_event'], 'push')
        self.assertEqual(entry['origin'], 'reused_exact_source_push')

    def test_delayed_expected_automatic_run_is_bound_without_any_duplicate_post(self):
        lane = dict(self.lane(11), reuse_push_run=True, expect_push_for_this_run=True)
        control = self.controller(lanes=[lane])
        control.state['push_started_utc'] = '2026-10-20T00:00:00+00:00'
        git, posts, _ = self.fake_ci(control, initial_rows=[self.push_run()])
        original_gh = control.gh
        lists = []

        def delayed(endpoint, **kwargs):
            if endpoint == 'actions/workflows/11/runs?per_page=100':
                lists.append(endpoint)
                if len(lists) == 1:
                    return {'workflow_runs': [], 'total_count': 0}
            return original_gh(endpoint, **kwargs)

        control.gh = delayed
        clock = argparse.Namespace(monotonic=Mock(side_effect=[100, 101, 102, 103]), sleep=Mock())
        with patch.object(release, 'git', side_effect=git), patch.object(release, 'time', clock):
            control.ci()
        self.assertEqual(len(lists), 2)
        self.assertEqual(posts, [])
        self.assertIs(control.state.get('all_ci_pass'), True)
        entry = json.loads((control.out / 'github-state').read_text(encoding='utf-8'))['runs'][0]
        self.assertEqual(entry['run_id'], 900)
        self.assertEqual(entry['origin'], 'reused_exact_source_push')

    def test_absent_expected_automatic_run_times_out_without_manual_dispatch(self):
        lane = dict(self.lane(11), reuse_push_run=True, expect_push_for_this_run=True)
        control = self.controller(lanes=[lane])
        control.state['push_started_utc'] = '2026-10-20T00:00:00+00:00'
        git, posts, calls = self.fake_ci(control, initial_rows=[])
        clock = argparse.Namespace(monotonic=Mock(side_effect=[100, 101, 281]), sleep=Mock())
        with patch.object(release, 'git', side_effect=git), patch.object(release, 'time', clock):
            with self.assertRaisesRegex(RuntimeError, 'Expected automatic push run was not observed; no duplicate dispatch'):
                control.ci()
        lists = [call for call in calls if call[:2] == ('gh', 'actions/workflows/11/runs?per_page=100')]
        self.assertEqual(len(lists), 2)
        self.assertEqual(posts, [])
        self.assertIs(control.state.get('all_ci_pass'), False)
        self.assertEqual(control.state['phase'], 'waiting_for_exact_source_push_run')

    def test_stale_wrong_sha_or_unopted_push_run_requires_one_actual_dispatch(self):
        variants = [('stale', self.push_run(created_at='2000-01-01T00:00:00Z'), True),
                    ('wrong-sha', self.push_run(head_sha=OTHER_HEAD), True),
                    ('wrong-branch', self.push_run(head_branch='unrelated'), True),
                    ('not-opted-in', self.push_run(), False)]
        for name, run, opted in variants:
            with self.subTest(case=name):
                control = self.controller(lanes=[dict(self.lane(11), reuse_push_run=opted)])
                control.state['push_started_utc'] = '2026-10-20T00:00:00+00:00'
                git, posts, _ = self.fake_ci(control, initial_rows=[run])
                with patch.object(release, 'git', side_effect=git):
                    control.ci()
                self.assertEqual(posts, [11])
                self.assertIs(control.state.get('all_ci_pass'), True)

    def test_ambiguous_automatic_push_runs_fail_closed_without_any_dispatch(self):
        control = self.controller(lanes=[dict(self.lane(11), reuse_push_run=True)])
        control.state['push_started_utc'] = '2026-10-20T00:00:00+00:00'
        git, posts, _ = self.fake_ci(control, initial_rows=[self.push_run(), self.push_run(id=901)])
        with patch.object(release, 'git', side_effect=git):
            with self.assertRaisesRegex(RuntimeError, 'Multiple automatic runs'):
                control.ci()
        self.assertEqual(posts, [])
        self.assertIs(control.state.get('all_ci_pass'), False)

    def test_reused_push_final_api_must_preserve_its_bound_event(self):
        control = self.controller(lanes=[dict(self.lane(11), reuse_push_run=True)])
        control.state['push_started_utc'] = '2026-10-20T00:00:00+00:00'
        git, posts, _ = self.fake_ci(control, initial_rows=[self.push_run()],
                                     final_override=lambda run: dict(run, event='workflow_dispatch'))
        with patch.object(release, 'git', side_effect=git):
            with self.assertRaisesRegex(RuntimeError, 'identity differs'):
                control.ci()
        self.assertEqual(posts, [])
        self.assertIs(control.state.get('all_ci_pass'), False)

    def test_missing_corrupt_or_different_final_api_never_establishes_ci_pass(self):
        variants = [('missing', lambda run: {}), ('wrong-source', lambda run: dict(run, head_sha=OTHER_HEAD)),
                    ('wrong-workflow', lambda run: dict(run, workflow_id=22)),
                    ('wrong-bound-id', lambda run: dict(run, id=9999)),
                    ('wrong-branch', lambda run: dict(run, head_branch='unrelated-branch')),
                    ('wrong-event', lambda run: dict(run, event='push')),
                    ('failed', lambda run: dict(run, conclusion='failure'))]
        for name, mutate in variants:
            with self.subTest(case=name):
                control = self.controller(lanes=[self.lane(11)])
                git, _, _ = self.fake_ci(control, final_override=mutate)
                with patch.object(release, 'git', side_effect=git):
                    try:
                        control.ci()
                    except (RuntimeError, KeyError, TypeError, release.planner.PlanValidationError):
                        pass
                self.assertIs(control.state.get('all_ci_pass'), False)

    def test_required_skipped_missing_or_duplicate_failed_job_cannot_pass(self):
        for jobs in [[], [{'name': 'Actual QA', 'status': 'completed', 'conclusion': 'skipped'}],
                     [{'name': 'Actual QA', 'status': 'completed', 'conclusion': 'success'},
                      {'name': 'Actual QA', 'status': 'completed', 'conclusion': 'failure'}]]:
            with self.subTest(jobs=jobs):
                control = self.controller(lanes=[self.lane(11)])
                git, _, _ = self.fake_ci(control, jobs_override=jobs)
                with patch.object(release, 'git', side_effect=git):
                    control.ci()
                self.assertIs(control.state.get('all_ci_pass'), False)

    def test_workflow_specific_required_log_marker_is_an_actual_gate(self):
        lane = dict(self.lane(11), required_log_markers=['ACTUAL_NATIVE_PROOF'])
        for log, expected in [('no expected proof', False), ('ACTUAL_NATIVE_PROOF', True)]:
            with self.subTest(log=log):
                control = self.controller(lanes=[lane])
                git, _, _ = self.fake_ci(control)
                with patch.object(release, 'git', side_effect=git), patch.object(release, 'capture', return_value=log):
                    control.ci()
                self.assertIs(control.state.get('all_ci_pass'), expected)

    def test_final_api_and_required_jobs_green_records_ci_only_not_release_acceptance(self):
        control = self.controller(lanes=[self.lane(11)])
        git, _, _ = self.fake_ci(control)
        with patch.object(release, 'git', side_effect=git):
            control.ci()
        self.assertIs(control.state.get('all_ci_pass'), True)
        self.assertIs(control.state.get('accepted'), False)
        self.assertIn('external_release_gates_pending', control.state['phase'])

    def test_github_fields_are_sent_as_json_input_without_shell_or_secret_logs(self):
        control = self.controller()
        fields = {'ref': release.BRANCH, 'inputs': {'flag': True, 'mode': 'read-only'}}
        process = subprocess.CompletedProcess([], 0, '', '')
        with patch.object(release.subprocess, 'run', return_value=process) as run:
            self.assertIsNone(control.gh('actions/workflows/11/dispatches', method='POST', fields=fields))
        args, kwargs = run.call_args
        self.assertEqual(json.loads(kwargs['input']), fields)
        self.assertFalse(kwargs.get('shell', False))
        self.assertEqual(kwargs['timeout'], 120)
        self.assertIn('--input', args[0])

    def test_github_json_mutation_failure_is_not_automatically_retried(self):
        control = self.controller()
        with patch.object(release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'private stderr')) as run:
            with self.assertRaisesRegex(RuntimeError, 'no automatic retry') as error:
                control.gh('actions/workflows/11/dispatches', method='POST', fields={'ref': release.BRANCH})
        self.assertEqual(run.call_count, 1)
        self.assertNotIn('private stderr', str(error.exception))

    def test_continuation_source_inventory_allows_only_exact_reviewed_qa_edits(self):
        previous = {
            **release.CONTINUATION_PRIOR_FILE_HASHES,
            'lib/synthetic.dart': 'd' * 64,
        }
        current = dict(previous)
        current['tools/qa/bil_release_revalidation.py'] = 'a' * 64
        current['tools/qa/test_bil_release_revalidation.py'] = 'b' * 64
        self.assertEqual(release.continuation_source_changes(previous, current),
                         sorted(release.CONTINUATION_PRIOR_FILE_HASHES))
        for mutation in ('extra', 'missing', 'wrong_base'):
            with self.subTest(mutation=mutation):
                changed_previous = dict(previous)
                changed_current = dict(current)
                if mutation == 'extra':
                    changed_current['lib/synthetic.dart'] = 'e' * 64
                elif mutation == 'missing':
                    del changed_current['lib/synthetic.dart']
                else:
                    changed_previous['tools/qa/bil_release_revalidation.py'] = 'f' * 64
                with self.assertRaisesRegex(RuntimeError, 'Continuation|Prior source'):
                    release.continuation_source_changes(changed_previous, changed_current)

    def test_continuation_requires_run_mode_and_a_fresh_label(self):
        prefix = ['script', '--label', 'fresh-continuation', '--expect-head', HEAD,
                  '--flutter', 'synthetic-flutter', '--ci-manifest', 'synthetic-manifest.json',
                  '--continue-from', release.CONTINUATION_PRIOR_LABEL]
        with patch.object(sys, 'argv', prefix):
            with self.assertRaises(SystemExit) as error:
                release.main()
        self.assertEqual(error.exception.code, 2)
        with patch.object(sys, 'argv', ['script', '--label', release.CONTINUATION_PRIOR_LABEL,
                                       '--expect-head', HEAD, '--flutter', 'synthetic-flutter',
                                       '--ci-manifest', 'synthetic-manifest.json', '--run',
                                       '--continue-from', release.CONTINUATION_PRIOR_LABEL]):
            with self.assertRaises(SystemExit) as error:
                release.main()
        self.assertEqual(error.exception.code, 2)

    def test_local_sequence_keeps_full_original_and_never_updates_goldens(self):
        for failed_stage in [None, 'focused-01', 'goldens-01', 'full-analysis']:
            with self.subTest(failed_stage=failed_stage):
                control = self.controller()
                control.args.flutter = 'synthetic/flutter.bat'
                control.args.wait_resources_seconds = 0
                control.args.label = 'synthetic'
                commands = []
                def command(name, args, **kwargs):
                    commands.append((name, args, kwargs))
                    return name != failed_stage
                control.command = command
                with patch.object(release, 'capture', return_value=json.dumps({'frameworkVersion': '3.44.6'})), \
                     patch.object(release, 'sha', return_value=release.RUNNER_SHA), \
                     patch.object(release.owner, 'verified_branch'), \
                     patch.object(release.owner, 'ExclusiveRun', return_value=nullcontext()), \
                     patch.object(release, 'validate_package_discovery', return_value={'package_count': 2}), \
                     patch.object(release.owner, 'resources', return_value={'ram_available_bytes': 5 * 1024**3, 'disk_free_bytes': 6 * 1024**3}):
                    result = control.local()
                names = [name for name, _, _ in commands]
                self.assertEqual(names[:6], ['resolve-locked-dependencies', 'release-controller-regressions', 'format-reviewed',
                                            'focused-01', 'goldens-01', 'full-analysis'])
                self.assertEqual(commands[0][1][-3:], ['pub', 'get', '--enforce-lockfile'])
                self.assertNotIn('--update-goldens', [arg for _, args, _ in commands for arg in args])
                self.assertEqual('original-full-suite' in names, failed_stage is None)
                self.assertIs(result, failed_stage is None)
                if failed_stage is None:
                    full = commands[-1]
                    self.assertIn(str(self.root / 'tools/qa/bil_owner_full_test_runner.py'), full[1])
                    self.assertIn('--expect-head', full[1])
                    self.assertNotIn('--concurrency', full[1])

    def test_failed_bootstrap_or_discovery_stops_all_later_stages_under_owner_lock(self):
        for pub_ok in (False, True):
            with self.subTest(pub_ok=pub_ok):
                control = self.controller()
                control.args.flutter = 'synthetic/flutter.bat'
                control.args.wait_resources_seconds = 0
                control.args.label = 'synthetic'
                active = []
                commands = []

                class Lock:
                    def __enter__(inner):
                        active.append(True)
                    def __exit__(inner, *args):
                        active.pop()

                def command(name, args, **kwargs):
                    self.assertEqual(active, [True])
                    commands.append(name)
                    return pub_ok

                control.command = command
                with patch.object(release, 'capture', return_value=json.dumps({'frameworkVersion': '3.44.6'})), \
                     patch.object(release, 'sha', return_value=release.RUNNER_SHA), \
                     patch.object(release.owner, 'verified_branch'), \
                     patch.object(release.owner, 'ExclusiveRun', return_value=Lock()), \
                     patch.object(release, 'validate_package_discovery', side_effect=ValueError('missing generated root')) as validate:
                    self.assertFalse(control.local())
                self.assertEqual(commands, ['resolve-locked-dependencies'])
                self.assertEqual(validate.call_count, int(pub_ok))
                self.assertEqual(control.state['phase'], 'dependency_bootstrap_failed')
                self.assertFalse(control.state['accepted'])
                self.assertGreaterEqual(control.stable.call_count, 2 if pub_ok else 0)

    def test_stage_source_checkpoint_after_process_blocks_acceptance(self):
        control = self.controller()
        control.stable = Mock(side_effect=[None, RuntimeError('Source changed after process')])
        child = Mock()
        child.poll.return_value = 0
        child.wait.return_value = 0
        with patch.object(release.subprocess, 'Popen', return_value=child):
            with self.assertRaisesRegex(RuntimeError, 'Source changed'):
                control.command('synthetic-stage', ['synthetic-command'])
        self.assertEqual(control.state['stages'], [])

    def test_dashboard_server_is_retained_or_handed_off_after_run_completion(self):
        manifest = self.root / 'manifest.json'
        manifest.write_text(json.dumps({'required_workflow_ids': [11]}), encoding='utf-8')
        page = self.root / 'tools/qa/revalidation_dashboard.html'
        page.parent.mkdir(parents=True)
        page.write_text('<html>synthetic dashboard</html>', encoding='utf-8')
        control = self.controller()
        control.local = Mock(return_value=False)
        server = Mock()
        args = ['script', '--label', 'synthetic', '--expect-head', HEAD,
                '--flutter', 'synthetic-flutter', '--ci-manifest', str(manifest), '--run']
        with patch.object(sys, 'argv', args), patch.object(release, 'git', return_value=HEAD), \
             patch.object(release.planner, 'validate_ci_manifest', return_value=[self.lane(11)]), \
             patch.object(release.planner, 'focused_inventory', return_value=[FILE]), \
             patch.object(release.planner, 'golden_inventory', return_value=[FILE]), \
             patch.object(release.planner, 'e2e_inventory', return_value={}), \
             patch.object(release.owner, 'ExclusiveRun', return_value=nullcontext()), \
             patch.object(release, 'Controller', return_value=control), \
             patch.object(release, 'start_dashboard', return_value=server):
            self.assertEqual(release.main(), 1)
        final = json.loads((control.out / 'final-result.json').read_text(encoding='utf-8'))
        self.assertIs(final['all_ci_pass'], False)
        self.assertFalse(server.shutdown.called,
                         'Daemon HTTP server must be retained or handed to a surviving viewer before controller exits')

    def test_dashboard_is_a_separate_hidden_process_and_identity_is_verified(self):
        folder = self.root / 'synthetic'
        folder.mkdir()
        process = Mock(pid=1234)
        process.poll.return_value = None
        response = io.BytesIO(json.dumps({'label': folder.name}).encode('utf-8'))
        with patch.object(release.subprocess, 'Popen', return_value=process) as popen, \
             patch.object(urllib.request, 'urlopen', return_value=response):
            self.assertIs(release.start_dashboard(folder, 12345), process)
        command, kwargs = popen.call_args
        self.assertIn(str(self.root / 'tools/qa/bil_revalidation_dashboard_server.py'), command[0])
        self.assertIn(str(folder), command[0])
        self.assertEqual(kwargs['creationflags'], subprocess.CREATE_NO_WINDOW if release.os.name == 'nt' else 0)
        self.assertFalse(process.terminate.called)
        receipt = json.loads((folder / 'dashboard-server.json').read_text(encoding='utf-8'))
        self.assertIs(receipt['final_page_remains_visible'], True)
        self.assertEqual(receipt['pid'], 1234)

    def test_nested_original_dashboard_fetches_its_own_state_without_real_http(self):
        spec = importlib.util.spec_from_file_location('synthetic_dashboard_server',
            Path(__file__).with_name('bil_revalidation_dashboard_server.py'))
        server = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(server)
        original = self.root / 'original-full-dashboard/index.html'
        original.parent.mkdir()
        original.write_text("fetch('/state');fetch('/github-state');fetch('/current-work');", encoding='utf-8')
        with patch.object(sys, 'argv', ['server', '--directory', str(self.root), '--port', '12345']), \
             patch.object(server, 'ThreadingHTTPServer') as http:
            server.main()
        handler_type = http.call_args.args[1]
        handler = object.__new__(handler_type)
        handler.path = '/original-full-dashboard/'
        handler.wfile = io.BytesIO()
        handler.send_response = Mock()
        handler.send_header = Mock()
        handler.end_headers = Mock()
        handler.do_GET()
        body = handler.wfile.getvalue().decode('utf-8')
        for name in ('state', 'github-state', 'current-work'):
            self.assertIn(f"fetch('{name}'", body)
            self.assertNotIn(f"fetch('/{name}'", body)
        handler.send_response.assert_called_once_with(200)


if __name__ == '__main__':
    unittest.main()

class LiveBarcodeFixtureSafetyTests(unittest.TestCase):
    def test_live_fixture_is_project_scoped_unique_and_independently_cleaned(self):
        source = Path(__file__).resolve().parents[2] / "tool/nutrition/run_live_barcode_resolved_fixture_e2e.ps1"
        script = source.read_text(encoding="utf-8")
        self.assertIn("--project-ref $ProjectRef", script)
        self.assertIn("$gtin=New-TestGtin13", script)
        self.assertIn("p_gtin=$gtin", script)
        self.assertNotIn("p_gtin='4006381333931'", script)
        self.assertIn("RemoveOwnedCacheEntry", script)
        self.assertIn("cleanup_legacy_fixture", script)
        self.assertNotIn('/rest/v1/bil_barcode_shared_cache?', script)
        # The private table intentionally denies service-role REST access.
        # Exercise actual ownership/deleted-row/readback behavior rather than
        # requiring the old transport's return=representation header.
        powershell = shutil.which('pwsh') or shutil.which('powershell')
        self.assertIsNotNone(powershell, 'Offline fixture safety cannot be skipped')
        root = Path(__file__).resolve().parents[2]
        result = subprocess.run(
            [powershell, '-NoProfile', '-File',
             str(root / 'tool/nutrition/test_live_barcode_fixture_store.ps1')],
            cwd=root, capture_output=True, text=True, encoding='utf8', errors='replace',
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('BARCODE_FIXTURE_STORE_TESTS_PASS=13;LIVE_REQUESTS=0', result.stdout)
