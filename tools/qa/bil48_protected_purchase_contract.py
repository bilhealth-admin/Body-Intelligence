"""Exact version48 purchase-source guard only; no signing or release approval.

Historical40/44 source guards remain immutable. These two explicit pins are
reviewed source constants, never defaults computed from the checkout.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import re
import subprocess
from types import MappingProxyType

REPOSITORY = 'bilhealth-admin/Body-Intelligence'
SOURCE_BRANCH = 'codex/bil48-android40-passive-reconciliation-20261117'
CONTRACT_ID = 'bil48.purchase-source.v1'
STORE = 'lib/features/commerce/presentation/bil_dynamic_store_components.dart'
PRESS = 'lib/shared/widgets/bil_glass_press_feedback.dart'
HISTORICAL44 = MappingProxyType({
    STORE: '119f72914b468ff3db40dd07e72da96b837f7da7',
    PRESS: '653d424ddb6cca8adeb0d394f5c8f8866da3792d',
})
PROTECTED48 = MappingProxyType({
    STORE: 'da3c7dde8a1f9807345eb03e58c148874cfa8deb',
    PRESS: '653d424ddb6cca8adeb0d394f5c8f8866da3792d',
})

def require(condition, message):
    if not condition:
        raise ValueError(message)

def validate_observed(observed):
    require(isinstance(observed, dict) and set(observed) == set(PROTECTED48),
            'Exactly the two protected version48 paths are required')
    for path, expected in PROTECTED48.items():
        require(type(observed[path]) is str and observed[path] == expected,
                'Version48 protected source changed: ' + path)

def source_context(env):
    """Resolve only GitHub's actual source context, never a caller-selected pin."""
    event = env.get('BIL_PURCHASE_EVENT_NAME')
    branch = env.get('BIL_PURCHASE_SOURCE_BRANCH')
    source_sha = env.get('BIL_PURCHASE_SOURCE_SHA', '')
    require(branch == SOURCE_BRANCH, 'Version48 guard requires its exact source branch')
    require(re.fullmatch('[a-f0-9]{40}', source_sha) is not None,
            'An exact version48 source commit is required')
    if event in ('push', 'workflow_dispatch'):
        require(env.get('BIL_PURCHASE_REF') == 'refs/heads/' + SOURCE_BRANCH
                and env.get('BIL_PURCHASE_REF_NAME') == SOURCE_BRANCH
                and not env.get('BIL_PURCHASE_HEAD_REF')
                and not env.get('BIL_PURCHASE_HEAD_SHA')
                and not env.get('BIL_PURCHASE_HEAD_REPOSITORY')
                and env.get('BIL_PURCHASE_EVENT_SHA') == source_sha,
                'Version48 branch/ref/commit context mismatch')
    elif event == 'pull_request':
        ref = env.get('BIL_PURCHASE_REF', '')
        require(re.fullmatch(r'refs/pull/[1-9][0-9]*/merge', ref) is not None
                and env.get('BIL_PURCHASE_REF_NAME') == ref.removeprefix('refs/pull/')
                and env.get('BIL_PURCHASE_HEAD_REF') == SOURCE_BRANCH
                and env.get('BIL_PURCHASE_HEAD_REPOSITORY') == REPOSITORY
                and env.get('BIL_PURCHASE_HEAD_SHA') == source_sha,
                'Version48 pull request must identify the repository head commit')
    else:
        raise ValueError('Unsupported version48 source event')
    return source_sha

def git(root, *parts):
    return subprocess.check_output(['git', *parts], cwd=root, text=True).strip()

def verify48(root, env):
    expected_sha = source_context(env)
    root = root.resolve(strict=True)
    require(git(root, 'rev-parse', 'HEAD') == expected_sha,
            'Version48 must check the exact source head, never a PR merge commit')
    require(not git(root, 'status', '--porcelain=v1', '--untracked-files=all'),
            'Version48 source checkout changed before protected-source validation')
    observed = {}
    for relative in PROTECTED48:
        path = root / relative
        require(path.is_file() and not path.is_symlink()
                and path.resolve().is_relative_to(root),
                'Protected path must be a regular repository file')
        observed[relative] = git(root, 'hash-object', relative)
    validate_observed(observed)
    return {'status': 'VERSION48_PROTECTED_SOURCE_ONLY_PASS',
            'contract': CONTRACT_ID, 'source_sha': expected_sha,
            'source_branch': SOURCE_BRANCH, 'protected_blobs': observed,
            'signing_approved': False, 'store_submission_approved': False}

if __name__ == '__main__':
    print(json.dumps(verify48(Path.cwd(), os.environ), sort_keys=True))
