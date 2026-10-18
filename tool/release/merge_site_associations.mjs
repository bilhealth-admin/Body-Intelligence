import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { hasAasaContract } from './bilhealth_site_worker.mjs';

const appIdentity = /^[A-Z0-9]{10}\.com\.bilhealth\.bodyintelligencelog$/;
const paths = ['/auth/callback', '/auth/reset-password', '/invite/*', '/download'];

// Preserve deployed identities, other apps, and existing routing rules. Only
// complete routes implemented by BIL; explicit exclusions always fail closed.
export function completeBILAssociations(original) {
  const document = structuredClone(original);
  const details = document?.applinks?.details;
  if (!Array.isArray(details)) throw new Error('No deployed application identities');
  for (const detail of details) {
    const identities = Array.isArray(detail.appIDs) ? detail.appIDs : [detail.appID];
    if (!identities.some((value) => typeof value === 'string' && appIdentity.test(value))) continue;
    if (!Array.isArray(detail.components)) {
      detail.components = (detail.paths ?? []).map((path) => {
        if (typeof path !== 'string') throw new Error('Invalid deployed path rule');
        return path.startsWith('NOT ')
          ? { '/': path.slice(4), exclude: true }
          : { '/': path };
      });
    }
    for (const rule of detail.components) {
      if (rule.exclude === true && ['*', '/*', ...paths].includes(rule['/'])) {
        throw new Error('An explicit deployed exclusion requires owner review');
      }
    }
    if (!Array.isArray(detail.appIDs)) detail.appIDs = identities;
    for (const path of paths.slice(0, 3)) {
      if (!detail.components.some((rule) => rule['/'] === path && rule.exclude !== true)) {
        detail.components.push({ '/': path });
      }
    }
    if (!detail.components.some((rule) => rule['/'] === '/download'
      && rule.exclude !== true && rule['?']?.member === '?'.repeat(32))) {
      detail.components.push({ '/': '/download', '?': { member: '?'.repeat(32) } });
    }
    if (!hasAasaContract(document)) throw new Error('Completed association contract is invalid');
    return document;
  }
  throw new Error('No verified deployed BIL identity; refusing to invent one');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const path = process.argv[2];
  if (!path) throw new Error('A preserved AASA file is required');
  const original = JSON.parse(readFileSync(path, 'utf8'));
  writeFileSync(path, `${JSON.stringify(completeBILAssociations(original), null, 2)}\n`);
  console.log('BIL_ASSOCIATION_IDENTITIES_PRESERVED_ROUTES_COMPLETED=PASS');
}
