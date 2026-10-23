"""Run the immutable owner engine for the one authorized iOS38/Android33 branch.

Only branch identity and the deployed Smart Plan build capability differ.
Original source-freeze, scope, evidence, concurrency and failure checks remain.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import subprocess

import bil_owner_full_test_runner as owner

BRANCH = 'codex/bil-release-ios38-android33-20261022'
PROTECTED = '31554b3e078667a38bd3c53aa105f5f1d2a4dc96'
SOURCE_BASE = '937aea673c2e9c0bec15ef988131d58f96bf5afe'
OWNER_SHA256 = '3dbdc556d1484dfc250eb1d55154d431e8cc587ac013285f9c9e2d7fe1af54b2'
_original_command = owner.root_test_command


def verify_original(path):
    if hashlib.sha256(Path(path).read_bytes()).hexdigest() != OWNER_SHA256:
        raise RuntimeError('Original owner runner changed; execution refused')


def verify_branch(branch, head, ci_ref=None, ci_head=None):
    if branch == BRANCH:
        return
    if not branch and ci_ref == BRANCH and ci_head == head:
        return  # The original engine additionally verifies exact origin HEAD.
    raise RuntimeError('Only the authorized candidate branch is accepted')


def root_command(dart, snapshot):
    return [*_original_command(dart, snapshot),
            '--dart-define=BIL_SMART_PLAN_CLOUD_ENABLED=true']


def main():
    # The full root run must include all new PNG comparisons/captures even if
    # a previous code-only process inherited suppression flags.
    os.environ['BIL_CAPTURE_SMART_PLAN_GOLDENS'] = '1'
    os.environ['BIL_CAPTURE_COMMUNITY_REPORT'] = '1'
    verify_original(Path(owner.__file__))
    head = owner.git('rev-parse', 'HEAD')
    verify_branch(owner.git('branch', '--show-current'), head,
                  os.environ.get('GITHUB_REF_NAME'), os.environ.get('GITHUB_SHA'))
    for base in (PROTECTED, SOURCE_BASE):
        subprocess.run(['git', 'merge-base', '--is-ancestor', base, head],
                       cwd=owner.ROOT, check=True)
    owner.ALLOWED_BRANCH = BRANCH
    owner.root_test_command = root_command
    return owner.main()


if __name__ == '__main__':
    raise SystemExit(main())
