"""Update one explicitly reviewed closure case, preserving Master/Actual/Diff.

This is never validation. Run the selected case again without updating it.
Protected Home/watch/navigation/splash references are deliberately absent.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
DATA = 'test/visual_closure/actual_data_pages_golden_test.dart'
PRODUCTION = 'test/visual_closure/actual_production_pages_golden_test.dart'
CASES = {
    'catalog': (DATA, 'food catalog production empty state capture', 'food_catalog_phone',
                'Pearl surface and public Scan/Barcode labels remain visible; paid routes still enforce access.'),
    'today': (DATA, 'daily log production empty day capture', 'daily_log_empty_phone',
              'Selected day is centered; macro names/units stay outside locked values; empty day remains zero.'),
    'goals-1': (DATA, 'nutrition goals production capture page 1', 'nutrition_goals_phone',
                'One page book, clean closed rows, editable locks and fixed-unit reference; no inline explanatory caption.'),
    'goals-2': (DATA, 'nutrition goals production capture page 2', 'nutrition_goals_phone_2',
                'FDA units/references and Mg/P rows; total sugar remains unspecified; no invented legacy-percent conversion.'),
    'meals': (PRODUCTION, 'saved nutrition meals production empty-state capture', 'saved_nutrition_meals_phone',
              'Pearl surfaces; real recorded-meal copy journey, not only repeated meals; truthful empty creation state.'),
    'recipes': (PRODUCTION, 'saved nutrition recipes production empty-state capture', 'saved_nutrition_recipes_phone',
                'Pearl surfaces and accurate create/discover/save/log guidance; no fabricated recipe nutrition.'),
    'foods': (PRODUCTION, 'saved nutrition my_foods production empty-state capture', 'saved_nutrition_my_foods_phone',
              'Pearl surfaces and working custom-food entry; search/filter/empty actions retained.'),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def baselines():
    names = subprocess.check_output(['git', 'ls-files', '--', 'test'], cwd=ROOT).decode().splitlines()
    return {name: digest(ROOT / name) for name in names
            if '/goldens/' in name and name.endswith('.png')}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in CASES:
        raise SystemExit('Choose one reviewed closure case: ' + ', '.join(CASES))
    key = sys.argv[1]
    source, case, image, reason = CASES[key]
    name = 'visual_closure_' + image
    reference = ROOT / 'test/visual_closure/goldens' / (name + '.png')
    failures = ROOT / 'test/visual_closure/failures'
    before = baselines()
    target = ROOT / 'build/stage1-closure/golden-review-approved' / key
    target.mkdir(parents=True, exist_ok=False)
    artifacts = {}
    for label, path in [('master', reference), ('actual', failures / (name + '_testImage.png')),
                        ('diff', failures / (name + '_isolatedDiff.png'))]:
        data = path.read_bytes()
        (target / (label + '.png')).write_bytes(data)
        artifacts[label] = hashlib.sha256(data).hexdigest()
    recorded_master = failures / (name + '_masterImage.png')
    if digest(recorded_master) != artifacts['master']:
        raise SystemExit('Master changed since the reviewed comparison; inspect it again.')
    dart = Path('G:/BIL_Toolchains/Flutter/flutter/bin/cache/dart-sdk/bin/dart.exe')
    snapshot = Path('G:/BIL_Toolchains/Flutter/flutter/bin/cache/flutter_tools.snapshot')
    command = [str(dart), str(snapshot), 'test', '--no-pub', '--concurrency=1',
               '--timeout=3m', '--reporter=json', source, '--plain-name', case, '--update-goldens']
    record = {'case': case, 'reason': reason, 'reference': str(reference.relative_to(ROOT)).replace('\\', '/'),
              'reviewed_artifacts_sha256': artifacts, 'update_only': True,
              'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip(),
              'command': command, 'started': time.time()}
    with (target / 'update.log').open('wb') as stream:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        record['pid'] = process.pid
        try:
            record['exit_code'] = process.wait(timeout=240)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], check=False)
            record['exit_code'] = 124
    after = baselines()
    changed = [name for name in before if before[name] != after.get(name)]
    record['changed_baselines'] = changed
    record['after_sha256'] = digest(reference)
    events = []
    for line in (target / 'update.log').read_text(encoding='utf-8', errors='replace').splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'testDone' and not event.get('hidden'):
            events.append(event)
    record['exactly_one_success'] = len(events) == 1 and events[0].get('result') == 'success' and not events[0].get('skipped')
    record['accepted_one_reviewed_image'] = (record['exit_code'] == 0 and record['exactly_one_success'] and
        changed == [record['reference']] and record['after_sha256'] == artifacts['actual'])
    (target / 'review.json').write_bytes(json.dumps(record, ensure_ascii=False, indent=2).encode('utf-8'))
    print(json.dumps({k: record[k] for k in ['case', 'accepted_one_reviewed_image', 'after_sha256']}))
    return 0 if record['accepted_one_reviewed_image'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
