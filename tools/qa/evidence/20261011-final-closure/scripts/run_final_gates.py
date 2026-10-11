from pathlib import Path
import runpy,json,hashlib
ns=runpy.run_path('tools/qa/bil_codex_test_ladder.py',run_name='final_gates_only')
out=Path('build/qa-final-closure')
head=ns['git']('rev-parse','HEAD').stdout.decode().strip()
s={'tested_head':head,'fingerprint_before':ns['fingerprint'](head),'flutter':'3.44.6','stages':{},'full':'NOT_STARTED'}
original=ns['run_command']
def command(name,args):
    if args[:2]==['flutter','test']:args=[*args,'--reporter=json','--concurrency=1']
    return original(name,args)
ns['run_stage'].__globals__['run_command']=command
for stage in ['source','arabic','p0','focused','broad']:
    print('FINAL GATE',stage,flush=True)
    r=ns['run_stage'](stage,1)
    s['stages'][stage]=r
    s['fingerprint_after']=ns['fingerprint'](head)
    (out/'gates.json').write_bytes(json.dumps(s,indent=2).encode('utf-8'))
    if s['fingerprint_after']!=s['fingerprint_before']:raise SystemExit('Inputs changed during validation')
    if not r['passed']:raise SystemExit('RED '+stage+'; repair narrowly before resuming')
print('ALL PRIOR GATES GREEN; Full not yet started',flush=True)
