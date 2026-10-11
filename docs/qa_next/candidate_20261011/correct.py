"""Apply explicit analyzer corrections without weakening candidate or path integrity."""
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import zlib
import prepare

ROOT = Path(__file__).resolve().parent
OUT = prepare.OUT
REPORT = prepare.REPORT


def digest(value):
    return hashlib.sha256(value).hexdigest()


def load():
    original = prepare.bundle()
    encoded = (ROOT / 'post_analyze.b64').read_text().strip().encode('ascii')
    # Two transport transcription slips compared with the frozen local bytes.
    # Repairs are accepted ONLY if the original whole-payload SHA256 matches.
    encoded = encoded.replace(b'b9/+IcPv7zj6', b'b9/+IcPv7z6').replace(b'd3XYJiUFXmPB', b'd3XYJiU2PB')
    assert digest(encoded) == 'f4b509078f0a4e1199a117ef2ddab1bab3826a3e06d78c3637d19861f12c046b'
    decompressor = zlib.decompressobj()
    raw = decompressor.decompress(base64.b64decode(encoded, validate=True), 200000)
    assert decompressor.eof and not decompressor.unused_data
    assert digest(raw) == '1443fa614e23f81317ea8845d27c91d8cffb73511907d8ad6d158af3b57d6356'
    correction = json.loads(raw)
    assert correction['version'] == 1 and len(correction['files']) == 14
    names = sorted({row['path'] for row in original['files']} | {row['path'] for row in correction['files']})
    assert len(names) == 84
    for name in names:
        p = PurePosixPath(name)
        assert not p.is_absolute() and '..' not in p.parts
        assert p.parts[0] in ('lib', 'test') and p.suffix == '.dart'
        assert name not in original['protected']
        assert not any(Path(*p.parts[:i]).is_symlink() for i in range(1, len(p.parts) + 1))
    return original, correction, names


def remove_reported_unused_import(names):
    # Run38134129366 applied all 84 paths and formatted successfully. Its only
    # remaining analyzer diagnostic was this unused import. Do not suppress
    # analyzer diagnostics or regenerate the preserved candidate to remove it.
    name = 'lib/features/dashboard/providers/dashboard_preferences_provider.dart'
    assert name in names
    path = Path(name)
    text = path.read_text()
    directive = "import 'package:flutter/foundation.dart';\n"
    assert text.startswith(directive) and text.count(directive) == 1, name
    path.write_text(text[len(directive):])


def check(original, names):
    subprocess.run(['git', 'add', '-N', '--', *names], check=True)
    changed = set(prepare.git('diff', '--name-only').splitlines())
    assert changed == set(names), f'Source scope drift: {changed ^ set(names)}'
    assert not prepare.git('diff', '--name-only', '--diff-filter=D')
    subprocess.run(['git', 'diff', '--check'], check=True)
    prepare.protected(original)
    for name in names:
        assert len(Path(name).read_text().splitlines()) <= 1500, name
    (OUT / 'paths.txt').write_text('\n'.join(names) + '\n')
    (OUT / 'source.patch').write_text(prepare.git('diff', '--binary', '--', *names) + '\n')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    original, correction, names = load()
    assert os.environ.get('GITHUB_REPOSITORY', prepare.REPO) == prepare.REPO
    assert os.environ.get('GITHUB_REF', 'refs/heads/' + prepare.BRANCH) == 'refs/heads/' + prepare.BRANCH
    if sys.argv[1] == 'apply':
        for row in correction['files']:
            assert digest(Path(row['path']).read_bytes()) == row['before'], row['path']
        patch = OUT / 'post_analyze.patch'
        patch.write_text(correction['patch'])
        subprocess.run(['git', 'apply', '--check', str(patch)], check=True)
        subprocess.run(['git', 'apply', str(patch)], check=True)
        for row in correction['files']:
            assert digest(Path(row['path']).read_bytes()) == row['after'], row['path']
        remove_reported_unused_import(names)
        check(original, names)
        print('84 candidate paths prepared, including exact analyzer fixes and centred Today date.')
    elif sys.argv[1] == 'finalize':
        assert os.environ.get('ANALYZE_OUTCOME') == 'success'
        check(original, names)
        result = {'candidate_base': original['base'], 'preparation_head': prepare.git('rev-parse', 'HEAD'),
                  'run_id': os.environ.get('GITHUB_RUN_ID'), 'file_count': len(names),
                  'format': 'passed', 'analyze': 'passed', 'protected_sha256': original['protected'],
                  'files': [{'path': name, 'sha256': digest(Path(name).read_bytes())} for name in names],
                  'flutter_tests_run_by_this_workflow': False, 'full8_run': False,
                  'device_visual_performance_verification': 'pending', 'production_deployment': False,
                  'store_ready': False, 'today_date_circle': '36px; selected calendar day centred in seven-day window',
                  'resumed_from_failed_run': '38134129366',
                  'last_analyzer_fix': 'Remove unused foundation import only; no diagnostic suppression.',
                  'note': 'Strict formatting and analyzer only. Independent focused Codex tests required.'}
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        (OUT / 'preparation.json').write_text(REPORT.read_text())
        print(json.dumps({'source_files': len(names), 'analyze': 'passed', 'tests': 'pending'}))
    else:
        raise SystemExit('Unknown command')
