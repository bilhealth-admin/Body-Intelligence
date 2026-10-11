from pathlib import Path
import subprocess,shutil,json,time
root=Path.cwd();out=root/'build/qa-final-closure';results=[]
case='V2 review 320_ar_light_2.0x original photo, clock, controls and overflow'
jobs=[('cold-original-helper',Path(r'G:\BIL_Project\worktrees\bil-qa-final-shard0-20261011'),['test/features/nutrition/meal_vision_v2_matrix_test.dart','--plain-name',case]),('cold-fixed-helper',root,['test/features/nutrition/meal_vision_v2_matrix_test.dart','--plain-name',case]),('fixed-matrix-file',root,['test/features/nutrition/meal_vision_v2_matrix_test.dart']),('reference-copy-file',root,['test/localization/reference_delta_copy_test.dart'])]
for label,work,sources in jobs:
 args=[shutil.which('flutter'),'test','--no-pub','--concurrency=1','--timeout=3m','--reporter=json',*sources]
 start=time.monotonic();log=out/(label+'.jsonl')
 with log.open('w',encoding='utf-8') as dest:r=subprocess.run(args,cwd=work,stdout=dest,stderr=subprocess.STDOUT)
 item={'name':label,'exit_code':r.returncode,'seconds':round(time.monotonic()-start,1),'log':str(log.relative_to(root))};results.append(item)
 (out/'new-failures-focused.json').write_bytes(json.dumps(results,indent=2).encode())
 print(label,r.returncode,flush=True)
 if label!='cold-original-helper' and r.returncode:break
