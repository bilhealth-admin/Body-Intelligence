#!/usr/bin/env node

/**
 * Prepare one App Store Connect review-submission draft for BIL.
 *
 * This script deliberately has no code path that submits a review submission.
 * It only creates/reuses the editable draft, creates/reuses review-version
 * snapshots, adds the seven expected items, and verifies the resulting draft.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const APP_ID = '6805349703';
const PLATFORM = 'IOS';
const VERSION_STRING = '1.0.0';
const SUBSCRIPTION_GROUP_ID = '22343739';
const SUBSCRIPTIONS = new Map([
  ['6806555342', 'bil_premium'],
  ['6806555198', 'bil_premium_annual'],
  ['6806555282', 'bil_premium_ai_coach'],
  ['6806555344', 'bil_premium_ai_coach_annual'],
]);
const IAP_PRODUCT_ID = 'bil_ai_boost';
const EDITABLE_SUBMISSION_STATE = 'READY_FOR_REVIEW';
const ACTIVE_NONEDITABLE_STATES = new Set([
  'WAITING_FOR_REVIEW',
  'IN_REVIEW',
  'UNRESOLVED_ISSUES',
  'CANCELING',
  'COMPLETING',
]);
const REVIEWABLE_VERSION_STATES = new Set([
  'PREPARE_FOR_SUBMISSION',
  'READY_FOR_REVIEW',
]);
const OUTPUT = path.resolve(process.env.ASC_REVIEW_DRAFT_OUTPUT || 'asc-review-draft-result.json');

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function createJwt({ keyId, issuerId, privateKey }) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = base64Url(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 15 * 60,
    aud: 'appstoreconnect-v1',
  }));
  const signingInput = `${header}.${payload}`;
  const signature = crypto.sign('sha256', Buffer.from(signingInput), {
    key: privateKey,
    dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
  return `${signingInput}.${signature}`;
}

class AscClient {
  constructor({ keyId, issuerId, privateKey }) {
    this.keyId = keyId;
    this.issuerId = issuerId;
    this.privateKey = privateKey;
    this.baseUrl = 'https://api.appstoreconnect.apple.com';
  }

  async request(method, resource, body) {
    const url = resource.startsWith('http') ? resource : `${this.baseUrl}${resource}`;
    const response = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${createJwt(this)}`,
        Accept: 'application/json',
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await response.text();
    const parsed = text ? JSON.parse(text) : null;
    if (!response.ok) {
      const details = parsed?.errors?.map((error) => ({
        status: error.status,
        code: error.code,
        title: error.title,
        detail: error.detail,
        source: error.source,
      })) ?? [{ status: response.status, detail: 'No JSON error body returned' }];
      throw new Error(`ASC ${method} ${new URL(url).pathname} failed: ${JSON.stringify(details)}`);
    }
    return parsed;
  }

  async all(resource) {
    const data = [];
    let next = resource;
    while (next) {
      const page = await this.request('GET', next);
      data.push(...(page?.data ?? []));
      next = page?.links?.next ?? null;
    }
    return data;
  }
}

function clientFromEnvironment() {
  const keyId = process.env.ASC_KEY_ID?.trim();
  const issuerId = process.env.ASC_ISSUER_ID?.trim();
  const keyPath = process.env.ASC_PRIVATE_KEY_PATH?.trim();
  if (!keyId || !issuerId || !keyPath) {
    throw new Error('ASC_KEY_ID, ASC_ISSUER_ID, and ASC_PRIVATE_KEY_PATH are required');
  }
  return new AscClient({
    keyId,
    issuerId,
    privateKey: fs.readFileSync(path.resolve(keyPath), 'utf8'),
  });
}

const client = clientFromEnvironment();
const changes = [];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function exactlyOne(resource, predicate, label) {
  const matches = (await client.all(resource)).filter(predicate);
  assert(matches.length === 1, `${label}: expected exactly one match, found ${matches.length}`);
  return matches[0];
}

async function relatedId(resource, relationship) {
  const relation = resource?.relationships?.[relationship];
  if (relation?.data?.id) return relation.data.id;
  assert(relation?.links?.related, `Missing ${relationship} relationship for ${resource?.type}/${resource?.id}`);
  const response = await client.request('GET', relation.links.related);
  assert(response?.data?.id, `Missing related ${relationship} resource for ${resource.type}/${resource.id}`);
  return response.data.id;
}

async function listDraftItems(draftId) {
  const include = [
    'appStoreVersion',
    'inAppPurchaseVersion',
    'subscriptionVersion',
    'subscriptionGroupVersion',
  ].join(',');
  const response = await client.request(
    'GET',
    `/v1/reviewSubmissions/${draftId}/items?include=${include}&limit=50`,
  );
  const included = new Map(
    (response.included || []).map((resource) => [`${resource.type}:${resource.id}`, resource]),
  );
  const items = [];
  for (const item of response.data || []) {
    const populated = [
      ['appStoreVersion', 'appStoreVersions'],
      ['subscriptionGroupVersion', 'subscriptionGroupVersions'],
      ['subscriptionVersion', 'subscriptionVersions'],
      ['inAppPurchaseVersion', 'inAppPurchaseVersions'],
    ].filter(([name]) => item.relationships?.[name]?.data?.id);
    assert(populated.length === 1,
      `Review item ${item.id} must have exactly one supported relationship; found ${populated.length}`);
    const [relationship, type] = populated[0];
    const versionId = item.relationships[relationship].data.id;
    let version = included.get(`${type}:${versionId}`);
    if (!version) {
      const singularPath = {
        appStoreVersions: 'appStoreVersions',
        subscriptionGroupVersions: 'subscriptionGroupVersions',
        subscriptionVersions: 'subscriptionVersions',
        inAppPurchaseVersions: 'inAppPurchaseVersions',
      }[type];
      version = (await client.request('GET', `/v1/${singularPath}/${versionId}`)).data;
    }
    let key;
    let parentId = null;
    if (relationship === 'appStoreVersion') {
      key = `appStoreVersion:${versionId}`;
    } else if (relationship === 'subscriptionGroupVersion') {
      parentId = await relatedId(version, 'subscriptionGroup');
      key = `subscriptionGroup:${parentId}`;
    } else if (relationship === 'subscriptionVersion') {
      parentId = await relatedId(version, 'subscription');
      key = `subscription:${parentId}`;
    } else {
      parentId = await relatedId(version, 'inAppPurchase');
      key = `inAppPurchase:${parentId}`;
    }
    items.push({
      itemId: item.id,
      key,
      relationship,
      versionId,
      versionState: version.attributes?.state ?? null,
      parentId,
    });
  }
  return items;
}

async function reviewVersionCandidates(resource) {
  return (await client.all(resource)).filter((version) =>
    REVIEWABLE_VERSION_STATES.has(version.attributes?.state));
}

async function reuseOrCreateVersion({ key, listPath, createType, parentRelationship, parentType, parentId }) {
  const candidates = await reviewVersionCandidates(listPath);
  assert(candidates.length <= 1,
    `${key}: found ${candidates.length} editable review versions; refusing ambiguous selection`);
  if (candidates.length === 1) {
    return { version: candidates[0], created: false };
  }
  const response = await client.request('POST', `/v1/${createType}`, {
    data: {
      type: createType,
      relationships: {
        [parentRelationship]: { data: { type: parentType, id: parentId } },
      },
    },
  });
  changes.push({ action: 'createdReviewVersion', key, id: response.data.id });
  return { version: response.data, created: true };
}

async function createItem(draftId, relationship, versionType, versionId, key) {
  const response = await client.request('POST', '/v1/reviewSubmissionItems', {
    data: {
      type: 'reviewSubmissionItems',
      relationships: {
        reviewSubmission: { data: { type: 'reviewSubmissions', id: draftId } },
        [relationship]: { data: { type: versionType, id: versionId } },
      },
    },
  });
  changes.push({ action: 'addedReviewItem', key, id: response.data.id, versionId });
}

const app = (await client.request('GET', `/v1/apps/${APP_ID}`)).data;
assert(app.id === APP_ID, `App mismatch: expected ${APP_ID}, got ${app.id}`);

const appVersion = await exactlyOne(
  `/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=${PLATFORM}&limit=200`,
  (item) => item.attributes?.versionString === VERSION_STRING && item.attributes?.platform === PLATFORM,
  `iOS app version ${VERSION_STRING}`,
);

const group = (await client.request('GET', `/v1/subscriptionGroups/${SUBSCRIPTION_GROUP_ID}`)).data;
assert(group.id === SUBSCRIPTION_GROUP_ID, 'Subscription-group ID mismatch');
const liveSubscriptions = await client.all(
  `/v1/subscriptionGroups/${SUBSCRIPTION_GROUP_ID}/subscriptions?limit=200`,
);
assert(liveSubscriptions.length === SUBSCRIPTIONS.size,
  `Subscription group contains ${liveSubscriptions.length} subscriptions; expected ${SUBSCRIPTIONS.size}`);
for (const subscription of liveSubscriptions) {
  const expectedProductId = SUBSCRIPTIONS.get(subscription.id);
  assert(expectedProductId,
    `Unexpected subscription ${subscription.id}/${subscription.attributes?.productId}`);
  assert(subscription.attributes?.productId === expectedProductId,
    `Subscription mismatch ${subscription.id}: expected ${expectedProductId}, got ${subscription.attributes?.productId}`);
}

const iap = await exactlyOne(
  `/v1/apps/${APP_ID}/inAppPurchasesV2?limit=200`,
  (item) => item.attributes?.productId === IAP_PRODUCT_ID,
  `IAP ${IAP_PRODUCT_ID}`,
);

const submissions = await client.all(`/v1/apps/${APP_ID}/reviewSubmissions?limit=200`);
const editable = submissions.filter((item) => item.attributes?.state === EDITABLE_SUBMISSION_STATE);
assert(editable.length <= 1, `Found ${editable.length} editable review-submission drafts`);
const noneditableActive = submissions.filter((item) => ACTIVE_NONEDITABLE_STATES.has(item.attributes?.state));
assert(noneditableActive.length === 0,
  `Found active non-editable review submission(s): ${noneditableActive.map((item) => `${item.id}:${item.attributes.state}`).join(', ')}`);

let draft = editable[0];
if (!draft) {
  draft = (await client.request('POST', '/v1/reviewSubmissions', {
    data: {
      type: 'reviewSubmissions',
      attributes: { platform: PLATFORM },
      relationships: { app: { data: { type: 'apps', id: APP_ID } } },
    },
  })).data;
  changes.push({ action: 'createdReviewSubmissionDraft', id: draft.id });
}
assert(draft.attributes?.platform === PLATFORM,
  `Draft platform mismatch: expected ${PLATFORM}, got ${draft.attributes?.platform}`);
assert(draft.attributes?.state === EDITABLE_SUBMISSION_STATE,
  `Draft state mismatch: expected ${EDITABLE_SUBMISSION_STATE}, got ${draft.attributes?.state}`);

const expectedKeys = new Set([
  `appStoreVersion:${appVersion.id}`,
  `subscriptionGroup:${SUBSCRIPTION_GROUP_ID}`,
  ...[...SUBSCRIPTIONS.keys()].map((id) => `subscription:${id}`),
  `inAppPurchase:${iap.id}`,
]);
let existingItems = await listDraftItems(draft.id);
const seen = new Set();
for (const item of existingItems) {
  assert(expectedKeys.has(item.key), `Unexpected review item ${item.itemId}: ${item.key}`);
  assert(!seen.has(item.key), `Duplicate review item target: ${item.key}`);
  seen.add(item.key);
}

if (!seen.has(`appStoreVersion:${appVersion.id}`)) {
  await createItem(
    draft.id,
    'appStoreVersion',
    'appStoreVersions',
    appVersion.id,
    `appStoreVersion:${appVersion.id}`,
  );
}

if (!seen.has(`subscriptionGroup:${SUBSCRIPTION_GROUP_ID}`)) {
  const { version } = await reuseOrCreateVersion({
    key: `subscriptionGroup:${SUBSCRIPTION_GROUP_ID}`,
    listPath: `/v1/subscriptionGroups/${SUBSCRIPTION_GROUP_ID}/versions?limit=200`,
    createType: 'subscriptionGroupVersions',
    parentRelationship: 'subscriptionGroup',
    parentType: 'subscriptionGroups',
    parentId: SUBSCRIPTION_GROUP_ID,
  });
  await createItem(
    draft.id,
    'subscriptionGroupVersion',
    'subscriptionGroupVersions',
    version.id,
    `subscriptionGroup:${SUBSCRIPTION_GROUP_ID}`,
  );
}

for (const [subscriptionId, productId] of SUBSCRIPTIONS) {
  const key = `subscription:${subscriptionId}`;
  if (seen.has(key)) continue;
  const { version } = await reuseOrCreateVersion({
    key,
    listPath: `/v1/subscriptions/${subscriptionId}/versions?limit=200`,
    createType: 'subscriptionVersions',
    parentRelationship: 'subscription',
    parentType: 'subscriptions',
    parentId: subscriptionId,
  });
  await createItem(
    draft.id,
    'subscriptionVersion',
    'subscriptionVersions',
    version.id,
    `${key}:${productId}`,
  );
}

if (!seen.has(`inAppPurchase:${iap.id}`)) {
  const { version } = await reuseOrCreateVersion({
    key: `inAppPurchase:${iap.id}`,
    listPath: `/v2/inAppPurchases/${iap.id}/versions?limit=200`,
    createType: 'inAppPurchaseVersions',
    parentRelationship: 'inAppPurchase',
    parentType: 'inAppPurchases',
    parentId: iap.id,
  });
  await createItem(
    draft.id,
    'inAppPurchaseVersion',
    'inAppPurchaseVersions',
    version.id,
    `inAppPurchase:${iap.id}:${IAP_PRODUCT_ID}`,
  );
}

draft = (await client.request('GET', `/v1/reviewSubmissions/${draft.id}`)).data;
existingItems = await listDraftItems(draft.id);
assert(draft.attributes?.state === EDITABLE_SUBMISSION_STATE,
  `Final draft state changed unexpectedly to ${draft.attributes?.state}`);
assert(existingItems.length === expectedKeys.size,
  `Final draft item count ${existingItems.length}; expected ${expectedKeys.size}`);
const finalKeys = new Set(existingItems.map((item) => item.key));
for (const key of expectedKeys) assert(finalKeys.has(key), `Final draft is missing ${key}`);
assert(finalKeys.size === existingItems.length, 'Final draft contains duplicate target items');

const result = {
  generatedAt: new Date().toISOString(),
  finalSubmitCalled: false,
  app: { id: APP_ID },
  platform: PLATFORM,
  version: { id: appVersion.id, versionString: VERSION_STRING },
  reviewSubmission: {
    id: draft.id,
    state: draft.attributes?.state,
    submittedDate: draft.attributes?.submittedDate ?? null,
  },
  subscriptionGroup: { id: SUBSCRIPTION_GROUP_ID },
  subscriptions: liveSubscriptions.map((item) => ({
    id: item.id,
    productId: item.attributes.productId,
  })).sort((a, b) => a.productId.localeCompare(b.productId)),
  inAppPurchase: { id: iap.id, productId: IAP_PRODUCT_ID },
  items: existingItems.sort((a, b) => a.key.localeCompare(b.key)),
  changes,
  guard: 'NO_FINAL_SUBMIT_ENDPOINT_EXISTS_IN_THIS_SCRIPT',
};
fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
fs.writeFileSync(OUTPUT, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
console.log(JSON.stringify(result, null, 2));
