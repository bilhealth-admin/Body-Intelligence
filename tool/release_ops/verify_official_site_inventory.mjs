import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync, readdirSync, statSync, writeFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {join, resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const [candidate, output, toolchain] = process.argv.slice(2).map(value => resolve(value));
const source = '6bf23994712ffbdcb2d8179defec5852e5d08ae1';
const requireToolchain = createRequire(join(toolchain, 'package.json'));
// Internal official ESM bundles contain CommonJS builtin requires.
// Supply Node's standard require context without modifying package code.
globalThis.require = requireToolchain;
const wranglerVersion = requireToolchain('wrangler/package.json').version;
assert.equal(wranglerVersion, '4.125.0');
const helperPackage = JSON.parse(readFileSync(join(toolchain, 'node_modules/@cloudflare/deploy-helpers/package.json')));
assert.equal(helperPackage.version, '0.8.0');
const {buildAssetManifest, initDeployHelpersContext} = await import(pathToFileURL(join(toolchain, 'node_modules/@cloudflare/deploy-helpers/dist/index.mjs')));
const noNetwork = () => {throw new Error('Offline official asset collector attempted network');};
initDeployHelpersContext({logger: {loggerLevel: 'none', info() {}, debug() {}, log() {}, warn() {}, error() {}},
  fetchResult: noNetwork, fetchListResult: noNetwork, fetchPagedListResult: noNetwork, fetchKVGetValue: noNetwork,
  confirm: noNetwork, prompt: noNetwork, select: noNetwork});
const sha = value => createHash('sha256').update(value).digest('hex');
const official = await buildAssetManifest(join(candidate, 'public_site'));
const expected = JSON.parse(readFileSync(join(output, 'proposed-static-asset-manifest.json')));
assert.deepEqual(Object.keys(official).sort(), expected.map(row => row.path).sort(), 'Pinned Wrangler collector file set differs from reviewed inventory');
const recorded = {};
for (const row of expected) {
  const bytes = readFileSync(join(candidate, 'public_site', row.path));
  assert.equal(sha(bytes), row.sha256);
  assert.equal(official[row.path].size, bytes.length);
  assert.match(official[row.path].hash, /^[0-9a-f]+$/);
  recorded[row.path] = {...official[row.path], body_sha256: sha(bytes)};
}
for (const [name, expectedHash] of [['apple-app-site-association', 'f5b4e673f08264b75cf635b1a87da96ee85c96395f6b4979a33e8185b79cb455'], ['assetlinks.json', '5c6ae8e11182a7b60a5264a793e81cf8fd3cc69cd581ba4ad66f61e263786143']]) {
  assert.equal(recorded['/.well-known/' + name]?.body_sha256, expectedHash);
}
const staged = JSON.parse(readFileSync(join(output, 'deploy-project/wrangler.recovery.json')));
const sourceConfig = JSON.parse(readFileSync(join(candidate, 'wrangler.site.jsonc')));
assert.deepEqual(staged, {...sourceConfig, main: './worker/bilhealth_site_worker.mjs',
  assets: {...sourceConfig.assets, directory: join(candidate, 'public_site')}});
assert.equal(sha(readFileSync(join(output, 'deploy-project/worker/bilhealth_site_worker.mjs'))),
  sha(readFileSync(join(candidate, 'tool/release/bilhealth_site_worker.mjs'))));
const dryRoot = join(output, 'wrangler-dry-run');
const dryFiles = readdirSync(dryRoot, {recursive: true}).filter(name => statSync(join(dryRoot, name)).isFile() && name !== 'README.md');
assert.equal(dryFiles.length, 1, 'Unreviewed additional Wrangler module: SQL/data/modules may not join the site Worker');
assert.match(dryFiles[0], /\.(?:js|mjs)$/);
const workers = dryFiles;
const produced = readFileSync(join(dryRoot, workers[0]));
const original = readFileSync(join(candidate, 'tool/release/bilhealth_site_worker.mjs'));
assert.equal(produced.toString().replaceAll('\r\n', '\n'), original.toString().replaceAll('\r\n', '\n'), 'No-bundle output changed beyond line endings; review before deploy');
writeFileSync(join(output, 'official-wrangler-inventory.json'), JSON.stringify({status: 'PASS', source_sha: source,
  wrangler_version: wranglerVersion, deploy_helpers_version: helperPackage.version,
  collector: '@cloudflare/deploy-helpers buildAssetManifest exported by the pinned Wrangler4.125 source tag',
  dry_run_worker_file: workers[0], dry_run_worker_sha256: sha(produced), assets: recorded}, null, 2) + '\n');
console.log('PINNED_OFFICIAL_WRANGLER_ASSET_INVENTORY=PASS');

