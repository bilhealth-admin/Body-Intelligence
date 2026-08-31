#!/usr/bin/env node

/**
 * Add only Belarus to the live BIL AI monthly base plan and its free trial.
 *
 * Hard allow-list:
 * - product: bil_premium_ai_coach
 * - base plan: monthly / P1M
 * - region: BY
 * - base price: USD 7.19 (current Google convertRegionPrices result)
 * - offer: trial-7-day, free P7D, new-customer
 *
 * The tool does not touch any other market, price, product, listing, release,
 * questionnaire or credential. It is idempotent and emits credential-free
 * before/operations/after evidence.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const PACKAGE_NAME = 'com.bilhealth.bodyintelligencelog';
const PRODUCT_ID = 'bil_premium_ai_coach';
const BASE_PLAN_ID = 'monthly';
const BILLING_PERIOD = 'P1M';
const OFFER_ID = 'trial-7-day';
const OFFER_TAG = 'new-customer';
const REGION = 'BY';
const BY_PRICE = Object.freeze({ currencyCode: 'USD', units: '7', nanos: 190000000 });
const APPLY_ACK = 'BIL_ADD_BY_AI_MONTHLY_7_19_2026_08_31';
const API_ROOT = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function safeError(status, parsed) {
  return {
    status,
    code: parsed?.error?.code ?? status,
    statusText: parsed?.error?.status ?? null,
    message: parsed?.error?.message ?? null,
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

  patch(resource, body) {
    return this.request('PATCH', resource, body);
  }
}

function requireOk(result, label) {
  if (!result.ok) {
    throw new Error(`${label}_FAILED:${result.status}:${result.error?.statusText ?? 'UNKNOWN'}`);
  }
  return result.value;
}

function subscriptionPath(productId) {
  return `/applications/${encodeURIComponent(PACKAGE_NAME)}` +
    `/subscriptions/${encodeURIComponent(productId)}`;
}

function offerPath() {
  return `${subscriptionPath(PRODUCT_ID)}` +
    `/basePlans/${BASE_PLAN_ID}/offers/${OFFER_ID}`;
}

function moneyKey(price) {
  return `${price?.currencyCode ?? ''}|${price?.units ?? '0'}|${price?.nanos ?? 0}`;
}

function sameMoney(left, right) {
  return moneyKey(left) === moneyKey(right);
}

function basePlan(subscription) {
  return (subscription?.basePlans ?? []).find((item) => item.basePlanId === BASE_PLAN_ID);
}

function planRegionMap(plan) {
  return new Map((plan?.regionalConfigs ?? []).map((item) => [item.regionCode, item]));
}

function offerRegionMap(offer) {
  return new Map((offer?.regionalConfigs ?? []).map((item) => [item.regionCode, item]));
}

function phaseRegionMap(offer) {
  return new Map((offer?.phases?.[0]?.regionalConfigs ?? []).map(
    (item) => [item.regionCode, item],
  ));
}

function stableRegionHash(items, mapper) {
  const lines = [...items]
    .sort((left, right) => left.regionCode.localeCompare(right.regionCode))
    .map(mapper);
  return sha256(lines.join('\n'));
}

function planHash(plan, excludedRegion = null) {
  return stableRegionHash(
    (plan?.regionalConfigs ?? []).filter((item) => item.regionCode !== excludedRegion),
    (item) => `${item.regionCode}|${item.newSubscriberAvailability}|${moneyKey(item.price)}`,
  );
}

function offerHash(offer, excludedRegion = null) {
  const availability = stableRegionHash(
    (offer?.regionalConfigs ?? []).filter((item) => item.regionCode !== excludedRegion),
    (item) => `${item.regionCode}|${item.newSubscriberAvailability}`,
  );
  const phases = stableRegionHash(
    (offer?.phases?.[0]?.regionalConfigs ?? []).filter(
      (item) => item.regionCode !== excludedRegion,
    ),
    (item) => `${item.regionCode}|${Object.hasOwn(item, 'free')}`,
  );
  return { availability, phases };
}

function summary(subscription, offer, annual, boost) {
  const plan = basePlan(subscription);
  const byPlan = planRegionMap(plan).get(REGION) ?? null;
  const byOffer = offerRegionMap(offer).get(REGION) ?? null;
  const byPhase = phaseRegionMap(offer).get(REGION) ?? null;
  const annualPlan = (annual?.basePlans ?? []).find(
    (item) => item.basePlanId === 'yearly',
  );
  const annualBy = planRegionMap(annualPlan).get(REGION) ?? null;
  const boostOption = (boost?.purchaseOptions ?? []).find(
    (item) => item.purchaseOptionId === 'standard-2500',
  );
  const boostBy = (boostOption?.regionalPricingAndAvailabilityConfigs ?? []).find(
    (item) => item.regionCode === REGION,
  );
  return {
    monthly: {
      productId: subscription?.productId ?? null,
      basePlanId: plan?.basePlanId ?? null,
      state: plan?.state ?? null,
      billingPeriod: plan?.autoRenewingBasePlanType?.billingPeriodDuration ?? null,
      regionCount: plan?.regionalConfigs?.length ?? 0,
      by: byPlan ? {
        available: byPlan.newSubscriberAvailability,
        price: byPlan.price,
      } : null,
      nonByRegionHash: planHash(plan, REGION),
    },
    trial: {
      offerId: offer?.offerId ?? null,
      state: offer?.state ?? null,
      offerTags: (offer?.offerTags ?? []).map((item) => item.tag),
      duration: offer?.phases?.[0]?.duration ?? null,
      recurrenceCount: offer?.phases?.[0]?.recurrenceCount ?? null,
      availabilityRegionCount: offer?.regionalConfigs?.length ?? 0,
      phaseRegionCount: offer?.phases?.[0]?.regionalConfigs?.length ?? 0,
      byAvailable: byOffer?.newSubscriberAvailability ?? null,
      byFree: byPhase ? Object.hasOwn(byPhase, 'free') : false,
      nonByRegionHashes: offerHash(offer, REGION),
    },
    untouchedControls: {
      annualByPrice: annualBy?.price ?? null,
      annualRegionCount: annualPlan?.regionalConfigs?.length ?? 0,
      boostByPrice: boostBy?.price ?? null,
      boostRegionCount: boostOption?.regionalPricingAndAvailabilityConfigs?.length ?? 0,
    },
  };
}

function mutableBasePlan(plan, regionalConfigs) {
  return {
    basePlanId: plan.basePlanId,
    regionalConfigs,
    autoRenewingBasePlanType: plan.autoRenewingBasePlanType,
    offerTags: plan.offerTags,
    otherRegionsConfig: plan.otherRegionsConfig,
  };
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

async function readState(client) {
  const [subscriptionResult, offerResult, annualResult, boostResult] = await Promise.all([
    client.get(subscriptionPath(PRODUCT_ID)),
    client.get(offerPath()),
    client.get(subscriptionPath('bil_premium_ai_coach_annual')),
    client.get(`/applications/${encodeURIComponent(PACKAGE_NAME)}/oneTimeProducts/bil_ai_boost`),
  ]);
  return {
    statuses: {
      subscription: subscriptionResult.status,
      offer: offerResult.status,
      annual: annualResult.status,
      boost: boostResult.status,
    },
    subscription: requireOk(subscriptionResult, 'MONTHLY_GET'),
    offer: requireOk(offerResult, 'OFFER_GET'),
    annual: requireOk(annualResult, 'ANNUAL_GET'),
    boost: requireOk(boostResult, 'BOOST_GET'),
  };
}

function assertContract(state) {
  const plan = basePlan(state.subscription);
  if (!plan || plan.state !== 'ACTIVE' ||
      plan.autoRenewingBasePlanType?.billingPeriodDuration !== BILLING_PERIOD) {
    throw new Error('MONTHLY_BASE_PLAN_CONTRACT_MISMATCH');
  }
  if (state.offer?.state !== 'ACTIVE' || state.offer?.offerId !== OFFER_ID ||
      state.offer?.offerTags?.length !== 1 || state.offer.offerTags[0]?.tag !== OFFER_TAG ||
      state.offer?.phases?.length !== 1 || state.offer.phases[0]?.duration !== 'P7D' ||
      state.offer.phases[0]?.recurrenceCount !== 1) {
    throw new Error('MONTHLY_TRIAL_CONTRACT_MISMATCH');
  }
  const planCodes = [...planRegionMap(plan).keys()].sort();
  const offerCodes = [...offerRegionMap(state.offer).keys()].sort();
  const phaseCodes = [...phaseRegionMap(state.offer).keys()].sort();
  const planWithoutBy = planCodes.filter((code) => code !== REGION);
  const offerWithoutBy = offerCodes.filter((code) => code !== REGION);
  const phaseWithoutBy = phaseCodes.filter((code) => code !== REGION);
  if (JSON.stringify(planWithoutBy) !== JSON.stringify(offerWithoutBy) ||
      JSON.stringify(planWithoutBy) !== JSON.stringify(phaseWithoutBy)) {
    throw new Error('EXISTING_REGION_SETS_MISMATCH');
  }
}

const credentialsPath = argument('--credentials');
const outputDirectory = argument('--output-directory');
const apply = argument('--apply') === APPLY_ACK;
if (!credentialsPath || !outputDirectory) {
  throw new Error('--credentials and --output-directory are required');
}
if (!apply) throw new Error(`Refusing mutation: pass --apply ${APPLY_ACK}`);
const output = path.resolve(outputDirectory);
if (path.parse(output).root.toUpperCase() !== 'G:\\') {
  throw new Error(`Evidence must stay on G:, received ${output}`);
}
fs.mkdirSync(output, { recursive: true });

const credentials = JSON.parse(fs.readFileSync(path.resolve(credentialsPath), 'utf8'));
if (credentials.type !== 'service_account' || !credentials.client_email ||
    !credentials.private_key) {
  throw new Error('Credential file is not a complete Google service account');
}
const client = new PublisherClient(await accessToken(credentials));
const before = await readState(client);
assertContract(before);
const beforeSummary = summary(
  before.subscription,
  before.offer,
  before.annual,
  before.boost,
);
writeJson(path.join(output, 'before.json'), {
  generatedAt: new Date().toISOString(),
  mode: 'pre-mutation-live-read',
  packageName: PACKAGE_NAME,
  statuses: before.statuses,
  ...beforeSummary,
});

const conversionResult = await client.post(
  `/applications/${encodeURIComponent(PACKAGE_NAME)}/pricing:convertRegionPrices`,
  { price: { currencyCode: 'USD', units: '5', nanos: 990000000 } },
);
const conversion = requireOk(conversionResult, 'PRICE_CONVERSION');
const convertedBy = conversion?.convertedRegionPrices?.BY?.price;
const regionVersion = conversion?.regionVersion?.version;
if (!sameMoney(convertedBy, BY_PRICE) || !regionVersion) {
  throw new Error('BY_CURRENT_GOOGLE_CONVERSION_MISMATCH');
}

const operations = [{
  name: 'confirm-current-google-by-conversion',
  method: 'POST_NON_PERSISTENT_CALCULATION',
  httpStatus: conversionResult.status,
  result: { regionVersion, byPrice: convertedBy },
}];
const plan = basePlan(before.subscription);
const existingPlanBy = planRegionMap(plan).get(REGION);
if (existingPlanBy &&
    (!sameMoney(existingPlanBy.price, BY_PRICE) ||
      existingPlanBy.newSubscriberAvailability !== true)) {
  throw new Error('EXISTING_BY_MONTHLY_CONFIG_CONFLICT');
}

if (!existingPlanBy) {
  const updatedRegionalConfigs = [
    ...plan.regionalConfigs,
    { regionCode: REGION, newSubscriberAvailability: true, price: BY_PRICE },
  ];
  const resource = `${subscriptionPath(PRODUCT_ID)}` +
    `?updateMask=basePlans&regionsVersion.version=${encodeURIComponent(regionVersion)}`;
  const result = await client.patch(resource, {
    packageName: PACKAGE_NAME,
    productId: PRODUCT_ID,
    basePlans: [mutableBasePlan(plan, updatedRegionalConfigs)],
  });
  operations.push({
    name: 'add-by-to-ai-monthly-base-plan-only',
    method: 'PATCH',
    resource: `${subscriptionPath(PRODUCT_ID)}?updateMask=basePlans&regionsVersion.version={version}`,
    httpStatus: result.status,
    ok: result.ok,
    result: result.ok ? {
      basePlanId: BASE_PLAN_ID,
      addedRegion: REGION,
      addedPrice: BY_PRICE,
    } : result.error,
  });
  requireOk(result, 'MONTHLY_BY_PATCH');
}

const existingOfferBy = offerRegionMap(before.offer).get(REGION);
const existingPhaseBy = phaseRegionMap(before.offer).get(REGION);
if ((existingOfferBy && existingOfferBy.newSubscriberAvailability !== true) ||
    (existingPhaseBy && !Object.hasOwn(existingPhaseBy, 'free')) ||
    Boolean(existingOfferBy) !== Boolean(existingPhaseBy)) {
  throw new Error('EXISTING_BY_TRIAL_CONFIG_CONFLICT');
}
if (!existingOfferBy) {
  const phases = before.offer.phases.map((phase, index) => index === 0 ? {
    ...phase,
    regionalConfigs: [...phase.regionalConfigs, { regionCode: REGION, free: {} }],
  } : phase);
  const regionalConfigs = [
    ...before.offer.regionalConfigs,
    { regionCode: REGION, newSubscriberAvailability: true },
  ];
  const resource = `${offerPath()}` +
    `?updateMask=phases%2CregionalConfigs` +
    `&regionsVersion.version=${encodeURIComponent(regionVersion)}`;
  const result = await client.patch(resource, {
    packageName: PACKAGE_NAME,
    productId: PRODUCT_ID,
    basePlanId: BASE_PLAN_ID,
    offerId: OFFER_ID,
    phases,
    regionalConfigs,
  });
  operations.push({
    name: 'add-by-to-ai-monthly-free-trial-only',
    method: 'PATCH',
    resource: `${offerPath()}?updateMask=phases,regionalConfigs&regionsVersion.version={version}`,
    httpStatus: result.status,
    ok: result.ok,
    result: result.ok ? {
      offerId: OFFER_ID,
      addedRegion: REGION,
      phase: { duration: 'P7D', recurrenceCount: 1, free: true },
    } : result.error,
  });
  requireOk(result, 'MONTHLY_TRIAL_BY_PATCH');
}

writeJson(path.join(output, 'operations.json'), {
  generatedAt: new Date().toISOString(),
  mode: 'exact-allow-listed-mutation',
  packageName: PACKAGE_NAME,
  mutationPerformed: operations.some((item) => item.method === 'PATCH'),
  operations,
});

const after = await readState(client);
assertContract(after);
const afterSummary = summary(
  after.subscription,
  after.offer,
  after.annual,
  after.boost,
);
const verification = {
  monthlyRegionCount168: afterSummary.monthly.regionCount === 168,
  monthlyByExact:
    afterSummary.monthly.by?.available === true &&
    sameMoney(afterSummary.monthly.by?.price, BY_PRICE),
  trialAvailabilityCount168: afterSummary.trial.availabilityRegionCount === 168,
  trialPhaseCount168: afterSummary.trial.phaseRegionCount === 168,
  trialByExact: afterSummary.trial.byAvailable === true && afterSummary.trial.byFree,
  nonByMonthlyUnchanged:
    beforeSummary.monthly.nonByRegionHash === afterSummary.monthly.nonByRegionHash,
  nonByTrialUnchanged:
    beforeSummary.trial.nonByRegionHashes.availability ===
      afterSummary.trial.nonByRegionHashes.availability &&
    beforeSummary.trial.nonByRegionHashes.phases ===
      afterSummary.trial.nonByRegionHashes.phases,
  annualUntouched:
    JSON.stringify(beforeSummary.untouchedControls.annualByPrice) ===
      JSON.stringify(afterSummary.untouchedControls.annualByPrice) &&
    beforeSummary.untouchedControls.annualRegionCount ===
      afterSummary.untouchedControls.annualRegionCount,
  boostUntouched:
    JSON.stringify(beforeSummary.untouchedControls.boostByPrice) ===
      JSON.stringify(afterSummary.untouchedControls.boostByPrice) &&
    beforeSummary.untouchedControls.boostRegionCount ===
      afterSummary.untouchedControls.boostRegionCount,
};
verification.pass = Object.values(verification).every(Boolean);
writeJson(path.join(output, 'after.json'), {
  generatedAt: new Date().toISOString(),
  mode: 'post-mutation-live-read',
  packageName: PACKAGE_NAME,
  statuses: after.statuses,
  verification,
  ...afterSummary,
});
if (!verification.pass) throw new Error('POST_MUTATION_VERIFICATION_FAILED');

console.log(`Exact BY monthly repair verified: ${output}`);
