"""Review redacted scanner candidates against exact source, never print values.

This is not a scanner suppression: unknown/new candidate shapes fail the gate.
Raw Gitleaks results are retained independently, including historical findings.
"""
from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess

from run_gate import ROOT, EVIDENCE


def review(finding: dict, source: str, relative: str) -> str | None:
    start, end = finding['StartLine'] - 1, finding['EndLine']
    lines = source.splitlines()
    excerpt = '\n'.join(lines[start:end])
    match = finding['Match']
    if 'REDACTED' not in match:
        return None
    label = match.split('REDACTED')[0]
    if (finding['RuleID'] == 'sumologic-access-token'
            and relative == 'artifacts/workout_media/workout_exact200_manifest.csv'):
        rows = list(csv.DictReader(source.splitlines()))
        # Sumo squat is an exercise name. The neighboring CSV field is a
        # content digest, not a Sumo Logic credential.
        header = source.splitlines()[0]
        if 'sha256' in header.lower():
            for row in rows:
                if any('resistance-lower-body-sumo-squat-technique.mp4' in v for v in row.values()):
                    digests = [v for k, v in row.items() if 'sha256' in k.lower()]
                    if digests and all(re.fullmatch('[a-f0-9]{64}', v) for v in digests):
                        return 'Historical exercise filename and adjacent SHA-256 metadata, not Sumo Logic access'
    if finding['RuleID'] == 'private-key':
        if relative != 'test/fixtures/release/source_hygiene_secret_scanner_contract.json':
            return None
        # Parse candidate PEM text with Node's real cryptographic key parser.
        # Successful parsing is an actual key and MUST remain unresolved.
        try:
            data = json.loads(source)
            texts = []
            def collect(value):
                if isinstance(value, str) and 'PRIVATE KEY-----' in value:
                    texts.append(value)
                elif isinstance(value, dict):
                    if isinstance(value.get('text_base64'), str):
                        collect(base64.b64decode(value['text_base64']).decode('utf-8'))
                    for child in value.values(): collect(child)
                elif isinstance(value, list):
                    for child in value: collect(child)
            collect(data)
            if not texts: return None
            result = subprocess.run(['node', '-e',
                "const c=require('node:crypto'); let s='';process.stdin.on('data',x=>s+=x);"
                "process.stdin.on('end',()=>{for(const k of JSON.parse(s)){try{c.createPrivateKey(k);"
                "process.exit(1)}catch{}}});"], input=json.dumps(texts),
                text=True, capture_output=True, check=False)
            if result.returncode == 0:
                return 'Negative secret-scanner fixture; every PEM rejected by crypto.createPrivateKey'
        except (ValueError, OSError):
            return None
        return None
    # Match only literal quoted assignments; do not print their values.
    values = re.findall(re.escape(label) + r'([^\s\"\'\r\n,;}]+)', excerpt)
    if not values:
        return None
    if 'Sha256' in label or 'sha256' in label:
        if relative.startswith('artifacts/workout_media/') and all(
                re.fullmatch('[a-f0-9]{64}', v) for v in values):
            return 'Named SHA-256 content fingerprint in workout release metadata, not a credential'
    if 'SUPABASE' in label:
        if all(re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]+', v) for v in values):
            return 'Public Supabase publishable key; no secret/service-role key'
        roles = []
        for value in values:
            try:
                body = value.split('.')[1]
                roles.append(json.loads(base64.urlsafe_b64decode(body + '=' * (-len(body) % 4))).get('role'))
            except (ValueError, IndexError, TypeError):
                return None
        if roles and all(role == 'anon' for role in roles):
            return 'Public legacy Supabase anon JWT, not privileged service_role'
    if 'instructionKey' in label and (relative.startswith('assets/catalogs/recipes/')
            or relative.startswith('test/fixtures/recipe_catalog/')):
        if all(re.fullmatch(r'[a-z0-9-]+(?:-step-|\.step)\d+', v) for v in values):
            return 'Recipe instruction localization identifier, not a secret'
    allowed_identifiers = {
        'lib/features/intelligence_center/services/coach_memory_repository.dart': r'coachExplicitMemoriesV1',
        'lib/features/notifications/services/daily_reminder_store.dart': r'bil\.daily-reminders\.v1',
        'test/features/intelligence_center/coach_review_actions_regression_test.dart': r'intelligence[A-Za-z0-9]+',
        'test/features/intelligence_center/coach_page_lifecycle_regression_test.dart': r'intelligence[A-Za-z0-9]+',
        'test/intelligence_center_composer_test.dart': r'intelligence[A-Za-z0-9]+',
        'tool/localization/generate_extended_runtime_copy.dart': r'ZXQP(?:BIL|AICOACH|PREMIUM)BRAND9X7ZXQP',
        'supabase/functions/ai-coach-global-reset/mobile_integrity_test.ts': r'integrity-(?:global|individual|notification)-0001',
    }
    pattern = allowed_identifiers.get(relative)
    if pattern and all(re.fullmatch(pattern, v) for v in values):
        return 'Literal local storage/translation/idempotency test identifier; not authentication material'
    if relative == 'cloudflare/workout-runtime/test/worker.spec.ts' and 'hs256Token' in label:
        try:
            token = values[0]
            header = token.split('.')[0]
            parsed = json.loads(base64.urlsafe_b64decode(header + '=' * (-len(header) % 4)))
            if parsed.get('alg') == 'HS256' and 'signature' in token.split('.')[-1]:
                return 'Negative HS256 rejection fixture with literal dummy signature'
        except (ValueError, IndexError):
            return None
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    reviewed = []
    for finding in json.loads(args.report.read_text(encoding='utf-8')):
        path = finding['File'].replace('\\', '/')
        commit = finding.get('Commit')
        if commit:
            relative = path
            source = subprocess.check_output(['git', 'show', f'{commit}:{relative}'], cwd=ROOT).decode('utf-8')
        else:
            relative = path.split('/secret_source_snapshot_', 1)[1].split('/', 1)[1]
            source = Path(path).read_text(encoding='utf-8-sig')
        reason = review(finding, source, relative)
        reviewed.append({'file': relative, 'line': finding['StartLine'],
            'rule': finding['RuleID'], 'commit': commit,
            'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
            'status': 'PASS' if reason else 'FAIL',
            'reason': reason or 'Unresolved; manual source investigation required'})
    output = EVIDENCE / (args.report.stem + '_review.json')
    output.write_text(json.dumps(reviewed, indent=2) + '\n', encoding='utf-8')
    unresolved = [r for r in reviewed if r['status'] != 'PASS']
    print(json.dumps({'candidates': len(reviewed), 'resolved': len(reviewed) - len(unresolved),
                      'unresolved': unresolved, 'report': str(output)}, indent=2))
    return int(bool(unresolved))


if __name__ == '__main__':
    raise SystemExit(main())
