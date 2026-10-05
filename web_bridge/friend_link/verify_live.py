"""Verify deployed HTTPS content. This does not claim a real phone opened BIL."""
import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

root = Path('evidence')
text = (root / 'deploy.log').read_text(encoding='utf-8')
urls = sorted(set(re.findall(r'https://bil-friend-link-20261005\.[a-z0-9-]+\.workers\.dev', text)))
if len(urls) != 1:
    raise SystemExit('DEPLOYED_HTTPS_URL_NOT_UNIQUELY_IDENTIFIED')
base = urls[0]
code = '0123456789abcdef0123456789abcdef'
checks = [
    ('valid_ar', f'/open-bil?code={code}&lang=ar', 'GET', 200, f'href="bil://community/member/{code}"'),
    ('valid_en', f'/open-bil?code={code}&lang=en', 'GET', 200, '<html lang="en" dir="ltr">'),
    ('converter', '/open-bil', 'GET', 200, 'id="code-form"'),
    ('invalid_code', '/open-bil?code=not-a-code', 'GET', 400, 'id="error"'),
    ('reject_post', '/open-bil', 'POST', 405, 'Method not allowed'),
    ('no_unrelated_routes', '/privacy', 'GET', 404, 'Not found'),
]
results = []
for name, path, method, expected_status, fragment in checks:
    error_text = None
    for attempt in range(6):
        try:
            request = urllib.request.Request(base + path, method=method,
                headers={'User-Agent': 'BIL-web-bridge-verification/1.0'})
            try:
                response = urllib.request.urlopen(request, timeout=15)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                status = response.code
                headers = dict(response.headers)
                body = response.read().decode('utf-8')
                if status != expected_status or fragment not in body:
                    raise ValueError(f'{name}: HTTP {status} or content mismatch')
                if response.headers.get('X-Bil-Bridge') != 'bil-friend-link-web-20261005-v1':
                    raise ValueError('Unexpected deployment marker')
            results.append({'name': name, 'status': 'PASS', 'http_status': status})
            break
        except Exception as error:
            error_text = str(error)
            if attempt < 5:
                time.sleep(5)
    else:
        report = {'status': 'FAIL', 'url': base, 'error': error_text, 'checks': results}
        (root / 'live-verification.json').write_text(json.dumps(report, indent=2))
        raise SystemExit(error_text)
report = {'status': 'PASS', 'url': base + '/open-bil', 'checks': results,
          'native_phone_launch_verified': False, 'existing_app_share_button_changed': False,
          'existing_bilhealth_worker_modified': False, 'database_modified': False}
(root / 'live-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
