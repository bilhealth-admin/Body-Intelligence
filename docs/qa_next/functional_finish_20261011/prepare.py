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
CONTRACT_TEST = 'test/features/recipe_import/trusted_recipe_diary_service_test.dart'

def git(*args):
    return subprocess.check_output(['git', *args]).decode().strip()

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def protected():
    prior = json.loads(Path('docs/qa_next/evidence/20261011-functional-integration/preparation.json').read_text())
    for name, expected in prior['protected_sha256'].items():
        assert digest(name) == expected, f'Protected file changed: {name}'
    return prior['protected_sha256']

def corrections():
    # Resolve ambiguous imports reported by run38135758330. This changes a
    # namespace, not assertion semantics or analyzer configuration.
    path = Path('test/data/repositories/recipe_serving_evidence_test.dart')
    text = path.read_text()
    old = "import 'package:drift/drift.dart';"
    assert text.count(old) == 1
    path.write_text(text.replace(old, "import 'package:drift/drift.dart' hide isNull;"))
    assert digest(path) == 'bc3c8cdecbe29f3d1083115cc84a633c232c18868164fe7659d7eea493d6b1e6'
    path = Path(CONTRACT_TEST)
    assert digest(path) == '2a2b5f16c14c0d6b40520f603f94c7f482213fb9c72adbdb3297aa46a258db71'
    text = path.read_text()
    edits = [
        ("import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';",
         "import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';\nimport 'package:body_intelligence_log/data/database/meal_food_evidence.dart';"),
        ("        startsWith('recipe-calculation:'),",
         "        startsWith('recipe_serving_v1:recipe-calculation:'),"),
        ("      expect((await database.select(database.foods).get()), hasLength(1));",
         "      final evidence = MealFoodEvidence.read(logged.single.items.first);\n      expect(evidence.isValid, isTrue);\n      expect(evidence.recipe?.source, startsWith('recipe-calculation:'));\n      expect(logged.single.items.first.servingUnitSnapshot, 'serving');\n      expect((await database.select(database.foods).get()), hasLength(1));"),
    ]
    for old, new in edits:
        assert text.count(old) == 1
        text = text.replace(old, new)
    path.write_text(text)
    assert digest(path) == '6f940c24d323dd450ab6a0a70f0d64f43ffbfcc6b137516ff5af2922594c28f6'

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
    names.append(CONTRACT_TEST)
    assert len(names) == len(set(names)) == 14
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
        corrections()
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
                  'resumed_from_run': '38135758330',
                  'test_contract_note': 'Original provenance assertions retained and strengthened for serving envelope.',
                  'pending': 'Independent focused Codex tests, device UX, cloud round-trip and performance verification.'}
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        (OUT / 'preparation.json').write_text(REPORT.read_text())
    else:
        raise SystemExit('Unknown command')
