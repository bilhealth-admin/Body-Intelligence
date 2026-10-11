from pathlib import Path
import json
out=Path('build/qa-final-closure');state=json.loads((out/'full-results.json').read_text(encoding='utf-8'))
for key,r in sorted(state['shards'].items()):
 if r['status']!='RUNNING':print('shard',key,r['status'],r.get('PASS'),r.get('FAIL'),r.get('SKIP'));continue
 c={'PASS':0,'FAIL':0,'SKIP':0};suites=0;errors=[];tests={}
 for line in (out/f'full-shard-{key}.jsonl').read_text(encoding='utf-8',errors='replace').splitlines():
  try:e=json.loads(line)
  except ValueError:continue
  suites+=e.get('type')=='suite'
  if e.get('type')=='testStart':tests[e['test']['id']]=e['test']['name']
  if e.get('type')=='error':errors.append(e)
  if e.get('type')=='testDone' and not e.get('hidden'):c['SKIP' if e.get('skipped') else 'PASS' if e['result']=='success' else 'FAIL']+=1
 print('shard',key,'RUNNING','loaded',suites,c)
 if errors:print(json.dumps([{'test':tests.get(e['testID']), 'error':e['error'][:800]} for e in errors],ensure_ascii=True))
print('Memory sample', (out/'full-memory.jsonl').read_text(encoding='utf-8').splitlines()[-1])
