"""Prepare iOS38/Android33 or verify exact-source prerequisites. Never uploads."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

import bil_release_delivery as delivery

ROOT = Path(__file__).resolve().parents[2]
BRANCH = 'codex/bil-release-ios38-android33-20261022'
PROTECTED = '31554b3e078667a38bd3c53aa105f5f1d2a4dc96'
SOURCE_BASE = '937aea673c2e9c0bec15ef988131d58f96bf5afe'
TARGETS = {'ios': '38', 'android': '33'}
MANIFESTS = {
    'ios': 'docs/release/BIL_IOS_V38_CANDIDATE_2026-10-22.md',
    'android': 'docs/release/BIL_ANDROID_V33_REVISED_CANDIDATE_2026-10-22.md',
}


def validate_identity(platform, build, head, branch):
    if platform not in TARGETS or build != TARGETS[platform]:
        raise ValueError('Only iOS38 and Android33 are authorized by this profile')
    if not re.fullmatch(r'[0-9a-f]{40}', head) or branch != BRANCH:
        raise ValueError('Full source SHA and the independent release branch are required')


def validate_manifest(text, platform):
    required = (
        '`STAGING_MANIFEST_COMPLETE: YES`',
        '`CANDIDATE_FROZEN_OR_ACCEPTED: YES`',
        '`UNRESOLVED_REVIEW_COUNT: 0`',
        '`RELEASE_VERSION: 1.0.0`',
        f'`RELEASE_BUILD_NUMBER: {TARGETS[platform]}`',
    )
    if any(text.splitlines().count(line) != 1 for line in required):
        raise ValueError('Candidate source record is incomplete or not accepted')


def verify_ci(platform, head, run_ids, api=delivery.gh):
    validate_identity(platform, TARGETS[platform], head, BRANCH)
    protected = api('git/ref/heads/integration/bil-qa-media-policy-20261011')
    if protected.get('object', {}).get('sha') != PROTECTED:
        raise ValueError('Protected original branch changed; signing is blocked')
    plan = json.loads((ROOT / 'tools/qa/revalidation_ci_plan.json').read_text(encoding='utf-8'))
    proofs = delivery.validate_prerequisites(plan, run_ids, head, api, expected_branch=BRANCH)
    security = delivery.verify_security(run_ids, head, api, expected_branch=BRANCH)
    return {'source_sha': head, 'branch': BRANCH, 'platform': platform,
            'build': TARGETS[platform], 'ci_lanes': len(proofs), 'security': security}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=TARGETS)
    parser.add_argument('--expected-head')
    parser.add_argument('--verify-ci', action='store_true')
    args = parser.parse_args()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
    detached_workflow = (args.verify_ci and not branch
                         and os.environ.get('GITHUB_REF_NAME') == BRANCH)
    if branch != BRANCH and not detached_workflow:
        raise SystemExit('Candidate preparation requires its independent release branch')
    for base in (PROTECTED, SOURCE_BASE):
        subprocess.run(['git', 'merge-base', '--is-ancestor', base, head], cwd=ROOT, check=True)
    if not args.verify_ci:
        print(json.dumps({'status': 'PREPARING_NOT_ACCEPTED', 'source_sha': head,
            'branch': branch, 'version': '1.0.0', 'builds': TARGETS,
            'manifests': MANIFESTS, 'signing': 'NOT_RUN', 'testflight': 'NOT_RUN',
            'google_play': 'NOT_RUN', 'production': 'NOT_CHANGED'}, indent=2))
        return
    if args.platform is None or args.expected_head != head or os.environ.get('GITHUB_SHA') != head:
        raise SystemExit('Signing requires identical dispatched, checked-out and tested source')
    if os.environ.get('GITHUB_REF_NAME') != BRANCH:
        raise SystemExit('Signing requires the approved candidate workflow branch')
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
        raise SystemExit('Signing requires a clean committed source')
    validate_manifest((ROOT / MANIFESTS[args.platform]).read_text(encoding='utf-8'), args.platform)
    runs = json.loads(os.environ.get('QA_RUN_IDS', '{}'))
    result = verify_ci(args.platform, head, runs)
    result['manifest_sha256'] = hashlib.sha256((ROOT / MANIFESTS[args.platform]).read_bytes()).hexdigest()
    print(json.dumps(result, indent=2))
    print('EXACT_SOURCE_CI_AND_STRICT_SECURITY=PASS')


if __name__ == '__main__':
    main()
