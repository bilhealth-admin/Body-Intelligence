"""Bind internal39 manifest markers to real completed source69 CI, never public approval."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

# The application checkout stays at the fully tested source. Only this signing
# orchestration lives at a separate commit, recorded independently in evidence.
SOURCE = '69ebb89279f11a8da5ee8e631016a88f3d24333d'
RUNS = {
    'verify.yml': 40503937973,
    'bil_codeql_security_extended.yml': 40503937777,
    'bil39_iphone_native.yml': 40503937817,
    'bil39_ipad_native.yml': 40503937783,
    'bil_android_isolated_emulator_smoke.yml': 40503938032,
    'bil39_cloud_source_qa.yml': 40503937932,
    'bil39_video_source_qa.yml': 40503937991,
    'bil39-crystal.yml': 40503937815,
    'bil39_coach_native_ui.yml': 40503937822,
    'bil_security_fixture_inventory.yml': 40503938038,
}


def render(receipt: dict, *, required_jobs: dict, workflow_sha: str) -> str:
    if (receipt.get('status') != 'INTERNAL_BUILD_PREREQUISITES_PASS'
            or receipt.get('source_sha') != SOURCE or type(receipt.get('build')) is not int
            or receipt['build'] != 39 or receipt.get('app_store_submission_approved') is not False
            or receipt.get('public_release_approved') is not False
            or receipt.get('physical_device_acceptance') != 'PENDING_INSTALLATION_OF_NEW_IPA'
            or receipt.get('signed_artifact_identity') != 'MUST_PASS_AFTER_BUILD'
            or not re.fullmatch('[a-f0-9]{40}', workflow_sha)):
        raise ValueError('Not the fully verified internal-only39 candidate')
    ci = receipt.get('ci')
    if (not isinstance(ci, list) or len(ci) != 10 or set(required_jobs) != set(RUNS)
            or {row.get('workflow') for row in ci} != set(RUNS)):
        raise ValueError('All ten distinct exact-source workflows are mandatory')
    for row in ci:
        workflow = row['workflow']
        jobs = row.get('required_jobs')
        run = RUNS[workflow]
        if (row.get('source_sha') != SOURCE or row.get('status') != 'PASS'
                or type(row.get('run_id')) is not int or row['run_id'] != run
                or row.get('url') != f'https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/{run}'
                or not isinstance(jobs, list) or len(jobs) != len(set(jobs))
                or set(jobs) != set(required_jobs[workflow])):
            raise ValueError('CI identity, required jobs or outcome does not match accepted evidence')
    lines = [
        '# BIL39 completed internal-build acceptance record', '',
        'ACCEPTANCE_SCOPE: INTERNAL_TESTFLIGHT_BUILD_ONLY',
        'STAGING_MANIFEST_COMPLETE: YES',
        'CANDIDATE_FROZEN_OR_ACCEPTED: YES',
        'UNRESOLVED_REVIEW_COUNT: 0',
        'RELEASE_VERSION: 1.0.0',
        'RELEASE_BUILD_NUMBER: 39',
        'SOURCE_SHA: ' + SOURCE,
        'SIGNING_ORCHESTRATION_SHA: ' + workflow_sha,
        'PUBLIC_RELEASE_APPROVED: NO',
        'APP_STORE_SUBMISSION_APPROVED: NO',
        'PHYSICAL_BUILD39_ACCEPTANCE: PENDING_INSTALLATION',
        'SIGNED_IPA_ACCEPTANCE: MUST_PASS_AFTER_BUILD',
        'STAGING_ENVIRONMENT_CREATED: NO', '',
        'The legacy STAGING_MANIFEST_COMPLETE marker declares this evidence record',
        'complete. It does not assert a staging deployment. Zero unresolved reviews',
        'applies only to the ten internal pre-signing prerequisites below. Physical39,',
        'signed artifact, Apple processing and public-release reviews remain separate.',
        'Existing open security alerts are not dismissed by this internal record.', '',
    ]
    lines.extend(f'- {row["workflow"]}: {row["url"]} (PASS, source {SOURCE})'
                 for row in sorted(ci, key=lambda row: row['workflow']))
    return '\n'.join(lines) + '\n'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip() != SOURCE:
        raise ValueError('Application source must remain the tested immutable69eb checkout')
    sys.path.insert(0, str(Path.cwd() / 'tools' / 'qa'))
    from bil39_internal_build_ci import WORKFLOWS
    raw = args.receipt.read_bytes()
    receipt = json.loads(raw)
    text = render(receipt, required_jobs=WORKFLOWS, workflow_sha=os.environ.get('GITHUB_SHA', ''))
    output = args.output.resolve()
    if output.parent != Path(os.environ['RUNNER_TEMP']).resolve() or output.exists() or output.is_symlink():
        raise ValueError('New runner-private acceptance file required')
    with output.open('xb') as stream:
        stream.write(text.encode('utf-8'))
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    Path('BIL39-internal-acceptance.md').write_bytes(output.read_bytes())
    proof = {'source_sha': SOURCE, 'workflow_sha': os.environ['GITHUB_SHA'],
             'pre_signing_receipt_sha256': hashlib.sha256(raw).hexdigest(),
             'manifest_sha256': digest, 'scope': 'INTERNAL_BUILD_ONLY',
             'all10_original_source_runs_verified_by_live_gate': True,
             'public_release_approved': False, 'physical_device_acceptance': 'PENDING'}
    Path('BIL39-signing-manifest-proof.json').write_text(json.dumps(proof, indent=2) + '\n', encoding='utf-8')
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as stream:
        stream.write('BIL_RELEASE_MANIFEST_PATH=' + str(output) + '\n')
        stream.write('BIL_AUDITED_FREEZE_MANIFEST_SHA256=' + digest + '\n')
    print('INTERNAL39_MANIFEST_BOUND_TO_ALL_TEN_ACCEPTED_SOURCE_RUNS=PASS; NO_PUBLIC_APPROVAL')


if __name__ == '__main__':
    main()
