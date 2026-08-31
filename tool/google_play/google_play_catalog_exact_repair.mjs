#!/usr/bin/env node

/**
 * Exact, idempotent Google Play catalog repair for the BIL v1 contract.
 *
 * This tool is deliberately allow-listed to three operations:
 *   1. create/activate trial-7-day on the AI Coach monthly P1M base plan;
 *   2. create/activate trial-7-day on the AI Coach annual P1Y base plan;
 *   3. deactivate the accidental P1M base plan inside the annual product.
 *
 * It never edits prices, listings, benefits, app content, Data safety, tracks,
 * releases or reviews. It emits credential-free before/operation/after JSON.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const OFFER_ID = 'trial-7-day';
const OFFER_TAG = 'new-customer';
const TRIAL_DURATION = 'P7D';
const APPLY_ACK = 'BIL_EXACT_CATALOG_REPAIR_2026_08_31';

const TARGETS = Object.freeze([
  Object.freeze({
    productId: 'bil_premium_ai_coach',
    basePlanId: 'monthly',
    billingPeriod: 'P1M',
  }),
  Object.freeze({
    productId: 'bil_premium_ai_coach_annual',
    basePlanId: 'yearly',
    billingPeriod: 'P1Y',
  }),
]);

const ACCIDENTAL_PLAN = Object.freeze({
  productId: 'bil_premium_ai_coach_annual',
  basePlanId: 'annual',
  billingPeriod: 'P1M',
});

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function safeError(status, parsed) {
  const details = parsed?.error?.details ?? [];
  const reasons = details
    .flatMap((detail) => detail?.reason ? [detail.reason] : [])
    .filter((value, index, all) => all.indexOf(value) === index);
  return {
    status,
    code: parsed?.error?.code ?? status,
    statusText: parsed?.error?.status ?? null,
    message: parsed?.error?.message ?? null,
    reasons,
  };
}

async function accessToken(credentials) {
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = credentials.token_uri || 'https://oauth2.googleapis.com/token';
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: credentials.client_email,
    scope: SCOPE,
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const signingInput = `${header}.${claims}`;
  const signature = crypto
    .sign('RSA-SHA256', Buffer.from(signingInput), credentials.private_key)
    .toString('base64url');
  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${signingInput}.${signature}`,
    }),
  });
  const parsed = await response.json().catch(() => null);
  if (!response.ok || !parsed?.access_token) {
    throw new Error(`GOOGLE_OAUTH_FAILED:${response.status}`);
  }
  return parsed.access_token;
}

class PublisherClient {
  constructor(token) {
    this.token = token;
  }

  async request(method, resource, body) {
    const response = await fetch(`${API_ROOT}${resource}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: 'application/json',
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const text = await response.text();
    const parsed = text ? JSON.parse(text) : null;
    if (!response.ok) {
      return { ok: false, status: response.status, error: safeError(response.status, parsed) };
    }
    return { ok: true, status: response.status, value: parsed };
  }

  get(resource) {
    return this.request('GET', resource);
  }

  post(resource, body = {}) {
    return this.request('POST', resource, body);
  }
}

function requireOk(result, label) {
  if (!result.ok) {
    throw new Error(`${label}_FAILED:${result.status}:${result.error?.statusText ?? 'UNKNOWN'}`);
  }
  return result.value;
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function planPeriod(basePlan) {
  return basePlan?.autoRenewingBasePlanType?.billingPeriodDuration ?? null;
}

function planSummary(basePlan) {
  const regionLines = [...(basePlan?.regionalConfigs ?? [])]
    .sort((left, right) => left.regionCode.localeCompare(right.regionCode))
    .map((entry) => [
      entry.regionCode,
      entry.newSubscriberAvailability,
      entry.price?.currencyCode,
      entry.price?.units,
      entry.price?.nanos ?? 0,
    ].join('|'));
  return {
    basePlanId: basePlan?.basePlanId ?? null,
    state: basePlan?.state ?? null,
    billingPeriod: planPeriod(basePlan),
    regionalConfigCount: basePlan?.regionalConfigs?.length ?? 0,
    regionalConfigSha256: sha256(regionLines.join('\n')),
    offerTags: (basePlan?.offerTags ?? []).map((entry) => entry.tag),
    newRegionsAvailable: basePlan?.otherRegionsConfig?.newSubscriberAvailability ?? null,
  };
}

function offerSummary(offer) {
  if (!offer) return null;
  return {
    productId: offer.productId,
    basePlanId: offer.basePlanId,
    offerId: offer.offerId,
    state: offer.state,
    offerTags: (offer.offerTags ?? []).map((entry) => entry.tag),
    phaseCount: offer.phases?.length ?? 0,
    phases: (offer.phases ?? []).map((phase) => ({
      recurrenceCount: phase.recurrenceCount,
      duration: phase.duration,
      regionalConfigCount: phase.regionalConfigs?.length ?? 0,
      allRegionsFree: (phase.regionalConfigs ?? []).every(
        (config) => Object.hasOwn(config, 'free'),
      ),
      otherRegionsFree: Object.hasOwn(phase.otherRegionsConfig ?? {}, 'free'),
    })),
    targeting: offer.targeting ?? null,
    regionalConfigCount: offer.regionalConfigs?.length ?? 0,
    allRegionsAvailable: (offer.regionalConfigs ?? []).every(
      (config) => config.newSubscriberAvailability === true,
    ),
    otherRegionsAvailable:
      offer.otherRegionsConfig?.otherRegionsNewSubscriberAvailability ?? null,
  };
}

function exactOffer(offer, target, expectedRegionCodes) {
  if (!offer || offer.productId !== target.productId ||
      offer.basePlanId !== target.basePlanId || offer.offerId !== OFFER_ID) {
    return false;
  }
  if (offer.phases?.length !== 1 || offer.offerTags?.length !== 1 ||
      offer.offerTags[0]?.tag !== OFFER_TAG) {
    return false;
  }
  const phase = offer.phases[0];
  if (phase.recurrenceCount !== 1 || phase.duration !== TRIAL_DURATION ||
      !Object.hasOwn(phase.otherRegionsConfig ?? {}, 'free')) {
    return false;
  }
  const offeredCodes = (offer.regionalConfigs ?? []).map((entry) => entry.regionCode).sort();
  const phaseCodes = (phase.regionalConfigs ?? []).map((entry) => entry.regionCode).sort();
  if (JSON.stringify(offeredCodes) !== JSON.stringify(expectedRegionCodes) ||
      JSON.stringify(phaseCodes) !== JSON.stringify(expectedRegionCodes)) {
    return false;
  }
  if (!(offer.regionalConfigs ?? []).every(
        (entry) => entry.newSubscriberAvailability === true) ||
      !(phase.regionalConfigs ?? []).every((entry) => Object.hasOwn(entry, 'free')) ||
      offer.otherRegionsConfig?.otherRegionsNewSubscriberAvailability !== true) {
    return false;
  }
  return Object.hasOwn(
    offer.targeting?.acquisitionRule?.scope ?? {},
    'anySubscriptionInApp',
  );
}

function findSubscription(catalog, productId) {
  return (catalog?.subscriptions ?? []).find((item) => item.productId === productId);
}

function findBasePlan(subscription, basePlanId) {
  return (subscription?.basePlans ?? []).find((item) => item.basePlanId === basePlanId);
}

function offerList(value) {
  return value?.subscriptionOffers ?? [];
}

function subscriptionPath(productId) {
  return `/applications/${encodeURIComponent(PACKAGE_NAME)}` +
    `/subscriptions/${encodeURIComponent(productId)}`;
}

function offerPath(productId, basePlanId) {
  return `${subscriptionPath(productId)}` +
    `/basePlans/${encodeURIComponent(basePlanId)}/offers`;
}

async function readCatalog(client) {
  const subscriptionsResult = await client.get(
    `/applications/${encodeURIComponent(PACKAGE_NAME)}/subscriptions?pageSize=100`,
  );
  const subscriptions = requireOk(subscriptionsResult, 'SUBSCRIPTIONS_GET');
  const offers = [];
  for (const subscription of subscriptions.subscriptions ?? []) {
    for (const basePlan of subscription.basePlans ?? []) {
      const result = await client.get(`${offerPath(
        subscription.productId,
        basePlan.basePlanId,
      )}?pageSize=100`);
      requireOk(result, `OFFERS_GET_${subscription.productId}_${basePlan.basePlanId}`);
      offers.push({
        productId: subscription.productId,
        basePlanId: basePlan.basePlanId,
        status: result.status,
        offers: offerList(result.value),
      });
    }
  }
  return { subscriptions, offers, subscriptionsStatus: subscriptionsResult.status };
}

function catalogEvidence(catalog) {
  return {
    subscriptionsHttpStatus: catalog.subscriptionsStatus,
    subscriptions: (catalog.subscriptions.subscriptions ?? []).map((subscription) => ({
      productId: subscription.productId,
      basePlans: (subscription.basePlans ?? []).map(planSummary),
    })),
    offers: catalog.offers.map((entry) => ({
      productId: entry.productId,
      basePlanId: entry.basePlanId,
      httpStatus: entry.status,
      items: entry.offers.map(offerSummary),
    })),
  };
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function assertSourceContract() {
  const source = fs.readFileSync(
    path.resolve('lib/features/commerce/domain/store_catalog_configuration.dart'),
    'utf8',
  );
  for (const expected of [
    "static const premiumAiCoachMonthly = 'bil_premium_ai_coach';",
    "static const premiumAiCoachAnnual = 'bil_premium_ai_coach_annual';",
    "static const googleAiTrialOfferId = 'trial-7-day';",
    "static const googleAiTrialOfferTag = 'new-customer';",
    "static const googleAiTrialPeriodIso8601 = 'P7D';",
  ]) {
    if (!source.includes(expected)) throw new Error(`SOURCE_CONTRACT_MISMATCH:${expected}`);
  }
}

function targetContext(catalog, target) {
  const subscription = findSubscription(catalog.subscriptions, target.productId);
  const basePlan = findBasePlan(subscription, target.basePlanId);
  if (!subscription || !basePlan || basePlan.state !== 'ACTIVE' ||
      planPeriod(basePlan) !== target.billingPeriod) {
    throw new Error(`TARGET_BASE_PLAN_MISMATCH:${target.productId}:${target.basePlanId}`);
  }
  const expectedRegionCodes = (basePlan.regionalConfigs ?? [])
    .filter((entry) => entry.newSubscriberAvailability === true)
    .map((entry) => entry.regionCode)
    .sort();
  if (expectedRegionCodes.length === 0 ||
      basePlan.otherRegionsConfig?.newSubscriberAvailability !== true) {
    throw new Error(`TARGET_AVAILABILITY_MISMATCH:${target.productId}:${target.basePlanId}`);
  }
  const entry = catalog.offers.find(
    (item) => item.productId === target.productId && item.basePlanId === target.basePlanId,
  );
  const existing = entry?.offers?.find((offer) => offer.offerId === OFFER_ID) ?? null;
  if (existing && !exactOffer(existing, target, expectedRegionCodes)) {
    throw new Error(`EXISTING_OFFER_CONTRACT_MISMATCH:${target.productId}:${target.basePlanId}`);
  }
  return { subscription, basePlan, expectedRegionCodes, existing };
}

function createOfferBody(target, basePlan) {
  const regionalConfigs = (basePlan.regionalConfigs ?? [])
    .filter((entry) => entry.newSubscriberAvailability === true)
    .map((entry) => ({
      regionCode: entry.regionCode,
      newSubscriberAvailability: true,
    }));
  return {
    packageName: PACKAGE_NAME,
    productId: target.productId,
    basePlanId: target.basePlanId,
    offerId: OFFER_ID,
    phases: [{
      recurrenceCount: 1,
      duration: TRIAL_DURATION,
      regionalConfigs: regionalConfigs.map((entry) => ({
        regionCode: entry.regionCode,
        free: {},
      })),
      otherRegionsConfig: { free: {} },
    }],
    targeting: {
      acquisitionRule: {
        scope: { anySubscriptionInApp: {} },
      },
    },
    regionalConfigs,
    otherRegionsConfig: { otherRegionsNewSubscriberAvailability: true },
    offerTags: [{ tag: OFFER_TAG }],
  };
}

function recordOperation(operations, name, method, resource, result, valueSummary = null) {
  operations.push({
    name,
    method,
    resource,
    httpStatus: result.status,
    ok: result.ok,
    result: result.ok ? valueSummary : result.error,
  });
}

const credentialsPath = argument('--credentials');
const outputDirectory = argument('--output-directory');
const apply = argument('--apply') === APPLY_ACK;
if (!credentialsPath || !outputDirectory) {
  throw new Error('--credentials and --output-directory are required');
}
if (!apply) {
  throw new Error(`Refusing mutation: pass --apply ${APPLY_ACK}`);
}
const output = path.resolve(outputDirectory);
if (path.parse(output).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Repair evidence must stay on G:, received ${output}`);
}
fs.mkdirSync(output, { recursive: true });

const credentials = JSON.parse(fs.readFileSync(path.resolve(credentialsPath), 'utf8'));
if (credentials.type !== 'service_account' || !credentials.client_email ||
    !credentials.private_key) {
  throw new Error('Credential file is not a complete Google service account');
}

assertSourceContract();
const client = new PublisherClient(await accessToken(credentials));
const operations = [];
const before = await readCatalog(client);
writeJson(path.join(output, 'before.json'), {
  generatedAt: new Date().toISOString(),
  mode: 'pre-mutation-live-read',
  packageName: PACKAGE_NAME,
  ...catalogEvidence(before),
});

const targetContexts = TARGETS.map((target) => ({
  target,
  ...targetContext(before, target),
}));
const annualSubscription = findSubscription(
  before.subscriptions,
  ACCIDENTAL_PLAN.productId,
);
const accidentalBasePlan = findBasePlan(annualSubscription, ACCIDENTAL_PLAN.basePlanId);
if (!accidentalBasePlan || planPeriod(accidentalBasePlan) !== ACCIDENTAL_PLAN.billingPeriod ||
    !['ACTIVE', 'INACTIVE'].includes(accidentalBasePlan.state)) {
  throw new Error('ACCIDENTAL_BASE_PLAN_CONTRACT_MISMATCH');
}

// This endpoint only calculates prices. Its response supplies the current
// RegionsVersion required by offer creation and does not persist catalog data.
const regionVersionResult = await client.post(
  `/applications/${encodeURIComponent(PACKAGE_NAME)}/pricing:convertRegionPrices`,
  { price: { currencyCode: 'USD', units: '1' } },
);
const regionVersionValue = requireOk(regionVersionResult, 'REGIONS_VERSION_LOOKUP');
const regionVersion = regionVersionValue?.regionVersion?.version;
if (!regionVersion) throw new Error('REGIONS_VERSION_MISSING');
recordOperation(
  operations,
  'resolve-current-regions-version',
  'POST_READ_ONLY_CALCULATION',
  '/applications/{packageName}/pricing:convertRegionPrices',
  regionVersionResult,
  { regionVersion },
);

for (const context of targetContexts) {
  const { target, basePlan } = context;
  let offer = context.existing;
  if (!offer) {
    const resource = `${offerPath(target.productId, target.basePlanId)}` +
      `?offerId=${encodeURIComponent(OFFER_ID)}` +
      `&regionsVersion.version=${encodeURIComponent(regionVersion)}`;
    const result = await client.post(resource, createOfferBody(target, basePlan));
    recordOperation(
      operations,
      `create-${target.productId}-${target.basePlanId}-${OFFER_ID}`,
      'POST',
      resource.replace(regionVersion, '{regionsVersion}'),
      result,
      result.ok ? offerSummary(result.value) : null,
    );
    offer = requireOk(result, `OFFER_CREATE_${target.productId}_${target.basePlanId}`);
  }
  if (offer.state !== 'ACTIVE') {
    const resource = `${offerPath(target.productId, target.basePlanId)}` +
      `/${encodeURIComponent(OFFER_ID)}:activate`;
    const result = await client.post(resource, {});
    recordOperation(
      operations,
      `activate-${target.productId}-${target.basePlanId}-${OFFER_ID}`,
      'POST',
      resource,
      result,
      result.ok ? offerSummary(result.value) : null,
    );
    requireOk(result, `OFFER_ACTIVATE_${target.productId}_${target.basePlanId}`);
  }
}

if (accidentalBasePlan.state === 'ACTIVE') {
  const resource = `${subscriptionPath(ACCIDENTAL_PLAN.productId)}` +
    `/basePlans/${encodeURIComponent(ACCIDENTAL_PLAN.basePlanId)}:deactivate`;
  const result = await client.post(resource, {});
  recordOperation(
    operations,
    'deactivate-accidental-monthly-plan-inside-annual-product',
    'POST',
    resource,
    result,
    result.ok ? {
      productId: result.value?.productId ?? null,
      basePlans: (result.value?.basePlans ?? []).map(planSummary),
    } : null,
  );
  requireOk(result, 'ACCIDENTAL_BASE_PLAN_DEACTIVATE');
}

writeJson(path.join(output, 'operations.json'), {
  generatedAt: new Date().toISOString(),
  mode: 'exact-allow-listed-mutation',
  packageName: PACKAGE_NAME,
  mutationPerformed: operations.some((entry) => entry.method === 'POST'),
  operations,
});

const after = await readCatalog(client);
const afterContexts = TARGETS.map((target) => targetContext(after, target));
const afterAnnual = findSubscription(after.subscriptions, ACCIDENTAL_PLAN.productId);
const afterAccidental = findBasePlan(afterAnnual, ACCIDENTAL_PLAN.basePlanId);
const verification = {
  accidentalP1MPlanInactive:
    afterAccidental?.state === 'INACTIVE' &&
    planPeriod(afterAccidental) === ACCIDENTAL_PLAN.billingPeriod,
  targets: TARGETS.map((target, index) => ({
    productId: target.productId,
    basePlanId: target.basePlanId,
    billingPeriod: target.billingPeriod,
    offerActive: afterContexts[index].existing?.state === 'ACTIVE',
    offerExact: exactOffer(
      afterContexts[index].existing,
      target,
      afterContexts[index].expectedRegionCodes,
    ),
  })),
};
verification.pass = verification.accidentalP1MPlanInactive &&
  verification.targets.every((target) => target.offerActive && target.offerExact);
writeJson(path.join(output, 'after.json'), {
  generatedAt: new Date().toISOString(),
  mode: 'post-mutation-live-read',
  packageName: PACKAGE_NAME,
  verification,
  ...catalogEvidence(after),
});
if (!verification.pass) throw new Error('POST_MUTATION_VERIFICATION_FAILED');

process.stdout.write(`Exact Google Play catalog repair verified: ${output}\n`);
