"""Apply the byte-verified R3 source patch only to the authorized QA worktree.

The compressed payload contains ordinary reviewable Dart source differences,
not executable binaries, fonts, user assets or production configuration.
The workflow commits the exact result BEFORE running Flutter checks.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import zlib

if os.environ.get('GITHUB_REF') != 'refs/heads/qa/coach-community-next-20261005':
    raise RuntimeError('Only the isolated QA branch may apply R3')
root = Path('.')
manifest = json.loads((root/'tool/qa_next/revision_r3_manifest.json').read_text())
subprocess.run(['git','merge-base','--is-ancestor',manifest['base_commit'],'HEAD'],check=True)
subprocess.run(['git','diff','--exit-code'],check=True)
paths = []
for row in manifest['files']:
    p = Path(row['path'])
    if p.is_absolute() or '..' in p.parts or p.parts[0] not in ('lib','test') or p.suffix != '.dart' or p.is_symlink():
        raise RuntimeError('Unexpected patch path')
    if row['before_sha256'] is None:
        if p.exists(): raise RuntimeError('New path already exists: '+str(p))
    elif not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=row['before_sha256']:
        raise RuntimeError('Source changed; refusing overwrite: '+str(p))
    paths.append(p.as_posix())
compressed=(root/'tool/qa_next/revision_r3.patch.zlib').read_bytes()
if len(compressed)>1024*1024: raise RuntimeError('Oversized payload')
decoder=zlib.decompressobj()
patch=decoder.decompress(compressed,1024*1024)
if not decoder.eof or decoder.unused_data or decoder.unconsumed_tail: raise RuntimeError('Invalid bounded payload')
if hashlib.sha256(patch).hexdigest()!=manifest['patch_sha256']: raise RuntimeError('Patch digest mismatch')
subprocess.run(['git','apply','--check','--whitespace=error','-'],input=patch,check=True)
subprocess.run(['git','apply','--whitespace=error','-'],input=patch,check=True)
for row in manifest['files']:
    if hashlib.sha256(Path(row['path']).read_bytes()).hexdigest()!=row['after_sha256']:
        raise RuntimeError('Result digest mismatch: '+row['path'])
changed=set(subprocess.check_output(['git','diff','--name-only'],text=True).splitlines())
if changed-set(paths): raise RuntimeError('Unexpected changes outside R3')
subprocess.run(['dart','format','--output=none','--set-exit-if-changed',*paths],check=True)
print('R3 exact source materialized:',len(paths),'files. Native tests have not run yet.')
