"""Verify the reviewed current purchase UI and press feedback on the exact application checkout."""
import json
import os
from pathlib import Path
from types import MappingProxyType

from bil49_protected_purchase_contract import PRESS, SOURCE_BRANCH, STORE, git, require, source_context

PROTECTED50 = MappingProxyType({
    STORE: 'f8f6dcec3f8779eb5e7de0fc9e8e29526d5c01dd',
    PRESS: '653d424ddb6cca8adeb0d394f5c8f8866da3792d',
})


def validate_observed(observed):
    require(isinstance(observed, dict) and set(observed) == set(PROTECTED50),
            'Exactly both version50 protected paths are required')
    for path, expected in PROTECTED50.items():
        require(type(observed[path]) is str and observed[path] == expected,
                'Version50 protected source changed: ' + path)


def verify50(root, env):
    head = source_context(env)
    root = root.resolve(strict=True)
    require(Path(git(root, 'rev-parse', '--show-toplevel')).resolve() == root,
            'Expected the application repository root')
    require(git(root, 'rev-parse', 'HEAD') == head, 'Current application HEAD differs from event source')
    require(not git(root, 'status', '--porcelain=v1', '--untracked-files=all'), 'Current application checkout changed')
    observed = {}
    for relative, expected in PROTECTED50.items():
        path = root / relative
        require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root),
                'Missing or nonregular protected path: ' + relative)
        require(git(root, 'ls-tree', head, '--', relative) == f'100644 blob {expected}\t{relative}',
                'Protected application tree entry differs: ' + relative)
        observed[relative] = git(root, 'hash-object', relative)
    validate_observed(observed)
    return {'status': 'VERSION50_PROTECTED_SOURCE_ONLY_PASS', 'contract': 'bil50.purchase-source.v1',
            'source_sha': head, 'source_branch': SOURCE_BRANCH, 'protected_blobs': observed,
            'signing_approved': False, 'store_submission_approved': False}


if __name__ == '__main__':
    print(json.dumps(verify50(Path.cwd(), os.environ), sort_keys=True))
