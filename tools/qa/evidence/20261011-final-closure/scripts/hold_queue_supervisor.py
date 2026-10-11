from pathlib import Path
import ctypes,json,time,subprocess,datetime
from ctypes import wintypes
out=Path('build/qa-final-closure');state=json.loads((out/'full-results.json').read_text(encoding='utf-8'))
k=ctypes.WinDLL('kernel32',use_last_error=True)
k.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD];k.OpenProcess.restype=wintypes.HANDLE
k.WaitForSingleObject.argtypes=[wintypes.HANDLE,wintypes.DWORD];k.GetExitCodeProcess.argtypes=[wintypes.HANDLE,ctypes.POINTER(wintypes.DWORD)];k.TerminateProcess.argtypes=[wintypes.HANDLE,wintypes.UINT]
query=subprocess.run(['powershell','-NoProfile','-Command',"Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'python.exe' -and $_.CommandLine -like '*run_isolated_full.py*') -or ($_.Name -eq 'cmd.exe' -and $_.CommandLine -like '*--total-shards=8*') } | Select-Object ProcessId,ParentProcessId,CommandLine | ConvertTo-Json"],capture_output=True,text=True,check=True)
procs=json.loads(query.stdout);parents=[p for p in procs if 'run_isolated_full.py' in p['CommandLine']];assert len(parents)==1
parent=parents[0];assert parent['ProcessId']==22076
children={str(i):next(p for p in procs if p['ParentProcessId']==parent['ProcessId'] and f'--shard-index={i} ' in p['CommandLine']) for i in [0,1]}
handles={i:k.OpenProcess(0x100000|0x1000,False,p['ProcessId']) for i,p in children.items()};assert all(handles.values())
ph=k.OpenProcess(1,False,parent['ProcessId']);assert ph
assert k.TerminateProcess(ph,125)
state['orchestration_handoff']={'reason':'Pause six unstarted shards after shared Vision fixture readiness failure; running test processes are not interrupted.','terminated_driver_pid':parent['ProcessId'],'running_cmd_handles_retained':children,'time':datetime.datetime.now(datetime.timezone.utc).isoformat()}
for i in range(2,8):state['shards'][str(i)]={'status':'NOT_STARTED','reason':'Queued launch paused for shared test fixture repair'}
(out/'partial-full-original-results.json').write_bytes(json.dumps(state,indent=2).encode('utf-8'))
print('Queue paused; both running Flutter test processes retained with exit-status handles',flush=True)
while handles:
 for i,h in list(handles.items()):
  if k.WaitForSingleObject(h,0)==0:
   code=wintypes.DWORD();assert k.GetExitCodeProcess(h,ctypes.byref(code))
   log=out/f'full-shard-{i}.jsonl';events=[]
   for line in log.read_text(encoding='utf-8',errors='replace').splitlines():
    try:e=json.loads(line)
    except ValueError:continue
    if isinstance(e,dict):events.append(e)
   done=[e for e in events if e.get('type')=='testDone' and not e.get('hidden')];final=next((e for e in reversed(events) if e.get('type')=='done'),None)
   state['shards'][i].update({'status':'PASS' if code.value==0 and final and final.get('success') else 'FAIL','exit_code':code.value,'PASS':sum(e['result']=='success' and not e.get('skipped') for e in done),'FAIL':sum(e['result'] in ('error','failure') and not e.get('skipped') for e in done),'SKIP':sum(bool(e.get('skipped')) for e in done),'suites_loaded':sum(e.get('type')=='suite' for e in events),'done_event':final})
   del handles[i];(out/'partial-full-original-results.json').write_bytes(json.dumps(state,indent=2).encode('utf-8'));print('Original shard completed',i,state['shards'][i]['status'],flush=True)
 row={'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),'active':sorted(map(int,handles)),'phase':'queue-paused supervisor'}
 # Separate monitor retains OS memory observations without altering any test.
 with (out/'full-supervisor-events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(row)+'\n')
 time.sleep(2)
print('Both original diagnostic shards finished; remaining six not started',flush=True)
