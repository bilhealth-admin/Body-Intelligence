#!/usr/bin/env node

/**
 * Guarded Google Play closed-testing release tool for BIL Android v5.
 *
 * The default invocation is a local-only dry run. It makes no OAuth request,
 * creates no App Edit, and uploads nothing. Live execution is deliberately
 * locked to the existing alpha track, versionCode 5, completed status, an
 * exact AAB SHA-256, and ERROR_IF_IN_REVIEW commit behavior.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

export const RELEASE_CONTRACT = Object.freeze({
  packageName: 'com.bilhealth.bodyintelligencelog',
  track: 'alpha',
  previousVersionCode: '4',
  versionCode: '5',
  status: 'completed',
  reviewBoundary: 'ERROR_IF_IN_REVIEW',
  releaseName: 'Body Intelligence Log 1.0.0 (5) - Quality and AI Coach',
});

export const RELEASE_NOTES = Object.freeze([
  Object.freeze({
    language: 'en-GB',
    text:
      'Quality and stability improvements across Body Intelligence Log. ' +
      'AI Coach reset and usage clarity were refined, workout and meal ' +
      'journeys improved, incremental food search and barcode handling ' +
      'strengthened, and reliability polished throughout.',
  }),
  Object.freeze({
    language: 'ar',
    text:
      'تحسينات في الجودة والاستقرار في Body Intelligence Log، مع تطوير ' +
      'وضوح استخدام وإعادة ضبط AI Coach، وتحسين مسارات التمارين والوجبات، ' +
      'وتعزيز البحث التدريجي عن الأطعمة والتعامل مع الباركود، ورفع موثوقية ' +
      'التطبيق عموماً.',
  }),
]);

const API_ROOT =
  'https://androidpublisher.googleapis.com/androidpublisher/v3';
const UPLOAD_ROOT =
  'https://androidpublisher.googleapis.com/upload/androidpublisher/v3';
const TOKEN_URI = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const JSON_TIMEOUT_MS = 60_000;
const UPLOAD_TIMEOUT_MS = 300_000;

const VALUE_FLAGS = new Set([
  '--aab',
  '--credentials',
  '--output',
  '--confirm-package',
  '--confirm-track',
  '--confirm-current-version-code',
  '--confirm-version-code',
  '--confirm-status',
  '--confirm-review-boundary',
  '--confirm-aab-sha256',
]);

export class SafeFailure extends Error {
  constructor(code, detail = null, report = null) {
    super(code);
    this.name = 'SafeFailure';
    this.code = code;
    this.detail = detail;
    this.report = report;
  }
}

function fail(code, detail = null) {
  throw new SafeFailure(code, detail);
}

export function parseArguments(argv = []) {
  const options = {
    mode: 'dry-run',
    help: false,
  };
  let explicitMode = null;
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index];
    if (item === '--help' || item === '-h') {
      options.help = true;
      continue;
    }
    if (item === '--execute' || item === '--dry-run') {
      const requested = item === '--execute' ? 'execute' : 'dry-run';
      if (explicitMode && explicitMode !== requested) {
        fail('CONFLICTING_MODES');
      }
      explicitMode = requested;
      options.mode = requested;
      continue;
    }
    if (!VALUE_FLAGS.has(item)) {
      fail('UNKNOWN_ARGUMENT', { argument: String(item).slice(0, 80) });
    }
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      fail('ARGUMENT_VALUE_REQUIRED', { argument: item });
    }
    const key = item.slice(2).replaceAll('-', '_');
    if (options[key] !== undefined) {
      fail('DUPLICATE_ARGUMENT', { argument: item });
    }
    options[key] = value;
    index += 1;
  }
  return options;
}

function isLowerHexSha256(value) {
  if (typeof value !== 'string' || value.length !== 64) return false;
  for (const character of value) {
    const isDigit = character >= '0' && character <= '9';
    const isHexLetter = character >= 'a' && character <= 'f';
    if (!isDigit && !isHexLetter) return false;
  }
  return true;
}

function resolveOutput(outputPath) {
  const output = path.resolve(outputPath);
  if (path.parse(output).root.slice(0, 2).toUpperCase() !== 'G:') {
    fail('OUTPUT_MUST_STAY_ON_G');
  }
  if (path.extname(output).toLowerCase() !== '.json') {
    fail('OUTPUT_MUST_BE_JSON');
  }
  return output;
}

function safeCredentialStructure(credentials) {
  return Boolean(
    credentials &&
      credentials.type === 'service_account' &&
      typeof credentials.client_email === 'string' &&
      credentials.client_email.endsWith('.gserviceaccount.com') &&
      typeof credentials.private_key === 'string' &&
      credentials.private_key.includes('BEGIN PRIVATE KEY') &&
      (credentials.token_uri === undefined ||
        credentials.token_uri === TOKEN_URI),
  );
}

function loadCredentials(credentialsPath) {
  let parsed;
  try {
    parsed = JSON.parse(
      fs.readFileSync(path.resolve(credentialsPath), 'utf8'),
    );
  } catch {
    fail('CREDENTIAL_FILE_UNREADABLE');
  }
  if (!safeCredentialStructure(parsed)) {
    fail('CREDENTIAL_FILE_INVALID');
  }
  return parsed;
}

async function inspectAab(aabPath) {
  const resolved = path.resolve(aabPath);
  if (path.extname(resolved).toLowerCase() !== '.aab') {
    fail('AAB_EXTENSION_REQUIRED');
  }
  let stat;
  let prefix;
  try {
    stat = fs.statSync(resolved);
    const descriptor = fs.openSync(resolved, 'r');
    try {
      prefix = Buffer.alloc(4);
      fs.readSync(descriptor, prefix, 0, 4, 0);
    } finally {
      fs.closeSync(descriptor);
    }
  } catch {
    fail('AAB_FILE_UNREADABLE');
  }
  if (!stat.isFile() || stat.size < 4 || prefix.toString('hex') !== '504b0304') {
    fail('AAB_FILE_INVALID');
  }
  const digest = crypto.createHash('sha256');
  try {
    for await (const chunk of fs.createReadStream(resolved)) {
      digest.update(chunk);
    }
  } catch {
    fail('AAB_HASH_FAILED');
  }
  return {
    path: resolved,
    basename: path.basename(resolved),
    byteLength: stat.size,
    sha256: digest.digest('hex'),
  };
}

function safeAabSummary(aab) {
  return aab
    ? {
        basename: aab.basename,
        byteLength: aab.byteLength,
        sha256: aab.sha256,
      }
    : null;
}

export function buildTrackUpdate() {
  return {
    track: RELEASE_CONTRACT.track,
    releases: [
      {
        name: RELEASE_CONTRACT.releaseName,
        versionCodes: [RELEASE_CONTRACT.versionCode],
        releaseNotes: RELEASE_NOTES.map((item) => ({ ...item })),
        status: RELEASE_CONTRACT.status,
      },
    ],
  };
}

export function buildCommitResource(editPath) {
  const query = new URLSearchParams({
    changesInReviewBehavior: RELEASE_CONTRACT.reviewBoundary,
  });
  return editPath + ':commit?' + query.toString();
}

export function plannedOperations() {
  return [
    'locally verify AAB ZIP signature and exact SHA-256',
    'authenticate with Android Publisher scope',
    'create one App Edit',
    'read alpha track, bundle catalog, and tester fingerprint',
    'require alpha completed versionCode 4 or idempotent completed versionCode 5',
    'upload the exact AAB only when versionCode 5 is absent',
    'require Google upload response versionCode 5 and matching SHA-256',
    'update the existing alpha track only, with status completed',
    'validate the App Edit before commit',
    'commit with changesInReviewBehavior=ERROR_IF_IN_REVIEW',
    'open a fresh App Edit and verify bundle, alpha release, and tester fingerprint',
    'delete every uncommitted or verification App Edit',
  ];
}

function baseReport(mode, aab = null) {
  return {
    generatedAt: new Date().toISOString(),
    mode,
    packageName: RELEASE_CONTRACT.packageName,
    track: RELEASE_CONTRACT.track,
    previousVersionCode: RELEASE_CONTRACT.previousVersionCode,
    targetVersionCode: RELEASE_CONTRACT.versionCode,
    targetStatus: RELEASE_CONTRACT.status,
    reviewBoundary: RELEASE_CONTRACT.reviewBoundary,
    releaseName: RELEASE_CONTRACT.releaseName,
    releaseNotes: RELEASE_NOTES.map((item) => ({ ...item })),
    aab: safeAabSummary(aab),
    plannedOperations: plannedOperations(),
    testerMutationEndpointUsed: false,
    mutationPerformed: false,
    committed: false,
  };
}

async function createDryRun(options) {
  const blockers = [];
  let aab = null;
  let credentialsReady = false;

  if (!options.aab) {
    blockers.push('AAB_PATH_REQUIRED_FOR_EXECUTION');
  } else {
    try {
      aab = await inspectAab(options.aab);
    } catch (error) {
      blockers.push(sanitizeFailure(error).code);
    }
  }

  if (!options.credentials) {
    blockers.push('CREDENTIAL_PATH_REQUIRED_FOR_EXECUTION');
  } else {
    try {
      loadCredentials(options.credentials);
      credentialsReady = true;
    } catch (error) {
      blockers.push(sanitizeFailure(error).code);
    }
  }

  if (!options.output) blockers.push('OUTPUT_PATH_REQUIRED_FOR_EXECUTION');

  const report = baseReport('dry-run-local-only', aab);
  report.networkRequestsMade = 0;
  report.credentialsReady = credentialsReady;
  report.remoteVersionCodeVerification = 'pending-live-execution';
  report.blockers = blockers;
  report.executionLock = {
    confirmationsRequired: [
      '--confirm-package ' + RELEASE_CONTRACT.packageName,
      '--confirm-track ' + RELEASE_CONTRACT.track,
      '--confirm-current-version-code ' +
        RELEASE_CONTRACT.previousVersionCode,
      '--confirm-version-code ' + RELEASE_CONTRACT.versionCode,
      '--confirm-status ' + RELEASE_CONTRACT.status,
      '--confirm-review-boundary ' + RELEASE_CONTRACT.reviewBoundary,
      '--confirm-aab-sha256 <exact-lowercase-sha256>',
    ],
  };
  return report;
}

function validateExecutionLock(options, aab) {
  const checks = [
    ['CONFIRM_PACKAGE_REQUIRED', options.confirm_package,
      RELEASE_CONTRACT.packageName],
    ['CONFIRM_TRACK_REQUIRED', options.confirm_track,
      RELEASE_CONTRACT.track],
    ['CONFIRM_CURRENT_VERSION_REQUIRED', options.confirm_current_version_code,
      RELEASE_CONTRACT.previousVersionCode],
    ['CONFIRM_VERSION_REQUIRED', options.confirm_version_code,
      RELEASE_CONTRACT.versionCode],
    ['CONFIRM_STATUS_REQUIRED', options.confirm_status,
      RELEASE_CONTRACT.status],
    ['CONFIRM_REVIEW_BOUNDARY_REQUIRED', options.confirm_review_boundary,
      RELEASE_CONTRACT.reviewBoundary],
  ];
  for (const [code, actual, expected] of checks) {
    if (actual !== expected) fail(code);
  }
  if (
    !isLowerHexSha256(options.confirm_aab_sha256) ||
    options.confirm_aab_sha256 !== aab.sha256
  ) {
    fail('CONFIRM_AAB_SHA256_REQUIRED');
  }
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

async function accessToken(credentials) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(
    JSON.stringify({
      iss: credentials.client_email,
      scope: SCOPE,
      aud: TOKEN_URI,
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = header + '.' + claims;
  let signature;
  try {
    signature = crypto
      .sign('RSA-SHA256', Buffer.from(signingInput), credentials.private_key)
      .toString('base64url');
  } catch {
    fail('GOOGLE_JWT_SIGNING_FAILED');
  }
  let response;
  try {
    response = await fetch(TOKEN_URI, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: signingInput + '.' + signature,
      }),
      signal: AbortSignal.timeout(JSON_TIMEOUT_MS),
    });
  } catch {
    fail('GOOGLE_OAUTH_NETWORK_FAILED');
  }
  const parsed = await response.json().catch(() => null);
  if (!response.ok || !parsed?.access_token) {
    fail('GOOGLE_OAUTH_FAILED', { httpStatus: response.status });
  }
  return parsed.access_token;
}

function apiErrorDetail(response, parsed) {
  const reasons = [];
  for (const item of parsed?.error?.details ?? []) {
    if (typeof item?.reason === 'string') reasons.push(item.reason);
  }
  return {
    httpStatus: response.status,
    status: parsed?.error?.status ?? null,
    reasons: [...new Set(reasons)].sort(),
  };
}

class PlayClient {
  constructor(token) {
    this.token = token;
    this.requestCount = 0;
  }

  async json(method, resource, body, label) {
    this.requestCount += 1;
    let response;
    try {
      response = await fetch(API_ROOT + resource, {
        method,
        headers: {
          Authorization: 'Bearer ' + this.token,
          Accept: 'application/json',
          ...(body === undefined
            ? {}
            : { 'Content-Type': 'application/json' }),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        signal: AbortSignal.timeout(JSON_TIMEOUT_MS),
      });
    } catch {
      fail(label + '_NETWORK_FAILED');
    }
    const text = await response.text();
    let parsed = null;
    if (text) {
      try {
        parsed = JSON.parse(text);
      } catch {
        if (!response.ok) {
          fail(label + '_FAILED', { httpStatus: response.status });
        }
        fail(label + '_INVALID_JSON');
      }
    }
    if (!response.ok) {
      fail(label + '_FAILED', apiErrorDetail(response, parsed));
    }
    return { httpStatus: response.status, value: parsed };
  }

  async upload(editPath, aab) {
    this.requestCount += 1;
    const query = new URLSearchParams({ uploadType: 'media' });
    const resource = editPath + '/bundles?' + query.toString();
    let response;
    try {
      response = await fetch(UPLOAD_ROOT + resource, {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + this.token,
          Accept: 'application/json',
          'Content-Type': 'application/octet-stream',
          'Content-Length': String(aab.byteLength),
        },
        body: fs.createReadStream(aab.path),
        duplex: 'half',
        signal: AbortSignal.timeout(UPLOAD_TIMEOUT_MS),
      });
    } catch {
      fail('BUNDLE_UPLOAD_NETWORK_FAILED');
    }
    const parsed = await response.json().catch(() => null);
    if (!response.ok) {
      fail('BUNDLE_UPLOAD_FAILED', apiErrorDetail(response, parsed));
    }
    if (!parsed) fail('BUNDLE_UPLOAD_INVALID_JSON');
    return { httpStatus: response.status, value: parsed };
  }
}

function versionCodes(release) {
  return (release?.versionCodes ?? []).map(String).sort();
}

function exactCompletedRelease(track, versionCode) {
  const releases = track?.releases ?? [];
  return (
    track?.track === RELEASE_CONTRACT.track &&
    releases.length === 1 &&
    releases[0]?.status === RELEASE_CONTRACT.status &&
    JSON.stringify(versionCodes(releases[0])) ===
      JSON.stringify([String(versionCode)])
  );
}

function findBundle(bundles, versionCode) {
  return (bundles?.bundles ?? []).find(
    (bundle) => String(bundle?.versionCode) === String(versionCode),
  );
}

export function classifyAlphaState(track, bundles, expectedSha256) {
  const targetBundle = findBundle(bundles, RELEASE_CONTRACT.versionCode);
  if (targetBundle) {
    const remoteSha256 = String(targetBundle.sha256 ?? '').toLowerCase();
    if (
      !isLowerHexSha256(remoteSha256) ||
      remoteSha256 !== expectedSha256
    ) {
      fail('REMOTE_VERSION_5_SHA256_MISMATCH');
    }
  }
  if (exactCompletedRelease(track, RELEASE_CONTRACT.versionCode)) {
    if (!targetBundle) fail('REMOTE_VERSION_5_BUNDLE_MISSING');
    return { state: 'already-completed', targetBundle };
  }
  if (!exactCompletedRelease(track, RELEASE_CONTRACT.previousVersionCode)) {
    fail('ALPHA_BASELINE_DRIFT');
  }
  return {
    state: targetBundle ? 'reuse-existing-version-5' : 'upload-version-5',
    targetBundle: targetBundle ?? null,
  };
}

function summarizeTrack(track) {
  return {
    track: track?.track ?? null,
    releases: (track?.releases ?? []).map((release) => ({
      name: release?.name ?? null,
      status: release?.status ?? null,
      versionCodes: versionCodes(release),
      releaseNoteLanguages: (release?.releaseNotes ?? [])
        .map((note) => note?.language)
        .filter(Boolean)
        .sort(),
    })),
  };
}

function summarizeBundle(bundle) {
  return bundle
    ? {
        versionCode: String(bundle.versionCode),
        sha256: String(bundle.sha256 ?? '').toLowerCase(),
      }
    : null;
}

function canonicalize(value) {
  if (Array.isArray(value)) {
    const values = value.map(canonicalize);
    return values.sort((left, right) =>
      JSON.stringify(left).localeCompare(JSON.stringify(right)),
    );
  }
  if (value && typeof value === 'object') {
    const output = {};
    for (const key of Object.keys(value).sort()) {
      output[key] = canonicalize(value[key]);
    }
    return output;
  }
  return value;
}

function testerFingerprint(testers) {
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(canonicalize(testers ?? {})))
    .digest('hex');
}

function packagePath() {
  return (
    '/applications/' + encodeURIComponent(RELEASE_CONTRACT.packageName)
  );
}

async function insertEdit(client, label) {
  const result = await client.json(
    'POST',
    packagePath() + '/edits',
    {},
    label,
  );
  const editId = result.value?.id;
  if (!editId) fail(label + '_ID_MISSING');
  return {
    httpStatus: result.httpStatus,
    editPath:
      packagePath() + '/edits/' + encodeURIComponent(String(editId)),
  };
}

async function readAlphaState(client, editPath, prefix) {
  const trackResource =
    editPath + '/tracks/' + encodeURIComponent(RELEASE_CONTRACT.track);
  const testersResource =
    editPath + '/testers/' + encodeURIComponent(RELEASE_CONTRACT.track);
  const [track, bundles, testers] = await Promise.all([
    client.json('GET', trackResource, undefined, prefix + '_TRACK_GET'),
    client.json('GET', editPath + '/bundles', undefined,
      prefix + '_BUNDLES_GET'),
    client.json('GET', testersResource, undefined, prefix + '_TESTERS_GET'),
  ]);
  return {
    track: track.value,
    bundles: bundles.value,
    testerFingerprint: testerFingerprint(testers.value),
    httpStatus: {
      track: track.httpStatus,
      bundles: bundles.httpStatus,
      testers: testers.httpStatus,
    },
  };
}

async function deleteEdit(client, editPath, label) {
  const result = await client.json('DELETE', editPath, undefined, label);
  return result.httpStatus;
}

function assertUploadedBundle(bundle, aab) {
  if (String(bundle?.versionCode) !== RELEASE_CONTRACT.versionCode) {
    fail('UPLOADED_VERSION_CODE_NOT_5');
  }
  if (String(bundle?.sha256 ?? '').toLowerCase() !== aab.sha256) {
    fail('UPLOADED_SHA256_MISMATCH');
  }
}

function assertVerifiedState(state, aab, beforeTesterFingerprint) {
  if (!exactCompletedRelease(state.track, RELEASE_CONTRACT.versionCode)) {
    fail('POST_COMMIT_ALPHA_VERIFICATION_FAILED');
  }
  const bundle = findBundle(state.bundles, RELEASE_CONTRACT.versionCode);
  if (!bundle) fail('POST_COMMIT_BUNDLE_5_MISSING');
  if (String(bundle.sha256 ?? '').toLowerCase() !== aab.sha256) {
    fail('POST_COMMIT_BUNDLE_SHA256_MISMATCH');
  }
  if (state.testerFingerprint !== beforeTesterFingerprint) {
    fail('POST_COMMIT_TESTER_FINGERPRINT_CHANGED');
  }
  return bundle;
}

async function executeRelease(options, aab, credentials) {
  const report = baseReport('execute-locked-alpha-v5', aab);
  report.outcome = 'started';
  report.steps = {};
  const token = await accessToken(credentials);
  const client = new PlayClient(token);
  let workEditPath = null;
  let committed = false;
  let failure = null;

  try {
    const inserted = await insertEdit(client, 'WORK_EDIT_INSERT');
    workEditPath = inserted.editPath;
    report.steps.workEditCreated = {
      ok: true,
      httpStatus: inserted.httpStatus,
    };

    const before = await readAlphaState(client, workEditPath, 'BEFORE');
    const classification = classifyAlphaState(
      before.track,
      before.bundles,
      aab.sha256,
    );
    report.remoteBefore = {
      track: summarizeTrack(before.track),
      bundle5: summarizeBundle(
        findBundle(before.bundles, RELEASE_CONTRACT.versionCode),
      ),
      testerFingerprint: before.testerFingerprint,
      httpStatus: before.httpStatus,
      classification: classification.state,
    };

    if (classification.state === 'already-completed') {
      report.outcome = 'already-completed-and-verified';
      report.steps.idempotentNoOp = true;
    } else {
      let bundle = classification.targetBundle;
    if (!bundle) {
      const uploaded = await client.upload(workEditPath, aab);
      assertUploadedBundle(uploaded.value, aab);
      bundle = uploaded.value;
      report.steps.bundleUpload = {
        ok: true,
        httpStatus: uploaded.httpStatus,
        bundle: summarizeBundle(bundle),
      };
      report.mutationPerformed = true;
    } else {
      assertUploadedBundle(bundle, aab);
      report.steps.bundleUpload = {
        ok: true,
        skipped: true,
        reason: 'matching-version-5-already-exists',
        bundle: summarizeBundle(bundle),
      };
    }

    const trackResource =
      workEditPath + '/tracks/' +
      encodeURIComponent(RELEASE_CONTRACT.track);
    const updated = await client.json(
      'PUT',
      trackResource,
      buildTrackUpdate(),
      'ALPHA_TRACK_UPDATE',
    );
    if (!exactCompletedRelease(
      updated.value,
      RELEASE_CONTRACT.versionCode,
    )) {
      fail('ALPHA_TRACK_UPDATE_RESPONSE_MISMATCH');
    }
    report.steps.trackUpdate = {
      ok: true,
      httpStatus: updated.httpStatus,
      track: summarizeTrack(updated.value),
    };
    report.mutationPerformed = true;

    const validated = await client.json(
      'POST',
      workEditPath + ':validate',
      undefined,
      'EDIT_VALIDATE',
    );
    report.steps.validateBeforeCommit = {
      ok: true,
      httpStatus: validated.httpStatus,
    };

    const committedEdit = await client.json(
      'POST',
      buildCommitResource(workEditPath),
      undefined,
      'EDIT_COMMIT',
    );
    committed = true;
    report.committed = true;
    report.steps.commit = {
      ok: true,
      httpStatus: committedEdit.httpStatus,
      changesInReviewBehavior: RELEASE_CONTRACT.reviewBoundary,
    };

    const verifyInsert = await insertEdit(client, 'VERIFY_EDIT_INSERT');
    report.steps.verifyEditCreated = {
      ok: true,
      httpStatus: verifyInsert.httpStatus,
    };
    try {
      const after = await readAlphaState(
        client,
        verifyInsert.editPath,
        'AFTER',
      );
      const verifiedBundle = assertVerifiedState(
        after,
        aab,
        before.testerFingerprint,
      );
      report.remoteAfter = {
        track: summarizeTrack(after.track),
        bundle5: summarizeBundle(verifiedBundle),
        testerFingerprint: after.testerFingerprint,
        testerFingerprintUnchanged: true,
        httpStatus: after.httpStatus,
      };
      report.steps.postCommitVerification = { ok: true };
    } finally {
      report.steps.verifyEditDeleted = {
        ok: true,
        httpStatus: await deleteEdit(
          client,
          verifyInsert.editPath,
          'VERIFY_EDIT_DELETE',
        ),
      };
    }
      report.outcome = 'committed-and-verified';
    }
  } catch (error) {
    failure = error;
    report.outcome = 'failed';
    report.failure = sanitizeFailure(error);
  } finally {
    if (workEditPath && !committed) {
      try {
        report.steps.workEditDeleted = {
          ok: true,
          httpStatus: await deleteEdit(
            client,
            workEditPath,
            'WORK_EDIT_DELETE',
          ),
        };
      } catch (cleanupError) {
        report.steps.workEditDeleted = {
          ok: false,
          failure: sanitizeFailure(cleanupError),
        };
        if (!failure) failure = cleanupError;
      }
    }
    report.networkRequestsMade = client.requestCount + 1;
  }

  if (failure) {
    throw new SafeFailure(
      sanitizeFailure(failure).code,
      sanitizeFailure(failure).detail,
      report,
    );
  }
  return report;
}

export function sanitizeFailure(error) {
  if (error instanceof SafeFailure) {
    return {
      code: error.code,
      ...(error.detail ? { detail: error.detail } : {}),
    };
  }
  return { code: 'UNEXPECTED_FAILURE' };
}

function writeReport(output, report) {
  const resolved = resolveOutput(output);
  try {
    fs.mkdirSync(path.dirname(resolved), { recursive: true });
    const temporary =
      resolved + '.tmp-' + process.pid + '-' + Date.now();
    fs.writeFileSync(
      temporary,
      JSON.stringify(report, null, 2) + String.fromCharCode(10),
      'utf8',
    );
    fs.renameSync(temporary, resolved);
  } catch (error) {
    if (error instanceof SafeFailure) throw error;
    fail('REPORT_WRITE_FAILED');
  }
}

function helpText() {
  return [
    'Default (zero network / zero mutation):',
    '  node tool/google_play/google_play_alpha_v5_release.mjs',
    '',
    'Optional local preflight inputs:',
    '  --aab <signed-v5.aab> --credentials <service-account.json>',
    '  --output G:/BIL_Temp/google-play-alpha-v5-report.json',
    '',
    'Live execution additionally requires --execute and every exact',
    'confirmation printed by the dry-run report, including the AAB SHA-256.',
    'The live path is permanently locked to package ' +
      RELEASE_CONTRACT.packageName + ', track alpha, versionCode 5,',
    'status completed, and ERROR_IF_IN_REVIEW.',
  ].join(String.fromCharCode(10));
}

export async function runCli(argv = process.argv.slice(2)) {
  const options = parseArguments(argv);
  if (options.help) return { help: helpText() };

  if (options.mode === 'dry-run') {
    const report = await createDryRun(options);
    if (options.output) writeReport(options.output, report);
    return { report };
  }

  if (!options.aab) fail('AAB_PATH_REQUIRED');
  if (!options.credentials) fail('CREDENTIAL_PATH_REQUIRED');
  if (!options.output) fail('OUTPUT_PATH_REQUIRED');
  resolveOutput(options.output);
  const aab = await inspectAab(options.aab);
  validateExecutionLock(options, aab);
  const credentials = loadCredentials(options.credentials);
  try {
    const report = await executeRelease(options, aab, credentials);
    writeReport(options.output, report);
    return { report };
  } catch (error) {
    const safe = sanitizeFailure(error);
    const report =
      error instanceof SafeFailure && error.report
        ? error.report
        : {
            ...baseReport('execute-locked-alpha-v5', aab),
            outcome: 'failed',
            failure: safe,
          };
    writeReport(options.output, report);
    throw new SafeFailure(safe.code, safe.detail, report);
  }
}

const isMain =
  Boolean(process.argv[1]) &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isMain) {
  runCli()
    .then((result) => {
      if (result.help) {
        process.stdout.write(result.help + String.fromCharCode(10));
      } else {
        process.stdout.write(
          JSON.stringify(result.report, null, 2) + String.fromCharCode(10),
        );
      }
    })
    .catch((error) => {
      process.stderr.write(sanitizeFailure(error).code +
        String.fromCharCode(10));
      process.exitCode = 1;
    });
}
