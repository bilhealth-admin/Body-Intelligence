"""Derive recording APK from one existing signed RC; never recompile the app."""
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile
from native_capture import gh_json, require, sha256, save, validate_manifest

SOURCE='1b23d4d4bb73d467f9c3cf1425b2eb2d8cc78c2d'
RUN=39993060544
JOB=120549463993
ARTIFACT=12520662030
AAB_SHA='ca00a379ba2de164577a8b53a6c4cea6e89d74a16c9247cc2f1adc9220460149'
REPO='bilhealth-admin/Body-Intelligence'

def main():
    out=Path(os.environ['RUNNER_TEMP'])/'bil-google-signed-input';out.mkdir()
    run=gh_json(f'repos/{REPO}/actions/runs/{RUN}')
    job=gh_json(f'repos/{REPO}/actions/jobs/{JOB}')
    art=gh_json(f'repos/{REPO}/actions/artifacts/{ARTIFACT}')
    require(run['head_sha']==SOURCE and run['path']=='.github/workflows/bil_rc_mobile_test_build.yml'
            and run['event']=='workflow_dispatch' and run['status']=='completed', 'wrong_rc_producer')
    # Whole workflow was cancelled for iOS. Android completed successfully; do
    # not turn the unrelated iOS cancellation into a claimed complete CI pass.
    require(job['run_id']==RUN and job['head_sha']==SOURCE
            and job['name']=='Android APK/AAB + emulator evidence'
            and job['status']=='completed' and job['conclusion']=='success', 'android_job_not_successful')
    require(art['id']==ARTIFACT and not art['expired'] and art['workflow_run']['id']==RUN
            and art['workflow_run']['head_sha']==SOURCE
            and art['name']=='bil-rc-android-main-binaries-'+SOURCE
            and re.fullmatch('sha256:[0-9a-f]{64}',art.get('digest','')), 'wrong_artifact')
    archive=out/'rc-binaries.zip'
    with archive.open('wb') as f:
        subprocess.run(['gh','api',f'repos/{REPO}/actions/artifacts/{ARTIFACT}/zip'],stdout=f,check=True)
    require('sha256:'+sha256(archive)==art['digest'],'archive_digest_mismatch')
    aab=out/'app-release.aab'
    with zipfile.ZipFile(archive) as z:
        entries=[i for i in z.infolist() if PurePosixPath(i.filename).name=='app-release.aab']
        require(len(entries)==1 and entries[0].file_size<1500000000,'ambiguous_aab')
        with z.open(entries[0]) as src,aab.open('wb') as dst:shutil.copyfileobj(src,dst)
    require(sha256(aab)==AAB_SHA,'aab_hash_mismatch')
    expected=os.environ['EXPECTED_UPLOAD_CERT_SHA256'].replace(':','').lower()
    require(re.fullmatch('[0-9a-f]{64}',expected),'missing_certificate')
    subprocess.run(['jarsigner','-verify',str(aab)],check=True,stdout=subprocess.DEVNULL)
    cert=subprocess.check_output(['keytool','-printcert','-jarfile',str(aab)],text=True)
    matches=re.findall(r'SHA256:\s*([0-9A-Fa-f:]{64,95})',cert)
    require(matches and all(x.replace(':','').lower()==expected for x in matches),'aab_certificate_mismatch')
    jar=out/'bundletool.jar'
    urllib.request.urlretrieve('https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar',jar)
    require(sha256(jar)=='a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29','bundletool_digest_mismatch')
    # Signing material exists only in the isolated hosted runner, outside artifacts.
    with tempfile.TemporaryDirectory(prefix='bil-recording-signing-') as temp:
        private=Path(temp);os.chmod(private,0o700)
        for name,data in [('upload.jks',base64.b64decode(os.environ['KEYSTORE_BASE64'],validate=True)),
                          ('store.pass',os.environ['STORE_PASSWORD'].encode()),
                          ('key.pass',os.environ['KEY_PASSWORD'].encode())]:
            p=private/name;p.write_bytes(data);os.chmod(p,0o600)
        apks=out/'derived.apks'
        subprocess.run(['java','-jar',str(jar),'build-apks','--bundle='+str(aab),'--output='+str(apks),
                        '--mode=universal','--ks='+str(private/'upload.jks'),
                        '--ks-key-alias='+os.environ['KEY_ALIAS'],
                        '--ks-pass=file:'+str(private/'store.pass'),'--key-pass=file:'+str(private/'key.pass')],check=True)
    apk=out/'BIL-Android33-derived-universal.apk'
    with zipfile.ZipFile(apks) as z, z.open('universal.apk') as src,apk.open('wb') as dst:shutil.copyfileobj(src,dst)
    sdk=Path(os.environ['ANDROID_HOME'])
    signer=sorted(sdk.glob('build-tools/*/apksigner'))[-1]
    signature=subprocess.check_output([str(signer),'verify','--verbose','--print-certs',str(apk)],text=True)
    certs=re.findall(r'^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F:]+)$',signature,re.M)
    require(len(certs)==1 and certs[0].replace(':','').lower()==expected,'apk_certificate_mismatch')
    xml=subprocess.check_output([str(sdk/'cmdline-tools/latest/bin/apkanalyzer'),'manifest','print',str(apk)],text=True)
    validate_manifest(xml)
    save(out/'BIL-android-recording-apk-receipt.json',{
        'status':'VERIFIED_DERIVED_SIGNED_QA_APK','source_sha':SOURCE,'build':33,
        'package':'com.bilhealth.bodyintelligencelog','aab_sha256':AAB_SHA,'apk_sha256':sha256(apk),
        'certificate_sha256':expected,'installation_source':'not_installed','app_recompiled':False,
        'play_upload_performed':False,'producer_scope':'signed RC; Android job passed; whole workflow cancelled on iOS',
        'scope':'Actual signed RC, sideloaded. Ads disabled in this RC. Not Play delivery, final production certification, Play Billing or Integrity recognition proof.'})
    save(out/'producer-identity.json',{'source_sha':SOURCE,'run_id':RUN,'job_id':JOB,'artifact_id':ARTIFACT,
        'archive_digest':art['digest'],'aab_sha256':AAB_SHA,'app_recompiled':False,
        'android_job_conclusion':'success','whole_run_conclusion':run['conclusion'],'ads_enabled':False,
        'final_production_certification':False,'play_delivery_proven':False})
    print('EXISTING_SIGNED_RC_DERIVED_FOR_NATIVE_RECORDING; NO_APP_REBUILD; NOT_PLAY_DELIVERED')

if __name__=='__main__':main()
