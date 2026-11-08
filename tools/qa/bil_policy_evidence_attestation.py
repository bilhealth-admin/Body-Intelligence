"""Verify documentation equivalence with exact-source CI and both native ZIPs.

This read-only evidence gate never signs, uploads, dispatches or certifies a
store release. Historical closure receipts are not rewritten or grandfathered.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request

import bil_native_source_evidence as native


SCHEMA = 'bil.policy-exact-source-native-pair.v2'
BRANCHES = {'integration/bil-qa-media-policy-20261011',
    'codex/bil-release-ios38-android33-20261022'}
SPECS = {
    'policy': ('bil_apple_google_policy_gate.yml', 'push', {
        'Source and affected regressions; certification remains separate',
        'Seven exact plan goldens on their Windows reference platform'}),
    'source_security': ('bil_codeql_security_extended.yml', 'push', {
        'CodeQL (actions)', 'CodeQL (javascript-typescript)', 'CodeQL (python)',
        'Isolated Semgrep source audit'}),
    'android_startup': ('bil_android_isolated_emulator_smoke.yml', 'push', {
        f'Android {level} offline-config startup' for level in (26, 29, 33, 34, 35, 36)}),
    'native_android': ('bil_codeql_security_extended.yml', 'workflow_dispatch', {
        'Android API 33 native integration without CodeQL tracing'}),
    'iphone_native': ('bil39_iphone_native.yml', 'push', {native.native_job_name('iphone')}),
    'ipad_native': ('bil39_ipad_native.yml', 'push', {native.native_job_name('ipad')}),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, url):
        return None


class GitHubEvidenceClient:
    """Bounded authenticated API reads; signed ZIP redirects receive no token."""
    def __init__(self, token, *, opener=None):
        require(isinstance(token, str) and token, 'GitHub read token required')
        self.token = token
        self.opener = opener or urllib.request.build_opener(_NoRedirect())

    def _request(self, path, accept='application/vnd.github+json'):
        require(isinstance(path, str) and path.startswith('/actions/')
            and not any(value in path for value in ('..', '\\', '#')),
            'Only repository-scoped Actions evidence endpoints are permitted')
        return urllib.request.Request('https://api.github.com/repos/' + native.REPOSITORY + path,
            headers={'Authorization': 'Bearer ' + self.token, 'Accept': accept,
                'User-Agent': 'BIL-policy-evidence-attestation', 'X-GitHub-Api-Version': '2026-03-10'})

    def api(self, path):
        with self.opener.open(self._request(path), timeout=30) as response:
            body = response.read(4 * 1024 * 1024 + 1)
        require(len(body) <= 4 * 1024 * 1024, 'Actions metadata exceeds bound')
        document = json.loads(body)
        require(isinstance(document, dict), 'Actions metadata must be an object')
        return document

    def download(self, artifact_id, destination):
        require(type(artifact_id) is int and artifact_id > 0, 'Exact artifact ID required')
        try:
            response = self.opener.open(self._request(
                f'/actions/artifacts/{artifact_id}/zip', 'application/octet-stream'), timeout=30)
        except urllib.error.HTTPError as redirect:
            if redirect.code != 302:
                redirect.close()
                raise ValueError('Authenticated artifact ZIP could not be obtained') from None
            location = redirect.headers.get('Location', '')
            redirect.close()
            parsed = urllib.parse.urlsplit(location)
            host = parsed.hostname or ''
            require(parsed.scheme == 'https' and parsed.username is None and parsed.password is None
                and parsed.port in (None, 443) and not parsed.fragment
                and (host.endswith('.blob.core.windows.net') or host.endswith('.githubusercontent.com')),
                'Unexpected GitHub artifact redirect origin')
            # Never forward GitHub Authorization to the signed storage URL.
            response = self.opener.open(urllib.request.Request(location,
                headers={'User-Agent': 'BIL-policy-evidence-attestation'}), timeout=30)
        with response:
            require(response.status == 200, 'Artifact ZIP response must succeed')
            declared = response.headers.get('Content-Length')
            require(declared is None or (declared.isdecimal() and 0 < int(declared) <= native.MAX_ARCHIVE),
                'Artifact ZIP declared size exceeds bound')
            total = 0
            with Path(destination).open('xb') as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    require(total <= native.MAX_ARCHIVE, 'Artifact ZIP exceeds download bound')
                    output.write(chunk)
            require(total > 0, 'Artifact ZIP cannot be empty')


def _all_jobs(api, run_id, attempt):
    jobs = []
    for page in range(1, 101):
        batch = api(f'/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100&page={page}')
        rows, count = batch.get('jobs'), batch.get('total_count')
        require(isinstance(rows, list) and len(rows) <= 100 and type(count) is int and count >= 0,
            'Complete attempt-specific job inventory required')
        jobs.extend(rows)
        if len(rows) < 100:
            require(len(jobs) == count, 'Attempt job pagination is incomplete')
            return jobs
    raise ValueError('Attempt job inventory exceeds bound')


def verify_evidence(record, *, root, source_sha, source_tree, branch, api, download, archive_dir):
    require(branch in BRANCHES and re.fullmatch('[a-f0-9]{40}', source_sha or '')
        and re.fullmatch('[a-f0-9]{40}', source_tree or ''), 'Approved exact tested source required')
    require(record.get('schema') == SCHEMA and record.get('tested_source_sha') == source_sha
        and record.get('tested_source_branch') == branch,
        'New exact-source native-pair closure record required')
    runs = record.get('required_runs')
    require(isinstance(runs, dict) and set(runs) == set(SPECS),
        'Every CI role and both separate native runs are mandatory')
    ids = [row.get('run_id') for row in runs.values() if isinstance(row, dict)]
    require(len(ids) == len(SPECS) and all(type(value) is int and value > 0 for value in ids)
        and len(set(ids)) == len(ids), 'Distinct exact workflow run IDs required')
    contexts, proofs = {}, []
    for role, (workflow, event, expected) in SPECS.items():
        row = runs[role]
        run_id, attempt_number = row['run_id'], row.get('run_attempt')
        require(type(attempt_number) is int and attempt_number > 0, 'Explicit current run attempt required')
        run = api(f'/actions/runs/{run_id}')
        require(run.get('id') == run_id and run.get('run_attempt') == attempt_number
            and run.get('head_sha') == source_sha and run.get('head_branch') == branch
            and run.get('repository', {}).get('full_name') == native.REPOSITORY
            and run.get('path') == '.github/workflows/' + workflow and run.get('event') == event
            and run.get('status') == 'completed' and run.get('conclusion') == 'success',
            'Required workflow identity, source or success does not match')
        attempt = api(f'/actions/runs/{run_id}/attempts/{attempt_number}')
        require(attempt.get('id') == run_id and attempt.get('run_attempt') == attempt_number
            and attempt.get('head_sha') == source_sha and attempt.get('status') == 'completed'
            and attempt.get('conclusion') == 'success', 'Current authenticated attempt required')
        jobs = _all_jobs(api, run_id, attempt_number)
        require(jobs and len({job.get('id') for job in jobs}) == len(jobs)
            and all(type(job.get('id')) is int and job['id'] > 0
                and job.get('run_id') == run_id and job.get('run_attempt') == attempt_number
                and job.get('head_sha') == source_sha and job.get('status') == 'completed'
                and job.get('conclusion') in ('success', 'skipped') for job in jobs),
            'Required current-attempt jobs are incomplete or foreign')
        successful = [job['name'] for job in jobs if job['conclusion'] == 'success']
        require(set(successful) == expected and len(successful) == len(expected),
            'Required jobs are missing, skipped, failed, duplicated or different')
        proofs.append({'role': role, 'run_id': run_id, 'attempt': attempt_number,
            'head_sha': source_sha, 'verified_successful_jobs': sorted(successful)})
        contexts[role] = (run, jobs, attempt)
    native_rows = []
    for device in native.DEVICES:
        role = device + '_native'
        run, jobs, attempt = contexts[role]
        artifact_id = runs[role].get('artifact_id')
        require(type(artifact_id) is int and artifact_id > 0, 'Both exact native artifact IDs required')
        metadata = api(f'/actions/artifacts/{artifact_id}')
        proof = native.validate_native_workflow_contract(root, device, branch)
        archive = Path(archive_dir) / (device + '.zip')
        download(artifact_id, archive)
        native_rows.append(native.validate_native_artifact(run, jobs, metadata, archive,
            device=device, source_sha=source_sha, source_tree=source_tree, source_branch=branch,
            source_scope_hashes=proof['source_scope_hashes'], expected_runner_names=proof['runner_test_names'],
            source_root=root, attempt=attempt))
    pair = native.require_native_pair(native_rows, source_sha=source_sha, source_tree=source_tree)
    return {'status': 'PASS_SOURCE_EQUIVALENCE_AND_LIVE_CI', 'tested_source_sha': source_sha,
        'tested_source_tree': source_tree, 'verified_runs': proofs, 'native_pair': pair,
        'implementation_changed': False, 'full_suite_repeated': False,
        'pre_submission_certification': 'BLOCKED', 'signed_build_or_store_acceptance_proven': False}


def write_verified_evidence(output, record, **arguments):
    output = Path(output)
    require(not output.exists(), 'A previous attestation cannot serve as new evidence')
    result = verify_evidence(record, **arguments)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


def documentation_source(root, record, environment):
    def git(*values):
        return subprocess.check_output(['git', *values], cwd=root, text=True).strip()
    source, head = record.get('tested_source_sha'), git('rev-parse', 'HEAD')
    branch = environment.get('GITHUB_REF_NAME')
    require(environment.get('GITHUB_REPOSITORY') == native.REPOSITORY and branch in BRANCHES
        and head == environment.get('GITHUB_SHA') and re.fullmatch('[a-f0-9]{40}', source or '')
        and git('rev-parse', 'HEAD^') == source, 'Documentation commit must follow its exact tested source')
    require(not git('status', '--porcelain=v1', '--untracked-files=all'),
        'Documentation attestation requires a clean immutable checkout')
    changed = [path for path in subprocess.check_output(
        ['git', 'diff', '--name-only', '-z', source, head], cwd=root).decode().split('\0') if path]
    require(changed and all(path.startswith('docs/qa_next/') for path in changed),
        'Implementation changed after the tested source')
    return {'source': source, 'head': head, 'branch': branch, 'changed': changed,
        'tree': git('rev-parse', source + '^{tree}')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', type=Path,
        default=Path('docs/qa_next/evidence/policy-gate-20261015/ci-closure.json'))
    parser.add_argument('--output', type=Path,
        default=Path('build/qa/policy-gate-20261015/final-evidence-attestation.json'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    record = json.loads((root / args.record).read_text(encoding='utf-8'))
    identity = documentation_source(root, record, os.environ)
    source, head, branch = identity['source'], identity['head'], identity['branch']
    client = GitHubEvidenceClient(os.environ.get('GH_TOKEN'))
    with tempfile.TemporaryDirectory(prefix='bil-policy-native-') as archives:
        result = write_verified_evidence(root / args.output, record, root=root, source_sha=source,
            source_tree=identity['tree'], branch=branch,
            api=client.api, download=client.download, archive_dir=archives)
    result.update(attested_commit_sha=head, changed_paths=identity['changed'])
    (root / args.output).write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as stream:
            stream.write(f'Final commit `{head}` matches tested `{source}`. All six required runs and '
                'both exact native ZIPs were verified. Store certification remains BLOCKED.\n')


if __name__ == '__main__':
    main()
