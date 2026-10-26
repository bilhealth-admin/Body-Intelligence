"""Exact-SHA pre-signing gate for internal BIL39, never public release approval.

The comprehensive post-installation release validator remains independent.
This pre-signing phase cannot certify an IPA that does not yet exist or claim
physical-device acceptance before the owner can install that IPA in TestFlight.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.parse
import urllib.request

REPOSITORY = 'bilhealth-admin/Body-Intelligence'
BRANCH = 'bil39/integration-20261025'
BASE = '155b079696430919f8272df934371f033fb11be2'
WORKFLOWS = {
    'verify.yml': {'source-checks', 'flutter',
        'Exact-source QA receipt and orchestration regression tests',
        *{f'flutter-tests (shard {n} of 8)' for n in range(8)}},
    'bil_codeql_security_extended.yml': {
        *{f'CodeQL ({language})' for language in
          ('actions', 'javascript-typescript', 'python', 'java-kotlin', 'swift')},
        'Local Supabase migrations, SQL, Auth and RLS',
        'Isolated Semgrep source audit',
        'Android API 33 native integration without CodeQL tracing',
        'iPhone and iPad native tests from exact simulator bundles'},
    'bil_android_isolated_emulator_smoke.yml': {
        f'Android {api} offline-config startup' for api in (26, 29, 33, 34, 35, 36)},
    'bil39_cloud_source_qa.yml': {'isolated-coach-handler'},
    'bil39_video_source_qa.yml': {'local-worker-tests',
        'Read-only release-pinned public preview byte-range delivery'},
    'bil39-crystal.yml': {'Crystal format/analyze/widget (ubuntu-24.04)',
                         'Crystal format/analyze/widget (windows-latest)'},
    'bil39_coach_native_ui.yml': {'Native SwiftUI Coach Markdown (iPhone)',
                                 'Native SwiftUI Coach Markdown (iPad)'},
    'bil_security_fixture_inventory.yml': {
        'Non-live store URL reviewer and disclosure negative fixtures',
        'Native PostgreSQL17 circle review negative and replay assertions'},
}
PROTECTED = {
    'lib/features/commerce/presentation/bil_dynamic_store_components.dart':
        'fdd24dbfa5b16f78aad65a821a2f5cf1215f90d5',
    'lib/shared/widgets/bil_glass_press_feedback.dart':
        '653d424ddb6cca8adeb0d394f5c8f8866da3792d',
}


def validate_run(run, jobs, *, sha, workflow):
    if (run.get('head_sha') != sha or run.get('head_branch') != BRANCH
            or run.get('event') != 'push' or run.get('status') != 'completed'
            or run.get('conclusion') != 'success'
            or run.get('path') != '.github/workflows/' + workflow):
        raise ValueError(f'Incomplete or mismatched exact-source CI: {workflow}')
    if not str(run.get('html_url', '')).startswith(f'https://github.com/{REPOSITORY}/actions/runs/'):
        raise ValueError('CI evidence URL belongs to another repository')
    by_name = {job['name']: job for job in jobs}
    for name in WORKFLOWS[workflow]:
        job = by_name.get(name, {})
        if (job.get('conclusion') != 'success' or job.get('status') != 'completed'
                or job.get('head_sha') != sha):
            raise ValueError(f'Required job missing, skipped or failed: {workflow}: {name}')
    for job in jobs:
        if job.get('conclusion') not in ('success', 'skipped'):
            raise ValueError(f'An additional job failed or did not finish: {job.get("name")}')
    return {'workflow': workflow, 'source_sha': sha, 'run_id': run['id'],
            'url': run['html_url'], 'required_jobs': sorted(WORKFLOWS[workflow]),
            'status': 'PASS'}


def api(path):
    token = os.environ.get('GH_TOKEN', '')
    if not token:
        raise ValueError('GitHub read token unavailable')
    request = urllib.request.Request('https://api.github.com/repos/' + REPOSITORY + path,
        headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                 'X-GitHub-Api-Version': '2022-11-28'})
    with urllib.request.urlopen(request, timeout=40) as response:
        return json.load(response)


def all_jobs(run_id):
    jobs = []
    for page in range(1, 11):
        batch = api(f'/actions/runs/{run_id}/jobs?per_page=100&page={page}')['jobs']
        jobs.extend(batch)
        if len(batch) < 100:
            return jobs
    raise ValueError('Unexpectedly unbounded CI job inventory')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sha', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.sha):
        raise ValueError('A complete immutable source SHA is required')
    git = lambda *parts: subprocess.check_output(['git', *parts], text=True).strip()
    if git('rev-parse', 'HEAD') != args.sha or git('status', '--porcelain=v1', '--untracked-files=all'):
        raise ValueError('Signing checkout is not the clean audited source')
    subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, args.sha], check=True)
    for file, blob in PROTECTED.items():
        if git('hash-object', file) != blob:
            raise ValueError('Protected checkout source changed: ' + file)
    protected = api('/git/ref/heads/work/ios38-safe-fixes-20261025')
    if protected['object']['sha'] != BASE:
        raise ValueError('Protected iOS38 branch moved; independent review required')
    if os.environ.get('BIL39_VERIFIED_CLOUD_SOURCE_SHA') != args.sha:
        raise ValueError('Production Coach readback and live verification are not recorded for this SHA')
    receipts = []
    for workflow in WORKFLOWS:
        query = urllib.parse.urlencode({'head_sha': args.sha, 'branch': BRANCH,
                                        'event': 'push', 'per_page': 100})
        runs = api('/actions/workflows/' + workflow + '/runs?' + query)['workflow_runs']
        if not runs:
            raise ValueError('No exact-source final CI: ' + workflow)
        latest = max(runs, key=lambda item: (item['id'], item.get('run_attempt', 1)))
        receipts.append(validate_run(latest, all_jobs(latest['id']), sha=args.sha, workflow=workflow))
    report = {'status': 'INTERNAL_BUILD_PREREQUISITES_PASS', 'source_sha': args.sha,
              'build': 39, 'ci': receipts, 'protected_ios38_sha': BASE,
              'physical_device_acceptance': 'PENDING_INSTALLATION_OF_NEW_IPA',
              'signed_artifact_identity': 'MUST_PASS_AFTER_BUILD',
              'app_store_submission_approved': False,
              'public_release_approved': False}
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print('BIL39_INTERNAL_PRE_SIGNING_CI=PASS; PUBLIC_RELEASE_NOT_APPROVED')


if __name__ == '__main__':
    main()
