"""Exact-source CI and separate deployed-source parity for iOS41/Android33.

No upload or deployment occurs here. This pre-signing gate cannot certify a
future artifact or physical device, and source parity is not model health.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import urllib.parse

from bil40_internal_build_ci import REPOSITORY, WORKFLOWS, PROTECTED, api, all_jobs

BRANCH = 'codex/bil41-android33-release-20261106'
PROMOTION_BRANCH = 'codex/bil41-internal-testflight-20261106'
BASE = '155b079696430919f8272df934371f033fb11be2'
SIGNED40 = '0c94cf2a75c01ebb7cbea74704a18a8109831194'
CLOUD_SOURCE = '53924198e960edae0a06c8234cb0d216a7f89437'
CLOUD_RECEIPT = 'docs/release/BIL41_CLOUD_SOURCE_PARITY_20261106.json'
BUILDS = {'ios': 41, 'android': 33}


def validate_run(run, jobs, *, sha, workflow, branch=BRANCH):
    run_id = run.get('id')
    if (branch != BRANCH or type(run_id) is not int or run_id <= 0
            or run.get('head_sha') != sha or run.get('head_branch') != branch
            or run.get('event') != 'push' or run.get('status') != 'completed'
            or run.get('conclusion') != 'success'
            or run.get('path') != '.github/workflows/' + workflow
            or run.get('html_url') != f'https://github.com/{REPOSITORY}/actions/runs/{run_id}'):
        raise ValueError(f'Incomplete or mismatched exact-source CI: {workflow}')
    for name in WORKFLOWS[workflow]:
        matches = [job for job in jobs if job.get('name') == name]
        if (len(matches) != 1 or matches[0].get('conclusion') != 'success'
                or matches[0].get('status') != 'completed'
                or matches[0].get('head_sha') != sha):
            raise ValueError(f'Required job missing, duplicated, skipped or failed: {workflow}: {name}')
    if any(job.get('status') != 'completed' or job.get('conclusion') not in ('success', 'skipped')
           for job in jobs):
        raise ValueError('An additional CI job failed or did not finish')
    return {'workflow': workflow, 'source_sha': sha, 'source_branch': branch,
            'run_id': run_id, 'url': run['html_url'],
            'required_jobs': sorted(WORKFLOWS[workflow]), 'status': 'PASS'}


def cloud_parity(root: Path, receipt: dict, *, source_bytes=None) -> dict:
    """Verify recorded read-only deployment bytes, never claim a live response."""
    if (receipt.get('schema') != 'BIL_DEPLOYED_EDGE_SOURCE_PARITY_V1'
            or receipt.get('source_commit') != CLOUD_SOURCE
            or receipt.get('project_ref') != 'tgmanzhqulksykhslrzb'
            or receipt.get('function_slug') != 'ai-coach'
            or receipt.get('version') != 134 or receipt.get('status') != 'ACTIVE'
            or receipt.get('all_candidate_and_cloud_source_bytes_match') is not True
            or receipt.get('read_only') is not True
            or type(receipt.get('new_model_requests')) is not int or receipt['new_model_requests'] != 0
            or type(receipt.get('cloud_writes')) is not int or receipt['cloud_writes'] != 0):
        raise ValueError('Separate deployed Coach source parity receipt required')
    from datetime import datetime
    if datetime.fromisoformat(receipt.get('verified_at_utc', '')).utcoffset() is None:
        raise ValueError('Cloud readback time must be explicit')
    for key in ('deployed_archive_sha256', 'remote_read_response_sha256'):
        if not re.fullmatch('[0-9a-f]{64}', receipt.get(key, '')):
            raise ValueError('Missing deployed source readback digest')
    files = receipt.get('files')
    config = receipt.get('deployed_configuration')
    if not isinstance(files, list) or len(files) != 15 or not isinstance(config, list) or len(config) != 1:
        raise ValueError('All 15 runtime files and the deployed import configuration are required')
    seen = set()
    for row in files + config:
        name, digest = row.get('path', ''), row.get('sha256', '')
        path = PurePosixPath(name)
        if (not name.startswith('supabase/functions/') or path.is_absolute()
                or str(path) != name or '..' in path.parts or '\\' in name
                or name in seen or not re.fullmatch('[0-9a-f]{64}', digest)):
            raise ValueError('Invalid or duplicated deployed source path/digest')
        seen.add(name)
        file = root / name
        if file.is_symlink() or not file.is_file() or not file.resolve().is_relative_to(root.resolve()):
            raise ValueError('Deployed source path is not a regular repository file')
        observed = file.read_bytes()
        if hashlib.sha256(observed).hexdigest() != digest:
            raise ValueError('Candidate differs from deployed source: ' + name)
        if row in files and (type(row.get('bytes')) is not int or len(observed) != row['bytes']):
            raise ValueError('Recorded deployed source size mismatch')
        prior = source_bytes(name) if source_bytes else subprocess.check_output(
            ['git', 'show', CLOUD_SOURCE + ':' + name], cwd=root)
        if prior != observed:
            raise ValueError('Recorded cloud source commit differs from candidate: ' + name)
    if not {'supabase/functions/ai-coach/index.ts', 'supabase/functions/ai-coach/server.ts',
            'supabase/functions/_shared/mobile_integrity.ts',
            'supabase/functions/ai-coach/deno.json'}.issubset(seen):
        raise ValueError('Required deployed entrypoints/configuration are absent')
    return {'status': 'RECORDED_DEPLOYED_SOURCE_PARITY_PASS', 'source_commit': CLOUD_SOURCE,
            'deployed_version': 134, 'runtime_file_count': 15,
            'verified_at_utc': receipt['verified_at_utc'], 'new_model_requests': 0,
            'live_model_health': 'NOT_TESTED_BY_THIS_GATE'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--branch', choices=[BRANCH], required=True)
    parser.add_argument('--platform', choices=sorted(BUILDS), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.sha):
        raise ValueError('A complete immutable source SHA is required')
    git = lambda *parts: subprocess.check_output(['git', *parts], text=True).strip()
    if git('rev-parse', 'HEAD') != args.sha or git('status', '--porcelain=v1', '--untracked-files=all'):
        raise ValueError('Signing checkout is not the clean audited source')
    subprocess.run(['git', 'merge-base', '--is-ancestor', SIGNED40, args.sha], check=True)
    for file, blob in PROTECTED.items():
        if git('hash-object', file) != blob:
            raise ValueError('Protected purchase source changed: ' + file)
    for branch, expected in (('work/ios38-safe-fixes-20261025', BASE),
                             ('codex/bil40-device-fixes-20261028', SIGNED40),
                             (BRANCH, args.sha)):
        if api('/git/ref/heads/' + branch)['object']['sha'] != expected:
            raise ValueError('Protected or audited source branch moved: ' + branch)
    root = Path.cwd()
    raw = (root / CLOUD_RECEIPT).read_bytes()
    cloud = cloud_parity(root, json.loads(raw))
    cloud['receipt_sha256'] = hashlib.sha256(raw).hexdigest()
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
              'source_branch': BRANCH, 'platform': args.platform, 'build': BUILDS[args.platform],
              'ci': receipts, 'cloud_source_parity': cloud,
              'protected_ios38_sha': BASE, 'protected_ios40_sha': SIGNED40,
              'physical_device_acceptance': 'PENDING_INSTALLATION_OF_NEW_ARTIFACT',
              'signed_artifact_identity': 'MUST_PASS_AFTER_BUILD',
              'app_store_submission_approved': False, 'public_release_approved': False}
    with args.output.open('x', encoding='utf-8') as output:
        output.write(json.dumps(report, indent=2) + '\n')
    print('BIL41_ANDROID33_PRE_SIGNING_CI=PASS; PUBLIC_RELEASE_NOT_APPROVED')


if __name__ == '__main__':
    main()
