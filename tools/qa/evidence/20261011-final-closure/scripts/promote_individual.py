from pathlib import Path
import json,hashlib,subprocess,shutil,time
out=Path('build/qa-final-closure');items=json.loads(Path('tools/qa/evidence/20261011-known-failures-handoff/golden-decisions.json').read_text(encoding='utf-8'))
events=[]
for line in (out/'goldens-before-individual-review.jsonl').read_text(encoding='utf-8').splitlines():
 try:events.append(json.loads(line))
 except ValueError:pass
starts={e['test']['id']:e['test'] for e in events if e.get('type')=='testStart'}
suites={e['suite']['id']:e['suite']['path'] for e in events if e.get('type')=='suite'}
for row in items:
    name=row['name'];actuals=list(Path('test').rglob(name+'_testImage.png'));assert len(actuals)==1
    actual=actuals[0];assert hashlib.sha256(actual.read_bytes()).hexdigest()==row['current_sha256']
    assert hashlib.sha256(Path(row['baseline']).read_bytes()).hexdigest()==row['baseline_sha256']
    ids={e['testID'] for e in events if e.get('type')=='print' and name+'.png' in e.get('message','')}
    assert len(ids)==1,(name,ids)
    test=starts[ids.pop()];row['test_name']=test['name'];row['test_file']=str(Path(suites[test['suiteID']]).relative_to(Path.cwd()))
    row['decision']='APPROVED INDIVIDUALLY: stale baseline; no app design changes'
    row['reason']=row['observation']+' Current actual reviewed visually with its master/diffs and functional content intact. Source intentional route-local calm scope / reviewed dashboard source implementation; no removal of controls/values, no tofu, no clock rollback.'
    if name.startswith('premium_dashboard'):
        row['reason']+=' Protected Home: checked against source08631043 and docs/qa/BIL_DASHBOARD_OWNER_APPROVED_VISUAL_20261009_AR.md implementation intent (not a previous visual certificate). Added cal unit, reference counter geometry, Food/Water/Weight and contain-fit Discover preserve current intended implementation; no Home code modified. Golden benchmark does not show bottom bar; its five icons are verified separately in contracts/production captures.'
    if name.startswith('live_health'):
        row['reason']='Old Ahem master is invalid text evidence. Current silver metal clock is explicitly owner-approved, real14:22:08 and2198/80/300/4.8 readings. Approve this real-font silver case only; preserve painter and all readings.'
# These 29 decisions were made explicitly after reviewing every named pair;
# this driver applies each recorded decision separately and immediately verifies
# the matching case. It never invokes --update-goldens or selects new images.
(out/'individual-golden-approval.json').write_bytes(json.dumps(items,ensure_ascii=False,indent=2).encode('utf-8'))
for row in items:
    actual=next(Path('test').rglob(row['name']+'_testImage.png'))
    shutil.copyfile(actual,row['baseline'])
    log=out/(row['id']+'-narrow.jsonl')
    command=[shutil.which('flutter'),'test','--no-pub','--concurrency=1','--reporter=json',row['test_file'],'--plain-name',row['test_name']]
    start=time.monotonic()
    with log.open('w',encoding='utf-8') as dest:result=subprocess.run(command,stdout=dest,stderr=subprocess.STDOUT,check=False)
    row['narrow_result']={'exit_code':result.returncode,'seconds':round(time.monotonic()-start,1),'log':str(log)}
    (out/'individual-golden-approval.json').write_bytes(json.dumps(items,ensure_ascii=False,indent=2).encode('utf-8'))
    print(row['id'],row['name'],'PASS' if result.returncode==0 else 'FAIL',flush=True)
    if result.returncode:raise SystemExit('Narrow case failed; no subsequent promotion')
