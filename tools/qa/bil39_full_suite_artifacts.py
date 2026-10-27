"""Select the newest exact-run shard artifacts without deleting prior failures."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import zipfile

from bil39_internal_build_ci import BRANCH, REPOSITORY

MAX_ZIP = 32 * 1024 * 1024
MAX_EXPANDED = 128 * 1024 * 1024
MEMBERS = {'events.jsonl', 'receipt.json', 'plan.json'}


def select(artifacts, *, sha, run_id, total):
    if not re.fullmatch('[a-f0-9]{40}', sha) or type(run_id) is not int or run_id <= 0 or not 1 <= total <= 64:
        raise ValueError('Exact source/run and bounded shard count are required')
    result = []
    for index in range(total):
        name = f'bil39-full-shard-{index}-{sha}'
        candidates = [row for row in artifacts if row.get('name') == name]
        if not candidates:
            raise ValueError('Missing complete-suite artifact: ' + name)
        for row in candidates:
            identity = row.get('workflow_run', {})
            if (identity.get('head_sha') != sha or identity.get('id') != run_id or
                    identity.get('head_branch') != BRANCH or row.get('expired') is not False or
                    type(row.get('id')) is not int or row['id'] <= 0 or
                    type(row.get('size_in_bytes')) is not int or not 0 < row['size_in_bytes'] <= MAX_ZIP or
                    not re.fullmatch(r'sha256:[a-f0-9]{64}', row.get('digest') or '')):
                raise ValueError('Artifact identity, lifetime, size or digest is invalid')
            if datetime.fromisoformat(row['created_at'].replace('Z', '+00:00')).tzinfo is None:
                raise ValueError('Artifact creation time must be explicit')
        newest = max(datetime.fromisoformat(row['created_at'].replace('Z', '+00:00')) for row in candidates)
        latest = [row for row in candidates if datetime.fromisoformat(
            row['created_at'].replace('Z', '+00:00')) == newest]
        if len(latest) != 1:
            raise ValueError('Ambiguous newest shard artifact; do not guess by artifact ID')
        chosen = latest[0]
        result.append({'index': index, 'id': chosen['id'], 'name': name,
            'digest': chosen['digest'], 'created_at': chosen['created_at'],
            'superseded_artifact_ids': sorted(row['id'] for row in candidates if row is not chosen)})
    return result


def extract(archive, destination, *, digest):
    archive, destination = Path(archive), Path(destination)
    if archive.is_symlink() or not 0 < archive.stat().st_size <= MAX_ZIP:
        raise ValueError('Invalid downloaded shard archive')
    observed = 'sha256:' + hashlib.sha256(archive.read_bytes()).hexdigest()
    if observed != digest:
        raise ValueError('Downloaded shard archive digest does not match GitHub')
    with zipfile.ZipFile(archive) as bundle:
        entries = bundle.infolist()
        if (len(entries) != len(MEMBERS) or {row.filename for row in entries} != MEMBERS or
                sum(row.file_size for row in entries) > MAX_EXPANDED or
                any(row.is_dir() or stat.S_ISLNK(row.external_attr >> 16) for row in entries)):
            raise ValueError('Unexpected, duplicate, linked or oversized shard archive member')
        destination.mkdir(parents=True, exist_ok=False)
        for row in entries:
            with bundle.open(row) as source, (destination / row.filename).open('xb') as output:
                shutil.copyfileobj(source, output)


def api(path):
    output = subprocess.check_output(['gh', 'api', '--hostname', 'github.com',
        f'repos/{REPOSITORY}' + path], timeout=60)
    if len(output) > 2 * 1024 * 1024:
        raise ValueError('Unexpectedly large GitHub metadata response')
    return json.loads(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    parser.add_argument('--total', type=int, default=8)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch('[a-f0-9]{40}', args.sha) or args.run_id <= 0 or not 1 <= args.total <= 64:
        raise ValueError('Exact source/run and bounded shard count are required before API access')
    run = api(f'/actions/runs/{args.run_id}')
    if (run.get('head_sha') != args.sha or run.get('head_branch') != BRANCH or
            run.get('event') != 'push' or run.get('path') != '.github/workflows/verify.yml'):
        raise ValueError('Coverage artifacts must belong to this exact-source integration run')
    artifacts = []
    for page in range(1, 11):
        rows = api(f'/actions/runs/{args.run_id}/artifacts?per_page=100&page={page}')['artifacts']
        artifacts.extend(rows)
        if len(rows) < 100:
            break
    else:
        raise ValueError('Unbounded complete-suite artifact inventory')
    selected = select(artifacts, sha=args.sha, run_id=args.run_id, total=args.total)
    args.output.mkdir(parents=True, exist_ok=False)
    for row in selected:
        archive = args.output / f"shard-{row['index']}.zip"
        with archive.open('xb') as output:
            subprocess.run(['gh', 'api', '--hostname', 'github.com',
                f"repos/{REPOSITORY}/actions/artifacts/{row['id']}/zip"], stdout=output, check=True, timeout=60)
        extract(archive, args.output / f"shard-{row['index']}", digest=row['digest'])
    (args.output / 'artifact-selection.json').write_text(json.dumps({
        'source_sha': args.sha, 'run_id': args.run_id, 'artifacts': selected,
        'prior_artifacts_deleted': False, 'scope': 'Newest upload per exact-run shard; actual PASS checked separately'},
        indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'source_sha': args.sha, 'run_id': args.run_id, 'selected_shards': len(selected),
                      'prior_artifacts_deleted': False}))


if __name__ == '__main__':
    main()
