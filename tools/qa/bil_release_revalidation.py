"""Serial release revalidation using the unchanged owner full-suite runner.

Plan by default. --run starts one frozen local sequence; --publish authorizes
one commit/push only after every local gate passes, then the explicit CI plan.
No golden acceptance, automatic repair/retry or final store submission.
The owner-authorized signed iOS/TestFlight step runs only after all CI gates.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import urljoin, urlsplit
from urllib.request import url2pathname

ROOT = Path(__file__).resolve().parents[2]
RUNNER_SHA = '3dbdc556d1484dfc250eb1d55154d431e8cc587ac013285f9c9e2d7fe1af54b2'
BRANCH = 'integration/bil-qa-media-policy-20261011'
REPO = 'bilhealth-admin/Body-Intelligence'

# Narrow continuation for the prior run whose only rejection was known SQLite
# diagnostics printed outside Flutter's JSON test protocol.
CONTINUATION_PRIOR_LABEL = 'bil-release-20261021-06'
CONTINUATION_PRIOR_HEAD = '299fee0bbca94d25171ca025ff6ec3b29c8b550e'
CONTINUATION_PRIOR_FINGERPRINT = 'ef5be0cebd5935a9a743600ac1bd459f1e7c1844ad953c171d07f1f4166bdc7a'
CONTINUATION_PRIOR_FILE_HASHES = {
    'tools/qa/bil_release_revalidation.py': 'b62a44853a359149c275b42ddb618d82f2f72da0c2a1460a54658aa7f3e70eb1',
    'tools/qa/test_bil_release_revalidation.py': '60e888e6ecbbccc61094d2986be6b32e9db5648d1ad29fdfad8ef8dce6918f87',
}
CONTINUATION_PRIOR_STAGE_NAMES = [
    'resolve-locked-dependencies',
    'validate-package-discovery',
    'release-controller-regressions',
    'format-reviewed',
    'focused-01',
    'goldens-01',
    'full-analysis',
]

SQLITE_FIXTURE_DIAGNOSTIC_LABELS = frozenset({
    'before-real-write',
    'cleanup-complete',
    'cleanup-start',
    'connectivity-close',
    'initialize',
    'mount',
    'native-owner-bindings-ready',
    'real-write-finished',
    'sdk-close',
    'sdk-ready',
    'sqlite-a-close',
    'sqlite-b-close',
    'watchers-delivered',
})
SQLITE_PERFORMANCE_DIAGNOSTIC = re.compile(
    r'Shell: SQLite performance fixture: meals=(?:10|100) '
    r'materialized_aggregate_rows=\d+ aggregate_selects=\d+ '
    r'milliseconds=\d+'
)


def recognized_shell_diagnostic(line):
    prefix = 'Shell: SQLITE_FIXTURE_DIAGNOSTIC '
    if line.startswith(prefix):
        label = line[len(prefix):]
        return 'sqlite_fixture_lifecycle' if label in SQLITE_FIXTURE_DIAGNOSTIC_LABELS else None
    if len(line) <= 256 and SQLITE_PERFORMANCE_DIAGNOSTIC.fullmatch(line):
        return 'sqlite_performance_fixture'
    return None


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


owner = load('bil_original_owner_runner', ROOT / 'tools/qa/bil_owner_full_test_runner.py')
planner = load('bil_revalidation_plan', ROOT / 'tools/qa/bil_release_revalidation_plan.py')


def utc():
    return datetime.now(timezone.utc).isoformat()


def capture(command, *, timeout=120):
    return subprocess.check_output(command, cwd=ROOT, text=True,
                                   encoding='utf-8', timeout=timeout).strip()


def git(*args):
    return capture(['git', *args])


def atomic(path, value):
    owner.atomic_json(path, value)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def continuation_source_changes(previous, current):
    # Permit only the exact two QA parser/test edits from the failed prior run.
    if not isinstance(previous, dict) or not isinstance(current, dict):
        raise RuntimeError('Prior/current source inventories must be objects')
    if set(previous) != set(current):
        raise RuntimeError('Continuation source inventory gained or lost paths')
    changed = sorted(path for path in previous if previous[path] != current[path])
    if set(changed) != set(CONTINUATION_PRIOR_FILE_HASHES):
        raise RuntimeError('Continuation permits changes to only the two reviewed QA paths')
    if any(previous[path] != CONTINUATION_PRIOR_FILE_HASHES[path] for path in changed):
        raise RuntimeError('Prior source hashes differ from the recorded failed run')
    if any(not re.fullmatch(r'[0-9a-f]{64}', current[path]) for path in changed):
        raise RuntimeError('Continuation source hashes are malformed')
    return changed


def changed_paths():
    commands = [ ['git', 'diff', '--name-only', '-z', 'HEAD'],
                 ['git', 'ls-files', '--others', '--exclude-standard', '-z'] ]
    return sorted({p for cmd in commands for p in
                   subprocess.check_output(cmd, cwd=ROOT).decode().split('\0') if p})


def assert_source(frozen, head, branch):
    if owner.inputs() != frozen or git('rev-parse', 'HEAD') != head or git('branch', '--show-current') != branch:
        raise RuntimeError('Source changed; later stages and publishing are blocked')


def assert_publishable(*, frozen, head, branch, expected_remote, reviewed_paths):
    assert_source(frozen, head, branch)
    if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != expected_remote:
        raise RuntimeError('Remote moved; no commit/push was attempted')
    if git('diff', '--cached', '--name-only'):
        raise RuntimeError('Unexpected staged changes; no staging/commit attempted')
    current = {p for p in changed_paths() if not owner.generated_comparison(p)}
    if current != set(reviewed_paths):
        raise RuntimeError('Unreviewed dirty paths appeared; publishing blocked')


def verify_commit_inputs(frozen, *, expected_parent=None):
    """Compare tested bytes to committed blobs, independently of the index/hooks."""
    if expected_parent is not None and git('rev-parse', 'HEAD^') != expected_parent:
        raise RuntimeError('Published commit does not descend directly from the tested base')
    tree = subprocess.check_output(['git', 'ls-tree', '-r', '-z', 'HEAD'], cwd=ROOT)
    blobs = {}
    for entry in tree.split(b'\0'):
        if entry:
            meta, name = entry.split(b'\t', 1)
            blobs[name.decode('utf-8')] = meta.split()[2].decode()
    names = sorted(frozen)
    for name in names:
        if not (ROOT / name).is_file() or sha(ROOT / name) != frozen[name]:
            raise RuntimeError(f'Tested working file changed: {name}')
    hashes = subprocess.check_output(['git', 'hash-object', '--stdin-paths'], cwd=ROOT,
        input='\n'.join(json.dumps(n, ensure_ascii=False) for n in names).encode('utf-8') + b'\n').decode().splitlines()
    if len(hashes) != len(names) or any(blobs.get(n) != h for n, h in zip(names, hashes)):
        raise RuntimeError('Committed tree differs from the tested source; push blocked')


def test_result(log, expected_files, exit_code):
    ledger = owner.Ledger()
    malformed = []
    recognized_diagnostics = {}
    completed_ids = set()
    terminal = False
    event_types = {'start', 'allSuites', 'suite', 'group', 'debug', 'testStart', 'print',
                   'error', 'testDone', 'done'}
    for line in log.read_text(encoding='utf-8', errors='replace').splitlines():
        if not line.strip():
            continue
        if line.startswith('Shell: '):
            if terminal:
                malformed.append(line[:200])
                continue
            category = recognized_shell_diagnostic(line)
            if category is None:
                malformed.append(line[:200])
            else:
                recognized_diagnostics[category] = recognized_diagnostics.get(category, 0) + 1
            continue
        try:
            event = json.loads(line)
            if not isinstance(event, dict) or event.get('type') not in event_types:
                raise ValueError('Unknown event type')
            kind = event['type']
            if terminal:
                raise ValueError('Event after terminal outcome')
            if kind == 'testDone':
                key = event.get('testID')
                if (key not in ledger.tests or key in completed_ids or
                        event.get('result') not in {'success', 'failure', 'error'} or
                        not isinstance(event.get('skipped'), bool) or
                        not isinstance(event.get('hidden'), bool)):
                    raise ValueError('Malformed or duplicate test outcome')
                completed_ids.add(key)
            if kind == 'testStart' and event.get('test', {}).get('id') in ledger.tests:
                raise ValueError('Duplicate test identity')
            if kind == 'done':
                if not isinstance(event.get('success'), bool):
                    raise ValueError('Terminal result is not a boolean')
                terminal = True
            ledger.event(event)
        except (ValueError, KeyError, TypeError):
            malformed.append(line[:200])
    result = ledger.snapshot()
    result.update(exit_code=exit_code,
                  files_not_loaded=sorted(set(expected_files) - ledger.loaded_files),
                  files_without_test_outcome=sorted(set(expected_files) - ledger.executed_files),
                  stable_source=True, head_unchanged=True, branch_unchanged=True)
    result['malformed_protocol_lines'] = malformed
    result['recognized_shell_diagnostics'] = dict(sorted(recognized_diagnostics.items()))
    result['accepted'] = owner.accepted(result) and not malformed
    return result


def batches(base, files, limit=22000):
    """Windows argv bound; complete file inventory, no test-name selectors."""
    result, group = [], []
    for name in files:
        if group and len(subprocess.list2cmdline([*base, *group, name])) > limit:
            result.append(group)
            group = []
        group.append(name)
    if group:
        result.append(group)
    return result


def validate_package_discovery(project_root, *, required_entrypoints=None):
    """Validate resolved discovery, without assuming dependencies live in this tree."""
    project_root = Path(project_root).resolve()
    config_file = project_root / '.dart_tool/package_config.json'
    config = json.loads(config_file.read_text(encoding='utf-8'))
    if not isinstance(config, dict) or config.get('configVersion') != 2:
        raise ValueError('Expected package_config version2')
    packages = config.get('packages')
    if not isinstance(packages, list) or not packages:
        raise ValueError('Package discovery has no packages')

    def local_path(base, value, description):
        if not isinstance(value, str) or not value:
            raise ValueError(f'{description} must be a nonempty URI')
        uri = urlsplit(urljoin(base, value))
        if uri.scheme != 'file' or uri.query or uri.fragment:
            raise ValueError(f'{description} must resolve to a local file URI')
        authority = '' if uri.netloc in ('', 'localhost') else '//' + uri.netloc
        return Path(url2pathname(authority + uri.path)).resolve()

    names = set()
    self_root = None
    libraries = {}
    for package in packages:
        if not isinstance(package, dict):
            raise ValueError('Package discovery entry must be an object')
        name = package.get('name')
        if not isinstance(name, str) or not name or name in names:
            raise ValueError('Package discovery has a missing or duplicate name')
        names.add(name)
        root = local_path(config_file.as_uri(), package.get('rootUri'), f'{name} rootUri')
        if not root.is_dir():
            raise ValueError(f'{name} rootUri directory is missing: {root}')
        # Pub's hosted rootUri need not end in '/'; it still names a directory.
        package_uri = package.get('packageUri', '')
        if not isinstance(package_uri, str):
            raise ValueError(f'{name} packageUri must be a URI string')
        libraries[name] = local_path(root.as_uri().rstrip('/') + '/', package_uri or './',
                                     f'{name} packageUri')
        if name == 'body_intelligence_log':
            self_root = root
    if self_root != project_root:
        raise ValueError('body_intelligence_log discovery root differs from the current worktree')
    if not libraries['body_intelligence_log'].is_dir():
        raise ValueError('body_intelligence_log package library directory is missing')
    # Dart permits asset-only dependencies whose packageUri directory is absent.
    # Require only explicit application entrypoints, rather than inventing a
    # library-directory requirement for every dependency.
    for name, entrypoint in (required_entrypoints or {}).items():
        if name not in libraries or not (libraries[name] / entrypoint).is_file():
            raise ValueError(f'Required package entrypoint is missing: {name}/{entrypoint}')
    return {'package_count': len(names), 'project_root': str(project_root)}


class Controller:
    def __init__(self, args, plan):
        self.args, self.plan = args, plan
        self.out = ROOT / 'build/revalidation' / args.label
        self.out.mkdir(parents=True, exist_ok=False)
        self.frozen = owner.inputs()
        self.head = git('rev-parse', 'HEAD')
        self.branch = git('branch', '--show-current')
        self.reviewed = [p for p in changed_paths() if not owner.generated_comparison(p)]
        if any(p not in self.frozen for p in self.reviewed):
            raise RuntimeError('Unfingerprinted/deleted dirty path requires review before this run')
        self.state = dict(label=args.label, phase='preflight', expected_head=self.head,
                          source_fingerprint=owner.fingerprint(self.frozen),
                          started_utc=utc(), accepted=False, local_pass=False,
                          all_ci_pass=False, automatic_retry=False, stages=[],
                          manual_physical=plan.get('manual_physical', []))
        self.child = None
        atomic(self.out / 'source-inputs.json', self.frozen)
        atomic(self.out / 'plan.json', plan)
        self.update()

    def update(self, **values):
        self.state.update(values, updated_utc=utc())
        atomic(self.out / 'state', self.state)
        atomic(self.out / 'current-work', dict(
            head=self.state.get('published_head', self.head),
            fingerprint=self.state['source_fingerprint'], phase=self.state['phase'],
            steps=self.state['stages']))

    def stable(self):
        assert_source(self.frozen, self.head, self.branch)

    def command(self, name, command, *, timeout=1800, files=None, full_folder=None):
        self.stable()
        self.update(phase=name, counts={}, tests_completed=0)
        log = self.out / f'{name}.log'
        receipt = self.out / f'{name}-command.json'
        if full_folder is None:
            bounded = ROOT / '.github/scripts/bil_native_bounded_command.py'
            command = [sys.executable, str(bounded), '--label', name,
                       '--log', str(log), '--receipt', str(receipt),
                       '--timeout-seconds', str(timeout), '--running-timeout-seconds', str(timeout),
                       '--', *command]
        # The original full runner remains the sole owner of its Flutter child,
        # resource threshold, acceptance and complete test inventory.
        with (self.out / f'{name}-supervisor.log').open('wb') as output:
            self.child = subprocess.Popen(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
            last_size = -1
            while self.child.poll() is None:
                if full_folder is not None:
                    status = full_folder / 'status.json'
                    if status.exists():
                        try:
                            current = json.loads(status.read_text(encoding='utf-8'))
                            self.update(counts=current.get('counts', {}),
                                        tests_completed=current.get('tests_completed', 0),
                                        full_phase=current.get('phase'),
                                        full_status_path=str(status))
                        except (OSError, ValueError):
                            pass  # A viewer read never establishes PASS.
                elif files is not None and log.exists() and log.stat().st_size != last_size:
                    last_size = log.stat().st_size
                    current = test_result(log, files, -1)
                    self.update(counts=current['counts'], tests_completed=current['tests_completed'])
                time.sleep(2)
            code = self.child.wait()
            self.child = None
        self.stable()
        result = dict(name=name, exit_code=code, log=str(log), finished_utc=utc())
        if files is not None:
            result.update(test_result(log, files, code))
        elif full_folder is not None:
            final = full_folder / 'final-result.json'
            result['accepted'] = (code == 0 and final.is_file() and
                                  json.loads(final.read_text(encoding='utf-8')).get('accepted') is True)
            result['final_result'] = str(final)
        else:
            result['accepted'] = code == 0
        self.state['stages'].append(result)
        self.update()
        return result['accepted']

    def revalidate_prior_local_gates(self):
        if getattr(self.args, 'continue_from', None) != CONTINUATION_PRIOR_LABEL:
            raise RuntimeError('Only the explicitly reviewed prior run may be continued')
        self.stable()
        if self.head != CONTINUATION_PRIOR_HEAD or self.args.expect_head != CONTINUATION_PRIOR_HEAD:
            raise RuntimeError('Continuation requires the exact prior source HEAD')
        prior_dir = ROOT / 'build/revalidation' / CONTINUATION_PRIOR_LABEL
        try:
            prior_state = json.loads((prior_dir / 'state').read_text(encoding='utf-8'))
            prior_final = json.loads((prior_dir / 'final-result.json').read_text(encoding='utf-8'))
            prior_inputs = json.loads((prior_dir / 'source-inputs.json').read_text(encoding='utf-8'))
            prior_plan = json.loads((prior_dir / 'plan.json').read_text(encoding='utf-8'))
            prior_work = json.loads((prior_dir / 'current-work').read_text(encoding='utf-8'))
        except (OSError, ValueError) as error:
            raise RuntimeError('Prior run evidence is missing or unreadable') from error
        if prior_state != prior_final:
            raise RuntimeError('Prior state and final result disagree')
        if (prior_state.get('label') != CONTINUATION_PRIOR_LABEL or
                prior_state.get('expected_head') != CONTINUATION_PRIOR_HEAD or
                prior_state.get('source_fingerprint') != CONTINUATION_PRIOR_FINGERPRINT or
                owner.fingerprint(prior_inputs) != CONTINUATION_PRIOR_FINGERPRINT):
            raise RuntimeError('Prior run identity/fingerprint does not match the reviewed baseline')
        if (prior_state.get('phase') != 'local_gates_failed' or
                prior_state.get('accepted') is not False or
                prior_state.get('local_pass') is not False or
                prior_state.get('all_ci_pass') is not False or
                prior_state.get('automatic_retry') is not False):
            raise RuntimeError('Prior run is not the exact non-retried local-gate failure')
        if self.state.get('source_fingerprint') != owner.fingerprint(self.frozen):
            raise RuntimeError('New continuation source fingerprint is inconsistent')
        changed = continuation_source_changes(prior_inputs, self.frozen)
        if prior_plan != self.plan:
            raise RuntimeError('Release plan or test inventory changed since the prior run')
        if (prior_work.get('head') != CONTINUATION_PRIOR_HEAD or
                prior_work.get('fingerprint') != CONTINUATION_PRIOR_FINGERPRINT or
                prior_work.get('phase') != 'local_gates_failed' or
                prior_work.get('steps') != prior_state.get('stages')):
            raise RuntimeError('Prior dashboard ledger does not match the final result')

        stages = prior_state.get('stages')
        if (not isinstance(stages, list) or
                [stage.get('name') for stage in stages] != CONTINUATION_PRIOR_STAGE_NAMES):
            raise RuntimeError('Prior stage sequence differs from the reviewed run')
        by_name = {stage['name']: stage for stage in stages}
        if any(by_name[name].get('accepted') is not True for name in CONTINUATION_PRIOR_STAGE_NAMES
               if name != 'focused-01'):
            raise RuntimeError('A prior local gate besides focused reporter parsing was not accepted')
        focused_prior = by_name['focused-01']
        if (focused_prior.get('accepted') is not False or focused_prior.get('exit_code') != 0 or
                focused_prior.get('counts') != {'success': 1071, 'failure': 0, 'error': 0, 'skip': 0}):
            raise RuntimeError('Prior focused run differs from the expected reporter-only rejection')

        # Green stage labels are reusable only when their receipts authenticate the exact log bytes.
        for name in (name for name in CONTINUATION_PRIOR_STAGE_NAMES if name != 'validate-package-discovery'):
            stage = by_name[name]
            log = prior_dir / f'{name}.log'
            try:
                receipt = json.loads((prior_dir / f'{name}-command.json').read_text(encoding='utf-8'))
                payload = log.read_bytes()
            except (OSError, ValueError) as error:
                raise RuntimeError(f'Prior {name} receipt/log is missing or unreadable') from error
            if (stage.get('exit_code') != 0 or stage.get('log') != str(log) or
                    receipt.get('label') != name or receipt.get('effective_returncode') != 0 or
                    receipt.get('output_complete') is not True or receipt.get('timed_out') is not False or
                    receipt.get('supervisor_error') is not None or
                    receipt.get('output_bytes') != len(payload) or
                    receipt.get('output_sha256') != hashlib.sha256(payload).hexdigest()):
                raise RuntimeError(f'Prior {name} command receipt does not authenticate its log')

        try:
            discovery = json.loads((prior_dir / 'validate-package-discovery.json').read_text(encoding='utf-8'))
            current_discovery = validate_package_discovery(ROOT, required_entrypoints={
                'simple_barcode_scanner': 'simple_barcode_scanner.dart'})
        except (OSError, ValueError) as error:
            raise RuntimeError('Package discovery evidence cannot be revalidated without dependency installation') from error
        expected_discovery = {'package_count': 248, 'project_root': str(ROOT.resolve())}
        if (discovery.get('accepted') is not True or
                {key: discovery.get(key) for key in expected_discovery} != expected_discovery or
                current_discovery != expected_discovery):
            raise RuntimeError('Current resolved package discovery differs from the prior green result')

        focused = test_result(prior_dir / 'focused-01.log', self.plan['focused'], 0)
        raw_shell = [line for line in (prior_dir / 'focused-01.log').read_text(
            encoding='utf-8', errors='replace').splitlines() if line.startswith('Shell: ')]
        if (focused.get('accepted') is not True or
                focused.get('counts') != {'success': 1071, 'failure': 0, 'error': 0, 'skip': 0} or
                focused.get('tests_completed') != 1071 or focused.get('files_loaded') != 62 or
                focused.get('files_with_test_outcomes') != 62 or focused.get('files_not_loaded') or
                focused.get('files_without_test_outcome') or focused.get('error_events') != 0 or
                focused.get('recognized_shell_diagnostics') != {
                    'sqlite_fixture_lifecycle': 158, 'sqlite_performance_fixture': 2} or
                len(focused_prior.get('malformed_protocol_lines', [])) != 160 or
                sorted(raw_shell) != sorted(focused_prior.get('malformed_protocol_lines', [])) or
                any(recognized_shell_diagnostic(line) is None for line in raw_shell)):
            raise RuntimeError('Prior focused results do not reduce exactly to known SQLite fixture diagnostics')

        goldens = test_result(prior_dir / 'goldens-01.log', self.plan['goldens'], 0)
        if (goldens.get('accepted') is not True or
                goldens.get('counts') != {'success': 1767, 'failure': 0, 'error': 0, 'skip': 0} or
                goldens.get('tests_completed') != 1767 or goldens.get('files_loaded') != 95 or
                goldens.get('files_with_test_outcomes') != 95 or goldens.get('malformed_protocol_lines')):
            raise RuntimeError('Prior all-goldens run cannot be revalidated from its complete log')
        analysis = (prior_dir / 'full-analysis.log').read_text(encoding='utf-8', errors='replace')
        if 'No issues found!' not in analysis or by_name['full-analysis'].get('accepted') is not True:
            raise RuntimeError('Prior full analysis log does not contain its successful terminal result')

        report = {
            'prior_run': CONTINUATION_PRIOR_LABEL,
            'prior_head': CONTINUATION_PRIOR_HEAD,
            'prior_fingerprint': CONTINUATION_PRIOR_FINGERPRINT,
            'verified_changed_paths': changed,
            'reused_green_stages': ['resolve-locked-dependencies', 'validate-package-discovery',
                                    'format-reviewed', 'goldens-01', 'full-analysis'],
            'focused_reparsed': {
                'tests_completed': focused['tests_completed'],
                'files_loaded': focused['files_loaded'],
                'recognized_shell_diagnostics': focused['recognized_shell_diagnostics'],
                'prior_raw_diagnostic_lines': len(raw_shell),
            },
            'goldens_reparsed': {'tests_completed': goldens['tests_completed'],
                                 'files_loaded': goldens['files_loaded']},
            'analysis_log_sha256': sha(prior_dir / 'full-analysis.log'),
            'package_discovery': current_discovery,
            'release_controller_regressions_must_rerun': True,
            'accepted': True,
        }
        self.state['stages'].append(dict(name='prior-local-gates-revalidated', accepted=True,
                                         finished_utc=utc(), evidence=report))
        self.update(phase='prior-local-gates-revalidated', prior_local_gates=report)
        self.stable()
        return report

    def local(self):
        flutter = Path(self.args.flutter).resolve()
        dart = flutter.parent / 'cache/dart-sdk/bin/dart.exe'
        snapshot = flutter.parent / 'cache/flutter_tools.snapshot'
        engine = [str(dart), str(snapshot)]
        version = json.loads(capture([*engine, '--version', '--machine']))
        if version.get('frameworkVersion') != '3.44.6':
            raise RuntimeError('Pinned Flutter3.44.6 is required')
        if sha(ROOT / 'tools/qa/bil_owner_full_test_runner.py') != RUNNER_SHA:
            raise RuntimeError('Original comprehensive runner was changed')
        owner.verified_branch(self.head, self.branch)
        if getattr(self.args, 'continue_from', None):
            with owner.ExclusiveRun(ROOT / 'build/owner-full/active-run.lock'):
                self.revalidate_prior_local_gates()
                if not self.command('release-controller-regressions', [sys.executable, '-m', 'unittest',
                                    'discover', '-s', 'tools/qa', '-p', 'test_bil_release*.py', '-v'], timeout=600):
                    self.update(phase='release_controller_regressions_failed', accepted=False)
                    return False
            return self.run_original_full_suite(flutter)
        ok = True
        with owner.ExclusiveRun(ROOT / 'build/owner-full/active-run.lock'):
            if not self.command('resolve-locked-dependencies',
                                [*engine, 'pub', 'get', '--enforce-lockfile']):
                self.update(phase='dependency_bootstrap_failed', accepted=False)
                return False
            self.stable()
            self.update(phase='validate-package-discovery')
            discovery = dict(name='validate-package-discovery', finished_utc=utc())
            try:
                discovery.update(validate_package_discovery(ROOT, required_entrypoints={
                    'simple_barcode_scanner': 'simple_barcode_scanner.dart'}), accepted=True)
            except (OSError, ValueError) as error:
                discovery.update(accepted=False, error=str(error))
            self.stable()
            atomic(self.out / 'validate-package-discovery.json', discovery)
            self.state['stages'].append(discovery)
            self.update()
            if not discovery['accepted']:
                self.update(phase='dependency_bootstrap_failed', accepted=False)
                return False
            if not self.command('release-controller-regressions', [sys.executable, '-m', 'unittest',
                                'discover', '-s', 'tools/qa', '-p', 'test_bil_release*.py', '-v'], timeout=600):
                self.update(phase='release_controller_regressions_failed', accepted=False)
                return False
            dart_paths = [p for p in self.reviewed if p.endswith('.dart')]
            if dart_paths:
                ok = self.command('format-reviewed', [str(dart), 'format', '--output=none',
                                  '--set-exit-if-changed', *dart_paths], timeout=300) and ok
            base = [*engine, 'test', '--no-pub', '--reporter=json', '--concurrency=1', '--timeout=3m',
                    '--dart-define=BIL_PAYMENTS_ENABLED=true',
                    '--dart-define=BIL_TERMS_URL=https://www.bilhealth.com/terms',
                    '--dart-define=BIL_PRIVACY_URL=https://www.bilhealth.com/privacy']
            # Continue these diagnostic stages to retain every actual failure;
            # any failure blocks the expensive full run and all publishing.
            for stage in ('focused', 'goldens'):
                for index, group in enumerate(batches(base, self.plan[stage]), 1):
                    ok = self.command(f'{stage}-{index:02}', [*base, *group],
                                      timeout=5400, files=group) and ok
            ok = self.command('full-analysis', [*engine, 'analyze', '--no-pub',
                              '--fatal-infos', '--fatal-warnings'], timeout=1800) and ok
        if not ok:
            self.update(phase='local_gates_failed', accepted=False)
            return False
        return self.run_original_full_suite(flutter)

    def run_original_full_suite(self, flutter):
        # Preserve the original 4GiB admission guard. Waiting is explicit and
        # visible; no threshold changes or killing unrelated applications.
        deadline = time.monotonic() + self.args.wait_resources_seconds
        while True:
            resources = owner.resources()
            available = resources['ram_available_bytes']
            if resources['disk_free_bytes'] < 5 * 1024**3:
                raise RuntimeError('Original full-suite disk guard: less than5GiB')
            if available is None or available >= 4 * 1024**3:
                break
            self.update(phase='waiting_for_original_4gib_guard', resources=resources)
            if time.monotonic() >= deadline:
                raise RuntimeError('Original4GiB RAM guard remains unmet; full suite did not start')
            time.sleep(30)
            self.stable()
        label = f'{self.args.label}-full'
        folder = ROOT / 'build/owner-full' / label
        good = self.command('original-full-suite', [sys.executable, '-u',
                            str(ROOT / 'tools/qa/bil_owner_full_test_runner.py'), label,
                            '--expect-head', self.head, '--flutter', str(flutter),
                            '--dashboard-dir', str(self.out / 'original-full-dashboard')], full_folder=folder)
        self.update(local_pass=good, phase='local_pass' if good else 'full_suite_failed')
        return good

    def publish(self):
        if self.state.get('local_pass') is not True:
            raise RuntimeError('Commit/push requires all local stages and original full suite PASS')
        assert_publishable(frozen=self.frozen, head=self.head, branch=self.branch,
                           expected_remote=self.args.expect_head, reviewed_paths=self.reviewed)
        self.update(phase='publishing_validated_source')
        if self.reviewed:
            subprocess.run(['git', 'add', '--', *self.reviewed], cwd=ROOT, check=True)
            if set(git('diff', '--cached', '--name-only').splitlines()) != set(self.reviewed):
                raise RuntimeError('Staged path inventory differs from reviewed frozen paths')
            subprocess.run(['git', 'commit', '-m',
                            'fix: complete BIL release repairs and gated TestFlight validation'], cwd=ROOT, check=True)
        previous_head = self.head
        self.head = git('rev-parse', 'HEAD')
        if owner.inputs() != self.frozen:
            raise RuntimeError('Commit hook changed validated inputs; push blocked')
        verify_commit_inputs(self.frozen, expected_parent=previous_head if self.reviewed else None)
        if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != self.args.expect_head:
            raise RuntimeError('Remote changed before push; no force push is permitted')
        self.update(push_started_utc=datetime.now(timezone.utc).replace(microsecond=0).isoformat())
        subprocess.run(['git', 'push', 'origin', f'HEAD:refs/heads/{BRANCH}'], cwd=ROOT, check=True)
        if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != self.head:
            raise RuntimeError('Published remote SHA could not be verified')
        atomic(self.out / 'published-source.json', dict(
            validated_base_head=self.args.expect_head, published_head=self.head,
            source_fingerprint=owner.fingerprint(self.frozen), identical_inputs=True,
            committed_paths=self.reviewed, utc=utc()))
        self.update(published_head=self.head)

    def gh(self, endpoint, *, method=None, fields=None):
        cmd = ['gh', 'api', f'repos/{REPO}/{endpoint}']
        if method:
            cmd += ['--method', method]
        if fields is not None:
            cmd += ['--input', '-']
            result = subprocess.run(cmd, input=json.dumps(fields), cwd=ROOT,
                                    encoding='utf-8', capture_output=True, timeout=120)
            if result.returncode:
                raise RuntimeError(f'GitHub API mutation failed with exit{result.returncode}; no automatic retry')
            return json.loads(result.stdout) if result.stdout.strip() else None
        return json.loads(capture(cmd))

    def ci(self):
        pending = list(self.plan['workflows'])
        runs = []
        while pending:
            passed = {entry['lane'].get('lane_id'): entry for entry in runs if entry['status'] == 'success'}
            ready = [lane for lane in pending if set(lane.get('depends_on', [])) <= passed.keys()]
            if not ready:
                self.update(phase='github_dependencies_blocked', all_ci_pass=False)
                return
            resolved = []
            for lane in ready:
                inputs = dict(lane['inputs'])
                for key, producer in lane.get('input_from_run', {}).items():
                    inputs[key] = str(passed[producer]['run_id'])
                resolved.append(dict(lane, inputs=inputs))
            runs = self.ci_batch(resolved, prior_runs=runs)
            if not self.state.get('all_ci_pass'):
                return
            pending = [lane for lane in pending if lane not in ready]
        if self.plan.get('delivery'):
            delivery = load('bil_release_delivery', ROOT / 'tools/qa/bil_release_delivery.py')
            delivery.deliver(self, runs)

    def ci_batch(self, lanes, *, prior_runs=()):
        if not self.args.publish:
            self.update(phase='local_pass_ci_not_dispatched', accepted=False)
            return list(prior_runs)
        runs = list(prior_runs)
        self.update(phase='github_dispatching')
        for lane in lanes:
            self.stable()
            old = self.gh(f"actions/workflows/{lane['workflow_id']}/runs?per_page=100")['workflow_runs']
            if lane.get('reuse_push_run') and self.state.get('push_started_utc'):
                boundary = self.state['push_started_utc']
                discover_until = time.monotonic() + 180
                while True:
                    automatic = [r for r in old if r.get('head_sha') == self.head and
                        r.get('head_branch') == BRANCH and r.get('event') == 'push' and
                        r.get('created_at', '') >= boundary.replace('+00:00', 'Z')]
                    if automatic or not lane.get('expect_push_for_this_run'):
                        break
                    if time.monotonic() >= discover_until:
                        raise RuntimeError('Expected automatic push run was not observed; no duplicate dispatch')
                    self.stable()
                    if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != self.head:
                        raise RuntimeError('Remote moved while waiting for automatic CI')
                    self.update(phase='waiting_for_exact_source_push_run')
                    time.sleep(10)
                    old = self.gh(f"actions/workflows/{lane['workflow_id']}/runs?per_page=100")['workflow_runs']
                if len(automatic) > 1:
                    raise RuntimeError('Multiple automatic runs match this source; no duplicate dispatch')
                if automatic:
                    run = automatic[0]
                    runs.append(dict(lane=lane, after_run_id=run['id'] - 1,
                        created_after=boundary, bound_event='push', origin='reused_exact_source_push',
                        run_id=run['id'], url=run['html_url'], status=run['status']))
                    atomic(self.out / 'github-state', dict(snapshot_utc=utc(), runs=runs))
                    continue
            after = max((r['id'] for r in old), default=-1)
            boundary = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
            entry = dict(lane=lane, after_run_id=after, created_after=boundary,
                         status='dispatch_intent', intent_utc=utc(), bound_event='workflow_dispatch')
            runs.append(entry)
            # Persist before the POST. An unknown network outcome is never retried.
            atomic(self.out / 'github-state', dict(snapshot_utc=utc(), runs=runs))
            if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != self.head:
                raise RuntimeError('Remote moved before dispatch; no request was sent')
            try:
                self.gh(f"actions/workflows/{lane['workflow_id']}/dispatches", method='POST', fields={
                    'ref': BRANCH, 'inputs': lane.get('inputs', {})})
            except BaseException:
                entry.update(status='dispatch_outcome_unknown', last_update_utc=utc())
                atomic(self.out / 'github-state', dict(snapshot_utc=utc(), runs=runs))
                raise
            entry.update(status='discovering', dispatched_utc=utc())
            atomic(self.out / 'github-state', dict(snapshot_utc=utc(), runs=runs))
            # Bind this dispatch before sending another profile of the same workflow.
            discover_until = time.monotonic() + 180
            while True:
                self.stable()
                if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != self.head:
                    raise RuntimeError('Remote moved after dispatch; source certification blocked')
                candidates = self.candidates(lane, entry)
                if len(candidates) > 1:
                    raise RuntimeError('Ambiguous CI dispatch; no guessed run identity')
                if candidates:
                    run = candidates[0]
                    entry.update(run_id=run['id'], url=run['html_url'], status=run['status'])
                    atomic(self.out / 'github-state', dict(snapshot_utc=utc(), runs=runs))
                    break
                if time.monotonic() >= discover_until:
                    raise RuntimeError('Dispatched run was not identified; no automatic resubmission')
                time.sleep(10)
        self.update(phase='github_running')
        deadline = time.monotonic() + self.args.ci_timeout_hours * 3600
        while any(r['status'] not in ('success', 'failed') for r in runs):
            self.stable()
            if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != self.head:
                raise RuntimeError('Remote source moved during CI; results cannot certify another source')
            if time.monotonic() >= deadline:
                self.update(phase='github_pending_timeout', all_ci_pass=False)
                return runs
            for entry in runs:
                if entry['status'] in ('success', 'failed'):
                    continue
                lane = entry['lane']
                bound_id = entry['run_id']
                run = self.gh(f"actions/runs/{bound_id}")
                if (run.get('id') != bound_id or run.get('head_branch') != BRANCH or
                        run.get('event') != entry.get('bound_event', 'workflow_dispatch') or
                        run.get('head_sha') != self.head or
                        run.get('workflow_id') != lane['workflow_id']):
                    raise RuntimeError('Final GitHub API identity differs from the bound dispatch')
                entry.update(run_id=run['id'], url=run['html_url'], status=run['status'],
                             conclusion=run['conclusion'])
                if run['status'] == 'completed':
                    # Jobs are normally <100; pagination is explicit for large matrices.
                    jobs, page = [], 1
                    while True:
                        data = self.gh(f"actions/runs/{run['id']}/jobs?per_page=100&page={page}")['jobs']
                        jobs += data
                        if len(data) < 100:
                            break
                        page += 1
                    run['jobs'] = jobs
                    atomic(self.out / f"ci-{lane['workflow_id']}-{run['id']}.json", run)
                    try:
                        proof = planner.validate_ci_run(run, expected_head=self.head,
                            expected_workflow_id=lane['workflow_id'], after_run_id=entry['after_run_id'],
                            created_after=entry['created_after'], required_job_names=lane['required_jobs'])
                        for marker in lane.get('required_log_markers', []):
                            log = capture(['gh', 'run', 'view', str(run['id']), '--repo', REPO, '--log'], timeout=180)
                            if marker not in log:
                                raise planner.PlanValidationError(f'Required evidence marker absent: {marker}')
                        entry.update(status='success', proof=proof)
                    except planner.PlanValidationError as error:
                        entry.update(status='failed', error=str(error))
            atomic(self.out / 'github-state', dict(snapshot_utc=utc(), runs=runs))
            self.update()
            if any(r['status'] not in ('success', 'failed') for r in runs):
                time.sleep(60)
        passed = all(r['status'] == 'success' for r in runs) and bool(runs)
        self.update(all_ci_pass=passed, accepted=False,
                    phase='ci_pass_external_release_gates_pending' if passed else 'github_failed')
        return runs

    def candidates(self, lane, entry):
        return [r for r in self.gh(
            f"actions/workflows/{lane['workflow_id']}/runs?per_page=100")['workflow_runs']
            if r['id'] > entry['after_run_id'] and r['head_sha'] == self.head
            and r['event'] == 'workflow_dispatch' and r['head_branch'] == BRANCH
            and r['created_at'] >= entry['created_after'].replace('+00:00', 'Z')]


def start_dashboard(folder, port):
    # A separate hidden server keeps the final evidence visible after controller exit.
    log = (folder / 'dashboard-server.log').open('ab')
    try:
        process = subprocess.Popen([sys.executable, str(ROOT / 'tools/qa/bil_revalidation_dashboard_server.py'),
            '--directory', str(folder), '--port', str(port)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    finally:
        log.close()
    import urllib.request
    for _ in range(50):
        if process.poll() is not None:
            raise RuntimeError('Dashboard server did not bind; existing listener was not changed')
        try:
            with urllib.request.urlopen(f'http://127.0.0.1:{port}/state', timeout=1) as response:
                state = json.load(response)
            if state.get('label') == folder.name:
                atomic(folder / 'dashboard-server.json', dict(pid=process.pid, port=port,
                       directory=str(folder), verified_utc=utc(), final_page_remains_visible=True))
                return process
        except (OSError, ValueError):
            pass
        time.sleep(.1)
    process.terminate()
    raise RuntimeError('Fresh dashboard identity could not be verified')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--expect-head', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--ci-manifest', type=Path, required=True)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--continue-from', choices=[CONTINUATION_PRIOR_LABEL])
    parser.add_argument('--publish', action='store_true')
    parser.add_argument('--launch-background', action='store_true')
    parser.add_argument('--port', type=int, default=8770)
    parser.add_argument('--wait-resources-seconds', type=int, default=3600)
    parser.add_argument('--ci-timeout-hours', type=int, default=12)
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9][a-z0-9-]{1,75}', args.label):
        parser.error('A fresh plain run label is required')
    if args.publish and not args.run:
        parser.error('--publish requires --run')
    if args.continue_from and not args.run:
        parser.error('--continue-from requires --run')
    if args.continue_from and args.label == args.continue_from:
        parser.error('Continuation requires a fresh, unused label')
    if git('rev-parse', 'HEAD') != args.expect_head:
        parser.error('Expected HEAD differs from current source')
    manifest = json.loads(args.ci_manifest.read_text(encoding='utf-8'))
    lanes = planner.validate_ci_manifest(manifest,
        required_workflow_ids=manifest['required_workflow_ids'])
    plan = dict(manifest, workflows=lanes, focused=planner.focused_inventory(ROOT),
                goldens=planner.golden_inventory(ROOT), original_runner_sha256=RUNNER_SHA,
                e2e_inventory=planner.e2e_inventory(ROOT, manifest),
                order=['focused', 'all-goldens', 'full-analysis', 'original-full-suite',
                       'commit-push-if-all-local-pass', 'cloud-native-e2e-and-adversarial-github',
                       'strict-findings-review', 'signed-ios37-and-testflight-if-all-gates-pass'],
                release_certified=False)
    if args.launch_background:
        if not args.run:
            parser.error('--launch-background requires --run')
        folder = ROOT / 'build/revalidation-launches'
        folder.mkdir(parents=True, exist_ok=True)
        log_path = folder / f'{args.label}.log'
        if log_path.exists():
            parser.error('Launch label already exists; no automatic rerun')
        arguments = [a for a in sys.argv[1:] if a != '--launch-background']
        with log_path.open('xb') as log:
            process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), *arguments],
                cwd=ROOT, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        atomic(folder / f'{args.label}.json', dict(pid=process.pid, launched_utc=utc(),
            label=args.label, initial_head=args.expect_head, log=str(log_path),
            dashboard=f'http://127.0.0.1:{args.port}/',
            controller=str(Path(__file__).resolve()), original_runner_sha256=RUNNER_SHA))
        print(json.dumps(dict(pid=process.pid, log=str(log_path),
                             dashboard=f'http://127.0.0.1:{args.port}/')))
        return 0
    if not args.run:
        print(json.dumps(plan, indent=2))
        return 0
    with owner.ExclusiveRun(ROOT / 'build/revalidation/controller.lock'):
        control = Controller(args, plan)
        # A small current-stage page; the original detailed page is linked during full.
        page = ROOT / 'tools/qa/revalidation_dashboard.html'
        (control.out / 'index.html').write_bytes(page.read_bytes())
        atomic(control.out / 'github-state', dict(snapshot_utc=utc(), runs=[]))
        try:
            start_dashboard(control.out, args.port)
            if args.publish:
                capture(['gh', 'api', 'user', '--jq', '.login'])
                if git('ls-remote', 'origin', f'refs/heads/{BRANCH}').split()[0] != args.expect_head:
                    raise RuntimeError('Remote must match the frozen local base before starting')
            if not control.local():
                return 1
            if args.publish:
                control.publish()
            control.ci()
            return 0 if control.state.get('all_ci_pass') else 2
        except BaseException as error:
            if control.child is not None and control.child.poll() is None:
                owner.terminate_owned_process(control.child, lambda result: control.update(
                    phase='terminating_owned_child', termination=result))
            control.update(phase='controller_stopped', error=f'{type(error).__name__}: {error}',
                           accepted=False)
            return 1
        finally:
            atomic(control.out / 'final-result.json', control.state)


if __name__ == '__main__':
    raise SystemExit(main())
