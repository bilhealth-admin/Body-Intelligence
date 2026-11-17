from pathlib import Path
import ast, base64, datetime, hashlib, json, os, re, subprocess, sys, zlib

assert sys.platform=='linux','ACTUAL_LINUX_REQUIRED'
assert 'BIL_GOOGLE_REVIEWER_EMAIL'not in os.environ and 'BIL_GOOGLE_REVIEWER_PASSWORD'not in os.environ,'NO_REVIEWER_CREDENTIALS_ALLOWED'
BASE=Path(__file__).resolve().parent
PINS=json.loads((BASE/'frozen-inputs.json').read_bytes())
CONTROLLER=BASE.parents[1]
ROOT=Path(os.environ['GITHUB_WORKSPACE'])/'application-source'
TEMP=Path(os.environ['RUNNER_TEMP'])
OUT=Path(os.environ['GITHUB_WORKSPACE'])/'artifacts/reviewer39-guard-preflight-safe'
OUT.mkdir(parents=True,exist_ok=True)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(root,*args):return subprocess.run(['git','-C',str(root),*args],check=True,capture_output=True,timeout=20).stdout.decode().strip()
def save(name,data):(OUT/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
C5=PINS['source_C5'];CTRL=os.environ['GITHUB_SHA']
assert git(ROOT,'rev-parse','HEAD')==C5 and git(ROOT,'rev-parse','HEAD^{tree}')==PINS['source_tree']
assert git(CONTROLLER,'rev-parse','HEAD')==CTRL
assert git(CONTROLLER,'rev-list','--parents','-n','1','HEAD').split()==[CTRL,C5]
assert set(git(CONTROLLER,'diff','--name-only',C5,CTRL).splitlines())==set(PINS['exact_child_paths'])
assert not(ROOT/PINS['candidate_native_repository_path']).exists(),'SOURCE_CHECKOUT_MUST_NOT_MASQUERADE_AS_CONTROLLER'
body=(BASE/'candidate-controller.yml').read_bytes();assert sha(body)==PINS['candidate_yaml_sha256']
assert sha(Path(__file__).read_bytes())==PINS['driver_sha256']
found={}
for match in re.finditer(r"records = json.loads\(('(?:[^'\\]|\\.)*')\)",body.decode('utf-8')):
 for r in json.loads(ast.literal_eval(match[1])):
  name=r['name'];assert name not in found and '/'not in name and '\\'not in name
  b=base64.b64decode(r['compressed_base64'],validate=True);assert sha(b)==r['compressed_sha256']
  raw=zlib.decompress(b);assert len(raw)==r['raw_bytes']<=65536 and sha(raw)==r['raw_sha256'];found[name]=raw
assert set(found)==set(PINS['runtime22'])|{'test_approved_preparation.py'}
for name,pin in PINS['runtime22'].items():assert pin=={'bytes':len(found[name]),'sha256':sha(found[name])}
assert sha(found['test_approved_preparation.py'])==PINS['corrected_test_sha256']
testdir=TEMP/'approved-demo-preflight-tests';testdir.mkdir()
workflowdir=TEMP/'_github_workflow';workflowdir.mkdir(exist_ok=True)
workflow=workflowdir/'controller-test-input.yml'
with workflow.open('xb')as f:f.write(body)
for name,raw in found.items():
 p=(testdir/name)if name=='test_approved_preparation.py'else(TEMP/name)
 with p.open('xb')as f:f.write(raw)
 p.chmod(0o600)
# Reproduce legitimate shared RUNNER_TEMP output; these bytes are never executed.
for name in ['BIL-Android39-exact-QA.apk','BIL-Android39-exact.aab','fresh-native-artifact-14311910610.zip']:
 with(TEMP/name).open('xb')as f:f.write(b'SYNTHETIC_NONEXECUTED_HOUSEKEEPING_NOT_A_NATIVE_ARTIFACT\n')
for name in ['__pycache__','BIL_UIA2']:(TEMP/name).mkdir(exist_ok=True)
before={name:sha((TEMP/name).read_bytes())for name in PINS['runtime22']}
env=dict(os.environ,BIL_APPROVED_RUNTIME=str(TEMP),BIL_APPROVED_WORKFLOW=str(workflow),GITHUB_WORKSPACE=str(ROOT),PYTHONDONTWRITEBYTECODE='1')
for key in ['GH_TOKEN','GITHUB_TOKEN']:env.pop(key,None)
p=subprocess.run([sys.executable,'-X','utf8','-B',str(testdir/'test_approved_preparation.py')],cwd=ROOT,env=env,capture_output=True,timeout=60)
(OUT/'actual_python42.stdout.log').write_bytes(p.stdout);(OUT/'actual_python42.stderr.log').write_bytes(p.stderr)
python=json.loads(p.stdout.decode('utf-8').splitlines()[-1]);assert p.returncode==0 and python=={'status':'APPROVED_PREPARATION_GUARDS_PASS','tests_run':42,'failures':0,'errors':0,'skipped':0,'expected_failures':0,'unexpected_successes':0},'EXACT_STRUCTURED42_PASS_REQUIRED'
expected_ids=[]
tree=ast.parse(found['test_approved_preparation.py'])
for klass in tree.body:
 if isinstance(klass,ast.ClassDef):
  expected_ids.extend(klass.name+'.'+x.name for x in klass.body if isinstance(x,ast.FunctionDef)and x.name.startswith('test_'))
actual_ids=[]
for line in p.stderr.decode('utf-8').splitlines():
 m=re.match(r'(test_\w+) \(__main__\.(\w+)\.',line)
 if m:actual_ids.append(m[2]+'.'+m[1])
assert len(expected_ids)==len(actual_ids)==42 and set(expected_ids)==set(actual_ids),'ALL42_ACTUAL_CASE_IDENTITIES_REQUIRED'
parser=ROOT/'artifacts/tooling/bil-android-emulator-action/lib/script-parser.js'
assert sha(parser.read_bytes())==PINS['pinned_parser_sha256']
p=subprocess.run(['node',str(TEMP/'reviewer-shell-contract.cjs')],cwd=ROOT,env=env,capture_output=True,timeout=60)
(OUT/'actual_node17.stdout.log').write_bytes(p.stdout);(OUT/'actual_node17.stderr.log').write_bytes(p.stderr)
shell_path=ROOT/'artifacts/android39-approved-prep-restore-safe/SHELL_CONTRACT.json'
shell=json.loads(shell_path.read_bytes());assert p.returncode==0 and shell['status']=='ACTUAL_LINUX_39_ORIGINAL11_PLUS_APPROVED_PREPARATION6_PASS'
assert len(shell['cases'])==len({x['case']for x in shell['cases']})==17 and shell['actual_device_or_credentials_used']is False
assert before=={name:sha((TEMP/name).read_bytes())for name in PINS['runtime22']},'EXECUTED_RUNTIME22_MUST_REMAIN_BYTE_EXACT'
assert git(ROOT,'rev-parse','HEAD')==C5
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'ACTUAL_LINUX_SHARED_RUNNER_TEMP_SOURCE_CONTROLLER_SEPARATION_42_PLUS17_PASS','controller':CTRL,'source':C5,'source_tree':PINS['source_tree'],'candidate_yaml_sha256':sha(body),'python42':python,'actual_python_case_ids':sorted(actual_ids),'Linux_Bash17':shell,'all22_posthashes':before,'actual_source_lacks_new_controller_yaml':True,'controller_direct_parent_C5':True,'native_SDK_emulator_model_cloud_account_or_reviewer_credential_actions':0,'proof_scope':'Actual Linux harness/Python/Bash assertions with synthetic stub tools; not native reviewer preparation/A12/GoogleBilling or policy reinstatement.'}
save('ACTUAL_LINUX_42_PLUS17_PREFLIGHT_RESULT.json',receipt)
print(json.dumps({'status':receipt['status'],'python_cases':42,'Linux_Bash_cases':17,'runtime22_unchanged':True,'native_or_account_actions':0}))
