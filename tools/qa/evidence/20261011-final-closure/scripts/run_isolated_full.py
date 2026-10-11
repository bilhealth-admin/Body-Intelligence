from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import ctypes,json,runpy,subprocess,shutil,time,threading,datetime
root=Path.cwd();out=root/'build/qa-final-closure';g=json.loads((out/'gates.json').read_text(encoding='utf-8'))
ns=runpy.run_path('tools/qa/bil_codex_test_ladder.py',run_name='full_input_audit_only')
head=ns['git']('rev-parse','HEAD').stdout.decode().strip()
assert head==g['tested_head'] and ns['fingerprint'](head)==g['fingerprint_after']==g['fingerprint_before']
assert all(g['stages'][s]['passed'] for s in ['source','arabic','p0','focused','broad'])
workers=json.loads((out/'workers.json').read_text(encoding='utf-8'));assert len(workers)==8
class Memory(ctypes.Structure):
    _fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(s,ctypes.c_ulonglong) for s in ['total_phys','avail_phys','total_page','avail_page','total_virtual','avail_virtual','avail_extended']]
def memory():
    m=Memory();m.length=ctypes.sizeof(m);assert ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m));return {'total_bytes':m.total_phys,'available_bytes':m.avail_phys,'load_percent':m.load}
initial=memory();assert initial['available_bytes']>4.5*1024**3,('Insufficient free RAM for two workers',initial)
state={'head':head,'fingerprint':g['fingerprint_after'],'max_simultaneous_shards':2,'test_concurrency_per_shard':1,'initial_memory':initial,'shards':{},'passed':False}
lock=threading.Lock();active=set();stop=threading.Event();pause_queue=threading.Event();positions={}
def save(): (out/'full-results.json').write_bytes(json.dumps(state,indent=2).encode('utf-8'))
def monitor():
    with (out/'full-memory.jsonl').open('w',encoding='utf-8') as dest:
        while not stop.is_set():
            with lock:row={'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),'active':sorted(active),**memory()}
            dest.write(json.dumps(row)+'\n');dest.flush()
            for index in row['active']:
                file=out/f'full-shard-{index}.jsonl'
                if not file.exists():continue
                with file.open('r',encoding='utf-8',errors='replace') as source:
                    source.seek(positions.get(index,0));lines=source.readlines();positions[index]=source.tell()
                for line in lines:
                    try:event=json.loads(line)
                    except ValueError:continue
                    if event.get('type')=='error':
                        pause_queue.set()
                        with lock:
                            state.setdefault('queue_pause_failures',[]).append({'shard':index,'error_event':event});save()
            stop.wait(2)
def run(w):
    i=w['index'];work=Path(w['root']);assert w['head']==head
    if pause_queue.is_set():
        r={'status':'NOT_STARTED','reason':'Queued launch paused after a new failure; running shards complete without interruption.'}
        with lock:state['shards'][str(i)]=r;save()
        print('QUEUED PAUSED',i,flush=True);return r
    assert subprocess.run(['git','rev-parse','HEAD'],cwd=work,capture_output=True,text=True,check=True).stdout.strip()==head
    dirty=subprocess.run(['git','diff','HEAD','--name-only','--','.',':(glob,exclude)test/**/failures/*.png'],cwd=work,capture_output=True,text=True,check=True).stdout.strip();assert not dirty,dirty
    args=[shutil.which('flutter'),'test','--no-pub','--total-shards=8',f'--shard-index={i}','--concurrency=1','--timeout=3m','--reporter=json']
    log=out/f'full-shard-{i}.jsonl';log.write_bytes(b'');start=time.monotonic()
    with lock:active.add(i);state['shards'][str(i)]={'status':'RUNNING','root':str(work),'command':args,'log':str(log.relative_to(root))};save()
    print('START shard',i,flush=True)
    with log.open('a',encoding='utf-8') as dest:result=subprocess.run(args,cwd=work,stdout=dest,stderr=subprocess.STDOUT,check=False)
    events=[]
    for line in log.read_text(encoding='utf-8',errors='replace').splitlines():
        try:e=json.loads(line)
        except ValueError:continue
        if isinstance(e,dict):events.append(e)
    done=[e for e in events if e.get('type')=='testDone' and not e.get('hidden')]
    final=next((e for e in reversed(events) if e.get('type')=='done'),None)
    r={'status':'PASS' if result.returncode==0 and final and final.get('success') else 'FAIL','root':str(work),'command':args,'log':str(log.relative_to(root)),'exit_code':result.returncode,'seconds':round(time.monotonic()-start,1),'PASS':sum(e['result']=='success' and not e.get('skipped') for e in done),'FAIL':sum(e['result'] in ('error','failure') and not e.get('skipped') for e in done),'SKIP':sum(bool(e.get('skipped')) for e in done),'suites_loaded':sum(e.get('type')=='suite' for e in events),'done_event':final}
    with lock:active.remove(i);state['shards'][str(i)]=r;save()
    print('DONE shard',i,r['status'],r['PASS'],r['FAIL'],r['SKIP'],flush=True)
    return r
save();thread=threading.Thread(target=monitor,daemon=True);thread.start()
try:
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures=[pool.submit(run,w) for w in workers]
        for future in as_completed(futures):future.result()
finally:stop.set();thread.join()
state['passed']=all(r['status']=='PASS' and r['suites_loaded']>0 and r['PASS']>0 for r in state['shards'].values()) and len(state['shards'])==8
state['head_after']=ns['git']('rev-parse','HEAD').stdout.decode().strip();assert state['head_after']==head
state['fingerprint_after']=ns['fingerprint'](head);assert state['fingerprint_after']==state['fingerprint']
save();print('FULL COMPLETE',state['passed'],flush=True)
