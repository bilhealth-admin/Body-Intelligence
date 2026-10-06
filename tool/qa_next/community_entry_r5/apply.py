"""Apply the exact, locally authored R5 diff once to the isolated QA branch.

No SDK, dependencies, user data, network request, or application code is run by
this privileged materialization step. The following testing jobs are read-only.
The tracked diff is compressed solely for bounded transport through the editor;
its expanded, reviewable Dart source is committed before any test is executed.
"""
from pathlib import Path
import base64
import hashlib
import json
import os
import re
import subprocess
import zlib

BASE = 'ad3bc5905f336724584705c40cd9dd4eb22fa4e9'
BRANCH = 'refs/heads/qa/coach-community-next-20261005'
ALLOWED = {
    'lib/app/router/app_community_routes.dart',
    'lib/app/router/app_router.dart',
    'lib/features/community/data/community_repository_profile_moderation_mixin.dart',
    'lib/features/community/presentation/community_entry_copy.dart',
    'lib/features/community/presentation/community_entry_gate.dart',
    'lib/features/community/presentation/community_entry_welcome.dart',
    'lib/features/community/presentation/community_feed_tab.dart',
    'lib/features/community/presentation/community_hub_page.dart',
    'lib/features/community/services/community_entry_coordinator.dart',
    'test/features/community/community_entry_flow_test.dart',
    'test/features/community/community_entry_repository_test.dart',
    'test/features/community/community_entry_route_contract_test.dart',
    'test/qa_next/community_entry_capture_test.dart',
}

def git(*args, **kwargs):
    return subprocess.check_output(['git', *args], **kwargs)

if os.environ.get('GITHUB_REF') != BRANCH or os.environ.get('GITHUB_REPOSITORY') != 'bilhealth-admin/Body-Intelligence':
    raise RuntimeError('Only the authorized QA branch is permitted')
expected = os.environ['GITHUB_SHA']
if git('rev-parse', 'HEAD', text=True).strip() != expected:
    raise RuntimeError('Checkout does not match requested commit')
git('merge-base', '--is-ancestor', BASE, 'HEAD')
git('diff', '--exit-code')
out = Path('/tmp/bil-entry-r5'); out.mkdir(exist_ok=True)
entry = Path('lib/features/community/presentation/community_entry_gate.dart')
if not entry.exists():
    if git('diff', '--name-only', BASE, 'HEAD', '--', *sorted(ALLOWED), text=True).strip():
        raise RuntimeError('Application source drift: reconcile before materialization')
    root = Path(__file__).parent
    packed = b''.join((root / f'patch.{i}').read_bytes() for i in range(1, 8))
    if len(packed) != 21631 or hashlib.sha256(packed).hexdigest() != '7956805f43bd3a8c065da2729ff7f5523e89baa3e98136505e0cb673cca466ed':
        raise RuntimeError('Patch transport digest mismatch')
    decoder = zlib.decompressobj()
    patch = decoder.decompress(packed, 1000000)
    if not decoder.eof or decoder.unused_data or len(patch) != 89579:
        raise RuntimeError('Patch exceeds exact expected envelope')
    if hashlib.sha256(patch).hexdigest() != '2bd1016d00bc25b5e495cb6d88cf14c3dbcd2ce0ddb309fb722447eae7ff9da3':
        raise RuntimeError('Expanded patch digest mismatch')
    paths = re.findall(r'^diff --git a/(\S+) b/(\S+)$', patch.decode('utf-8'), re.M)
    if len(paths) != 13 or any(a != b for a, b in paths) or {a for a, b in paths} != ALLOWED:
        raise RuntimeError('Patch scope mismatch')
    git('apply', '--check', '-', input=patch)
    git('apply', '-', input=patch)
    git('diff', '--exit-code', '--', 'supabase', 'cloudflare', 'ios', 'android', 'pubspec.yaml', 'pubspec.lock')
    git('add', '--', *sorted(ALLOWED))
    git('config', 'user.name', 'BIL isolated QA')
    git('config', 'user.email', 'qa@users.noreply.github.com')
    git('commit', '-m', 'feat(community): require confirmed name-only profile and BIL Code at entry\n\nQA branch only. Preserve legacy member privacy, optional photo sync, original destinations and existing notifications. Add transport, lifecycle, 25-locale and actual Flutter capture tests. No production or store operation.')
    authorization = base64.b64encode(('x-access-token:' + os.environ['GH_TOKEN']).encode()).decode()
    print('::add-mask::' + authorization)
    remote_git = ['git', '-c', 'http.https://github.com/.extraheader=AUTHORIZATION: basic ' + authorization]
    remote = subprocess.check_output(remote_git + ['ls-remote', 'origin', BRANCH], text=True).split()[0]
    if remote != expected:
        raise RuntimeError('QA branch advanced; refusing overwrite')
    subprocess.run(remote_git + ['push', 'origin', 'HEAD:' + BRANCH], check=True)
actual = git('rev-parse', 'HEAD', text=True).strip()
manifest = [{'path': name, 'sha256': hashlib.sha256(Path(name).read_bytes()).hexdigest()} for name in sorted(ALLOWED)]
(out / 'source.json').write_text(json.dumps({'source_commit': actual, 'workflow_trigger_commit': expected, 'base_commit': BASE, 'source_files': manifest, 'production_modified': False, 'store_build_created': False, 'reference_parity_verified': False}, indent=2) + '\n')
(out / 'scope.txt').write_text('Exact tracked Community entry source. Host Flutter and synthetic HTTP fixtures; not device or production E2E. No build, signing, deployment, user data or fonts exported.\n')
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write('source_sha=' + actual + '\n')
print('Exact source revision:', actual)
