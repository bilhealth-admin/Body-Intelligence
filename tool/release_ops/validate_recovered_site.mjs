import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const [candidate, output] = process.argv.slice(2).map(value => resolve(value));
const source = '6bf23994712ffbdcb2d8179defec5852e5d08ae1';
const {default: worker, hasAasaContract, hasAssetLinksContract} = await import(pathToFileURL(resolve(candidate, 'tool/release/bilhealth_site_worker.mjs')));
const {completeBILAssociations} = await import(pathToFileURL(resolve(candidate, 'tool/release/merge_site_associations.mjs')));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const manifest = JSON.parse(readFileSync(resolve(output, 'proposed-static-asset-manifest.json')));
const associations = [
  ['apple-app-site-association', hasAasaContract, 'f5b4e673f08264b75cf635b1a87da96ee85c96395f6b4979a33e8185b79cb455'],
  ['assetlinks.json', hasAssetLinksContract, '5c6ae8e11182a7b60a5264a793e81cf8fd3cc69cd581ba4ad66f61e263786143'],
];
const assets = {fetch: async request => {
  const pathname = new URL(request.url).pathname;
  assert.ok(pathname.startsWith('/.well-known/') || pathname.startsWith('/policy-pages/'));
  const raw = readFileSync(resolve(candidate, 'public_site' + pathname));
  return new Response(raw, {headers: {'Content-Type': pathname.endsWith('.html') ? 'text/html; charset=utf-8' : 'application/json; charset=utf-8'}});
}};
for (const [name, validate, expected] of associations) {
  const path = '/.well-known/' + name;
  const raw = readFileSync(resolve(candidate, 'public_site' + path));
  const original = readFileSync(resolve(output, 'recovered-originals', name));
  assert.equal(digest(raw), expected);
  assert.equal(digest(original), expected);
  const parsed = JSON.parse(raw);
  assert.equal(validate(parsed), true);
  if (name === 'apple-app-site-association') {
    assert.deepEqual(completeBILAssociations(parsed), parsed, 'Recovery already has every route; no identities, exclusions or rules may change');
  }
  assert.equal(manifest.find(entry => entry.path === path)?.sha256, expected);
  for (const method of ['GET', 'HEAD']) {
    const response = await worker.fetch(new Request('https://www.bilhealth.com' + path, {method}), {ASSETS: assets});
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type'), /^application\/json/);
    const body = Buffer.from(await response.arrayBuffer());
    assert.equal(method === 'GET' ? digest(body) : body.length, method === 'GET' ? expected : 0);
  }
}
const policyPaths = ['/privacy', '/terms', '/subscription-terms', '/health-disclaimer', '/account-deletion', '/data-deletion', '/support', '/community-guidelines', '/contact'];
for (const path of policyPaths) {
  for (const language of ['en', 'ar']) {
    const expected = readFileSync(resolve(candidate, `public_site/policy-pages${path}.${language}.html`));
    for (const method of ['GET', 'HEAD']) {
      const response = await worker.fetch(new Request(`https://www.bilhealth.com${path}?lang=${language}`, {method}), {ASSETS: assets});
      assert.equal(response.status, 200);
      assert.equal(response.headers.get('content-language'), language);
      const body = Buffer.from(await response.arrayBuffer());
      assert.equal(method === 'GET' ? digest(body) : body.length, method === 'GET' ? digest(expected) : 0);
    }
  }
}
writeFileSync(resolve(output, 'contracts.json'), JSON.stringify({status: 'PASS', source_sha: source,
  association_hashes: Object.fromEntries(associations.map(([name, , hash]) => [name, hash])),
  identity_or_rule_changes: false, policies_get_and_head: 36}, null, 2) + '\n');
console.log('EXACT_RECOVERED_SITE_SOURCE_CONTRACTS=PASS');
