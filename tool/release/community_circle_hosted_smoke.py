"""Opt-in hosted Auth/Storage check; creates only uniquely marked disposable users.

No moderation authority is granted and nothing is approved for public discovery.
Credentials stay in memory. Recovery ledger contains IDs, never passwords/tokens.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-live', action='store_true', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--upload-format', choices=('raw', 'multipart'), default='multipart')
    parser.add_argument('--check-translation', action='store_true', help='Send only a fixed synthetic Hello through authenticated translation')
    parser.add_argument('--check-food-search', action='store_true', help='Search only fixed synthetic food terms through hosted API')
    args = parser.parse_args()
    from PIL import Image

    project = 'tgmanzhqulksykhslrzb'
    base = f'https://{project}.supabase.co'
    args.output.mkdir(parents=True, exist_ok=True)
    ledger = args.output / 'hosted-circle-recovery.json'
    if ledger.exists():
        raise RuntimeError('Existing recovery ledger requires cleanup first')
    command = [shutil.which('npx.cmd') or shutil.which('npx'), '--yes',
               '--cache', 'G:/BIL_Toolchains/npm-cache-bil-release',
               '--package', 'supabase@2.121.0', 'supabase', 'projects',
               'api-keys', '--project-ref', project, '--reveal', '--output', 'json']
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError('Authenticated management credentials unavailable')
    keys = json.loads(result.stdout)
    service = next(k['api_key'] for k in keys if k.get('name') == 'service_role')
    public = next(k['api_key'] for k in keys if k.get('name') == 'anon')
    del keys, result
    users, objects, checks = [], [], {}
    uploaded_count = 0
    run_id = uuid.uuid4().hex

    def request(path, method='GET', data=None, token=None, admin=False,
                raw=False, mime='application/json', extra=None):
        key = service if admin else public
        headers = {'apikey': key, 'Authorization': f'Bearer {key if admin else token or key}',
                   'Content-Type': mime, 'User-Agent': 'BIL-disposable-circle-QA/1'}
        headers.update(extra or {})
        payload = data if isinstance(data, bytes) else json.dumps(data).encode() if data is not None else None
        req = urllib.request.Request(base + path, data=payload, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=45) as response:
                body = response.read()
                return response.status, body if raw else json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            body = error.read()
            try:
                value = json.loads(body)
            except ValueError:
                value = {}
            return error.code, value

    def ok(path, method='POST', data=None, token=None, **kwargs):
        status, value = request(path, method, data, token, **kwargs)
        if not 200 <= status < 300:
            code = value.get('code', value.get('error', 'unknown')) if isinstance(value, dict) else 'unknown'
            raise RuntimeError(f'{method} {path.split("?")[0]} failed: HTTP {status} code={code}')
        return value

    def rpc(name, data, token):
        return ok('/rest/v1/rpc/' + name, data=data, token=token)

    def save_ledger():
        ledger.write_text(json.dumps({'project': project, 'run_id': run_id,
                                     'users': users, 'objects': objects}, indent=2) + '\n')

    outcome = 'FAIL'
    try:
        tokens = []
        for label in ('a', 'b'):
            email = f'bil-circle-{run_id}-{label}@bilhealth.invalid'
            password = secrets.token_urlsafe(36) + 'Aa9!'
            user = ok('/auth/v1/admin/users', data={'email': email, 'password': password,
                      'email_confirm': True, 'user_metadata': {'qa_circle_run': run_id}}, admin=True)
            users.append({'id': user['id'], 'email': email})
            save_ledger()
            session = ok('/auth/v1/token?grant_type=password', data={'email': email, 'password': password})
            assert session['user']['id'] == user['id']
            token = session['access_token']
            tokens.append(token)
            state = rpc('bil_current_community_policy_status', {}, token)
            assert state['status'] == 'acceptance_required'
            policy = state['version']
            status, rejected = request('/rest/v1/bil_public_profiles', 'POST',
                {'user_id': user['id'], 'display_name': 'Unaccepted QA alias',
                 'profile_visibility': 'private', 'discoverable': False}, token)
            assert status == 403 and rejected.get('message') == 'community_policy_acceptance_required'
            ok('/rest/v1/bil_content_policy_acceptances', data={'user_id': user['id'], 'policy_version': policy}, token=token)
            ok('/rest/v1/bil_public_profiles', data={'user_id': user['id'],
               'display_name': 'Circle QA ' + label, 'profile_visibility': 'private', 'discoverable': False}, token=token)
            assert rpc('bil_social_public_code_v2', {}, token)['code']
        checks['genuine_auth_policy_profile_code_two_ordinary_accounts'] = True
        checks['unaccepted_profile_insert_denied_before_explicit_acceptance'] = True
        a, b = tokens
        if args.check_translation:
            status, _ = request('/functions/v1/community-translate', 'POST',
                                {'texts': {'body': 'Hello'}, 'targetTag': 'ar'})
            assert status == 401, 'Unauthenticated translation must be denied'
            translated = ok('/functions/v1/community-translate', data={
                'texts': {'body': 'Hello'}, 'targetTag': 'ar'}, token=a)
            text = translated['texts']['body']
            assert translated['engine'] == 'google' and isinstance(text, str)
            assert text.strip() and text != 'Hello' and any('\u0600' <= c <= '\u06ff' for c in text)
            checks['translation_real_google_fixed_synthetic_text_auth_required'] = True
        if args.check_food_search:
            status, _ = request('/functions/v1/food-search', 'POST',
                                {'query': 'apple', 'locale': 'en', 'limit': 2})
            assert status == 401, 'Unauthenticated food search must be denied'
            for query, locale in [('apple', 'en'), ('تفاح', 'ar')]:
                foods = ok('/functions/v1/food-search', data={
                    'query': query, 'locale': locale, 'limit': 2}, token=a)
                rows = foods['foods']
                assert isinstance(rows, list) and rows, 'Expected real canonical USDA foods'
                assert all(row['provider'] == 'usda' and row['fdc_id'] is not None for row in rows)
            checks['food_search_real_usda_fixed_terms_auth_required'] = True
        created = rpc('bil_circle_create_v1', {'p_request_id': str(uuid.uuid4()),
                      'p_display_name': 'Disposable circle QA', 'p_description': 'Synthetic private pending test',
                      'p_rules': 'Respect community guidelines', 'p_access': 'public', 'p_join_policy': 'open'}, a)
        slug = created['circle_slug']
        assert created['circle']['review_status'] == 'pending'
        status, other = request('/rest/v1/rpc/bil_circle_read_v1', 'POST', {'p_slug': slug}, b)
        assert status in (400, 403, 404) or (status == 200 and other['circle'] is None)
        status, _ = request('/rest/v1/rpc/bil_circle_review_queue_v1', 'POST', {'p_limit': 1}, a)
        assert status == 403
        checks['pending_circle_hidden_from_other_account_no_review_authority'] = True
        image = io.BytesIO()
        Image.new('RGB', (64, 64), (235, 235, 235)).save(image, format='PNG')
        pixels = image.getvalue()
        reserved = rpc('bil_circle_media_prepare_v1', {'p_request_id': str(uuid.uuid4()),
                       'p_slug': slug, 'p_slot': 'avatar', 'p_mime_type': 'image/png',
                       'p_bytes': len(pixels), 'p_width': 64, 'p_height': 64}, a)
        media = reserved['media']
        path = media['object_path']
        assert path.startswith(users[0]['id'] + '/' + slug + '/')
        objects.append(path)
        save_ledger()
        target = '/storage/v1/object/community-circle-media/' + urllib.parse.quote(path, safe='/')
        download = target  # Same private download route as storage_client 2.6.0.
        upload, upload_mime = pixels, 'image/png'
        if args.upload_format == 'multipart':
            # Match storage_client 2.6.0: cacheControl plus an empty file field.
            boundary = 'bil-qa-' + uuid.uuid4().hex
            upload = (f'--{boundary}\r\nContent-Disposition: form-data; name="cacheControl"\r\n\r\n3600\r\n'
                      f'--{boundary}\r\nContent-Disposition: form-data; name=""; filename=""\r\n'
                      'Content-Type: image/png\r\n\r\n').encode() + pixels + f'\r\n--{boundary}--\r\n'.encode()
            upload_mime = 'multipart/form-data; boundary=' + boundary
        ok(target, data=upload, token=a, mime=upload_mime, extra={'x-upsert': 'false'})
        uploaded_count += 1
        status, body = request(download, token=a, raw=True)
        assert status == 200 and body == pixels
        for viewer in (b, None):
            status, _ = request(download, token=viewer, raw=True)
            assert status in (400, 401, 403, 404)
        status, _ = request(target, 'POST', pixels, a, mime='image/png', extra={'x-upsert': 'true'})
        assert status in (400, 403, 409)
        checks['real_image_bytes_owner_read_other_and_anonymous_denied_immutable'] = True
        finished = rpc('bil_circle_media_finish_v1', {'p_request_id': str(uuid.uuid4()),
                       'p_media_id': media['id']}, a)
        assert finished['media']['status'] == 'pending'
        assert rpc('bil_circle_read_v1', {'p_slug': slug}, a)['circle']['avatar'] is None
        status, body = request(download, token=a, raw=True)
        assert status == 200 and hashlib.sha256(body).digest() == hashlib.sha256(pixels).digest()
        checks['uploaded_image_stays_pending_no_public_avatar_slot'] = True
        outcome = 'PASS'
    finally:
        # Storage first: deleting SQL metadata cannot delete physical object bytes.
        if objects:
            ok('/storage/v1/object/community-circle-media', method='DELETE',
               data={'prefixes': objects}, admin=True)
            for path in objects:
                status, _ = request('/storage/v1/object/community-circle-media/' + urllib.parse.quote(path, safe='/'), admin=True, raw=True)
                assert status in (400, 404), 'Storage cleanup not confirmed'
        for user in users:
            current = ok('/auth/v1/admin/users/' + user['id'], method='GET', admin=True)
            assert current['email'] == user['email']
            assert current['user_metadata']['qa_circle_run'] == run_id
            ok('/auth/v1/admin/users/' + user['id'], method='DELETE', admin=True)
            status, _ = request('/auth/v1/admin/users/' + user['id'], admin=True)
            assert status == 404, 'Auth cleanup not confirmed'
        ledger.unlink(missing_ok=True)
        proof = {'result': outcome, 'checks': checks, 'cleanup_verified': True,
                 'created_users': len(users), 'reserved_object_paths': len(objects), 'uploaded_objects': uploaded_count,
                 'upload_format': args.upload_format,
                 'scope': 'Hosted Auth/Data API/actual Storage bytes, pending content only; no device or store certification'}
        (args.output / 'hosted-circle-proof.json').write_text(json.dumps(proof, indent=2) + '\n')
        print(json.dumps(proof))


if __name__ == '__main__':
    main()
