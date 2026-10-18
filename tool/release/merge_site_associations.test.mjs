import assert from 'node:assert/strict';
import test from 'node:test';
import { completeBILAssociations } from './merge_site_associations.mjs';
import { hasAasaContract } from './bilhealth_site_worker.mjs';

const identity = 'A1B2C3D4E5.com.bilhealth.bodyintelligencelog';
test('completes missing member routes without replacing deployed identities or rules', () => {
  const original = { applinks: { details: [
    { appIDs: ['Z9Y8X7W6V5.example.other'], components: [{ '/': '/other' }] },
    { appIDs: [identity], components: [{ '/': '/auth/callback' }, { '/': '/legacy/*' }] },
  ] }, webcredentials: { apps: [identity] } };
  const result = completeBILAssociations(original);
  assert.equal(hasAasaContract(result), true);
  assert.deepEqual(result.applinks.details[0], original.applinks.details[0]);
  assert.deepEqual(result.webcredentials, original.webcredentials);
  assert.deepEqual(result.applinks.details[1].appIDs, [identity]);
  assert.deepEqual(result.applinks.details[1].components.slice(0, 2), original.applinks.details[1].components);
  assert.equal(original.applinks.details[1].components.length, 2);
  assert.deepEqual(completeBILAssociations(result), result);
});
test('retains legacy appID and paths while adding equivalent component routes', () => {
  const original = { applinks: { details: [{ appID: identity, paths: ['/auth/callback', 'NOT /private/*'] }] } };
  const result = completeBILAssociations(original);
  assert.equal(hasAasaContract(result), true);
  assert.equal(result.applinks.details[0].appID, identity);
  assert.deepEqual(result.applinks.details[0].paths, original.applinks.details[0].paths);
  assert.ok(result.applinks.details[0].components.some((rule) => rule.exclude && rule['/'] === '/private/*'));
});
test('never creates a production identity from unknown documents', () => {
  for (const document of [{}, { applinks: { details: [{ appIDs: ['invalid-team.com.bilhealth.bodyintelligencelog'] }] } }]) {
    assert.throws(() => completeBILAssociations(document));
  }
});
test('does not override deliberate exclusions', () => {
  for (const path of ['*', '/*', '/download', '/invite/*']) {
    const document = { applinks: { details: [{ appIDs: [identity], components: [{ '/': path, exclude: true }] }] } };
    assert.throws(() => completeBILAssociations(document), /explicit deployed exclusion/);
  }
});
