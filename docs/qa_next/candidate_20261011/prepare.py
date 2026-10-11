"""Guarded source preparation, never a release or device-test certificate."""
import base64
import bz2
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
OUT = Path('build/bil-candidate-20261011')
BRANCH = 'integration/bil-qa-media-policy-20261011'
REPO = 'bilhealth-admin/Body-Intelligence'
REPORT = Path('docs/qa_next/evidence/20261011-functional-integration/preparation.json')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args]).decode().strip()


def read_part(name, expected):
    raw = (ROOT / name).read_text().strip().encode('ascii')
    if digest(raw) == expected:
        return raw
    repairs = {
        'part00.b64': ('e2969a20b2462b2361e5a0c303c5627c7c8f8c13c36e1298df7b25b625c11372', [(6097, 6099), (5732, 5734)]),
        'part02.b64': ('fb455393ecc647fd55084ac8ec5c654db35ef2d0dc501f1d760f81ef289bed0f', [(6466, 6468)]),
    }
    assert name in repairs, f'Unexpected transport error: {name}'
    received_hash, ranges = repairs[name]
    assert digest(raw) == received_hash, f'Unknown received bytes: {name}'
    for start, end in ranges:
        raw = raw[:start] + raw[end:]
    assert digest(raw) == expected, f'Original integrity not restored: {name}'
    print(f'Byte-exact transport repair: {name}; original frozen SHA256 verified.')
    return raw


def bundle():
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    assert manifest['chunks'] == len(manifest['parts']) == 11
    received = OUT / 'received-parts'
    received.mkdir(parents=True, exist_ok=True)
    for i in range(11):
        name = f'part{i:02}.b64'
        (received / name).write_bytes((ROOT / name).read_bytes())
    parts = []
    for name, expected in sorted(manifest['parts'].items()):
        assert name in [f'part{i:02}.b64' for i in range(11)]
        raw = read_part(name, expected)
        assert digest(raw) == expected, f'Part integrity failed: {name}'
        parts.append(raw)
    encoded = b''.join(parts)
    assert digest(encoded) == manifest['encoded_sha256'], 'Encoded integrity'
    decoder = bz2.BZ2Decompressor()
    raw = decoder.decompress(base64.b64decode(encoded, validate=True), max_length=2000000)
    assert decoder.eof and not decoder.unused_data, 'Truncated/oversized bundle'
    assert len(raw) == manifest['decoded_bytes']
    assert digest(raw) == manifest['decoded_sha256'], 'Decoded integrity'
    data = json.loads(raw)
    assert data['version'] == 1 and data['base'] == manifest['base']
    assert len(data['files']) == manifest['file_count'] == 78
    names = [row['path'] for row in data['files']]
    assert len(set(names)) == len(names), 'Duplicate paths'
    for name in names:
        path = PurePosixPath(name)
        assert not path.is_absolute() and '..' not in path.parts
        assert path.parts[0] in ('lib', 'test') and path.suffix == '.dart'
        assert not any(Path(*path.parts[:i]).is_symlink() for i in range(1, len(path.parts)+1))
        assert name not in data['protected'], 'Protected path requested'
    return data


def protected(data):
    for name, expected in data['protected'].items():
        assert digest(Path(name).read_bytes()) == expected, f'Protected file changed: {name}'


def validate_changes(data):
    names = [row['path'] for row in data['files']]
    subprocess.run(['git', 'add', '-N', '--', *names], check=True)
    changed = set(git('diff', '--name-only').splitlines())
    assert changed == set(names), f'Unexpected changed files: {changed ^ set(names)}'
    assert not git('diff', '--name-only', '--diff-filter=D'), 'Deletion forbidden'
    subprocess.run(['git', 'diff', '--check'], check=True)
    protected(data)
    for name in names:
        assert len(Path(name).read_text().splitlines()) <= 1500, name
    (OUT / 'source.patch').write_text(git('diff', '--binary', '--', *names) + '\n')


def apply(data):
    assert os.environ.get('GITHUB_REPOSITORY', REPO) == REPO
    assert os.environ.get('GITHUB_REF', 'refs/heads/' + BRANCH) == 'refs/heads/' + BRANCH
    protected(data)
    for row in data['files']:
        path = Path(row['path'])
        if row['before'] is None:
            assert not path.exists(), f'New file already exists: {path}'
        else:
            assert digest(path.read_bytes()) == row['before'], f'Base drift: {path}'
    patch = OUT / 'candidate.patch'
    patch.write_text(data['patch'])
    subprocess.run(['git', 'apply', '--check', str(patch)], check=True)
    subprocess.run(['git', 'apply', str(patch)], check=True)
    for row in data['files']:
        assert digest(Path(row['path']).read_bytes()) == row['after'], row['path']
    correction = ROOT / 'correction.patch'
    if correction.exists():
        subprocess.run(['git', 'apply', '--check', str(correction)], check=True)
        subprocess.run(['git', 'apply', str(correction)], check=True)
    validate_changes(data)
    (OUT / 'paths.txt').write_text('\n'.join(row['path'] for row in data['files']) + '\n')
    print('78 candidate source files applied; runtime verification is pending.')


def finalize(data):
    validate_changes(data)
    files = [{'path': row['path'], 'sha256': digest(Path(row['path']).read_bytes())}
             for row in data['files']]
    result = {'candidate_base': data['base'], 'preparation_head': git('rev-parse', 'HEAD'),
              'run_id': os.environ.get('GITHUB_RUN_ID'), 'file_count': len(files),
              'format': 'passed', 'analyze': 'passed', 'protected_sha256': data['protected'],
              'files': files, 'flutter_tests_run_by_this_workflow': False,
              'full8_run': False, 'device_visual_performance_verification': 'pending',
              'production_deployment': False, 'store_ready': False,
              'note': 'Strict formatting/analyzer only. Independent focused Codex tests required.'}
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    (OUT / 'preparation.json').write_text(REPORT.read_text())
    print(json.dumps({'files': len(files), 'analyze': 'passed', 'tests': 'pending'}))


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    data = bundle()
    if sys.argv[1] == 'apply':
        apply(data)
    elif sys.argv[1] == 'finalize':
        assert os.environ.get('ANALYZE_OUTCOME') == 'success', 'Analyzer not passed'
        finalize(data)
    else:
        raise SystemExit('Unknown command')
