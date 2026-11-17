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


def _capture_baseline_output(line, state, phase):
    # Retain the owned harness result even if it precedes the VM service banner.
    # Never retain/print service URLs, arbitrary child text, values, or secrets.
    if line.startswith('{'):
        try:
            document = json.loads(line)
        except json.JSONDecodeError:
            state['malformed_json_seen'] = True
            return
        if (isinstance(document, dict) and document.get('result') == 'PASS'
                and document.get('seed') == 20261015
                and document.get('generated_cases') == 10000
                and type(document.get('checks')) is int and document['checks'] > 0):
            state['observed'] = {key: document[key] for key in
                                 ('seed', 'generated_cases', 'checks', 'result')}
            state['result_phase'] = phase
        else:
            state['unexpected_json_seen'] = True
    if 'Bad state: bil-generated-check:' in line:
        # The known assertion text itself is not emitted; only its stable hash.
        label = line.split('Bad state: bil-generated-check:', 1)[1].strip()
        allowed = {
            'percent sum', 'percent bounds', 'independent 4/4/9 energy',
            'invalid edit accepted', 'invalid calories accepted',
            'locked target edited', 'invalid source calories accepted',
            'explicit protein lock', 'requested percentage',
            'gram to percent conversion', 'gram lock must preserve grams',
            'percentage lock must preserve percent',
            'atomic allocation preference group', 'calorie serialization',
            'gram serialization', 'percent serialization',
        }
        state['harness_assertion_sha256'] = hashlib.sha256(label.encode()).hexdigest()
        state['harness_assertion_code'] = (
            re.sub('[^A-Z0-9]+', '_', label.upper()).strip('_')
            if label in allowed else 'UNKNOWN_ASSERTION_WITHHELD'
        )
    if 'FormatException:' in line:
        state['child_failure_category'] = 'FORMAT_EXCEPTION'
        message = line.split('FormatException:', 1)[1].strip()
        messages = {
            'Invalid energy allocation.': 'INVALID_ENERGY_ALLOCATION',
            'Unlock this macro or review its energy.': 'UNLOCK_MACRO_OR_REVIEW_ENERGY',
            'Both other macros are locked.': 'BOTH_OTHER_MACROS_LOCKED',
            'Locked allocation exceeds the calorie goal.': 'LOCKED_ALLOCATION_EXCEEDS_GOAL',
            'Unlock a macro before changing calories.': 'UNLOCK_MACRO_BEFORE_CALORIES',
        }
        state['format_exception_code'] = messages.get(message, 'UNKNOWN_FORMAT_MESSAGE_WITHHELD')
    elif 'Error:' in line and 'Bad state: bil-generated-check:' not in line:
        state['child_failure_category'] = 'CHILD_ERROR'


def _read_until_vm_banner(lines, diagnostic):
    for line in lines:
        _capture_baseline_output(line, diagnostic, 'before_vm_banner')
        match = re.search(r'The Dart VM service is listening on (http://127\.0\.0\.1:\d+/\S+)', line)
        if match:
            return match[1]
    return None


def _baseline_outcome(exit_code, diagnostic):
    observed = diagnostic.get('observed')
    safe = {key: value for key, value in diagnostic.items() if key != 'observed'}
    safe.update(stage='BASELINE_PROCESS_FINISHED', baseline_exit_code=exit_code,
                valid_result_seen=observed is not None)
    return (observed if exit_code == 0 else None), safe


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
    diagnostic = {'observed': None, 'result_phase': None}
    try:
        vm_uri = _read_until_vm_banner(process.stdout, diagnostic)
        if not vm_uri:
            raise RuntimeError('The owned Dart VM did not expose its loopback service')
        coverage = owned / 'coverage.json'
        try:
            collected = subprocess.run([args.dart, '--packages=' + str(config), str(collector),
                '--uri=' + vm_uri, '--out=' + str(coverage), '--wait-paused',
                '--resume-isolates', '--function-coverage', '--branch-coverage'],
                check=False, timeout=120, stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE)
        except subprocess.TimeoutExpired:
            raise RuntimeError('COVERAGE_COLLECTOR_TIMEOUT_NO_URL_EMITTED') from None
        diagnostic['collector_exit_code'] = collected.returncode
        diagnostic['collector_stderr_sha256'] = hashlib.sha256(collected.stderr).hexdigest()
        if collected.returncode:
            print(json.dumps({'baseline_diagnostic': {
                'stage': 'COVERAGE_COLLECTOR_FAILED',
                'collector_exit_code': collected.returncode,
                'stderr_sha256': diagnostic['collector_stderr_sha256'],
            }}), flush=True)
            raise RuntimeError('COVERAGE_COLLECTOR_FAILED_NO_URL_EMITTED')
        for line in process.stdout:
            _capture_baseline_output(line, diagnostic, 'after_vm_banner')
        baseline_exit_code = process.wait(timeout=30)
        observed, safe_diagnostic = _baseline_outcome(baseline_exit_code, diagnostic)
        print(json.dumps({'baseline_diagnostic': safe_diagnostic}), flush=True)
        if baseline_exit_code != 0 or observed is None:
            raise RuntimeError('Baseline generated checks failed; see fixed diagnostic codes')
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
