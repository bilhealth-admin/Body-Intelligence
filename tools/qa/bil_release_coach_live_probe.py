"""Real Gemini intent probes using the existing disposable-account/cleanup flow.

No production model overrides, real-user grants, diary actions, or store writes.
Generated scripts contain static synthetic questions only, never credentials.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / 'tool/ai_coach/run_live_text_e2e.ps1'
BASE_QUESTION = 'I weigh 82 kg and my saved goal is 75 kg. How much remains?'
CASES = {
    'target_goal': 'My goal is 60 kg.',
    'log_weight': 'Log my weight as 60 kg.',
    'need_plan': 'Please, I need a plan.',
    'combined_month': 'بدي خطة غذاء وتمارين لشهر.',
    'today': 'شو تمريني اليوم؟',
    'missed': 'ما قدرت أتمرن مبارح.',
    'travel': 'غيّر تمرين الخميس لأني مسافر.',
    'three_months': 'اعمل لي خطة 3 أشهر.',
    'done_without_saved_plan': 'I finished my workout.',
    'allergy_dinner_en': 'Suggest a dinner using my saved food restrictions.',
    'allergy_dinner_ar': 'اقترح عشاء يناسب حساسياتي وتفضيلاتي المحفوظة.',
}


def validate(case: str, response: dict) -> None:
    for flag in ('success', 'session_revoked', 'user_deleted', 'cascade_clean'):
        if response.get(flag) is not True:
            raise ValueError('Actual response/cleanup is not verified: ' + flag)
    if response.get('quota_reserved') != 0 or response.get('duplicate_status') != 409:
        raise ValueError('Credit settlement or duplicate-request guard failed')
    if response.get('provider') != 'gemini' or response.get('provider_attempts') not in (1, 2, 3):
        raise ValueError('Real bounded Gemini call is required')
    recovery = response.get('quality_recovery')
    if recovery not in (None, '', 'verified_workout_review') or (recovery and case != 'done_without_saved_plan'):
        raise ValueError('Unexpected app-owned quality recovery')
    if response.get('provider_attempts') == 3:
        elapsed = response.get('latency_ms')
        if isinstance(elapsed, bool) or not isinstance(elapsed, (int, float)) or not 0 < elapsed < 28000:
            raise ValueError('Fallback plus citation repair must fit the existing client deadline')

    actions = response.get('proposed_actions')
    if not isinstance(actions, list) or len(actions) > 1:
        raise ValueError('Missing actual action response or unbounded actions')
    types = {a.get('type') for a in actions if isinstance(a, dict)}
    prose = (str(response.get('reply', '')) + '\n' + str(response.get('spoken_reply', ''))).lower()
    prose = re.sub('[أإآ]', 'ا', prose)
    if re.search(r"\b(?:i|we|bil)(?:'ve| have| has)?\s+(?:successfully\s+)?(?:logged|recorded|saved|activated|deleted|updated|completed|drafted|created|initiated|prepared)\s+(?:your|the|this|that|it|a)\b|(?:^|[.!؟\n]\s*)(?:لقد\s+)?(?:سجلت|حفظت|فعلت|اكملت|حذفت|عدلت|انشات|جهزت|اعددت)\s+(?:لك|ال|وزن|وجبة|تمرين|خط|مسودة)|(?:^|[.!؟\n]\s*)تم\s+(?:تسجيل|حفظ|تفعيل|حذف|تحديث|اكمال|انشاء|اعداد)\s+(?:ال|وزن|وجبة|تمرين|خط|مسودة)", prose):
        raise ValueError('Provider prose claimed an action without a native receipt')
    if case != 'log_weight' and types & {'log_weight', 'log_foods', 'quick_add_macros'}:
        raise ValueError('A goal or plan became an observed diary action')
    # These fixtures intentionally have no saved Smart Plan. The model must
    # request the supported read, rather than invent plan IDs or completion.
    if types & {'record_smart_plan_workout', 'request_smart_plan_revision'}:
        raise ValueError('An action invented an absent saved plan identity')
    if case in ('missed', 'done_without_saved_plan') and 'log_exercise' in types:
        raise ValueError('Missing workout identity/duration became a log action')
    if case == 'done_without_saved_plan' and not response.get('missing_data') and 'read_active_smart_plan' not in types:
        raise ValueError('Completion without a verified session needs actual clarification or native review')
    if case == 'log_weight':
        if len(actions) != 1 or actions[0].get('type') != 'log_weight':
            raise ValueError('Explicit weight recording was not proposed')
        if actions[0].get('arguments', {}).get('weightKg') != 60:
            raise ValueError('The explicit measured weight was changed')
        if actions[0].get('requires_confirmation') is not True:
            raise ValueError('Weight proposal bypassed confirmation')
    if case == 'target_goal' and actions and actions[0].get('type') == 'update_goal':
        if actions[0].get('arguments', {}).get('targetWeightKg') != 60:
            raise ValueError('Target goal proposal lost its explicit value')
    if case in ('combined_month', 'three_months'):
        if len(actions) != 1 or actions[0].get('type') != 'create_smart_plan_draft':
            raise ValueError('Explicit plan request did not offer native draft review')
        arguments = actions[0].get('arguments', {})
        if arguments.get('horizon') != ('month' if case == 'combined_month' else 'threeMonths'):
            raise ValueError('Requested plan duration was lost')
        if case == 'combined_month' and arguments.get('focus') != 'combined':
            raise ValueError('Training and nutrition focus was lost')
    if case in ('need_plan', 'target_goal') and not actions and not response.get('missing_data'):
        raise ValueError('No supported next action or essential clarification')
    if case in ('combined_month', 'today', 'missed', 'travel', 'three_months', 'allergy_dinner_ar'):
        if not re.search(r'[\u0600-\u06ff]', str(response.get('reply', ''))):
            raise ValueError('Arabic request did not receive an Arabic answer')


def script_for(case: str, cli: str | None = None) -> str:
    source = TEMPLATE.read_text(encoding='utf-8-sig')
    if source.count(BASE_QUESTION) != 1:
        raise ValueError('Reviewed disposable-account question marker changed')
    source = source.replace(BASE_QUESTION, CASES[case].replace("'", "''"))
    marker = "request_id = $requestId\n    locale = 'en'"
    if source.count(marker) != 1:
        raise ValueError('Reviewed request boundary changed')
    source = source.replace(marker, "request_id = $requestId\n    smart_plan_tools_version = 1\n    health_citation_catalog_version = 2\n    locale = 'en'")
    if case.startswith('allergy_dinner_'):
        profile = 'profile = @{ currentWeightKg = 82; targetWeightKg = 75 }'
        if source.count(profile) != 1:
            raise ValueError('Reviewed synthetic profile marker changed')
        source = source.replace(profile, 'profile = @{ currentWeightKg = 82; targetWeightKg = 75; dietaryPreferences = @{ allergens = @("peanut", "milk", "sesame"); requirements = @("halal"); pattern = "omnivore" } }')

    marker = 'if ([int]$response.attempts -ne 1)'
    if source.count(marker) != 1:
        raise ValueError('Reviewed provider attempt boundary changed')
    source = source.replace(marker, 'if ([int]$response.attempts -lt 1 -or [int]$response.attempts -gt 3)')
    source = source.replace('reply = $response.reply',
        "proposed_actions = @($response.proposed_actions)\n    missing_data = @($response.missing_data)\n    quality_recovery = $(if ($response.PSObject.Properties['quality_recovery']) { [string]$response.quality_recovery } else { $null })\n    reply = $response.reply", 1)
    def absolute_import(match):
        path = (TEMPLATE.parent / match[1].replace('\\', '/')).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError('QA dependency left the repository')
        return ". '" + str(path).replace("'", "''") + "'"
    source, count = re.subn(r"^\. \(Join-Path \$PSScriptRoot '([^']+)'\)\s*$",
                            absolute_import, source, flags=re.MULTILINE)
    if count != 4:
        raise ValueError('Disposable-account dependency inventory changed')
    if cli:
        source = source.replace('& npx --yes supabase@latest', "& '" + cli.replace("'", "''") + "'")
    else:
        source = source.replace('supabase@latest', 'supabase@2.121.0')
    return source


def verified_failed_cleanup(stderr: str) -> bool:
    for line in stderr.splitlines():
        if not line.startswith('BIL_AI_COACH_DIAGNOSTIC='):
            continue
        try:
            report = json.loads(line.partition('=')[2])
        except ValueError:
            continue
        if report.get('kind') != 'cleanup':
            continue
        counts = report.get('counts')
        names = ('auth_users', 'grants', 'subscriptions', 'events', 'usage', 'credit_weekly_usage',
                 'credit_monthly_usage', 'credit_balances', 'feedback', 'consents')
        return all(report.get(k) is True for k in ('session_revoked', 'user_deleted', 'cascade_clean')) and isinstance(counts, dict) and all(type(counts.get(k)) in (int, float) and counts[k] == 0 for k in names)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--case', choices=CASES, action='append')
    parser.add_argument('--supabase-cli')
    parser.add_argument('--powershell', default=shutil.which('pwsh'))
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    cases = args.case or list(CASES)
    if not args.run:
        print(json.dumps({'status': 'PLANNED', 'cases': cases, 'network_calls': 0}))
        return 0
    if not args.powershell:
        raise RuntimeError('PowerShell is required; live validation cannot be skipped')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    generated = args.output.parent / (args.output.stem + '-generated')
    generated.mkdir(exist_ok=True)
    report = {'schema': 'bil.coach.live-intelligence.v1', 'status': 'RUNNING',
              'request_capabilities': {'smart_plan_tools_version': 1, 'health_citation_catalog_version': 2},
              'template_sha256': hashlib.sha256(TEMPLATE.read_bytes()).hexdigest(),
              'scope': 'Real authenticated provider responses and settlement on disposable fixtures; no native diary actions are executed.',
              'cases': []}
    def save():
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    save()
    for case in cases:
        script = generated / (case + '.ps1')
        script.write_bytes(script_for(case, args.supabase_cli).encode('utf8'))
        print('Live Coach case: ' + case, flush=True)
        completed = subprocess.run([args.powershell, '-NoProfile', '-File', str(script),
            '-ProjectRef', 'tgmanzhqulksykhslrzb'], cwd=ROOT, capture_output=True, text=True,
            encoding='utf8', errors='replace')
        (generated / (case + '.stdout.log')).write_text(completed.stdout, encoding='utf8')
        (generated / (case + '.stderr.log')).write_text(completed.stderr, encoding='utf8')
        entry = {'case': case, 'status': 'FAIL', 'exit_code': completed.returncode,
                 'script_sha256': hashlib.sha256(script.read_bytes()).hexdigest()}
        try:
            if completed.returncode:
                raise RuntimeError('Live service did not return success; cleanup diagnostics retained')
            actual = json.loads(completed.stdout.lstrip('\ufeff'))
            entry['actual'] = actual
            validate(case, actual)
            entry['status'] = 'PASS'
        except (ValueError, RuntimeError) as error:
            entry['failure'] = str(error)
        report['cases'].append(entry)
        save()
        if entry['status'] != 'PASS':
            entry['cleanup_verified_after_failure'] = verified_failed_cleanup(completed.stderr)
            report['status'] = 'FAIL'
            save()
            print(json.dumps({'case': case, 'status': 'FAIL', 'failure': entry['failure']}), flush=True)
            if not entry['cleanup_verified_after_failure']:
                return 1
    report['status'] = 'PASS' if all(c['status'] == 'PASS' for c in report['cases']) else 'FAIL'
    save()
    print(json.dumps({'status': report['status'], 'actual_cases': len(report['cases'])}), flush=True)
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
