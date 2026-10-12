"""Explicit real SQLite/PG/AES cycle, never selected by root Flutter tests."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('focused_runner', ROOT/'tools/qa/bil_stage1_closure_runner.py')
focused = importlib.util.module_from_spec(spec)
spec.loader.exec_module(focused)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--psql', required=True)
    parser.add_argument('--pwsh', required=True)
    parser.add_argument('--flutter', required=True)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    if not args.label.replace('-', '').isalnum(): parser.error('plain label required')
    out = ROOT/'build/cloud-restore-v2'/args.label
    out.mkdir(parents=True, exist_ok=False)
    config = out/'server.json'
    inputs = focused.source_inputs()
    record = {'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'started':time.time(),'source_inputs':inputs,'source_fingerprint':focused.fingerprint(inputs)}
    with (out/'server.log').open('wb') as log:
        bridge = subprocess.Popen(['python','-X','utf8','tools/qa/bil_cloud_restore_v2_server.py',
            '--psql',args.psql,'--http-port','0','--config',str(config)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        try:
            for _ in range(100):
                if config.exists(): break
                if bridge.poll() is not None: raise RuntimeError('isolated bridge failed; inspect server.log')
                time.sleep(0.1)
            server = json.loads(config.read_text(encoding='utf-8'))
            environment = os.environ.copy()
            environment['BIL_LOCAL_RESTORE_CONFIG'] = str(config)
            environment['BIL_TEST_PWSH'] = args.pwsh
            environment['BIL_CLOSURE_CAPTURE_STAGE'] = args.label
            flutter_bin = Path(args.flutter).resolve().parent
            command = [str(flutter_bin/'cache/dart-sdk/bin/dart.exe'),
                       str(flutter_bin/'cache/flutter_tools.snapshot'),'test','--no-pub','--concurrency=1',
                       '--timeout=5m','--reporter=json','tools/qa/flutter/cloud_restore_postgres_cycle_test.dart']
            record['command'] = command
            with (out/'flutter.log').open('wb') as result:
                process = subprocess.Popen(command,cwd=ROOT,env=environment,stdout=result,stderr=subprocess.STDOUT)
                record['pid'] = process.pid
                (out/'result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
                try: record['exit_code'] = process.wait(timeout=600)
                except subprocess.TimeoutExpired:
                    subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True)
                    record['exit_code'] = 124
                    record['wall_timeout'] = True
            outcomes, errors, started, done = [], [], {}, set()
            for line in (out/'flutter.log').read_text(encoding='utf-8',errors='replace').splitlines():
                try: event=json.loads(line)
                except ValueError: continue
                if event.get('type')=='testDone' and not event.get('hidden'):
                    outcomes.append('skip' if event.get('skipped') else event['result'])
                if event.get('type')=='testStart': started[event['test']['id']]=event['test']['name']
                if event.get('type')=='testDone': done.add(event['testID'])
                if event.get('type')=='error': errors.append(event)
            record['counts']={x:outcomes.count(x) for x in ['success','failure','error','skip']}
            record['errors']=errors
            record['incomplete_tests']=[name for key,name in started.items() if key not in done]
            if not outcomes and record['exit_code']==0: record['exit_code']=79
        finally:
            if config.exists():
                request=urllib.request.Request(json.loads(config.read_text())['url']+'/__test__/shutdown',data=b'',method='POST')
                try:
                    with urllib.request.urlopen(request,timeout=10): pass
                except OSError: pass
            try: bridge.wait(timeout=15)
            except subprocess.TimeoutExpired: bridge.terminate();bridge.wait(timeout=5)
    record['finished']=time.time()
    record['end_fingerprint']=focused.fingerprint()
    record['stable_source']=record['end_fingerprint']==record['source_fingerprint']
    (out/'result.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:record[k] for k in ['exit_code','counts','stable_source']},ensure_ascii=False))
    return record['exit_code']

if __name__=='__main__': raise SystemExit(main())
