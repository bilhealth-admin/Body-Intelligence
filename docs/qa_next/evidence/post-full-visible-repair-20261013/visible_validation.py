import argparse, importlib.util, json, os, re, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('owner_run', ROOT / 'tools/qa/bil_owner_full_test_runner.py')
owner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(owner)
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
parser = argparse.ArgumentParser()
parser.add_argument('plan')
args = parser.parse_args()
plan_path = Path(args.plan).resolve()
plan = json.loads(plan_path.read_text(encoding='utf-8'))
if os.name == 'nt':
    import ctypes
    from ctypes import wintypes
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    user = ctypes.WinDLL('user32', use_last_error=True)
    kernel.GetConsoleWindow.restype = wintypes.HWND
    user.IsWindowVisible.argtypes = [wintypes.HWND]
    user.IsWindowVisible.restype = wintypes.BOOL
    window = kernel.GetConsoleWindow()
    if not window or not user.IsWindowVisible(window):
        raise RuntimeError('A visible native console is required; no validation was started.')
    print('Visible console verified: ' + str(window), flush=True)
folder = plan_path.parent / plan_path.stem
folder.mkdir(exist_ok=False)
started = owner.utc()
print('BIL VISIBLE VALIDATION — FOCUSED ONLY, NO FULL RESTART', flush=True)
print('Log folder: ' + str(folder), flush=True)
records = []
for index, job in enumerate(plan, 1):
    before = owner.inputs()
    entry = dict(job, started_utc=owner.utc(), runner_pid=os.getpid(), head=owner.git('rev-parse', 'HEAD'), branch=owner.git('branch', '--show-current'), source_fingerprint=owner.fingerprint(before), fingerprint_version=4)
    command = job['command']
    print('\n[%d/%d] %s\n%s' % (index, len(plan), job['label'], json.dumps(command, ensure_ascii=False)), flush=True)
    env = os.environ.copy()
    env.update(PYTHONIOENCODING='utf-8', NO_COLOR='1')
    env.update(job.get('environment', {}))
    clock = time.monotonic()
    ledger = owner.Ledger()
    text = []
    with (folder / (job['label'] + '.log')).open('w', encoding='utf-8') as log:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace', bufsize=1)
        entry['pid'] = child.pid
        (folder / (job['label'] + '.started.json')).write_text(json.dumps(entry, ensure_ascii=False, indent=2), encoding='utf-8')
        print('PID %d — test output follows in this visible terminal' % child.pid, flush=True)
        try:
            for line in child.stdout:
                log.write(line)
                log.flush()
                text.append(line)
                event = None
                if job['kind'] == 'flutter':
                    try: event = json.loads(line)
                    except ValueError: pass
                if isinstance(event, dict) and 'type' in event:
                    ledger.event(event)
                    if event['type'] == 'testStart':
                        test = event['test']
                        print('RUN  ' + test['name'], flush=True)
                    elif event['type'] == 'testDone' and not event.get('hidden'):
                        print('%-5s %s' % (('SKIP' if event.get('skipped') else event['result'].upper()), ledger.tests.get(event['testID'], {}).get('name', str(event['testID']))), flush=True)
                    elif event['type'] == 'error':
                        print('ERROR ' + event.get('error', '') + '\n' + event.get('stackTrace', ''), flush=True)
                    elif event['type'] == 'print':
                        print(event.get('message', ''), flush=True)
                else:
                    print(line, end='', flush=True)
            code = child.wait()
        except BaseException:
            owner.terminate_owned_process(child, lambda status: print(json.dumps(status), flush=True))
            raise
    after = owner.inputs()
    entry.update(exit_code=code, finished_utc=owner.utc(), seconds=round(time.monotonic()-clock, 2), end_fingerprint=owner.fingerprint(after), stable_source=before==after)
    entry['accepted'] = code == 0 and (entry['stable_source'] or job['kind'] == 'format-edit')
    if job['kind'] == 'flutter':
        entry.update(ledger.snapshot(), protocol_success=ledger.done, errors=ledger.errors)
        entry['accepted'] &= ledger.done is True and entry['tests_completed'] > 0 and not entry['in_progress'] and not ledger.errors and all(v==0 for k,v in entry['counts'].items() if k!='success')
    elif job['kind'] == 'deno':
        clean = re.sub(r'\x1b\[[0-9;]*m', '', ''.join(text))
        summaries = re.findall(r'(\d+) passed.*?(\d+) failed(?:.*?(\d+) ignored)?', clean)
        entry['counts'] = dict(success=sum(int(x[0]) for x in summaries), failure=sum(int(x[1]) for x in summaries), skip=sum(int(x[2] or 0) for x in summaries))
        entry['accepted'] &= entry['counts']['success'] > 0 and not entry['counts']['failure'] and not entry['counts']['skip']
    elif job['kind'] == 'python':
        matched = re.search(r'Ran (\d+) tests? in', ''.join(text))
        entry['tests_completed'] = int(matched.group(1)) if matched else 0
        entry['accepted'] &= entry['tests_completed'] > 0
    (folder / (job['label'] + '.result.json')).write_text(json.dumps(entry, ensure_ascii=False, indent=2), encoding='utf-8')
    records.append(entry)
    print('RESULT ' + json.dumps({key: entry[key] for key in ('label', 'accepted', 'exit_code', 'seconds', 'stable_source')} | ({'counts':entry['counts']} if 'counts' in entry else {}), ensure_ascii=False), flush=True)
    if not entry['accepted']:
        print('STOPPED at failure; no next test was started.', flush=True)
        break
result = dict(started_utc=started, finished_utc=owner.utc(), runner_pid=os.getpid(), jobs_requested=len(plan), jobs_completed=len(records), accepted=len(records)==len(plan) and all(r['accepted'] for r in records), records=records)
(folder/'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print('\nVISIBLE VALIDATION FINISHED: ' + str(result['accepted']) + '\n' + str(folder/'result.json'), flush=True)
sys.exit(0 if result['accepted'] else 79)
