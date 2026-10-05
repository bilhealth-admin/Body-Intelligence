"""Resolve the same scoped Cloudflare credential used by BIL's existing site job.
Never print the token, change the existing site, DNS, or any existing Worker.
"""
import json
import os
import urllib.error
import urllib.request

TOKEN = os.environ.get('CLOUDFLARE_API_TOKEN', '').strip()
NAME = 'bil-friend-link-20261005'
if not TOKEN:
    raise SystemExit('OWNER_INPUT_REQUIRED: CLOUDFLARE_API_TOKEN is not configured for this job.')

def get(path):
    request = urllib.request.Request('https://api.cloudflare.com/client/v4' + path,
        headers={'Authorization': 'Bearer ' + TOKEN, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        # No response headers or raw body (and never the token) enter the logs.
        if error.code == 404:
            return 404, {}
        raise SystemExit(f'CLOUDFLARE_PREFLIGHT_HTTP_{error.code}')

status, data = get('/accounts')
accounts = data.get('result') or []
if status != 200 or not data.get('success') or len(accounts) != 1:
    raise SystemExit('CLOUDFLARE_ACCOUNT_AMBIGUOUS_OR_UNAVAILABLE')
account = str(accounts[0].get('id') or '')
if len(account) != 32 or any(c not in '0123456789abcdef' for c in account):
    raise SystemExit('INVALID_CLOUDFLARE_ACCOUNT_ID')
# Refuse to overwrite any existing script, even one with the proposed name.
status, data = get(f'/accounts/{account}/workers/scripts/{NAME}/settings')
if status != 404:
    raise SystemExit('WORKER_ALREADY_EXISTS_OR_CANNOT_ESTABLISH_ABSENCE: refusing overwrite.')
with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as handle:
    handle.write('CLOUDFLARE_ACCOUNT_ID=' + account + '\n')
print('NEW_ISOLATED_WEB_WORKER_PREFLIGHT=PASS')
