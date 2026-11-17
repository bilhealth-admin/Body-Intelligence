"""Execute exact embedded transports and Linux shell fixtures; no emulator/SDK/API."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys,tempfile

def main():
    if sys.platform!='linux':raise RuntimeError('ACTUAL_LINUX_REQUIRED_NO_WINDOWS_BASH_PROBE')
    if any(k in os.environ for k in ('BIL_GOOGLE_REVIEWER_EMAIL','BIL_GOOGLE_REVIEWER_PASSWORD','GH_TOKEN','GITHUB_TOKEN')):
        raise RuntimeError('CREDENTIAL_FREE_PREFLIGHT_REQUIRED')
    root=Path(os.environ['GITHUB_WORKSPACE']).resolve(strict=True)
    here=Path(__file__).resolve().parent
    candidate=here/'android39_paid12_candidate.yml';tests=here/'test_external39.py'
    s=candidate.read_text(encoding='utf8')
    evidence=root/'artifacts/android39-reviewer-safe';evidence.mkdir(parents=True,exist_ok=False)
    runner_temp=Path(os.environ['RUNNER_TEMP']).resolve(strict=True)
    runtime=Path(tempfile.mkdtemp(prefix='android39-offline-',dir=runner_temp))
    os.chmod(runtime,0o700)
    transport_scripts=Path(tempfile.mkdtemp(prefix='android39-transport-code-',dir=runner_temp))
    os.chmod(transport_scripts,0o700)
    env={**os.environ,'RUNNER_TEMP':str(runtime),'BIL_EXTERNAL39_RUNTIME':str(runtime),'BIL_EXTERNAL39_WORKFLOW':str(candidate),'PYTHONDONTWRITEBYTECODE':'1'}
    # Only allow exact source-authored credential-free transport/readback blocks.
    blocks=re.findall(r"          python3 - <<'(PY_[A-Z_]+)'\n(.*?)          \1\n",s,re.S)
    allowed={'PY_REVIEWER_TRANSPORT','PY_REVIEWER_ALL_BYTES','PY_PINNED_HOST_TRANSPORT','PY_PULSE_TRANSPORT','PY_PULSE_READBACK'}
    selected=[(name,body) for name,body in blocks if name in allowed]
    # Six core groups, one18file readback, one3file host group, pulse transport+readback.
    expected={'PY_REVIEWER_TRANSPORT':6,'PY_REVIEWER_ALL_BYTES':1,'PY_PINNED_HOST_TRANSPORT':1,'PY_PULSE_TRANSPORT':1,'PY_PULSE_READBACK':1}
    counts={k:sum(name==k for name,_ in selected) for k in allowed}
    if counts!=expected:raise RuntimeError('EXACT_TEN_TRANSPORT_READBACK_BLOCKS_REQUIRED:'+json.dumps(counts))
    for index,(name,body) in enumerate(selected):
        code='\n'.join(line[10:] if line.startswith('          ') else line for line in body.splitlines())+'\n'
        script=transport_scripts/('offline-transport-'+str(index)+'.py')
        script.write_text(code,encoding='utf8')
        subprocess.run([sys.executable,'-B',str(script)],env=env,check=True,cwd=root)
    files=[p for p in runtime.iterdir() if p.is_file()]
    if len(files)!=22:raise RuntimeError('EXACT22_RUNTIME_REQUIRED')
    wrapper=runtime/'android39-reviewer-entrypoint.sh';os.chmod(wrapper,0o700)
    before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    python=subprocess.run([sys.executable,'-B',str(tests)],env=env,cwd=root,capture_output=True,text=True,timeout=60)
    (evidence/'PYTHON_GUARD_TRANSPORT.stdout.txt').write_text(python.stdout,encoding='utf8')
    (evidence/'PYTHON_GUARD_TRANSPORT.stderr.txt').write_text(python.stderr,encoding='utf8')
    actual_python=json.loads(python.stdout)
    if python.returncode or actual_python!={'tests_run':23,'failures':0,'errors':0,'skipped':0,'expected_failures':0,'unexpected_successes':0,'was_successful':True}:
        raise RuntimeError('ACTUAL23_GUARD_TRANSPORT_REQUIRED')
    # Real Bash/parser execution with fakeadb/python, synthetic NOT_AN_APK only.
    shell=subprocess.run(['node',str(runtime/'reviewer-shell-contract.cjs')],env=env,cwd=root,capture_output=True,text=True,timeout=60)
    (evidence/'SHELL_PREFLIGHT.stdout.txt').write_text(shell.stdout,encoding='utf8')
    (evidence/'SHELL_PREFLIGHT.stderr.txt').write_text(shell.stderr,encoding='utf8')
    if shell.returncode:raise RuntimeError('ACTUAL_LINUX_SHELL_FIXTURE_FAILED')
    contract=json.loads((evidence/'SHELL_CONTRACT.json').read_bytes())
    expected_cases={'success':0,'driver':46,'home':52,'install':43,'prelaunch':50,'renderer':51,'focus':45,'profile':49,'query':53,'occupied':54,'malformed':54}
    actual_cases={row['case']:row['exit'] for row in contract['cases']}
    if contract['status']!='ACTUAL_LINUX_39_EIGHT_CRITICAL_PLUS_THREE_ABSENCE_CASES_PASS' or len(contract['cases'])!=11 or actual_cases!=expected_cases:
        raise RuntimeError('ACTUAL_ELEVEN_CASES_REQUIRED')
    if before!={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files}:raise RuntimeError('RUNTIME_BYTES_CHANGED')
    receipt={'status':'EXTERNAL_ANDROID39_LINUX11_AND_PYTHON23_ACTUAL_PASS','actual_shell_cases':11,'actual_python_tests':23,
       'source_parent':'c5b610276a3bbee8a0e446300296920b5cdc9570','candidate_sha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),
       'test_sha256':hashlib.sha256(tests.read_bytes()).hexdigest(),'runtime22':before,'credentials_present_or_used':False,
       'sdk_emulator_or_real_apk_used':False,'network_requests_from_fixture':False,'actual_reviewer_functional_proven':False}
    (evidence/'OFFLINE_PREFLIGHT_ACCEPTANCE.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8')
    print(receipt['status'])

if __name__=='__main__':main()
