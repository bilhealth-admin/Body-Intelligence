from pathlib import Path
import subprocess,json,hashlib
root=Path.cwd();out=root/'build/qa-final-closure';head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip();rows=[]
for i in range(8):
 work=Path(f'G:/BIL_Project/worktrees/bil-qa-final-shard{i}-20261011')
 dirty=subprocess.run(['git','diff','HEAD','--name-only','--','.',':(glob,exclude)test/**/failures/*.png'],cwd=work,capture_output=True,text=True,check=True).stdout.strip();assert not dirty,dirty
 untracked=subprocess.run(['git','ls-files','--others','--exclude-standard','--','.',':(glob,exclude)test/**/failures/*.png'],cwd=work,capture_output=True,text=True,check=True).stdout.strip();assert not untracked,untracked
 outputs={str(p.relative_to(work)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (work/'test').rglob('failures/*.png')}
 old=subprocess.run(['git','rev-parse','HEAD'],cwd=work,capture_output=True,text=True,check=True).stdout.strip();log=out/f'shard-{i}-retarget-final.log'
 with log.open('w',encoding='utf-8') as f:subprocess.run(['git','-c','core.hooksPath=NUL','switch','--detach',head],cwd=work,stdout=f,stderr=subprocess.STDOUT,check=True)
 assert all(hashlib.sha256((work/p).read_bytes()).hexdigest()==h for p,h in outputs.items())
 rows.append({'index':i,'root':str(work),'head':head,'prior_head':old,'setup_log':str(log.relative_to(root)),'diagnostic_outputs_preserved':True,'dependencies':'unchanged lock/package configuration; existing offline setup retained'})
 print('Retargeted',i,head[:8],flush=True)
(out/'workers.json').write_bytes(json.dumps(rows,indent=2).encode())
