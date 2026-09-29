"""Strict host diagnostic on untouched 59839 source; never update a golden."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

out=Path(os.environ['RUNNER_TEMP'])/'sapphire-host-probe';out.mkdir(parents=True,exist_ok=True)
paths=json.loads(Path(__file__).with_name('visual_host_paths.json').read_text())
source=subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()
assert source=='59839c7deb4d1cc860275b9e69578e299cc24d0a'
assert paths and all(Path(p).is_file() for p in paths)
flutter=Path(shutil.which('flutter.bat') or shutil.which('flutter')).resolve()
dart=flutter.parent/'cache'/'dart-sdk'/'bin'/('dart.exe' if os.name=='nt' else 'dart')
snapshot=flutter.parent/'cache'/'flutter_tools.snapshot'
assert dart.is_file() and snapshot.is_file()
base=[str(dart),str(snapshot)]
version=subprocess.check_output([*base,'--version','--machine']).decode('utf-8',errors='replace')
(out/'plan.json').write_text(json.dumps({'source':source,'platform':platform.platform(),
 'files':paths,'version':version,'exclusions':[],'name_filters':[],
 'goldens_updated':False},indent=2),encoding='utf-8')
with (out/'events.jsonl').open('w',encoding='utf-8') as log,(out/'stderr.log').open('w',encoding='utf-8') as err:
    r=subprocess.run([*base,'test','--no-pub','--concurrency','1','--timeout','90s','--reporter','json',*paths],stdout=log,stderr=err,check=False)
for p in Path('test').rglob('*.png'):
    if 'failures' in p.parts:
        target=out/'visual-diffs'/p;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
changed=subprocess.check_output(['git','diff','--name-only']).decode().splitlines()
(out/'exit.json').write_text(json.dumps({'exit_code':r.returncode,'changed_tracked_files':changed}),encoding='utf-8')
assert not changed,'The diagnostic unexpectedly altered a tracked file'
sys.exit(r.returncode)
