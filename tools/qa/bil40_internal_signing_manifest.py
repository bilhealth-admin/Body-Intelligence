"""Bind internal Build40 to completed exact-source CI; never public approval."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from bil40_internal_build_ci import WORKFLOWS, REPOSITORY


def render(receipt: dict, *, source: str, workflow_sha: str) -> str:
    if (not re.fullmatch('[0-9a-f]{40}', source) or workflow_sha != source
            or receipt.get('source_sha') != source
            or receipt.get('status') != 'INTERNAL_BUILD_PREREQUISITES_PASS'
            or type(receipt.get('build')) is not int or receipt['build'] != 40
            or receipt.get('app_store_submission_approved') is not False
            or receipt.get('public_release_approved') is not False
            or receipt.get('physical_device_acceptance') != 'PENDING_INSTALLATION_OF_NEW_IPA'
            or receipt.get('signed_artifact_identity') != 'MUST_PASS_AFTER_BUILD'):
        raise ValueError('Not an exact-source internal-only Build40 receipt')
    ci = receipt.get('ci')
    if (not isinstance(ci, list) or len(ci) != len(WORKFLOWS)
            or {row.get('workflow') for row in ci} != set(WORKFLOWS)):
        raise ValueError('All distinct exact-source CI workflows are required')
    run_ids = set()
    for row in ci:
        run = row.get('run_id')
        jobs = row.get('required_jobs')
        if (type(run) is not int or run <= 0 or run in run_ids
                or row.get('source_sha') != source or row.get('status') != 'PASS'
                or row.get('url') != f'https://github.com/{REPOSITORY}/actions/runs/{run}'
                or not isinstance(jobs, list) or len(jobs) != len(set(jobs))
                or set(jobs) != WORKFLOWS[row['workflow']]):
            raise ValueError('Mismatched CI identity, job coverage or outcome')
        run_ids.add(run)
    lines = [
        '# BIL40 completed internal-build prerequisite record', '',
        'ACCEPTANCE_SCOPE: INTERNAL_TESTFLIGHT_BUILD_ONLY',
        'STAGING_MANIFEST_COMPLETE: YES',
        'CANDIDATE_FROZEN_OR_ACCEPTED: YES',
        'UNRESOLVED_REVIEW_COUNT: 0',
        'RELEASE_VERSION: 1.0.0',
        'RELEASE_BUILD_NUMBER: 40',
        'SOURCE_SHA: ' + source,
        'SIGNING_ORCHESTRATION_SHA: ' + workflow_sha,
        'PUBLIC_RELEASE_APPROVED: NO',
        'APP_STORE_SUBMISSION_APPROVED: NO',
        'PHYSICAL_BUILD40_ACCEPTANCE: PENDING_INSTALLATION',
        'SIGNED_IPA_ACCEPTANCE: MUST_PASS_AFTER_BUILD',
        'STAGING_ENVIRONMENT_CREATED: NO', '',
        'The legacy staging marker describes this prerequisite record, not a',
        'staging deployment. Zero unresolved reviews applies only to the exact',
        'pre-signing CI prerequisites. Build39 device findings and their Build40',
        'regressions remain separately tracked; physical40 acceptance, binary',
        'identity and Apple processing are not certified by this record.', '',
    ]
    lines += [f'- {r["workflow"]}: {r["url"]} (PASS, source {source})'
              for r in sorted(ci, key=lambda r: r['workflow'])]
    return '\n'.join(lines) + '\n'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    raw = args.receipt.read_bytes()
    text = render(json.loads(raw), source=source, workflow_sha=os.environ.get('GITHUB_SHA', ''))
    output = args.output.resolve()
    if output.parent != Path(os.environ['RUNNER_TEMP']).resolve() or output.exists() or output.is_symlink():
        raise ValueError('New runner-private acceptance file required')
    with output.open('xb') as stream:
        stream.write(text.encode('utf-8'))
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    Path('BIL40-internal-acceptance.md').write_bytes(output.read_bytes())
    proof = {'source_sha': source, 'workflow_sha': os.environ['GITHUB_SHA'],
             'pre_signing_receipt_sha256': hashlib.sha256(raw).hexdigest(),
             'manifest_sha256': digest, 'scope': 'INTERNAL_BUILD_ONLY',
             'all10_original_source_runs_verified_by_live_gate': True,
             'public_release_approved': False, 'physical_device_acceptance': 'PENDING'}
    Path('BIL40-signing-manifest-proof.json').write_text(json.dumps(proof, indent=2)+'\n', encoding='utf-8')
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as stream:
        stream.write('BIL_RELEASE_MANIFEST_PATH='+str(output)+'\n')
        stream.write('BIL_AUDITED_FREEZE_MANIFEST_SHA256='+digest+'\n')
    print('INTERNAL40_MANIFEST_BOUND_TO_EXACT_SOURCE_CI=PASS; NO_PUBLIC_APPROVAL')


if __name__ == '__main__':
    main()
