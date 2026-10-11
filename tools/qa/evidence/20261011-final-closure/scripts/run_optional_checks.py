from pathlib import Path
import subprocess,shutil,json,time
root=Path.cwd();out=root/'build/qa-final-closure';state=json.loads((out/'full-results.json').read_text(encoding='utf-8'))
assert sum(r['status']=='RUNNING' for r in state['shards'].values())<=1
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip();assert head==state['head']
jobs=[('live-workout-stream-opt-in',['test/features/wellness/wellness_video_stream_live_test.dart','--dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true']),('windows-symlink-security-forced-case',['test/launch_readiness/deferred_ios_google_mobile_ads_plugin_test.dart','--plain-name','symlinked override parent is rejected','--run-skipped'])]
results=[]
for label,extra in jobs:
 args=[shutil.which('flutter'),'test','--no-pub','--concurrency=1','--reporter=json',*extra];log=out/(label+'.jsonl');start=time.monotonic()
 with log.open('w',encoding='utf-8') as f:r=subprocess.run(args,cwd=root,stdout=f,stderr=subprocess.STDOUT)
 item={'name':label,'tested_head':head,'command':args,'exit_code':r.returncode,'seconds':round(time.monotonic()-start,1),'log':str(log.relative_to(root))};results.append(item)
 (out/'optional-check-results.json').write_bytes(json.dumps(results,indent=2).encode());print(label,r.returncode,flush=True)
