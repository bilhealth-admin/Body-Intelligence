#!/usr/bin/env bash

load_private_review_account() {
  local key_id="$1"
  local issuer_id="$2"
  local private_key_base64="$3"
  ASC_PRIVATE_KEY_BASE64="$private_key_base64" python3 - "$ASC_KEY_PATH" <<'PY'
import base64
import os
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_bytes(
    base64.b64decode(os.environ['ASC_PRIVATE_KEY_BASE64'], validate=True),
)
PY
  chmod 600 "$ASC_KEY_PATH"

  # Both values remain in one mode-0600 runner-temp file for this shell step.
  env ASC_KEY_ID="$key_id" ASC_ISSUER_ID="$issuer_id" \
    ASC_PRIVATE_KEY_PATH="$ASC_KEY_PATH" \
    BIL_REVIEW_CREDENTIALS_PATH="$REVIEW_CREDENTIALS" \
    node --input-type=module <<'NODE'
import fs from 'node:fs';
import { clientFromEnvironment } from './tool/apple_store_connect/asc_catalog_sync.mjs';

const client = clientFromEnvironment();
const versions = await client.all(
  '/v1/apps/6805349703/appStoreVersions?filter[platform]=IOS&limit=200',
);
const version = versions.find(
  (item) => item.attributes?.versionString === '1.0.0',
);
if (!version) throw new Error('App Store version 1.0.0 was not found.');
const response = await client.request(
  'GET',
  `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`,
);
const attributes = response?.data?.attributes ?? {};
const email = String(attributes.demoAccountName ?? '').trim();
const password = String(attributes.demoAccountPassword ?? '');
if (!email || !password) {
  throw new Error('Private App Store review credentials are incomplete.');
}
const escape = (value) => value
  .replaceAll('%', '%25')
  .replaceAll('\r', '%0D')
  .replaceAll('\n', '%0A');
process.stdout.write(`::add-mask::${escape(email)}\n`);
process.stdout.write(`::add-mask::${escape(password)}\n`);
fs.writeFileSync(
  process.env.BIL_REVIEW_CREDENTIALS_PATH,
  `${JSON.stringify({ email, password })}\n`,
  { encoding: 'utf8', mode: 0o600 },
);
fs.chmodSync(process.env.BIL_REVIEW_CREDENTIALS_PATH, 0o600);
process.stdout.write('APP_STORE_PRIVATE_REVIEW_CREDENTIAL_SCOPE=STEP_LOCAL_0600\n');
NODE
  rm -f "$ASC_KEY_PATH"
}
