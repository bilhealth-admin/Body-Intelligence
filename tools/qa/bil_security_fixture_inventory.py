"""Discover and execute reviewed non-live Node fixtures, without app builds."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOTS = ('tool/shared', 'tool/prebuild', 'tool/release',
         'tool/apple_store_connect', 'tool/google_play', 'tools')
LIVE_NAME = re.compile(r'(?:^|_)(?:live|e2e|native|postgres|production)(?:_|\.)')
ENV_KEYS = ('PATH', 'SystemRoot', 'WINDIR', 'COMSPEC', 'PATHEXT',
            'HOME', 'USERPROFILE', 'LOCALAPPDATA', 'APPDATA', 'LANG', 'LC_ALL')


def discover(root: Path) -> list[Path]:
    root = root.resolve(strict=True)
    found = set()
    for folder in ROOTS:
        for path in (root / folder).rglob('*.mjs'):
            if any(part in ('node_modules', '.git', '.dart_tool', 'build') for part in path.relative_to(root).parts):
                continue
            if not path.name.endswith(('.test.mjs', '_test.mjs')):
                continue
            if LIVE_NAME.search(path.name):
                raise ValueError('Live/native-named test needs a separate reviewed lane: '
                                 + path.relative_to(root).as_posix())
            if path.is_symlink() or not path.resolve().is_relative_to(root):
                raise ValueError('Test escapes source root')
            found.add(path.relative_to(root))
    return sorted(found)


def fixture_env(output: Path, guard: Path) -> dict[str, str]:
    env = {key: os.environ[key] for key in ENV_KEYS if key in os.environ}
    temporary = output.resolve() / 'private-tmp'
    temporary.mkdir(parents=True, exist_ok=False)
    env.update(TMP=str(temporary), TEMP=str(temporary), TMPDIR=str(temporary),
               BIL_FIXTURE_ONLY='true', TZ='UTC')
    env['NODE_OPTIONS'] = ' '.join((
        '--require=' + json.dumps(guard.resolve().as_posix()),
        '--permission', '--allow-fs-read=*',
        '--allow-fs-write=' + json.dumps(temporary.as_posix()),
        '--allow-child-process',
        # The permission model itself otherwise prepends its known warning to
        # child CLI stderr, breaking exact JSON diagnostics under test. The
        # limitation is recorded below; assertion/error output is not filtered.
        '--disable-warning=SecurityWarning'))
    return env


def run(root: Path, output: Path, node: str, *, guard: Path,
        expected_sha: str | None = None) -> dict:
    root = root.resolve(strict=True)
    output = output.resolve()
    if output.is_relative_to(root):
        raise ValueError('Evidence must be outside source checkout')
    output.mkdir(parents=True, exist_ok=False)
    if expected_sha is not None:
        if not re.fullmatch('[0-9a-f]{40}', expected_sha):
            raise ValueError('Expected SHA must be exact')
        actual = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
        if actual != expected_sha:
            raise ValueError('Source SHA mismatch')
        if subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain=v1', '--untracked-files=all'], text=True).strip():
            raise ValueError('Source checkout must be clean')
    paths = discover(root)
    if not paths:
        raise ValueError('No fixture tests discovered')
    before = {p.as_posix(): hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
    env = fixture_env(output, guard)
    report = {'schema': 'bil.fixture-security-inventory.v1', 'source_sha': expected_sha,
              'created_utc': datetime.now(timezone.utc).isoformat(),
              'network': 'Node transports denied; per-test injected stubs allowed',
              'write_scope': 'private temporary fixture directory only',
              'boundary': 'Reviewed unit fixtures; not a hostile-code sandbox or live security certification',
              'node_permission_warning': 'Only the exact known --allow-child-process permission note is omitted. The preload restores all other SecurityWarning messages and leaves assertions/errors unfiltered. Node permission model is accident prevention, not malicious-code containment.',
              'files': [], 'status': 'RUNNING'}
    def save():
        (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    save()
    for index, path in enumerate(paths):
        log = output / f'{index:02d}-{path.name}.tap.log'
        with log.open('w', encoding='utf-8') as stream:
            try:
                result = subprocess.run([node, '--test', '--test-reporter=tap', str(root / path)], cwd=root,
                                        env=env, stdout=stream, stderr=subprocess.STDOUT,
                                        timeout=120, check=False)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
            except OSError as error:
                stream.write(type(error).__name__ + '\n')
                code = 125
        text = log.read_text(encoding='utf-8', errors='replace')
        counts = {key: int(match.group(1)) if (match := re.search(r'^# ' + key + r' (\d+)$', text, re.M)) else None
                  for key in ('tests', 'pass', 'fail', 'cancelled', 'skipped', 'todo')}
        row = {'path': path.as_posix(), 'sha256': before[path.as_posix()],
               'exit_code': code, 'log': log.name,
               'counts': counts,
               'skipped': counts['skipped'] is None or counts['skipped'] > 0}
        report['files'].append(row)
        print(json.dumps(row), flush=True)
        save()
    after = {p.as_posix(): hashlib.sha256((root / p).read_bytes()).hexdigest() for p in discover(root)}
    report['source_unchanged'] = before == after
    if expected_sha is not None:
        report['checkout_clean_after'] = not subprocess.check_output(
            ['git', '-C', str(root), 'status', '--porcelain=v1', '--untracked-files=all'], text=True).strip()
    report['status'] = 'PASS' if (before == after and report.get('checkout_clean_after', True)
        and all(r['exit_code'] == 0 and not r['skipped'] and r['counts']['todo'] == 0
                and r['counts']['cancelled'] == 0 and r['counts']['fail'] == 0
                and r['counts']['tests'] > 0 for r in report['files'])) else 'FAIL'
    save()
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--output', type=Path)
    parser.add_argument('--expected-sha')
    parser.add_argument('--node', default=shutil.which('node'))
    args = parser.parse_args()
    if args.output is None:
        print(json.dumps([p.as_posix() for p in discover(args.root)], indent=2))
        return 0
    if not args.node:
        parser.error('Node is required')
    report = run(args.root, args.output, args.node,
                 guard=Path(__file__).with_name('bil_fixture_network_deny.cjs'),
                 expected_sha=args.expected_sha)
    return int(report['status'] != 'PASS')


if __name__ == '__main__':
    raise SystemExit(main())
