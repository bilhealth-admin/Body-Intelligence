"""Owner-approved internal-only use of prior byte-identical application evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
BRANCH='codex/bil-release-ios38-android33-20261022'
BASE='1b23d4d4bb73d467f9c3cf1425b2eb2d8cc78c2d'
REVIEWED='6a0ef55bdb11885937093332b0c455cc42f5d6c4'
PROTECTED='31554b3e078667a38bd3c53aa105f5f1d2a4dc96'
PRIOR_RUN=39992878548
MODE='owner_authorized_internal_prior_app_evidence'
AUTH='OWNER_APPROVED_INTERNAL_ONLY_20261023'
REPO='bilhealth-admin/Body-Intelligence'
RUNTIME=('lib','ios','android','assets','shaders','artifacts/workout_media',
         'test','integration_test','test_driver','pubspec.yaml','pubspec.lock',
         'analysis_options.yaml','l10n.yaml','supabase/functions')

def validate_identity(expected, head, ref, dirty, auth, changes):
    if (expected!=head or len(head)!=40 or any(c not in '0123456789abcdef' for c in head)
            or ref!=BRANCH or dirty or auth!=AUTH or changes):
        raise ValueError('Internal source identity, explicit authorization or application parity failed')

def validate_prior(run,jobs):
    if (run.get('id')!=PRIOR_RUN or run.get('head_sha')!=BASE
            or run.get('head_branch')!=BRANCH or run.get('workflow_id')!=386117761
            or run.get('event')!='workflow_dispatch' or run.get('status')!='completed'
            or run.get('conclusion')!='success'):
        raise ValueError('Prior application evidence identity or success failed')
    required={'Full analysis then one unsharded root suite','Supplemental source and dependency audits'}
    if (not jobs or not required.issubset({j.get('name') for j in jobs})
            or any(j.get('status')!='completed' or j.get('conclusion')!='success' for j in jobs)):
        raise ValueError('Prior application evidence jobs incomplete or failed')

def validate_helpers(changes, read_bytes):
    # Only this reviewed simulator cleanup correction differs from 6a0ef55b.
    # No production signing, native assertions or exit-status gate is waived.
    allowed = {'.github/scripts/bil_ios37_native_integration.sh': '68625566fd2fc38280ed3daec9851ec4d2539965a2a85d9a8d91cfddc07bc314'}
    if any(path not in allowed or hashlib.sha256(read_bytes(path)).hexdigest()!=allowed[path]
           for path in changes):
        raise ValueError('Unreviewed native or build helper changed')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-head',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    def git(*parts):
        return subprocess.check_output(['git',*parts],cwd=ROOT,text=True).strip()
    def api(path):
        return json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/{path}'],cwd=ROOT,text=True))
    head=git('rev-parse','HEAD')
    changes=git('diff','--name-only',BASE,head,'--',*RUNTIME).splitlines()
    validate_identity(args.expected_head,head,os.environ.get('GITHUB_REF_NAME'),
                      git('status','--porcelain'),os.environ.get('BIL_INTERNAL_TESTFLIGHT_AUTHORIZATION'),changes)
    if os.environ.get('GITHUB_SHA')!=head or os.environ.get('BIL_VALIDATION_MODE')!=MODE:
        raise ValueError('Dispatch source or validation mode differs')
    for base in (BASE,REVIEWED,PROTECTED):
        subprocess.run(['git','merge-base','--is-ancestor',base,head],cwd=ROOT,check=True)
    if api('git/ref/heads/'+BRANCH)['object']['sha']!=head:
        raise ValueError('Published candidate source differs')
    if api('git/ref/heads/integration/bil-qa-media-policy-20261011')['object']['sha']!=PROTECTED:
        raise ValueError('Protected branch moved')
    # Build helpers and existing native gate must retain the reviewed bytes.
    helper_changes=git('diff','--name-only',REVIEWED,head,'--','.github/scripts','tool/release','tool/apple_store_connect').splitlines()
    validate_helpers(helper_changes,lambda path:(ROOT/path).read_bytes())
    migration=git('diff','--name-only',REVIEWED,head,'--','supabase/migrations')
    if migration:
        raise ValueError('Migration source changed after reviewed deployment')
    run=api('actions/runs/'+str(PRIOR_RUN))
    jobs=api('actions/runs/'+str(PRIOR_RUN)+'/jobs?per_page=100')['jobs']
    if len(jobs)>=100:
        raise ValueError('Ambiguous prior job pagination')
    validate_prior(run,jobs)
    result={'status':'OWNER_AUTHORIZED_INTERNAL_TESTFLIGHT_ONLY','validation_mode':MODE,
        'source_sha':head,'prior_application_source_sha':BASE,'prior_full_suite_run':PRIOR_RUN,
        'application_and_native_test_bytes_unchanged':True,'protected_sha':PROTECTED,
        'exact_source_full_ci_repeated':False,'source_manifest_accepted':False,
        'known_unresolved_qa_runs':[40012542464,40012589309],
        'native_crypto_gate_still_required':False,
        'native_crypto_runtime_status':'NOT_RERUN_OWNER_APPROVED_INTERNAL_PRIOR_EVIDENCE',
        'signature_and_artifact_gates_still_required':True,
        'physical_device_verified':False,'public_release_approved':False,
        'owner_approval':'Explicit approval on 2026-10-23 for prior application evidence; renewed on 2026-10-24 to skip repeated simulator runtime tests and build/upload TestFlight immediately. No new runtime PASS claimed.'}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_bytes((json.dumps(result,indent=2)+'\n').encode())
    print(json.dumps(result))

if __name__=='__main__':main()
