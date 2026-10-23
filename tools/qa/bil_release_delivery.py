"""Exact-source CI/security prerequisites and owner-authorized TestFlight delivery.

No store submission, version increment or retry of an ambiguous upload.
TestFlight upload acceptance remains separate from Apple processing/device QA.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

import bil_release_revalidation_plan as planner

ROOT = Path(__file__).resolve().parents[2]
REPO = 'bilhealth-admin/Body-Intelligence'
BRANCH = 'integration/bil-qa-media-policy-20261011'
LANGUAGES = {'actions', 'javascript-typescript', 'python', 'java-kotlin', 'swift'}


def gh(endpoint):
    return json.loads(subprocess.check_output(['gh', 'api', f'repos/{REPO}/{endpoint}'],
                                             encoding='utf8', timeout=180))


def pages(api, endpoint, field=None):
    result = []
    for page in range(1, 101):
        data = api(endpoint + ('&' if '?' in endpoint else '?') + f'per_page=100&page={page}')
        values = data[field] if field else data
        if not isinstance(values, list):
            raise ValueError('Paginated GitHub response is not a list')
        result.extend(values)
        if len(values) < 100:
            return result
    raise ValueError('GitHub evidence exceeds bounded pagination; no partial acceptance')


def validate_prerequisites(manifest, run_ids, head, api=gh, *, expected_branch=BRANCH):
    lanes = planner.validate_ci_manifest(manifest, required_workflow_ids=manifest['required_workflow_ids'])
    expected = {lane['lane_id'] for lane in lanes}
    if (not isinstance(run_ids, dict) or set(run_ids) != expected
            or any(type(value) is not int or value <= 0 for value in run_ids.values())
            or len(set(run_ids.values())) != len(run_ids)):
        raise ValueError('Exact complete unique CI run inventory is required before signing')
    proofs = []
    for lane in lanes:
        run_id = run_ids[lane['lane_id']]
        run = api(f'actions/runs/{run_id}')
        if run.get('head_branch') != expected_branch or run.get('event') not in ('push', 'workflow_dispatch'):
            raise ValueError('CI prerequisite is from another branch/event')
        run['jobs'] = pages(api, f'actions/runs/{run_id}/jobs', 'jobs')
        proofs.append(planner.validate_ci_run(run, expected_head=head,
            expected_workflow_id=lane['workflow_id'], after_run_id=run_id - 1,
            created_after=run['created_at'], required_job_names=lane['required_jobs']))
    return proofs


def security_reports(semgrep, mobsf, analyses, alerts, head, *, expected_branch=BRANCH):
    if (semgrep.get('source_head') != head or semgrep.get('result') != 'CLEAN_SCAN'
            or semgrep.get('findings_count') != 0 or semgrep.get('findings') != []
            or semgrep.get('errors_count') != 0 or semgrep.get('errors') != []
            or type(semgrep.get('scanned_paths_count')) is not int or semgrep['scanned_paths_count'] <= 0):
        raise ValueError('Semgrep is incomplete or has findings requiring review')
    if (mobsf.get('audit_source') != head or mobsf.get('producer_source') != head
            or mobsf.get('producer_conclusion') != 'success'
            or mobsf.get('result') != 'STATIC_DEBUG_REPORT_PRESENT'
            or mobsf.get('internet_enabled_in_scanner') is not False):
        raise ValueError('MobSF report does not belong to the successful exact-source APK')
    for key in ('manifest_findings', 'code_findings'):
        values = mobsf.get(key)
        if not isinstance(values, list):
            raise ValueError('MobSF report is missing findings inventory')
        # No silent allowlist, even for a debug APK. Findings remain reviewable;
        # this static report never certifies a signed release or dynamic MASVS.
        if any(v.get('severity') not in ('info', 'good', 'secure', 'low') for v in values):
            raise ValueError('MobSF has unresolved findings or unknown severity')
    covered = set()
    for analysis in analyses:
        if (analysis.get('commit_sha') == head and analysis.get('tool', {}).get('name') == 'CodeQL'
                and analysis.get('ref') == 'refs/heads/' + expected_branch):
            language = analysis.get('category', '').removeprefix('/language:')
            if language in LANGUAGES:
                if analysis.get('error') or analysis.get('warning'):
                    raise ValueError('Exact-source CodeQL analysis is incomplete')
                covered.add(language)
    if covered != LANGUAGES:
        raise ValueError('All five exact-source CodeQL languages must have completed analysis')
    if not isinstance(alerts, list) or alerts:
        raise ValueError('Open CodeQL findings require review; a green workflow is insufficient')
    return {'status': 'PASS', 'source_sha': head, 'codeql_languages': sorted(covered),
            'open_codeql_alerts': 0, 'semgrep_findings': 0,
            'mobsf_scope': 'offline debug APK static report; not signed artifact/device security'}


def download_report(run_id, artifact, filename):
    # gh extracts only the small sanitized report artifact, never raw scanner data.
    with tempfile.TemporaryDirectory(prefix='bil-release-proof-') as folder:
        subprocess.run(['gh', 'run', 'download', str(run_id), '--repo', REPO,
                        '--name', artifact, '--dir', folder], check=True, timeout=300,
                       stdout=subprocess.DEVNULL)
        matches = list(Path(folder).rglob(filename))
        if len(matches) != 1:
            raise ValueError('Expected exactly one sanitized security report')
        return json.loads(matches[0].read_text(encoding='utf8'))


def verify_security(run_ids, head, api=gh, *, expected_branch=BRANCH):
    semgrep = download_report(run_ids['source_audit'], f'bil-source-audit-{head}', 'semgrep.json')
    mobsf = download_report(run_ids['offline_mobsf'], f'bil-offline-mobsf-{head}', 'summary.json')
    from urllib.parse import quote
    ref = quote('refs/heads/' + expected_branch, safe='')
    analyses = pages(api, f'code-scanning/analyses?ref={ref}')
    alerts = pages(api, f'code-scanning/alerts?state=open&ref={ref}')
    return security_reports(semgrep, mobsf, analyses, alerts, head, expected_branch=expected_branch)


def validate_upload(receipt, inventory, source, ipa_digest, head):
    if (source.strip() != head or receipt.get('source_sha') != head
            or receipt.get('build_number') != '37'
            or receipt.get('validate_outcome') != 'success'
            or receipt.get('upload_outcome') != 'success'
            or receipt.get('status') != 'UPLOAD_ACCEPTED'
            or receipt.get('ipa_sha256') != ipa_digest
            or inventory.get('ipa_sha256') != ipa_digest
            or inventory.get('status') != 'FINAL_ARTIFACT_IDENTITY_PASS'
            or inventory.get('platform') != 'ios' or inventory.get('build') != '37'
            or inventory.get('package') != 'com.bilhealth.bodyintelligencelog'):
        raise ValueError('Signed IPA, source, build and TestFlight receipt do not match')
    return {'status': 'UPLOAD_ACCEPTED', 'source_sha': head, 'build_number': '37',
            'ipa_sha256': ipa_digest, 'processing_verified': False, 'physical_device_verified': False}


def deliver(control, runs):
    if (control.state.get('local_pass') is not True or control.state.get('all_ci_pass') is not True
            or control.state.get('published_head') != control.head):
        raise ValueError('Signed delivery requires successful local and published exact-source CI')
    control.stable()
    run_ids = {entry['lane']['lane_id']: entry['run_id'] for entry in runs if entry['status'] == 'success'}
    validate_prerequisites(control.plan, run_ids, control.head, control.gh)
    control.update(phase='strict_security_evidence_review')
    security = verify_security(run_ids, control.head, control.gh)
    control.atomic_delivery_security = security
    control.update(security_review=security)
    head = control.head
    manifest = ROOT / 'docs/release/BIL_IOS_V37_FROZEN_SOURCE_MANIFEST_2026-10-16.md'
    expected = {'BIL_IOS_V37_AUDITED_SOURCE_SHA': head, 'BIL_ANDROID_V33_AUDITED_SOURCE_SHA': head,
                'BIL_IOS_V37_STAGING_MANIFEST_SHA256': hashlib.sha256(manifest.read_bytes()).hexdigest()}
    before = {name: control.gh('actions/variables/' + name)['value'] for name in expected}
    journal = {'source_sha': head, 'before': before, 'requested': expected, 'status': 'intent'}
    def save():
        control_module_atomic(control.out / 'release-source-binding.json', journal)
    save()
    for name, value in expected.items():
        control.stable()
        remote = subprocess.check_output(['git', 'ls-remote', 'origin', 'refs/heads/' + BRANCH],
                                         cwd=ROOT, encoding='utf8', timeout=120).split()[0]
        if remote != head:
            raise ValueError('Remote moved before signed source binding')
        control.gh('actions/variables/' + name, method='PATCH', fields={'name': name, 'value': value})
        journal['last_variable_updated'] = name
        save()  # Unknown outcomes are not retried or rolled back over another operator.
    if any(control.gh('actions/variables/' + name)['value'] != value for name, value in expected.items()):
        raise ValueError('Release source variable readback failed')
    journal['status'] = 'verified'
    save()
    lane = dict(control.plan['delivery'])
    lane['inputs'] = dict(lane['inputs'], expected_source_sha=head,
                          qa_run_ids=json.dumps(run_ids, sort_keys=True, separators=(',', ':')))
    control.update(phase='signed_ios37_testflight_prerequisites_passed')
    delivered_runs = control.ci_batch([lane], prior_runs=runs)
    if not control.state.get('all_ci_pass'):
        return
    signed = delivered_runs[-1]
    artifacts = pages(control.gh, f"actions/runs/{signed['run_id']}/artifacts", 'artifacts')
    name = f'bil-ios-signed-ipa-{head}'
    exact = [a for a in artifacts if a.get('name') == name and not a.get('expired')]
    if len(exact) != 1:
        raise ValueError('Signed release artifact is missing, duplicated or expired')
    # Stream the IPA hash from the extracted single artifact; never print its contents.
    with tempfile.TemporaryDirectory(prefix='bil-signed-ios37-', dir=control.out) as folder:
        subprocess.run(['gh', 'run', 'download', str(signed['run_id']), '--repo', REPO,
                        '--name', name, '--dir', folder], check=True, timeout=1800)
        folder = Path(folder)
        def unique(pattern):
            matches = list(folder.rglob(pattern))
            if len(matches) != 1:
                raise ValueError('Signed artifact evidence is absent or ambiguous: ' + pattern)
            return matches[0]
        with unique('*.ipa').open('rb') as handle:
            digest = hashlib.file_digest(handle, 'sha256').hexdigest()
        report = validate_upload(json.loads(unique('BIL-testflight-upload-receipt.json').read_text()),
            json.loads(unique('BIL-ios-final-artifact-inventory.json').read_text()),
            unique('BIL-source-head.txt').read_text(), digest, head)
    report.update(run_id=signed['run_id'], url=signed['url'], artifact_id=exact[0]['id'],
                  artifact_name=name, artifact_digest=exact[0].get('digest'))
    control_module_atomic(control.out / 'testflight-delivery.json', report)
    control.update(phase='testflight_upload_accepted_processing_and_device_checks_pending',
                   testflight_upload_accepted=True, testflight_delivery=report, accepted=False)


def control_module_atomic(path, value):
    # This module also runs independently on macOS before any signing inputs load.
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n', encoding='utf8')
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-ci', action='store_true', required=True)
    args = parser.parse_args()
    head = os.environ.get('EXPECTED_SOURCE_SHA', '')
    if (not re.fullmatch('[0-9a-f]{40}', head) or head != os.environ.get('GITHUB_SHA')
            or subprocess.check_output(['git', 'rev-parse', 'HEAD'], encoding='utf8').strip() != head):
        raise SystemExit('Signed build must use the same exact source as its prerequisite runs')
    manifest = json.loads((ROOT / 'tools/qa/revalidation_ci_plan.json').read_text(encoding='utf8'))
    run_ids = json.loads(os.environ.get('QA_RUN_IDS', '{}'))
    validate_prerequisites(manifest, run_ids, head)
    verify_security(run_ids, head)
    print('EXACT_SOURCE_CI_AND_STRICT_SECURITY=PASS')


if __name__ == '__main__':
    main()
