#!/usr/bin/env python3
"""Run all test/ files once; performance runs separately in the prerequisite.
No path exclusion or name filters. Preserve failures and exact visual diffs.
Native integration_test remains separate device acceptance, never counted here.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

out=Path('/tmp/sapphire-shard');out.mkdir(parents=True,exist_ok=True)
all_files=sorted(p.as_posix() for p in Path('test').rglob('*_test.dart'))
performance='test/performance_budget_test.dart'
assert performance in all_files
remaining=[p for p in all_files if p!=performance]
parts=[remaining[i::8] for i in range(8)]
assert sorted(p for group in parts for p in group)==remaining
assert len(set(p for group in parts for p in group))==len(remaining)
shard=int(os.environ['SHARD']);assigned=parts[shard]
source=subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()
plan={'source':source,'all_files':all_files,'shard':shard,'assigned':assigned,
      'prerequisite_files':[performance],'excluded_files':[],'name_filters':[]}
(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
command=['flutter','test','--no-pub','--concurrency','1','--timeout','90s','--reporter','json',*assigned]
with (out/'events.jsonl').open('w') as log,(out/'stderr.log').open('w') as errors:
    code=subprocess.run(command,stdout=log,stderr=errors,check=False).returncode
for image in Path('test').rglob('*.png'):
    if 'failures' in image.parts:
        target=out/'visual-diffs'/image
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(image,target)
starts={};completed=[];errors=[];suites={}
for line in (out/'events.jsonl').read_text().splitlines():
    try:e=json.loads(line)
    except json.JSONDecodeError:continue
    if e.get('type')=='suite':suites[e['suite']['id']]=e['suite']
    elif e.get('type')=='testStart':starts[e['test']['id']]=e['test']
    elif e.get('type')=='testDone':
        test=starts.get(e['testID'],{})
        completed.append({'id':e['testID'],'name':test.get('name'),
            'suiteID':test.get('suiteID'),'hidden':e.get('hidden',False),
            'skipped':e.get('skipped',False),'result':e.get('result')})
    elif e.get('type')=='error':errors.append(e)
summary={'source':source,'exit_code':code,'files':len(assigned),'tests':completed,'errors':errors,'suites':suites}
(out/'results.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
counts={status:sum(not t['hidden'] and not t['skipped'] and t['result']==status for t in completed)
        for status in ['success','failure','error']}
counts['skipped']=sum(not t['hidden'] and t['skipped'] for t in completed)
print(json.dumps({'shard':shard,'source':source,'files':len(assigned),'counts':counts,'exit_code':code}))
sys.exit(code)
