from pathlib import Path
import subprocess,json,shutil,time
root=Path.cwd();head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip()
workers=[]
for i in range(8):
    work=Path(f'G:/BIL_Project/worktrees/bil-qa-final-shard{i}-20261011')
    log=root/'build/qa-final-closure'/f'shard-{i}-setup.log'
    with log.open('w',encoding='utf-8') as dest:
        if not work.exists():subprocess.run(['git','-c','core.hooksPath=NUL','worktree','add','--detach',str(work),head],stdout=dest,stderr=subprocess.STDOUT,check=True)
        assert subprocess.run(['git','rev-parse','HEAD'],cwd=work,capture_output=True,text=True,check=True).stdout.strip()==head
        subprocess.run([shutil.which('flutter'),'pub','get','--offline'],cwd=work,stdout=dest,stderr=subprocess.STDOUT,check=True)
    workers.append({'index':i,'root':str(work),'head':head,'setup_log':str(log.relative_to(root))})
    (root/'build/qa-final-closure/workers.json').write_bytes(json.dumps(workers,indent=2).encode('utf-8'))
    print('Prepared isolated worker',i,head[:8],flush=True)
