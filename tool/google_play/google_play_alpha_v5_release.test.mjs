import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  PlayClient,
  RELEASE_CONTRACT,
  RELEASE_NOTES,
  SafeFailure,
  apiErrorDetail,
  buildResumableChunkHeaders,
  buildResumableInitiationHeaders,
  buildResumableStatusHeaders,
  buildCommitResource,
  buildReadOnlyPreflightResource,
  buildTrackUpdate,
  classifyAlphaState,
  parseArguments,
  plannedOperations,
  resumableOffsetFromRange,
  sanitizeGoogleErrorMessage,
  sanitizeFailure,
} from './google_play_alpha_v5_release.mjs';

const TEST_CHUNK_BYTES = 256 * 1024;

async function requestBodyBytes(body) {
  const chunks = [];
  for await (const chunk of body) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

async function withTemporaryAab(byteLength, callback) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'bil-play-aab-'));
  const aabPath = path.join(directory, 'test.aab');
  fs.writeFileSync(aabPath, Buffer.alloc(byteLength, 0x42));
  try {
    return await callback({ path: aabPath, byteLength });
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

test('release contract is permanently locked to existing closed alpha v5', () => {
  assert.equal(RELEASE_CONTRACT.packageName,
    'com.bilhealth.bodyintelligencelog');
  assert.equal(RELEASE_CONTRACT.track, 'alpha');
  assert.equal(RELEASE_CONTRACT.previousVersionCode, '4');
  assert.equal(RELEASE_CONTRACT.versionCode, '5');
  assert.equal(RELEASE_CONTRACT.status, 'completed');
  assert.equal(RELEASE_CONTRACT.reviewBoundary, 'ERROR_IF_IN_REVIEW');
  assert.ok(RELEASE_CONTRACT.releaseName.length <= 50);
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
  assert.equal(
    RELEASE_NOTES[1].text.includes('Ø') ||
      RELEASE_NOTES[1].text.includes('Ù'),
    false,
    'Arabic release notes must be real UTF-8 Arabic, never mojibake',
  );
  assert.equal(RELEASE_NOTES[1].text.startsWith('تحسينات'), true);
  assert.deepEqual(
    [...RELEASE_NOTES[1].text.slice(0, 7)].map(
      (character) => character.codePointAt(0),
    ),
    [1578, 1581, 1587, 1610, 1606, 1575, 1578],
  );
  assert.equal(
    [...RELEASE_NOTES[1].text].some((character) =>
      [195, 216, 217, 65533].includes(character.codePointAt(0))),
    false,
    'Arabic release notes must not contain mojibake sentinels',
  );
  assert.equal(
    Buffer.from(RELEASE_NOTES[1].text, 'utf8').toString('utf8'),
    RELEASE_NOTES[1].text,
  );
});

test('Google API errors retain one bounded sanitized diagnostic message', () => {
  const detail = apiErrorDetail(
    { status: 400 },
    {
      error: {
        status: 'INVALID_ARGUMENT',
        message:
          ' Invalid release note\nBearer secret-token ' +
          'access_token=secret-value&field=releaseNotes ',
        details: [{ reason: 'TRACK_INVALID' }],
        errors: [
          { reason: 'RELEASE_NOTE_INVALID' },
          { reason: 'TRACK_INVALID' },
        ],
      },
    },
  );
  assert.deepEqual(detail, {
    httpStatus: 400,
    status: 'INVALID_ARGUMENT',
    reasons: ['RELEASE_NOTE_INVALID', 'TRACK_INVALID'],
    message:
      'Invalid release note Bearer [REDACTED] ' +
      'access_token=[REDACTED]&field=releaseNotes',
  });
  assert.equal(detail.message.includes('secret-token'), false);
  assert.equal(detail.message.includes('secret-value'), false);

  const bounded = sanitizeGoogleErrorMessage('x'.repeat(1_000));
  assert.equal(bounded.length, 400);
  assert.equal(bounded.endsWith('...'), true);
  assert.equal(sanitizeGoogleErrorMessage('\n\t'), null);
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
  assert.equal(
    parseArguments(['--read-only-preflight']).mode,
    'read-only-preflight',
  );
  assert.throws(
    () => parseArguments(['--execute', '--dry-run']),
    (error) => error instanceof SafeFailure &&
      error.code === 'CONFLICTING_MODES',
  );
  const resource = buildReadOnlyPreflightResource();
  assert.equal(
    resource,
    '/applications/com.bilhealth.bodyintelligencelog/reviews?maxResults=1',
  );
  assert.equal(resource.includes('/edits'), false);
  assert.equal(resource.includes('/bundles'), false);
  assert.equal(resource.includes('/tracks'), false);
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

test('resumable requests use exact initiation, chunk, and status headers', () => {
  assert.deepEqual(
    buildResumableInitiationHeaders('test-token', 600000),
    {
      Authorization: 'Bearer test-token',
      Accept: 'application/json',
      'Content-Length': '0',
      'X-Upload-Content-Type': 'application/octet-stream',
      'X-Upload-Content-Length': '600000',
    },
  );
  assert.deepEqual(
    buildResumableChunkHeaders('test-token', 262144, 524287, 600000),
    {
      Authorization: 'Bearer test-token',
      Accept: 'application/json',
      'Content-Type': 'application/octet-stream',
      'Content-Length': '262144',
      'Content-Range': 'bytes 262144-524287/600000',
    },
  );
  assert.deepEqual(
    buildResumableStatusHeaders('test-token', 600000),
    {
      Authorization: 'Bearer test-token',
      Accept: 'application/json',
      'Content-Length': '0',
      'Content-Range': 'bytes */600000',
    },
  );
});

test('308 Range is authoritative for the next resumable offset', () => {
  assert.equal(resumableOffsetFromRange(null, 600000), 0);
  assert.equal(
    resumableOffsetFromRange('bytes=0-262143', 600000),
    262144,
  );
  assert.equal(resumableOffsetFromRange('0-42', 600000), 43);
  assert.throws(
    () => resumableOffsetFromRange('bytes=1-42', 600000),
    (error) => error instanceof SafeFailure &&
      error.code === 'BUNDLE_UPLOAD_RANGE_INVALID',
  );
  assert.throws(
    () => resumableOffsetFromRange('bytes=0-599999', 600000),
    (error) => error instanceof SafeFailure &&
      error.code === 'BUNDLE_UPLOAD_RANGE_INVALID',
  );
});

test('chunk upload advances only from Google 308 Range', async () => {
  const byteLength = TEST_CHUNK_BYTES + 7;
  await withTemporaryAab(byteLength, async (aab) => {
    const sessionUri =
      'https://androidpublisher.googleapis.com/upload/session?id=test';
    const calls = [];
    const fetchImpl = async (url, options) => {
      calls.push({ url: String(url), options });
      if (calls.length === 1) {
        assert.match(String(url), /uploadType=resumable/);
        assert.equal(options.method, 'POST');
        assert.equal(options.redirect, 'manual');
        return new Response(null, {
          status: 200,
          headers: { Location: sessionUri },
        });
      }
      if (calls.length === 2) {
        assert.equal(options.headers['Content-Range'],
          `bytes 0-${TEST_CHUNK_BYTES - 1}/${byteLength}`);
        assert.equal((await requestBodyBytes(options.body)).length,
          TEST_CHUNK_BYTES);
        return new Response(null, {
          status: 308,
          headers: { Range: `bytes=0-${TEST_CHUNK_BYTES - 1}` },
        });
      }
      assert.equal(options.headers['Content-Range'],
        `bytes ${TEST_CHUNK_BYTES}-${byteLength - 1}/${byteLength}`);
      assert.equal((await requestBodyBytes(options.body)).length, 7);
      return new Response(JSON.stringify({ versionCode: 5 }), {
        status: 201,
        headers: { 'Content-Type': 'application/json' },
      });
    };
    const client = new PlayClient('test-token', {
      fetchImpl,
      sleep: async () => {},
      chunkBytes: TEST_CHUNK_BYTES,
    });
    const result = await client.upload('/applications/p/edits/e', aab);
    assert.equal(result.httpStatus, 201);
    assert.equal(result.value.versionCode, 5);
    assert.equal(client.requestCount, 3);
  });
});

test('network interruption queries status and resumes confirmed offset',
  async () => {
    const byteLength = TEST_CHUNK_BYTES + 11;
    await withTemporaryAab(byteLength, async (aab) => {
      const sessionUri =
        'https://androidpublisher.googleapis.com/upload/session?id=resume';
      let call = 0;
      const fetchImpl = async (url, options) => {
        call += 1;
        if (call === 1) {
          return new Response(null, {
            status: 200,
            headers: { Location: sessionUri },
          });
        }
        if (call === 2) {
          assert.equal(options.headers['Content-Range'],
            `bytes 0-${TEST_CHUNK_BYTES - 1}/${byteLength}`);
          throw new Error('simulated connection loss after server receive');
        }
        if (call === 3) {
          assert.equal(String(url), sessionUri);
          assert.equal(options.method, 'PUT');
          assert.equal(options.body, undefined);
          assert.equal(options.headers['Content-Length'], '0');
          assert.equal(options.headers['Content-Range'],
            `bytes */${byteLength}`);
          return new Response(null, {
            status: 308,
            headers: { Range: `bytes=0-${TEST_CHUNK_BYTES - 1}` },
          });
        }
        assert.equal(options.headers['Content-Range'],
          `bytes ${TEST_CHUNK_BYTES}-${byteLength - 1}/${byteLength}`);
        assert.equal((await requestBodyBytes(options.body)).length, 11);
        return new Response(JSON.stringify({ versionCode: 5 }), {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        });
      };
      const client = new PlayClient('test-token', {
        fetchImpl,
        sleep: async () => {},
        chunkBytes: TEST_CHUNK_BYTES,
      });
      const result = await client.upload('/applications/p/edits/e', aab);
      assert.equal(result.value.versionCode, 5);
      assert.equal(call, 4);
      assert.equal(client.requestCount, 4);
    });
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
      source.lastIndexOf('const credentials = loadCredentials'),
  );
});
