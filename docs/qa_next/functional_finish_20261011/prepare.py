"""Narrow follow-up to the integrated 84-file candidate; no behavioral test claims."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
OUT = Path('build/bil-functional-finish')
REPORT = Path('docs/qa_next/evidence/20261011-functional-integration/final-supplement.json')
BRANCH = 'integration/bil-qa-media-policy-20261011'
REPO = 'bilhealth-admin/Body-Intelligence'

def git(*args):
    return subprocess.check_output(['git', *args]).decode().strip()

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def protected():
    prior = json.loads(Path('docs/qa_next/evidence/20261011-functional-integration/preparation.json').read_text())
    for name, expected in prior['protected_sha256'].items():
        assert digest(name) == expected, f'Protected file changed: {name}'
    return prior['protected_sha256']

def check(names):
    subprocess.run(['git', 'add', '-N', '--', *names], check=True)
    changed = set(git('diff', '--name-only').splitlines())
    assert changed == set(names), f'Unexpected source drift: {changed ^ set(names)}'
    assert not git('diff', '--name-only', '--diff-filter=D'), 'Deletion forbidden'
    subprocess.run(['git', 'diff', '--check'], check=True)
    protected()
    for name in names:
        assert len(Path(name).read_text().splitlines()) <= 1500, name
    (OUT / 'paths.txt').write_text('\n'.join(names) + '\n')
    (OUT / 'source.patch').write_text(git('diff', '--binary', '--', *names) + '\n')

if __name__ == '__main__':
    assert os.environ.get('GITHUB_REPOSITORY', REPO) == REPO
    assert os.environ.get('GITHUB_REF', 'refs/heads/' + BRANCH) == 'refs/heads/' + BRANCH
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    names = [row['path'] for row in manifest['files']]
    assert len(names) == len(set(names)) == 13
    guarded = protected()
    for name in names:
        p = PurePosixPath(name)
        assert not p.is_absolute() and '..' not in p.parts
        assert p.parts[0] in ('lib', 'test') and p.suffix == '.dart' and name not in guarded
        assert not any(Path(*p.parts[:i]).is_symlink() for i in range(1, len(p.parts) + 1))
    if sys.argv[1] == 'apply':
        for row in manifest['files']:
            if row['before'] is None:
                assert not Path(row['path']).exists(), row['path']
            else:
                assert digest(row['path']) == row['before'], f"Base drift: {row['path']}"
        patch = ROOT / 'source.patch'
        subprocess.run(['git', 'apply', '--check', str(patch)], check=True)
        subprocess.run(['git', 'apply', str(patch)], check=True)
        for row in manifest['files']:
            assert digest(row['path']) == row['after'], f"Result mismatch: {row['path']}"
        check(names)
    elif sys.argv[1] == 'finalize':
        assert os.environ.get('ANALYZE_OUTCOME') == 'success'
        check(names)
        result = {'base': manifest['base'], 'preparation_head': git('rev-parse', 'HEAD'),
                  'run_id': os.environ.get('GITHUB_RUN_ID'), 'source_files': len(names),
                  'format': 'passed', 'analyze': 'passed', 'flutter_tests_run': False,
                  'full8_run': False, 'builds': False, 'production_changed': False,
                  'store_approved': False, 'protected_sha256': guarded,
                  'files': [{'path': name, 'sha256': digest(name)} for name in names],
                  'scope': 'Immutable per-serving 13-nutrient evidence, USDA links, no automatic workout paywall.',
                  'pending': 'Independent focused Codex tests, device UX, cloud round-trip and performance verification.'}
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        (OUT / 'preparation.json').write_text(REPORT.read_text())
    else:
        raise SystemExit('Unknown command')
