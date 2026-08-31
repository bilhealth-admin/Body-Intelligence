#!/usr/bin/env node

/**
 * Narrow App Store Connect mutation for the public en-US app name.
 * The request intentionally patches only appInfoLocalizations.name.
 */

import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const LOCALIZATION_ID = '2ed17031-9665-4f8f-9a75-e4efd2e4e178';
const TARGET_NAME = 'Body Intelligence Log';

const client = clientFromEnvironment();
const endpoint =
  `/v1/appInfoLocalizations/${LOCALIZATION_ID}` +
  '?fields[appInfoLocalizations]=locale,name,subtitle,privacyPolicyUrl,privacyChoicesUrl';

const before = await client.request('GET', endpoint);
const beforeName = before.data?.attributes?.name ?? null;

if (beforeName === TARGET_NAME) {
  process.stdout.write(`${JSON.stringify({ changed: false, name: beforeName })}\n`);
  process.exit(0);
}

if (!process.argv.includes('--apply') || process.env.ASC_ALLOW_MUTATION !== 'YES') {
  throw new Error(
    `Mutation refused. Current name is ${JSON.stringify(beforeName)}; ` +
      'pass --apply with ASC_ALLOW_MUTATION=YES after owner confirmation.',
  );
}

await client.request('PATCH', `/v1/appInfoLocalizations/${LOCALIZATION_ID}`, {
  data: {
    type: 'appInfoLocalizations',
    id: LOCALIZATION_ID,
    attributes: { name: TARGET_NAME },
  },
});

const after = await client.request('GET', endpoint);
const afterName = after.data?.attributes?.name ?? null;
if (afterName !== TARGET_NAME) {
  throw new Error(`Name read-back mismatch: ${JSON.stringify(afterName)}`);
}

process.stdout.write(
  `${JSON.stringify({ changed: true, before: beforeName, after: afterName })}\n`,
);
