from pathlib import Path
import json,hashlib,shutil,subprocess
root=Path.cwd();source=root/'build/qa-final-closure';full=json.loads((source/'full-results.json').read_text(encoding='utf-8'))
assert full['passed'] and len(full['shards'])==8 and all(r['status']=='PASS' for r in full['shards'].values())
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip();assert head==full['head_after']==full['head']
inputs=json.loads((source/'final-code-inputs.json').read_text(encoding='utf-8'));assert head==inputs['head']
assert all(hashlib.sha256((root/p).read_bytes()).hexdigest()==h for p,h in inputs['files'].items())
dest=root/'tools/qa/evidence/20261011-final-closure';assert not dest.exists();dest.mkdir(parents=True)
manifest={}
def copy_file(src,relative):
 target=dest/relative;target.parent.mkdir(parents=True,exist_ok=True);data=src.read_bytes();original=hashlib.sha256(data).hexdigest()
 if src.suffix in {'.json','.jsonl','.log','.py','.html','.md','.txt'}:data=data.replace(b'\r\n',b'\n')
 target.write_bytes(data);manifest[str(relative).replace('\\','/')]={'sha256':hashlib.sha256(data).hexdigest(),'original_sha256':original,'bytes':len(data)}
for p in source.iterdir():
 if p.is_file():copy_file(p,Path('logs' if p.suffix in {'.log','.jsonl'} else 'records' if p.suffix=='.json' else 'scripts')/p.name)
gates=json.loads((source/'gates.json').read_text(encoding='utf-8'))
for stage,r in gates['stages'].items():
 if stage=='source':
  for i,j in enumerate(r['format']):copy_file(root/j['log'],Path('logs')/f'source-format-{i+1}.log')
  copy_file(root/r['analyze']['log'],Path('logs/source-analyze.log'))
 else:
  for name,j in r['jobs'].items():copy_file(root/j['log'],Path('logs')/(name+'.jsonl'))
for p in (source/'golden-review').rglob('*'):
 if p.is_file():copy_file(p,Path('golden-review')/p.relative_to(source/'golden-review'))
photos=['functional_final_80g_nutrition.png','zoom_pending_original_decode.png','clock_11_30_430_ar_dark_1.0x.png','review_initial_320_ar_dark_2.0x.png','review_initial_430_ar_dark_1.0x.png','original_photo_zoom_430_ar_dark_1.0x.png']
for name in photos:
 p=root/'build/vision-v2-captures'/name
 if p.exists():copy_file(p,Path('vision-current')/name)
cases=[];skips=[];assignments={};rows=json.loads((source/'individual-golden-approval.json').read_text(encoding='utf-8'))
for key,r in sorted(full['shards'].items()):
 worker=Path(r['root']);events=[]
 assert subprocess.run(['git','rev-parse','HEAD'],cwd=worker,capture_output=True,text=True,check=True).stdout.strip()==head
 assert not subprocess.run(['git','diff','HEAD','--name-only','--','.',':(glob,exclude)test/**/failures/*.png'],cwd=worker,capture_output=True,text=True,check=True).stdout.strip()
 assert not subprocess.run(['git','ls-files','--others','--exclude-standard','--','.',':(glob,exclude)test/**/failures/*.png'],cwd=worker,capture_output=True,text=True,check=True).stdout.strip()
 assert all(hashlib.sha256((worker/p).read_bytes()).hexdigest()==h for p,h in inputs['files'].items()),f'Worker {key} tested input bytes drifted'
 for line in (root/r['log']).read_text(encoding='utf-8-sig',errors='replace').splitlines():
  try:e=json.loads(line)
  except ValueError:continue
  if isinstance(e,dict):events.append(e)
 suites={e['suite']['id']:e['suite']['path'] for e in events if e.get('type')=='suite'}
 starts={e['test']['id']:e['test'] for e in events if e.get('type')=='testStart'};selected=[]
 for e in events:
  if e.get('type')!='testDone' or e.get('hidden'):continue
  t=starts[e['testID']];path=suites[t['suiteID']].replace('\\','/');prefix=str(worker).replace('\\','/')+'/'
  assert path.startswith(prefix),path;path=path[len(prefix):];item={'file':path,'name':t['name'],'result':e['result'],'skip':e.get('skipped',False),'skip_reason':t['metadata'].get('skipReason')}
  selected.append(item);ident=path+':'+t['name'];assignments.setdefault(ident,set()).add(key)
  if e.get('skipped'):skips.append({'shard':key,**item})
 captured=[]
 for p in (worker/'build/vision-v2-captures').glob('*.png'):
  if p.name.startswith('TEST_FIXTURE'):continue
  relative=Path('shards')/key/'vision'/p.name;copy_file(p,relative);captured.append(str(relative).replace('\\','/'))
 approved=[{'id':x['id'],'name':x['test_name'],'gallery':x['current_gallery']} for x in rows if any(t['name']==x['test_name'] for t in selected)]
 payload={'tested_head':head,**r,'selected_cases':selected,'new_flutter_captures':captured,'approved_golden_cases':approved}
 target=dest/'shards'/key/'result.json';target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(json.dumps(payload,indent=2).encode());cases.extend(selected)
assert all(len(v)==1 for v in assignments.values()),'A test identity was assigned to multiple shards'
summary={'tested_code_head':head,'ladder_fingerprint':full['fingerprint'],'semantic_input_sha256':inputs['semantic_sha256'],'full_totals':{k:sum(r[k] for r in full['shards'].values()) for k in ['PASS','FAIL','SKIP']},'visible_case_executions':len(cases),'unique_case_identities':len(assignments),'skips':skips,'all_eight_shards_completed':True,'max_simultaneous_shards':2,'concurrency_per_shard':1}
(dest/'summary.json').write_bytes(json.dumps(summary,indent=2).encode());(dest/'artifact-hashes.json').write_bytes(json.dumps(manifest,indent=2).encode())
files=subprocess.run(['git','diff','--name-only','06c365022f20e0f0c5d6e901b19a8efb1419b81f',head],capture_output=True,text=True,check=True).stdout;(dest/'changed-code-files.txt').write_bytes(files.encode())
print(json.dumps(summary,ensure_ascii=True),flush=True)
