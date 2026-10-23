"""Actual manual-sync service against Supabase using disposable non-admin users.

No migration, real-user mutation, entitlement grant, or key reset is permitted.
The app test uses signed user sessions; service credentials only create/clean
the uniquely named fixture. Native channel substitutions are explicit in proof.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[2]
PROJECT = 'tgmanzhqulksykhslrzb'
BASE = f'https://{PROJECT}.supabase.co'


def one_row(raw):
    result = json.loads(raw)
    rows = result.get('rows') if isinstance(result, dict) else result
    if not isinstance(rows, list) or len(rows) != 1:
        raise RuntimeError('Expected one database evidence row')
    return rows[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', type=Path, required=True)
    parser.add_argument('--flutter', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--confirm-live-disposable', action='store_true', required=True)
    parser.add_argument('--cleanup-only', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    if not output.is_relative_to((ROOT / 'build').resolve()):
        raise SystemExit('Evidence and temporary credentials must stay in ignored build/')
    output.mkdir(parents=True, exist_ok=args.cleanup_only)
    config_path = output / 'private-fixture.json'
    started = datetime.now(timezone.utc).isoformat()
    proof = {'schema': 'bil.manual-sync-live.v1', 'started_at': started,
             'project': PROJECT, 'status': 'FAIL', 'cleanup_verified': False}
    fixture = {'project': PROJECT, 'started_at': started, 'url': BASE, 'users': []}
    if args.cleanup_only:
        fixture = json.loads(config_path.read_text(encoding='utf8'))
        proof = json.loads((output / 'result.json').read_text(encoding='utf8'))
        started = fixture['started_at']
        if fixture['project'] != PROJECT or fixture['url'] != BASE:
            raise SystemExit('Cleanup fixture provenance mismatch')
    token = None
    server = None

    def cli(*arguments, sql=None):
        result = subprocess.run([str(args.cli), *arguments], input=sql,
            cwd=ROOT, text=True, encoding='utf8', stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=120)
        if result.returncode:
            raise RuntimeError('Supabase CLI evidence request failed')
        return result.stdout

    def query(sql):
        return one_row(cli('db', 'query', '--linked', '--project-ref', PROJECT,
                           '--output', 'json', sql=sql))

    def request(method, path, data=None, *, user_token=None):
        key = fixture['public_key'] if user_token else server
        headers = {'apikey': key, 'Authorization': 'Bearer ' + (user_token or key),
                   'Content-Type': 'application/json', 'User-Agent': 'BIL-Manual-Sync-QA/1'}
        req = urllib.request.Request(BASE + path, method=method, headers=headers,
              data=None if data is None else json.dumps(data).encode())
        try:
            with urllib.request.urlopen(req, timeout=45) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as exc:
            # Do not expose response bodies, authorization headers or tokens.
            raise RuntimeError(f'Fixture HTTP status {exc.code}') from None

    def find_user(email):
        for page in range(1, 101):
            value = request('GET', f'/auth/v1/admin/users?page={page}&per_page=100')
            users = value['users']
            found = [u for u in users if u.get('email') == email]
            if len(found) > 1:
                raise RuntimeError('Ambiguous disposable identity')
            if found:
                return found[0]
            if len(users) < 100:
                return None
        raise RuntimeError('Disposable identity recovery did not finish')

    def save_fixture():
        config_path.write_text(json.dumps(fixture), encoding='utf8')

    try:
        keys = json.loads(cli('projects', 'api-keys', '--project-ref', PROJECT,
                              '--reveal', '--output', 'json'))
        server = next(k['api_key'] for k in keys if k['name'] == 'service_role')
        fixture['public_key'] = next(k['api_key'] for k in keys if k.get('type') == 'publishable')
        del keys
        if args.cleanup_only:
            return  # The finally block independently verifies all residue.
        suffix = uuid.uuid4().hex
        for label in ('a', 'b'):
            email = f'bil-manual-sync-{suffix}-{label}@bilhealth.invalid'
            user = {'id': '', 'email': email, 'password': 'Bil!' + uuid.uuid4().hex + 'A9'}
            fixture['users'].append(user)
            save_fixture()  # Recover identity even if create commits then times out.
            try:
                created = request('POST', '/auth/v1/admin/users', {
                    'email': email, 'password': user['password'], 'email_confirm': True})
            except Exception:
                created = find_user(email)
                if created is None:
                    raise
            user['id'] = str(uuid.UUID(created['id']))
            save_fixture()
        proof['fixture_owners'] = [u['id'] for u in fixture['users']]
        proof['head'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        sources = [
            'lib/features/cloud_platform/services/cloud_manual_sync_service.dart',
            'lib/features/cloud_platform/services/durable_offline_first_cloud_platform.dart',
            'lib/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart',
            'tools/qa/flutter/manual_sync_live_e2e_test.dart',
            'tools/qa/manual_sync_crypto_bridge.mjs',
            'tools/qa/run_manual_sync_live_e2e.py',
        ]
        sources = sorted(set(sources) | {
            p.relative_to(ROOT).as_posix()
            for folder in ('lib/features/cloud_platform', 'lib/data/database')
            for p in (ROOT / folder).rglob('*.dart')})
        proof['source_sha256'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources}
        env = dict(os.environ, BIL_MANUAL_SYNC_CONFIG=str(config_path))
        with (output / 'flutter.log').open('w', encoding='utf8') as log:
            result = subprocess.run([str(args.flutter), 'test', '--no-pub', '--reporter', 'expanded',
                'tools/qa/flutter/manual_sync_live_e2e_test.dart'], cwd=ROOT, env=env,
                stdout=log, stderr=subprocess.STDOUT, timeout=1500)
        proof['flutter_exit'] = result.returncode
        if (output / 'service-proof.json').is_file():
            proof['service'] = json.loads((output / 'service-proof.json').read_text(encoding='utf8'))
        if result.returncode or proof.get('service', {}).get('status') != 'PASS':
            raise RuntimeError('Actual manual synchronization did not pass; inspect sanitized Flutter log')
        proof['status'] = 'PASS'
    except Exception as exc:
        proof['error'] = str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__
        print('Manual sync live proof: FAIL; final validation remains blocked', flush=True)
    finally:
        try:
            owners = []
            for user in fixture['users']:
                if not re.fullmatch(r'bil-manual-sync-[0-9a-f]{32}-[ab]@bilhealth\.invalid', user['email']):
                    raise RuntimeError('Disposable identity guard failed')
                if user['id']:
                    owners.append(str(uuid.UUID(user['id'])))
                found = find_user(user['email'])
                if found is None:
                    continue
                uid = str(uuid.UUID(found['id']))
                if user['id'] and uid != user['id']:
                    raise RuntimeError('Fixture ID differs; cleanup refused')
                if found['email'] != user['email'] or datetime.fromisoformat(found['created_at'].replace('Z', '+00:00')) < datetime.fromisoformat(started):
                    raise RuntimeError('Fixture identity/time mismatch; cleanup refused')
                if uid not in owners:
                    owners.append(uid)
                # Only this brand-new fixture's Vault key. A key reference has
                # ON DELETE CASCADE but Vault itself does not; remove before Auth.
                vault_name = 'bil_cloud_payload_' + uid.replace('-', '')
                deletion = query(f"with removed as (delete from vault.secrets s using public.bil_cloud_key_refs r, auth.users u where s.id=r.vault_secret_id and r.owner_id=u.id and u.id='{uid}'::uuid and u.email='{user['email']}' and u.created_at>='{started}'::timestamptz and s.name='{vault_name}' and s.created_at>='{started}'::timestamptz returning s.id) select count(*)::int as deleted_fixture_keys from removed;")
                if deletion['deleted_fixture_keys'] not in (0, 1):
                    raise RuntimeError('Unexpected Vault cleanup count')
                # Normal signed-user logout, then exact admin deletion. No
                # service token is passed to the Flutter app/test.
                try:
                    session = request('POST', '/auth/v1/token?grant_type=password', {
                        'email': user['email'], 'password': user['password']})
                    token = session['access_token']
                    request('POST', '/auth/v1/logout?scope=global', user_token=token)
                    token = None
                finally:
                    request('DELETE', '/auth/v1/admin/users/' + uid)
            if owners:
                quoted = ','.join("'" + uid + "'::uuid" for uid in owners)
                schema = query("select json_agg(json_build_object('table',table_name,'column',column_name)) as owned_columns from information_schema.columns where table_schema='public' and column_name in ('owner_id','user_id') and udt_name='uuid'")
                columns = schema['owned_columns']
                if isinstance(columns, str):
                    columns = json.loads(columns)
                counts = [f"(select count(*) from public.\"{v['table']}\" where \"{v['column']}\" in ({quoted}))" for v in columns
                    if re.fullmatch('[a-z_0-9]+', v['table'])]
                values = ','.join(counts)
                proof['cleanup'] = query(f"select (select count(*)::int from auth.users where id in ({quoted})) as auth_users,(select count(*)::int from auth.sessions where user_id in ({quoted})) as sessions,(select count(*)::int from public.bil_cloud_key_refs where owner_id in ({quoted})) as key_refs,(select count(*)::int from vault.secrets where name in ({','.join(repr('bil_cloud_payload_' + uid.replace('-', '')) for uid in owners)})) as vault_secrets,ARRAY[{values}] as owned_table_counts")
                cleanup = proof['cleanup']
                # PostgreSQL bigint array elements are strings in CLI JSON.
                # Accept only exact nonnegative integer representations.
                actual_counts = [cleanup[k] for k in ('auth_users', 'sessions', 'key_refs', 'vault_secrets')] + cleanup['owned_table_counts']
                proof['cleanup_verified'] = bool(cleanup['owned_table_counts']) and all(
                    type(n) is int and n == 0 or type(n) is str and n == '0'
                    for n in actual_counts)
                proof['owned_columns_inventoried'] = len(columns)
            else:
                proof['cleanup_verified'] = not fixture['users']
            if proof['cleanup_verified']:
                config_path.unlink(missing_ok=True)
        except Exception as exc:
            proof['cleanup_error'] = str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__
        if not proof['cleanup_verified']:
            proof['status'] = 'FAIL'
        proof['completed_at'] = datetime.now(timezone.utc).isoformat()
        (output / 'result.json').write_text(json.dumps(proof, indent=2) + '\n', encoding='utf8')
        print('MANUAL_SYNC_LIVE=' + proof['status'] + ';CLEANUP=' + str(proof['cleanup_verified']), flush=True)
    if proof['status'] != 'PASS':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
