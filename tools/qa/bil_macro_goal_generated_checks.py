"""Bounded generated checks, explicit mutants and VM coverage of the real editor.

Never modifies lib/test or dependency files. Mutants live in a unique build dir.
This is one domain target, not whole-app fuzzing or a global coverage score.
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import tempfile
from datetime import datetime, timezone

HARNESS = r"""
import 'dart:convert';
import 'dart:math';
import '__TARGET__';

var checks = 0;
void require(bool ok, String label) {
  checks++;
  if (!ok) throw StateError('bil-generated-check: $label');
}
void close(double actual, double expected, String label) {
  require(actual.isFinite && (actual - expected).abs() < 1e-7, label);
}
void reject(void Function() action, String label) {
  try { action(); } on FormatException { checks++; return; }
  throw StateError('bil-generated-check: $label');
}
void coherent(MacroGoalAllocation value) {
  close(value.carbohydrate + value.protein + value.fat, 100, 'percent sum');
  for (final item in MacroGoal.values) {
    require(value.percent(item) >= 0 && value.percent(item) <= 100, 'percent bounds');
  }
  close(value.grams(MacroGoal.carbohydrate) * 4 +
        value.grams(MacroGoal.protein) * 4 +
        value.grams(MacroGoal.fat) * 9, value.calories, 'independent 4/4/9 energy');
}
void main() {
  final random = Random(20261015);
  const base = MacroGoalAllocation(1000, 45, 20, 35);
  for (final bad in [double.nan, double.infinity, double.negativeInfinity, -1.0, 101.0]) {
    reject(() => base.edit(MacroGoal.carbohydrate, bad), 'invalid edit accepted');
  }
  for (final bad in [double.nan, double.infinity, 0.0, -1.0, 10001.0]) {
    reject(() => base.withCalories(bad), 'invalid calories accepted');
  }
  for (final goal in MacroGoal.values) {
    reject(() => base.edit(goal, 10, locked: {goal}), 'locked target edited');
  }
  reject(() => const MacroGoalAllocation(10001,45,20,35).edit(MacroGoal.fat,30),
      'invalid source calories accepted');
  for (var i = 0; i < 10000; i++) {
    final protein = random.nextDouble() * 100;
    final carbs = random.nextDouble() * (100 - protein);
    final start = MacroGoalAllocation(400 + random.nextDouble() * 9600,
        carbs, protein, 100 - protein - carbs);
    coherent(start);
    final value = random.nextDouble() * (100 - protein);
    final percent = start.edit(MacroGoal.carbohydrate, value,
        locked: {MacroGoal.protein}, previous: MacroGoal.protein);
    coherent(percent);
    close(percent.protein, protein, 'explicit protein lock');
    close(percent.carbohydrate, value, 'requested percentage');
    final grams = start.edit(MacroGoal.carbohydrate,
        start.calories * value / 400, inGrams: true, previous: MacroGoal.protein);
    close(grams.carbohydrate, value, 'gram to percent conversion');
    coherent(grams);
    final scaled = start.withCalories(10000,
        locked: {MacroGoal.protein}, gramLocks: {MacroGoal.protein});
    coherent(scaled);
    close(scaled.grams(MacroGoal.protein), start.grams(MacroGoal.protein),
        'gram lock must preserve grams');
    final fixedPercent = start.withCalories(10000, locked: {MacroGoal.protein});
    coherent(fixedPercent);
    close(fixedPercent.protein, protein, 'percentage lock must preserve percent');
    final prefs = scaled.toPreferences();
    require(prefs.length == 7, 'atomic allocation preference group');
    close(double.parse(prefs['goal.calories']!), scaled.calories, 'calorie serialization');
    for (final goal in MacroGoal.values) {
      final key = MacroGoalAllocation.key(goal);
      close(double.parse(prefs['goal.${key}Grams']!), scaled.grams(goal), 'gram serialization');
      close(double.parse(prefs['goal.${key}Percent']!), scaled.percent(goal), 'percent serialization');
    }
  }
  print(jsonEncode({'seed':20261015,'generated_cases':10000,'checks':checks,'result':'PASS'}));
}
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dart', required=True)
    parser.add_argument('--output-root', default='build/qa/macro-generated')
    args = parser.parse_args()
    source = pathlib.Path('lib/features/nutrition/domain/macro_goal_editor.dart').resolve()
    original = source.read_bytes()
    text = original.decode('utf-8')
    root = pathlib.Path(args.output_root)
    root.mkdir(parents=True, exist_ok=True)
    owned = pathlib.Path(tempfile.mkdtemp(prefix='bounded-', dir=root)).resolve()
    started = datetime.now(timezone.utc).isoformat()
    baseline = owned / 'baseline.dart'
    baseline.write_bytes(HARNESS.replace('__TARGET__', source.as_uri()).encode())
    # Use the already installed coverage version from the existing package map.
    config = pathlib.Path('.dart_tool/package_config.json').resolve()
    packages = json.loads(config.read_text(encoding='utf-8'))['packages']
    coverage_uri = next(p['rootUri'] for p in packages if p['name'] == 'coverage')
    from urllib.parse import unquote, urlparse
    coverage_path = pathlib.Path(unquote(urlparse(coverage_uri).path).lstrip('/'))
    if not coverage_path.exists():
        coverage_path = pathlib.Path(unquote(urlparse(coverage_uri).path))
    collector = coverage_path / 'bin/collect_coverage.dart'
    process = subprocess.Popen([args.dart, '--enable-vm-service=0',
        '--pause-isolates-on-exit', '--branch-coverage', str(baseline)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8')
    vm_uri = None
    observed = None
    try:
        for line in process.stdout:
            match = re.search(r'The Dart VM service is listening on (http://127\.0\.0\.1:\d+/\S+)', line)
            if match:
                vm_uri = match[1]
                break
        if not vm_uri:
            raise RuntimeError('The owned Dart VM did not expose its loopback service')
        coverage = owned / 'coverage.json'
        subprocess.run([args.dart, '--packages=' + str(config), str(collector),
            '--uri=' + vm_uri, '--out=' + str(coverage), '--wait-paused',
            '--resume-isolates', '--function-coverage', '--branch-coverage'],
            check=True, timeout=120, stdout=subprocess.DEVNULL)
        for line in process.stdout:
            if line.startswith('{'):
                observed = json.loads(line)
        if process.wait(timeout=30) != 0 or observed is None:
            raise RuntimeError('Baseline generated checks failed')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
    data = json.loads(coverage.read_text(encoding='utf-8'))
    entries = [row for row in data['coverage'] if row['source'] == source.as_uri()]
    if len(entries) != 1:
        raise RuntimeError('Coverage does not contain exactly the real target source')
    row = entries[0]
    coverage_counts = {}
    for key in ['hits', 'funcHits', 'branchHits']:
        values = row.get(key, [])
        coverage_counts[key] = {'measured':len(values)//2,
                               'hit':sum(count > 0 for count in values[1::2])}
    mutants = [
        ('fat_energy_is_four', 'goal == MacroGoal.fat ? 9 : 4', 'goal == MacroGoal.fat ? 4 : 4'),
        ('allow_locked_edit', 'next > 100 || locked.contains(goal)', 'next > 100'),
        ('allow_nonfinite_edit', '!value.isFinite ||', ''),
        ('forget_gram_lock', 'percent(item) * calories / next', 'percent(item)'),
        ('allow_too_large_calories', 'next > 10000 ||', ''),
    ]
    results = []
    for name, before, after in mutants:
        if before not in text:
            raise RuntimeError('Mutation site drifted: ' + name)
        target = owned / (name + '.dart')
        target.write_bytes(text.replace(before, after).encode())
        harness = owned / (name + '_checks.dart')
        harness.write_bytes(HARNESS.replace('__TARGET__', target.as_uri()).encode())
        ran = subprocess.run([args.dart, str(harness)], capture_output=True,
                             encoding='utf-8', timeout=60)
        # A compile failure is not a killed behavioral mutant.
        killed = ran.returncode != 0 and 'Bad state: bil-generated-check:' in ran.stderr
        results.append({'name':name,'behaviorally_killed':killed,'exit_code':ran.returncode})
        if not killed:
            raise RuntimeError('Mutant survived or did not compile: ' + name)
    if source.read_bytes() != original:
        raise RuntimeError('Real source changed during measurement')
    report = {'started_at_utc':started,'finished_at_utc':datetime.now(timezone.utc).isoformat(),
        'source_head':subprocess.check_output(['git','rev-parse','HEAD'],encoding='utf-8').strip(),
        'target':str(source.relative_to(pathlib.Path.cwd())),
        'target_sha256':hashlib.sha256(original).hexdigest(), 'source_unchanged':True,
        'generated_checks':observed,'coverage':coverage_counts,'mutants':results,
        'scope':'One pure Dart macro editor, deterministic generated boundary/metamorphic cases and five explicit non-equivalent mutants; not whole-app fuzz, a full mutation score, provider intelligence or device performance'}
    (owned / 'result.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
    print(json.dumps({'result':'PASS','report':str(owned/'result.json'),**observed,
                      'behavioral_mutants_killed':len(results),'coverage':coverage_counts}))


if __name__ == '__main__':
    main()
