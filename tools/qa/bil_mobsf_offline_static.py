"""Static debug-APK audit in a pinned, network-disabled disposable MobSF."""

import argparse
import hashlib
import json
import os
import pathlib
import re
import secrets
import subprocess
import sys
import time
import urllib.parse
import urllib.request

IMAGE = 'opensecurity/mobile-security-framework-mobsf@sha256:5113fbad0727445dda01afdccafea5e107bfa8632ead8a169492f5caa8aa1b7c'
REPOSITORY = 'bilhealth-admin/Body-Intelligence'
BRANCH = 'integration/bil-qa-media-policy-20261011'
CANDIDATE_BRANCH = 'codex/bil-release-ios38-android33-20261022'
ALLOWED_BRANCHES = (BRANCH, CANDIDATE_BRANCH)
CODEQL_WORKFLOW_ID = 384948928


def validate_producer(producer, jobs, *, branch, audit_sha):
    if branch not in ALLOWED_BRANCHES:
        raise ValueError('Unauthorized audit branch')
    if producer.get('head_branch') != branch or producer.get('status') != 'completed':
        raise ValueError('Producer must be completed on the exact audit branch')
    if producer.get('workflow_id') != CODEQL_WORKFLOW_ID or producer.get('event') not in ('push', 'workflow_dispatch'):
        raise ValueError('The authorized compiler workflow must produce the APK')
    source, attempt = producer.get('head_sha'), producer.get('run_attempt')
    if not isinstance(source, str) or not re.fullmatch('[0-9a-f]{40}', source):
        raise ValueError('Invalid producer source')
    if type(attempt) is not int or attempt < 1:
        raise ValueError('Invalid producer attempt')
    if branch == CANDIDATE_BRANCH and (source != audit_sha or producer.get('conclusion') != 'success'):
        raise ValueError('Candidate APK requires a successful producer on the exact candidate SHA')
    required = {'Build Android plugin sources for CodeQL',
                'Preserve the isolated Android debug APK for static inspection'}
    for job in jobs:
        if job.get('name') != 'CodeQL (java-kotlin)':
            continue
        if branch == CANDIDATE_BRANCH and job.get('conclusion') != 'success':
            continue
        passed = {step.get('name') for step in job.get('steps', []) if step.get('conclusion') == 'success'}
        if required <= passed and 'Upload Android CodeQL APK and build evidence' in passed:
            return source, attempt, f'bil-android-codeql-apk-{source}-{attempt}'
        # Preserve the original diagnostic-only integration-branch contract.
        # Never reuse an earlier-attempt legacy artifact for a newer attempt.
        if branch == BRANCH and attempt == 1 and required <= passed and 'Upload Android API 33 native integration evidence' in passed:
            return source, attempt, f'bil-android33-native-integration-{source}'
    raise ValueError('One exact producer job must retain successful build, APK capture and upload steps')


def select_artifact(artifacts, *, name, run_id, source):
    matches = [item for item in artifacts if item.get('name') == name]
    if len(matches) != 1:
        raise ValueError('Missing or ambiguous exact-attempt APK artifact')
    artifact = matches[0]
    if artifact.get('expired') is not False or type(artifact.get('id')) is not int or artifact['id'] <= 0:
        raise ValueError('Expired or invalid APK artifact')
    if type(artifact.get('size_in_bytes')) is not int or not 0 < artifact['size_in_bytes'] <= 1024**3:
        raise ValueError('Invalid or excessive artifact size')
    identity = artifact.get('workflow_run', {})
    if str(identity.get('id')) != str(run_id) or identity.get('head_sha') != source:
        raise ValueError('APK artifact belongs to another run or source')
    return artifact


def summarize(report):
    if report.get('package_name') != 'com.bilhealth.bodyintelligencelog':
        raise ValueError('Unexpected APK package')
    if str(report.get('version_code')) != '33':
        raise ValueError('Expected the isolated debug build 33')
    manifest = report.get('manifest_analysis', {}).get('manifest_findings')
    code = report.get('code_analysis', {}).get('findings')
    permissions = report.get('permissions')
    if not isinstance(manifest, list) or not isinstance(code, dict) or not isinstance(permissions, dict):
        raise ValueError('MobSF did not deliver its required static report sections')
    # Do not publish matched strings, API keys, URLs, raw code or report logs.
    return {
        'result': 'STATIC_DEBUG_REPORT_PRESENT',
        'scope': 'Offline static debug APK only; not Dart analysis, dynamic MASVS, release AAB or store approval',
        'package_name': report['package_name'], 'version_code': report['version_code'],
        'min_sdk': report.get('min_sdk'), 'target_sdk': report.get('target_sdk'),
        'permissions': sorted(permissions),
        'manifest_findings': [{'rule': item.get('rule'), 'severity': item.get('severity')}
                              for item in manifest],
        'code_findings': [{'rule': rule, 'severity': item.get('metadata', {}).get('severity'),
                           'affected_files_count': len(item.get('files', {}))}
                          for rule, item in code.items()],
        'internet_enabled_in_scanner': False, 'source_uploaded_externally': False,
    }


def inside_container():
    key = os.environ['MOBSF_API_KEY']
    base = 'http://127.0.0.1:8000'
    for _ in range(90):
        try:
            with urllib.request.urlopen(base, timeout=2):
                break
        except OSError:
            time.sleep(2)
    else:
        raise RuntimeError('MobSF server startup timed out')

    def api(route, data, content_type='application/x-www-form-urlencoded'):
        request = urllib.request.Request(base + route, data=data,
            headers={'Authorization': key, 'Content-Type': content_type}, method='POST')
        with urllib.request.urlopen(request, timeout=1200) as response:
            return json.load(response)

    boundary = 'bil-offline-apk-' + secrets.token_hex(12)
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
            'filename="bil.apk"\r\nContent-Type: application/vnd.android.package-archive\r\n\r\n').encode()
    body += pathlib.Path('/tmp/bil.apk').read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    uploaded = api('/api/v1/upload', body, f'multipart/form-data; boundary={boundary}')
    file_hash = uploaded.get('hash', '')
    if not re.fullmatch('[0-9a-f]{32}', file_hash):
        raise RuntimeError('MobSF upload did not return a scan identity')
    api('/api/v1/scan', urllib.parse.urlencode({'hash': file_hash}).encode())
    result = api('/api/v1/report_json', urllib.parse.urlencode({'hash': file_hash}).encode())
    print(json.dumps(summarize(result)))


def host(args):
    if (args.expected_branch not in ALLOWED_BRANCHES or
            os.environ.get('GITHUB_REPOSITORY') != REPOSITORY or
            os.environ.get('GITHUB_REF_NAME') != args.expected_branch):
        raise ValueError('Only the authorized repository and exact audit branch are allowed')
    if not re.fullmatch('[0-9]+', args.artifact_run):
        raise ValueError('A numeric producer run is required')

    def gh(*command):
        return subprocess.check_output(['gh', *command], text=True)

    producer = json.loads(gh('api', f'repos/{REPOSITORY}/actions/runs/{args.artifact_run}'))
    attempt = producer.get('run_attempt')
    if type(attempt) is not int or attempt < 1:
        raise ValueError('Invalid producer attempt')
    jobs = json.loads(gh('api', f'repos/{REPOSITORY}/actions/runs/{args.artifact_run}/attempts/{attempt}/jobs?per_page=100'))['jobs']
    source, attempt, artifact_name = validate_producer(producer, jobs,
        branch=args.expected_branch, audit_sha=os.environ['GITHUB_SHA'])
    listed = json.loads(gh('api', f'repos/{REPOSITORY}/actions/runs/{args.artifact_run}/artifacts?per_page=100'))
    if listed.get('total_count', 0) > 100:
        raise ValueError('Artifact inventory requires explicit pagination')
    artifact = select_artifact(listed['artifacts'], name=artifact_name, run_id=args.artifact_run, source=source)
    subprocess.run(['git', 'fetch', '--no-tags', '--depth=1', 'origin', source], check=True,
                   stdout=subprocess.DEVNULL)
    paths = subprocess.check_output(['git', 'diff', '--name-only', source, 'HEAD'], text=True).splitlines()
    qa = ('.github/', 'docs/', 'test/', 'integration_test/', 'tools/qa/', 'supabase/tests/')
    if any(not item.startswith(qa) for item in paths):
        raise ValueError('Application/dependency changes require a newly built APK')
    inputs = pathlib.Path(os.environ['RUNNER_TEMP']) / 'bil-mobsf-apk'
    subprocess.run(['gh', 'run', 'download', args.artifact_run,
                    '-n', artifact_name, '-D', str(inputs)], check=True)
    apk = inputs / 'offline-debug-build33.apk'
    expected = (inputs / 'apk.sha256').read_text().split()[0]
    actual = hashlib.sha256(apk.read_bytes()).hexdigest()
    if not re.fullmatch('[0-9a-f]{64}', expected) or actual != expected:
        raise ValueError('APK artifact checksum mismatch')
    subprocess.run(['docker', 'pull', IMAGE], check=True, stdout=subprocess.DEVNULL)
    environment = os.environ.copy()
    environment['MOBSF_API_KEY'] = secrets.token_hex(32)
    container = subprocess.check_output(['docker', 'run', '--rm', '-d', '--network', 'none',
        '--cpus', '2', '--memory', '4g', '--pids-limit', '512',
        '--security-opt', 'no-new-privileges:true', '-e', 'MOBSF_API_KEY', IMAGE],
        env=environment, text=True).strip()
    if not re.fullmatch('[0-9a-f]{64}', container):
        raise RuntimeError('Docker did not return the owned scanner identity')
    try:
        subprocess.run(['docker', 'cp', str(apk), container + ':/tmp/bil.apk'], check=True)
        subprocess.run(['docker', 'cp', str(pathlib.Path(__file__).resolve()),
                        container + ':/tmp/bil-mobsf.py'], check=True)
        executed = subprocess.run(['docker', 'exec', container, 'python3', '/tmp/bil-mobsf.py', '--inside'],
            capture_output=True, text=True, timeout=1500)
        if executed.returncode:
            raise RuntimeError('Offline MobSF static stage failed: ' + executed.stderr[-1800:])
        result = json.loads(executed.stdout)
        result.update({'scanner_image': IMAGE, 'producer_run': args.artifact_run,
                       'producer_source': source, 'producer_conclusion': producer['conclusion'],
                       'producer_attempt': attempt, 'artifact_id': artifact['id'], 'artifact_name': artifact_name,
                       'audit_source': os.environ['GITHUB_SHA'], 'apk_sha256': actual,
                       'qa_only_changed_paths': paths})
        output = pathlib.Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes((json.dumps(result, indent=2) + '\n').encode('utf-8'))
        print(json.dumps({'result': result['result'], 'apk_sha256': actual,
                          'manifest_findings': len(result['manifest_findings']),
                          'code_findings': len(result['code_findings'])}))
    finally:
        subprocess.run(['docker', 'rm', '-f', container], check=True, stdout=subprocess.DEVNULL)


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['--inside']:
            inside_container()
        else:
            parser = argparse.ArgumentParser()
            parser.add_argument('--artifact-run', required=True)
            parser.add_argument('--expected-branch', required=True, choices=ALLOWED_BRANCHES)
            parser.add_argument('--output', required=True)
            host(parser.parse_args())
    except Exception as error:
        print(type(error).__name__ + ': ' + str(error), file=sys.stderr)
        sys.exit(1)
