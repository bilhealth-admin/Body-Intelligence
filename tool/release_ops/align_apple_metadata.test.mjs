// All HTTP replies, credentials and entity state in this file are synthetic.
// There is no use of global fetch and no external network operation.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { runAppleMetadataAlignment } from './align_apple_metadata.mjs';

const SOURCE = 'd781d520c3175438376d2db216e44a0675cc2170';
const hash = value => crypto.createHash('sha256').update(value, 'utf8').digest('hex');
const fixturePem = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' }).privateKey.export({ type: 'pkcs8', format: 'pem' });
const ids = {
  app_id: '6805349703', bundle_id: 'com.bilhealth.bodyintelligencelog',
  version_id: '7a132506-d5a8-4810-a51f-b2dc2bd636cf',
  review_id: 'ce559d08-1073-4d88-9887-7f31d1951533',
  localization_id: '3866ba6c-b637-4f70-9c53-d6274c37bc62',
};
function fixture(t, options = {}) {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'bil-apple-offline-'));
  t.after(() => fs.rmSync(out, { recursive: true, force: true }));
  const state = {
    app: { id: ids.app_id, attributes: { bundleId: ids.bundle_id } },
    version: { id: ids.version_id, attributes: { platform: 'IOS', versionString: '1.0.0', appStoreState: 'PREPARE_FOR_SUBMISSION', releaseType: 'MANUAL', usesIdfa: false } },
    build: null,
    review: { id: ids.review_id, attributes: {
      notes: 'Old preparation notes', demoAccountName: 'private-fixture-reviewer', demoAccountPassword: 'private-fixture-password',
      demoAccountRequired: true, contactFirstName: 'Private fixture contact', contactEmail: 'private-fixture-contact@example.invalid', contactPhone: 'private-fixture-phone',
    } },
    localization: { id: ids.localization_id, attributes: { locale: 'en-US', description: 'Old public description', keywords: 'nutrition,fitness', supportUrl: 'https://example.invalid/support', marketingUrl: 'https://example.invalid/' } },
  };
  const plan = { ...ids, source_sha: SOURCE, review_notes: 'Updated reviewed preparation notes', description: 'Updated public description', expected_description_sha256: hash(state.localization.attributes.description) };
  const env = {
    BIL_APPLE_EXPECTED_SOURCE: SOURCE,
    APP_STORE_CONNECT_KEY_ID: 'synthetic-key', APP_STORE_CONNECT_ISSUER_ID: 'synthetic-issuer',
    APP_STORE_CONNECT_PRIVATE_KEY_BASE64: Buffer.from(fixturePem).toString('base64'),
    BIL_APPLE_METADATA_APPLY: 'SAVE_REVIEW_PREPARATION_ONLY',
    BIL_EXPECTED_NOTE_SHA256: hash(state.review.attributes.notes),
  };
  const initial = structuredClone(state);
  const calls = [], reads = new Map();
  const resourceKeys = new Map([
    ['/v1/apps/' + ids.app_id, 'app'], ['/v1/appStoreVersions/' + ids.version_id, 'version'],
    ['/v1/appStoreVersions/' + ids.version_id + '/build', 'build'],
    ['/v1/appStoreReviewDetails/' + ids.review_id, 'review'],
    ['/v1/appStoreVersionLocalizations/' + ids.localization_id, 'localization'],
  ]);
  const fetcher = async (url, init) => {
    const parsed = new URL(url);
    assert.equal(parsed.origin, 'https://api.appstoreconnect.apple.com');
    assert.equal(init.redirect, 'error');
    const key = resourceKeys.get(parsed.pathname);
    assert.ok(key, 'Only the five reviewed resources are reachable.');
    assert.ok(['GET', 'PATCH'].includes(init.method));
    calls.push({ key, method: init.method, body: init.body ? JSON.parse(init.body) : undefined });
    if (init.method === 'GET') {
      const count = (reads.get(key) ?? 0) + 1;
      reads.set(key, count);
      options.onGet?.({ key, count, state, calls });
      return new Response(JSON.stringify({ data: state[key] }), { status: 200 });
    }
    assert.ok(['review', 'localization'].includes(key));
    const payload = JSON.parse(init.body).data;
    assert.deepEqual(Object.keys(payload.attributes), [key === 'review' ? 'notes' : 'description']);
    if (options.rejectPatch === key) return new Response('Not returned or logged by the writer', { status: 409 });
    Object.assign(state[key].attributes, payload.attributes);
    options.afterPatch?.({ key, state });
    if (options.ambiguousPatch === key) throw new Error('Synthetic lost response after accepted write');
    return new Response(JSON.stringify({ data: state[key] }), { status: 200 });
  };
  const run = () => runAppleMetadataAlignment({ plan, out, env, fetcher });
  const receipt = () => JSON.parse(fs.readFileSync(path.join(out, 'metadata-alignment-result.json'), 'utf8'));
  const patches = () => calls.filter(call => call.method === 'PATCH');
  return { out, state, initial, plan, env, calls, run, receipt, patches };
}

test('audit-only reads the fixed app and never writes or exports credentials', async t => {
  const f = fixture(t);
  delete f.env.BIL_APPLE_METADATA_APPLY;
  const result = await f.run();
  assert.equal(result.status, 'GET_AUDIT_ONLY');
  assert.equal(f.calls.length, 5);
  assert.equal(f.patches().length, 0);
  assert.deepEqual(f.state, f.initial);
  assert.deepEqual(result.credentialPresence, { username: true, password: true });
  const publicReport = JSON.stringify(f.receipt());
  for (const privateValue of ['private-fixture-reviewer', 'private-fixture-password', 'Private fixture contact', 'private-fixture-contact@example.invalid', 'private-fixture-phone', fixturePem]) {
    assert.equal(publicReport.includes(privateValue), false);
  }
});

test('saves exactly two text fields, reads them back and preserves every other attribute', async t => {
  const f = fixture(t);
  const result = await f.run();
  assert.equal(result.status, 'PREPARATION_TEXT_SAVED_NOT_RELEASE_CERTIFICATION');
  assert.equal(f.state.review.attributes.notes, f.plan.review_notes);
  assert.equal(f.state.localization.attributes.description, f.plan.description);
  const expected = structuredClone(f.initial);
  expected.review.attributes.notes = f.plan.review_notes;
  expected.localization.attributes.description = f.plan.description;
  assert.deepEqual(f.state, expected);
  assert.deepEqual(f.patches().map(call => call.key), ['review', 'localization']);
  assert.ok(result.mutations.every(mutation => mutation.status === 'SAVED_AND_EXACT_READBACK'));
  assert.equal(result.appPrivacyChanged, false);
  assert.equal(result.buildChanged, false);
  assert.equal(result.submissionRequested, false);
  assert.equal(result.privateFieldsPreserved, true);
  assert.equal(result.otherLocalizationFieldsPreserved, true);
  assert.deepEqual(f.receipt(), result);
});

for (const stale of ['notes', 'description']) {
  test('stale ' + stale + ' hash blocks all writes', async t => {
    const f = fixture(t);
    if (stale === 'notes') f.env.BIL_EXPECTED_NOTE_SHA256 = '0'.repeat(64);
    else f.plan.expected_description_sha256 = '0'.repeat(64);
    const result = await f.run();
    assert.equal(result.failure, stale === 'notes' ? 'STALE_REVIEW_NOTES' : 'STALE_DESCRIPTION');
    assert.equal(f.patches().length, 0);
    assert.deepEqual(f.state, f.initial);
  });
}

for (const change of ['draft', 'build']) {
  test('draft/build changed between initial audit and write guard blocks all writes: ' + change, async t => {
    const f = fixture(t, { onGet({ key, count, state }) {
      if (key === 'version' && count === 2 && change === 'draft') state.version.attributes.appStoreState = 'WAITING_FOR_REVIEW';
      if (key === 'build' && count === 2 && change === 'build') state.build = { id: 'synthetic-new-build' };
    } });
    const result = await f.run();
    assert.equal(result.failure, change === 'draft' ? 'DRAFT_STATE_MISMATCH' : 'BUILD_ALREADY_ATTACHED');
    assert.equal(f.patches().length, 0);
    assert.deepEqual(result.mutations, []);
  });
}

test('another operator changing review fields before write prevents overwrite', async t => {
  const f = fixture(t, { onGet({ key, count, state }) {
    if (key === 'review' && count === 2) state.review.attributes.notes = 'Other operator newer note';
  } });
  const result = await f.run();
  assert.equal(result.failure, 'REVIEW_CHANGED_BEFORE_WRITE');
  assert.equal(f.patches().length, 0);
  assert.equal(f.state.review.attributes.notes, 'Other operator newer note');
});

test('second PATCH rejection preserves the first saved field and a partial-write receipt', async t => {
  const f = fixture(t, { rejectPatch: 'localization' });
  const result = await f.run();
  assert.equal(result.status, 'BLOCKED_OR_PARTIAL_WRITE_REQUIRES_READBACK');
  assert.equal(result.httpStatus, 409);
  assert.equal(f.state.review.attributes.notes, f.plan.review_notes);
  assert.equal(f.state.localization.attributes.description, f.initial.localization.attributes.description);
  assert.deepEqual(result.mutations.map(mutation => mutation.status), ['SAVED_AND_EXACT_READBACK', 'PATCH_ATTEMPTED_READBACK_REQUIRED']);
  assert.deepEqual(f.receipt(), result);
});

test('ambiguous accepted PATCH is never retried and keeps readback-required intent', async t => {
  const f = fixture(t, { ambiguousPatch: 'review' });
  const result = await f.run();
  assert.equal(result.status, 'BLOCKED_OR_PARTIAL_WRITE_REQUIRES_READBACK');
  assert.equal(f.patches().length, 1);
  assert.equal(f.state.review.attributes.notes, f.plan.review_notes);
  assert.equal(f.state.localization.attributes.description, f.initial.localization.attributes.description);
  assert.equal(result.mutations[0].status, 'PATCH_ATTEMPTED_READBACK_REQUIRED');
  assert.deepEqual(f.receipt(), result);
});

test('unexpected private-field change on readback blocks the next write without exporting its value', async t => {
  const f = fixture(t, { afterPatch({ key, state }) {
    if (key === 'review') state.review.attributes.demoAccountPassword = 'another-private-fixture-password';
  } });
  const result = await f.run();
  assert.equal(result.failure, 'UNTOUCHED_FIELD_MISMATCH');
  assert.equal(result.privateFieldsPreserved, false);
  assert.equal(result.privateFieldsChanged, true);
  assert.equal(f.patches().length, 1);
  assert.equal(JSON.stringify(f.receipt()).includes('another-private-fixture-password'), false);
});

test('source expectation is mandatory and mismatches do not authenticate or call HTTP', async t => {
  for (const expected of [undefined, 'short', 'f'.repeat(40)]) {
    const f = fixture(t);
    f.env.BIL_APPLE_EXPECTED_SOURCE = expected;
    const result = await f.run();
    assert.equal(result.failure, expected?.length === 40 ? 'UNEXPECTED_PLAN_SOURCE' : 'EXPECTED_SOURCE_REQUIRED');
    assert.equal(f.calls.length, 0);
  }
});

test('another app/resource plan is rejected before credentials or HTTP', async t => {
  for (const key of ['app_id', 'bundle_id', 'version_id', 'review_id', 'localization_id']) {
    const f = fixture(t);
    f.plan[key] = 'unapproved-resource';
    const result = await f.run();
    assert.equal(result.failure, 'UNEXPECTED_PLAN_IDENTITY');
    assert.equal(f.calls.length, 0);
  }
});
