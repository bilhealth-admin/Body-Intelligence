from pathlib import Path
import runpy,json,subprocess,copy
ns=runpy.run_path('tools/qa/bil_codex_test_ladder.py',run_name='fixture_revalidation')
out=Path('build/qa-final-closure');old=json.loads((out/'gates-c2844272.json').read_text())
head=ns['git']('rev-parse','HEAD').stdout.decode().strip()
changed=ns['git']('diff','--name-only',old['tested_head'],head,'--','.').stdout.decode().splitlines()
assert changed==['test/features/nutrition/vision_v2_test_fixture.dart','test/localization/reference_delta_copy_test.dart'],changed
fixture='test/features/nutrition/vision_v2_test_fixture.dart'
parents=sorted(str(p).replace('\\','/') for p in Path('test').rglob('*.dart') if p.name!='vision_v2_test_fixture.dart' and 'vision_v2_test_fixture.dart' in p.read_text(encoding='utf-8'))
assert parents==sorted(['test/features/nutrition/'+p for p in ['meal_vision_final_portion_test.dart','meal_vision_premium_visual_contract_test.dart','meal_vision_reference_capture_test.dart','meal_vision_v2_interaction_test.dart','meal_vision_v2_matrix_test.dart']]),parents
s={'tested_head':head,'fingerprint_before':ns['fingerprint'](head),'flutter':'3.44.6','stages':{},'full':'NOT_STARTED','revalidation':{'from_head':old['tested_head'],'changed_inputs':changed,'fixture_importers':parents,'additional_full_discovery_narrow_test':'test/localization/reference_delta_copy_test.dart','rerun_jobs':['source','arabic-vision-v2','p0-vision-quantity-basis'],'unchanged_groups':'Execution evidence retained only for groups whose test inputs and application/assets/dependencies are unchanged. Full is rerun on the final HEAD.'}}
original=ns['run_command']
def command(name,args):
 if args[:2]==['flutter','test']:args=[*args,'--reporter=json','--concurrency=1']
 return original(name,args)
ns['run_stage'].__globals__['run_command']=command
for stage in ['source','arabic','p0','focused','broad']:
 previous=copy.deepcopy(old['stages'][stage])
 for name in ['arabic-vision-v2','p0-vision-quantity-basis']:previous.get('jobs',{}).pop(name,None)
 print('REVALIDATE',stage,flush=True)
 r=ns['run_stage'](stage,1,previous)
 for name,job in r.get('jobs',{}).items():
  if name in previous.get('jobs',{}):job['retained_execution_head']=old['tested_head'];job['revalidated_unchanged_inputs_on_head']=head
 s['stages'][stage]=r;s['fingerprint_after']=ns['fingerprint'](head)
 (out/'gates.json').write_bytes(json.dumps(s,indent=2).encode())
 assert s['fingerprint_after']==s['fingerprint_before']
 assert r['passed'],stage
print('Prior gates revalidated; two affected test groups rerun, unchanged groups retained explicitly',flush=True)
