import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  RELEASE_CONTRACT,
  RELEASE_NOTES,
  SafeFailure,
  buildCommitResource,
  buildTrackUpdate,
  classifyAlphaState,
  parseArguments,
  plannedOperations,
  sanitizeFailure,
} from './google_play_alpha_v5_release.mjs';

test('release contract is permanently locked to existing closed alpha v5', () => {
  assert.equal(RELEASE_CONTRACT.packageName,
    'com.bilhealth.bodyintelligencelog');
  assert.equal(RELEASE_CONTRACT.track, 'alpha');
  assert.equal(RELEASE_CONTRACT.previousVersionCode, '4');
  assert.equal(RELEASE_CONTRACT.versionCode, '5');
  assert.equal(RELEASE_CONTRACT.status, 'completed');
  assert.equal(RELEASE_CONTRACT.reviewBoundary, 'ERROR_IF_IN_REVIEW');
});

test('track body contains exact release and concise English/Arabic notes', () => {
  const body = buildTrackUpdate();
  assert.equal(body.track, 'alpha');
  assert.equal(body.releases.length, 1);
  assert.deepEqual(body.releases[0].versionCodes, ['5']);
  assert.equal(body.releases[0].status, 'completed');
  assert.deepEqual(
    body.releases[0].releaseNotes.map((note) => note.language),
    ['en-GB', 'ar'],
  );
  for (const note of RELEASE_NOTES) {
    assert.ok(note.text.length > 80);
    assert.ok(note.text.length <= 500);
  }
  assert.match(RELEASE_NOTES[0].text, /AI Coach/);
  assert.match(RELEASE_NOTES[0].text, /workout and meal/);
  assert.match(RELEASE_NOTES[0].text, /food search and barcode/);
  assert.match(RELEASE_NOTES[1].text, /AI Coach/);
  assert.match(RELEASE_NOTES[1].text, /التمارين والوجبات/);
  assert.match(RELEASE_NOTES[1].text, /الباركود/);
});

test('commit always uses ERROR_IF_IN_REVIEW and no implicit review flags', () => {
  const resource = buildCommitResource('/applications/x/edits/y');
  assert.equal(
    resource,
    '/applications/x/edits/y:commit?' +
      'changesInReviewBehavior=ERROR_IF_IN_REVIEW',
  );
  assert.equal(resource.includes('changesNotSentForReview'), false);
});

test('default CLI mode is dry-run and conflicting modes are rejected', () => {
  assert.equal(parseArguments([]).mode, 'dry-run');
  assert.equal(parseArguments(['--execute']).mode, 'execute');
  assert.throws(
    () => parseArguments(['--execute', '--dry-run']),
    (error) => error instanceof SafeFailure &&
      error.code === 'CONFLICTING_MODES',
  );
});

test('default process makes zero network calls and performs zero mutation', () => {
  const script = fileURLToPath(
    new URL('./google_play_alpha_v5_release.mjs', import.meta.url),
  );
  const result = spawnSync(process.execPath, [script], {
    cwd: process.cwd(),
    encoding: 'utf8',
    env: {
      ...process.env,
      GOOGLE_APPLICATION_CREDENTIALS: '',
    },
  });
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.mode, 'dry-run-local-only');
  assert.equal(report.networkRequestsMade, 0);
  assert.equal(report.mutationPerformed, false);
  assert.equal(report.committed, false);
  assert.equal(report.testerMutationEndpointUsed, false);
  assert.ok(report.blockers.includes('AAB_PATH_REQUIRED_FOR_EXECUTION'));
  assert.ok(report.blockers.includes(
    'CREDENTIAL_PATH_REQUIRED_FOR_EXECUTION',
  ));
});

test('plan orders validation before guarded commit and independent verify', () => {
  const plan = plannedOperations();
  const validateIndex = plan.findIndex((item) =>
    item.includes('validate the App Edit'));
  const commitIndex = plan.findIndex((item) =>
    item.includes('commit with'));
  const verifyIndex = plan.findIndex((item) =>
    item.includes('fresh App Edit'));
  assert.ok(validateIndex >= 0);
  assert.ok(commitIndex > validateIndex);
  assert.ok(verifyIndex > commitIndex);
  assert.ok(plan.some((item) => item.includes('existing alpha track only')));
});

test('alpha baseline accepts exact v4, and target state is idempotent', () => {
  const baseline = {
    track: 'alpha',
    releases: [{ status: 'completed', versionCodes: ['4'] }],
  };
  assert.deepEqual(
    classifyAlphaState(baseline, { bundles: [] }, 'a'.repeat(64)),
    { state: 'upload-version-5', targetBundle: null },
  );
  const targetBundle = {
    versionCode: 5,
    sha256: 'b'.repeat(64),
  };
  const completed = {
    track: 'alpha',
    releases: [{ status: 'completed', versionCodes: ['5'] }],
  };
  assert.deepEqual(
    classifyAlphaState(
      completed,
      { bundles: [targetBundle] },
      'b'.repeat(64),
    ),
    { state: 'already-completed', targetBundle },
  );
});

test('alpha drift and remote SHA mismatch are fail-closed', () => {
  assert.throws(
    () => classifyAlphaState(
      {
        track: 'beta',
        releases: [{ status: 'completed', versionCodes: ['4'] }],
      },
      { bundles: [] },
      'a'.repeat(64),
    ),
    (error) => sanitizeFailure(error).code === 'ALPHA_BASELINE_DRIFT',
  );
  assert.throws(
    () => classifyAlphaState(
      {
        track: 'alpha',
        releases: [{ status: 'completed', versionCodes: ['4'] }],
      },
      { bundles: [{ versionCode: 5, sha256: 'b'.repeat(64) }] },
      'a'.repeat(64),
    ),
    (error) =>
      sanitizeFailure(error).code ===
        'REMOTE_VERSION_5_SHA256_MISMATCH',
  );
  assert.throws(
    () => classifyAlphaState(
      {
        track: 'alpha',
        releases: [{ status: 'completed', versionCodes: ['5'] }],
      },
      { bundles: [{ versionCode: 5 }] },
      'a'.repeat(64),
    ),
    (error) =>
      sanitizeFailure(error).code ===
        'REMOTE_VERSION_5_SHA256_MISMATCH',
  );
});

test('source never mutates testers and upload is unavailable in dry run', () => {
  const source = fs.readFileSync(
    new URL('./google_play_alpha_v5_release.mjs', import.meta.url),
    'utf8',
  );
  assert.equal(source.includes("client.json('PUT', testersResource"), false);
  assert.equal(source.includes("client.json('PATCH', testersResource"), false);
  assert.match(source, /if \(options\.mode === 'dry-run'\)/);
  assert.match(source, /const credentials = loadCredentials/);
  assert.ok(
    source.indexOf("if (options.mode === 'dry-run')") <
      source.indexOf('const credentials = loadCredentials'),
  );
});
