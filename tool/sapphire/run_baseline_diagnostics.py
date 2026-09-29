"""Diagnose previously omitted files against untouched source; preserve failure."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

out=Path('/tmp/sapphire-baseline');out.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('portable',Path('tool/release/run_portable_release_tests.py'))
portable=importlib.util.module_from_spec(spec);spec.loader.exec_module(portable)
policy=portable.load_code_only_policy()
requested=set(portable.EXCLUDED_TESTS)|set(policy.NOT_RUN)|set(policy.MIXED_NAMES)|{
 'test/connected_health/apple_health_permission_flow_test.dart',
 'test/features/community/community_review_regression_test.dart',
 'test/features/community/community_social_v2_ui_test.dart'}
paths=sorted(p for p in requested if Path(p).is_file())
source=subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()
assert source=='59839c7deb4d1cc860275b9e69578e299cc24d0a'
(out/'plan.json').write_text(json.dumps({'source':source,'files':paths,'name_filters':[],
 'purpose':'Independent baseline diagnostic; not candidate acceptance',
 'file_sha256':{p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths}},indent=2)+'\n')
with (out/'events.jsonl').open('w') as log,(out/'stderr.log').open('w') as err:
    r=subprocess.run(['flutter','test','--no-pub','--concurrency','1','--timeout','90s','--reporter','json',*paths],stdout=log,stderr=err,check=False)
for image in Path('test').rglob('*.png'):
    if 'failures' in image.parts:
        target=out/'visual-diffs'/image;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(image,target)
(out/'exit.json').write_text(json.dumps({'source':source,'exit_code':r.returncode})+'\n')
sys.exit(r.returncode)
