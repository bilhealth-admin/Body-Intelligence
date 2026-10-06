"""Materialize the reviewed two-file R5 analyzer repair on the QA branch only.

The readable replacements and before/after digests are exact. No dependencies,
app code, network data, build, or production operation run in this write step.
Tests execute the resulting committed revision in separate read-only jobs.
"""
from pathlib import Path
import base64
import hashlib
import json
import os
import subprocess

BASE = '0c26336545709575addd7544402e164aed37a553'
BRANCH = 'refs/heads/qa/coach-community-next-20261005'
REPAIRS = {
    'lib/features/community/presentation/community_entry_gate.dart': (
        'b0b858e2cee3b83b2bf44c58c0a39231779953fec34ddad8cb9589565fcf1612',
        '9e7a9be940c5acbaa2933597455c0a486f236956c130f2041c7f29cda6eb4508',
        [
            ('      if (_sameOperation(generation, owner))\n        setState(() => _failedCheck = true);', '      if (_sameOperation(generation, owner)) {\n        setState(() => _failedCheck = true);\n      }', 1),
            ('    if (!synced && _sameOperation(generation, owner)) {', '    if (!synced && mounted && _sameOperation(generation, owner)) {', 1),
        ],
    ),
    'test/features/community/community_entry_flow_test.dart': (
        '0180a5ce6e4ac1f92087fded00e95934ac1e180ea17ec537739569c67e20d596',
        '65490d6a6b3f369378ff1ee5c54254d5f19896d51022cfc5a65f6f43f30b5558',
        [
            ('  EntryRepositoryFixture({String? owner = ownerA})\n    : owner = owner,\n      super(', '  EntryRepositoryFixture({this.owner = ownerA})\n    : super(', 1),
            ('    if (currentUserId != expectedOwnerId)\n      throw const CommunityEntryOwnerChanged();', '    if (currentUserId != expectedOwnerId) {\n      throw const CommunityEntryOwnerChanged();\n    }', 2),
            ("        if (tag != 'en')\n          expect(value, isNot(CommunityEntryCopy.resolve('en', key)));", "        if (tag != 'en') {\n          expect(value, isNot(CommunityEntryCopy.resolve('en', key)));\n        }", 1),
        ],
    ),
}

def git(*args, **kwargs):
    return subprocess.check_output(['git', *args], **kwargs)

if os.environ.get('GITHUB_REF') != BRANCH or os.environ.get('GITHUB_REPOSITORY') != 'bilhealth-admin/Body-Intelligence':
    raise RuntimeError('Authorized isolated QA branch only')
expected = os.environ['GITHUB_SHA']
if git('rev-parse', 'HEAD', text=True).strip() != expected:
    raise RuntimeError('Checkout identity mismatch')
git('merge-base', '--is-ancestor', BASE, 'HEAD')
git('diff', '--exit-code')
out = Path('/tmp/bil-entry-r5'); out.mkdir(exist_ok=True)
changed = []
for name, (before, after, replacements) in REPAIRS.items():
    p = Path(name)
    data = p.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest == after:
        continue
    if digest != before:
        raise RuntimeError('Source drift; reconcile instead of overwriting: ' + name)
    text = data.decode('utf-8')
    for old, new, count in replacements:
        if text.count(old) != count:
            raise RuntimeError('Replacement occurrence mismatch: ' + name)
        text = text.replace(old, new)
    encoded = text.encode('utf-8')
    if hashlib.sha256(encoded).hexdigest() != after:
        raise RuntimeError('Reviewed result digest mismatch: ' + name)
    p.write_bytes(encoded)
    changed.append(name)
if changed:
    actual_changes = set(git('diff', '--name-only', text=True).splitlines())
    if actual_changes != set(changed):
        raise RuntimeError('Unexpected edit outside reviewed files')
    git('add', '--', *changed)
    git('config', 'user.name', 'BIL isolated QA')
    git('config', 'user.email', 'qa@users.noreply.github.com')
    git('commit', '-m', 'fix(community): guard optional-photo context and close entry analyzer findings\n\nExact reviewed two-file repair. Every persistence, privacy, failure and accessibility assertion retained. QA only, no backend or release operations.')
    auth = base64.b64encode(('x-access-token:' + os.environ['GH_TOKEN']).encode()).decode()
    print('::add-mask::' + auth)
    remote_git = ['git', '-c', 'http.https://github.com/.extraheader=AUTHORIZATION: basic ' + auth]
    remote = subprocess.check_output(remote_git + ['ls-remote', 'origin', BRANCH], text=True).split()[0]
    if remote != expected:
        raise RuntimeError('QA branch advanced; refusing overwrite')
    subprocess.run(remote_git + ['push', 'origin', 'HEAD:' + BRANCH], check=True)
actual = git('rev-parse', 'HEAD', text=True).strip()
manifest = [{'path': name, 'sha256': hashlib.sha256(Path(name).read_bytes()).hexdigest()} for name in sorted(REPAIRS)]
(out / 'source.json').write_text(json.dumps({'source_commit': actual, 'workflow_trigger_commit': expected, 'base_commit': BASE, 'repaired_files': manifest, 'production_modified': False, 'store_build_created': False, 'reference_parity_verified': False}, indent=2) + '\n')
(out / 'scope.txt').write_text('Exact reviewed R5 repair, committed before tests. Native Flutter host fixtures only, no claim of live-device or complete reference parity.\n')
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write('source_sha=' + actual + '\n')
print('Exact source revision:', actual)
