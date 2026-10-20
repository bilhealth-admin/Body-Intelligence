// Preparation-only writer. Default mode is GET/audit. No App Privacy,
// purchases, build association, agreement or submission endpoint is callable.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

const ROOT = 'https://api.appstoreconnect.apple.com';
const FIXED = Object.freeze({
  app_id: '6805349703',
  bundle_id: 'com.bilhealth.bodyintelligencelog',
  version_id: '7a132506-d5a8-4810-a51f-b2dc2bd636cf',
  review_id: 'ce559d08-1073-4d88-9887-7f31d1951533',
  localization_id: '3866ba6c-b637-4f70-9c53-d6274c37bc62',
});
const hash = value => crypto.createHash('sha256').update(value, 'utf8').digest('hex');
const omit = (attributes, key) => Object.fromEntries(Object.entries(attributes).filter(([name]) => name !== key));
function guard(condition, code) {
  if (!condition) { const error = new Error(code); error.code = 'BIL_GUARD'; throw error; }
}
function jwt(env) {
  const id = env.APP_STORE_CONNECT_KEY_ID;
  const issuer = env.APP_STORE_CONNECT_ISSUER_ID;
  const encoded = env.APP_STORE_CONNECT_PRIVATE_KEY_BASE64;
  guard(id && issuer && encoded, 'MISSING_APPLE_CREDENTIALS');
  const now = Math.floor(Date.now() / 1000);
  const part = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const input = part({ alg: 'ES256', kid: id, typ: 'JWT' }) + '.' + part({ iss: issuer, iat: now - 5, exp: now + 600, aud: 'appstoreconnect-v1' });
  return input + '.' + crypto.sign('sha256', Buffer.from(input), {
    key: Buffer.from(encoded, 'base64'), dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
}

export async function runAppleMetadataAlignment({ plan, out, env = process.env, fetcher = fetch }) {
  fs.mkdirSync(out, { recursive: true });
  const report = {
    checkedAt: new Date().toISOString(), source: plan?.source_sha ?? null,
    status: 'NOT_VERIFIED', appPrivacyChanged: false, privateFieldsChanged: false,
    privateFieldsPreserved: null, otherLocalizationFieldsPreserved: null,
    productsChanged: false, buildChanged: false, submissionRequested: false, mutations: [],
  };
  const save = () => fs.writeFileSync(path.join(out, 'metadata-alignment-result.json'), JSON.stringify(report, null, 2) + '\n');
  const routes = {
    app: '/v1/apps/' + FIXED.app_id,
    version: '/v1/appStoreVersions/' + FIXED.version_id,
    build: '/v1/appStoreVersions/' + FIXED.version_id + '/build',
    review: '/v1/appStoreReviewDetails/' + FIXED.review_id,
    localization: '/v1/appStoreVersionLocalizations/' + FIXED.localization_id,
  };
  let token;
  async function api(resource, method = 'GET', body) {
    guard(Object.values(routes).includes(resource), 'UNREVIEWED_RESOURCE');
    guard(method === 'GET' || (method === 'PATCH' && [routes.review, routes.localization].includes(resource)), 'UNREVIEWED_METHOD');
    const response = await fetcher(ROOT + resource, {
      method, redirect: 'error', signal: AbortSignal.timeout(20000),
      headers: { Authorization: 'Bearer ' + token, Accept: 'application/json', 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) {
      const error = new Error('APPLE_METADATA_HTTP_FAILURE');
      error.httpStatus = response.status;
      throw error;
    }
    return response.json();
  }
  async function snapshot() {
    const [app, version, build, review, localization] = await Promise.all(Object.values(routes).map(resource => api(resource)));
    guard(app.data?.id === FIXED.app_id, 'APP_ID_MISMATCH');
    guard(app.data.attributes?.bundleId === FIXED.bundle_id, 'BUNDLE_ID_MISMATCH');
    guard(version.data?.id === FIXED.version_id, 'VERSION_ID_MISMATCH');
    guard(version.data.attributes?.platform === 'IOS', 'PLATFORM_MISMATCH');
    guard(version.data.attributes.versionString === '1.0.0', 'VERSION_STRING_MISMATCH');
    guard(version.data.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION', 'DRAFT_STATE_MISMATCH');
    guard(build.data === null, 'BUILD_ALREADY_ATTACHED');
    guard(review.data?.id === FIXED.review_id, 'REVIEW_ID_MISMATCH');
    guard(localization.data?.id === FIXED.localization_id, 'LOCALIZATION_ID_MISMATCH');
    guard(localization.data.attributes?.locale === 'en-US', 'LOCALE_MISMATCH');
    return { app: app.data, version: version.data, review: review.data, localization: localization.data };
  }
  try {
    guard(plan && typeof plan === 'object', 'PLAN_REQUIRED');
    for (const [key, value] of Object.entries(FIXED)) guard(plan[key] === value, 'UNEXPECTED_PLAN_IDENTITY');
    guard(typeof env.BIL_APPLE_EXPECTED_SOURCE === 'string' && /^[0-9a-f]{40}$/.test(env.BIL_APPLE_EXPECTED_SOURCE), 'EXPECTED_SOURCE_REQUIRED');
    guard(plan.source_sha === env.BIL_APPLE_EXPECTED_SOURCE, 'UNEXPECTED_PLAN_SOURCE');
    guard(typeof plan.review_notes === 'string' && Buffer.byteLength(plan.review_notes, 'utf8') <= 4000, 'INVALID_NOTES_OR_LENGTH');
    guard(typeof plan.description === 'string' && [...plan.description].length <= 4000, 'INVALID_DESCRIPTION_OR_LENGTH');
    token = jwt(env);
    const before = await snapshot();
    report.beforeNoteSha256 = hash(before.review.attributes.notes ?? '');
    report.beforeDescriptionSha256 = hash(before.localization.attributes.description ?? '');
    report.plannedNoteSha256 = hash(plan.review_notes);
    report.plannedDescriptionSha256 = hash(plan.description);
    report.applePrivacyTrackingAnswers = 'NOT_READ_OR_CHANGED_BY_PUBLIC_METADATA_API';
    report.credentialPresence = {
      username: !!before.review.attributes.demoAccountName,
      password: !!before.review.attributes.demoAccountPassword,
    };
    if (env.BIL_APPLE_METADATA_APPLY !== 'SAVE_REVIEW_PREPARATION_ONLY') {
      report.status = 'GET_AUDIT_ONLY';
    } else {
      guard(env.BIL_EXPECTED_NOTE_SHA256 === report.beforeNoteSha256, 'STALE_REVIEW_NOTES');
      guard(plan.expected_description_sha256 === report.beforeDescriptionSha256, 'STALE_DESCRIPTION');
      const beforeWrite = await snapshot();
      guard(isDeepStrictEqual(before.review.attributes, beforeWrite.review.attributes), 'REVIEW_CHANGED_BEFORE_WRITE');
      guard(isDeepStrictEqual(before.localization.attributes, beforeWrite.localization.attributes), 'LOCALIZATION_CHANGED_BEFORE_WRITE');
      for (const [type, id, attribute, value, resource] of [
        ['appStoreReviewDetails', FIXED.review_id, 'notes', plan.review_notes, routes.review],
        ['appStoreVersionLocalizations', FIXED.localization_id, 'description', plan.description, routes.localization],
      ]) {
        const original = type === 'appStoreReviewDetails' ? before.review : before.localization;
        if (original.attributes[attribute] === value) {
          report.mutations.push({ type, id, attribute, status: 'ALREADY_IDENTICAL' });
          continue;
        }
        // Persist intent before dispatch, including the case where a transport
        // fails after Apple accepted the PATCH. Never blindly retry the write.
        const mutation = { type, id, attribute, status: 'PATCH_ATTEMPTED_READBACK_REQUIRED' };
        report.mutations.push(mutation);
        save();
        await api(resource, 'PATCH', { data: { type, id, attributes: { [attribute]: value } } });
        mutation.status = 'PATCH_COMPLETED_PENDING_READBACK';
        save();
        const readback = (await api(resource)).data;
        guard(readback?.attributes?.[attribute] === value, 'TEXT_READBACK_MISMATCH');
        const preserved = isDeepStrictEqual(omit(original.attributes, attribute), omit(readback.attributes, attribute));
        if (type === 'appStoreReviewDetails') {
          report.privateFieldsPreserved = preserved;
          report.privateFieldsChanged = !preserved;
        } else report.otherLocalizationFieldsPreserved = preserved;
        guard(preserved, 'UNTOUCHED_FIELD_MISMATCH');
        mutation.status = 'SAVED_AND_EXACT_READBACK';
        save();
      }
      const after = await snapshot();
      report.privateFieldsPreserved = isDeepStrictEqual(omit(before.review.attributes, 'notes'), omit(after.review.attributes, 'notes'));
      report.privateFieldsChanged = !report.privateFieldsPreserved;
      report.otherLocalizationFieldsPreserved = isDeepStrictEqual(omit(before.localization.attributes, 'description'), omit(after.localization.attributes, 'description'));
      guard(report.privateFieldsPreserved, 'PRIVATE_OR_CONTACT_FIELD_CHANGED');
      guard(report.otherLocalizationFieldsPreserved, 'OTHER_LOCALIZATION_FIELD_CHANGED');
      guard(isDeepStrictEqual(before.version.attributes, after.version.attributes), 'VERSION_ATTRIBUTES_CHANGED');
      report.status = 'PREPARATION_TEXT_SAVED_NOT_RELEASE_CERTIFICATION';
    }
  } catch (error) {
    report.status = 'BLOCKED_OR_PARTIAL_WRITE_REQUIRES_READBACK';
    report.failure = error.code === 'BIL_GUARD' ? error.message : 'APPLE_METADATA_REQUEST_OR_CONFIGURATION_FAILED';
    if (Number.isInteger(error.httpStatus)) report.httpStatus = error.httpStatus;
  } finally { save(); }
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const planFile = process.argv[2], out = process.argv[3];
  if (!planFile || !out) throw new Error('Usage: align_apple_metadata.mjs plan.json output-directory');
  const report = await runAppleMetadataAlignment({ plan: JSON.parse(fs.readFileSync(planFile, 'utf8')), out });
  console.log(JSON.stringify({ status: report.status, mutations: report.mutations.map(({ attribute, status }) => ({ attribute, status })), appPrivacyChanged: false, submissionRequested: false }));
  if (report.status === 'BLOCKED_OR_PARTIAL_WRITE_REQUIRES_READBACK') process.exitCode = 1;
}
