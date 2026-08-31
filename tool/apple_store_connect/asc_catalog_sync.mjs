#!/usr/bin/env node

/**
 * BIL App Store Connect catalog preparation utility.
 *
 * Safe defaults:
 *   node tool/apple_store_connect/asc_catalog_sync.mjs --dry-run
 *
 * Read-only live inspection:
 *   ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_PRIVATE_KEY_PATH=G:\\...\\AuthKey.p8 \
 *     node tool/apple_store_connect/asc_catalog_sync.mjs --inspect
 *
 * Idempotent shell creation/repair is deliberately double-gated and does not
 * touch prices, availability, localizations, offers, or review submission:
 *   ASC_ALLOW_MUTATION=YES node ... --apply-shells
 */

import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(scriptPath);
const projectRoot = path.resolve(scriptDir, '..', '..');

const policyPath = path.join(scriptDir, 'apple_catalog_policy.json');
const policy = readJson(policyPath);

function projectPath(relativePath) {
  return path.resolve(projectRoot, relativePath);
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function isoValues(arrayBody) {
  return [...arrayBody.matchAll(/'([A-Z]{2,3})'/g)].map((match) => match[1]);
}

export function extractTerritoryPolicy(sqlText) {
  const arrays = [...sqlText.matchAll(/array\[((?:\s*'[A-Z]{2,3}'\s*,?)+)\]::text\[\]/g)]
    .map((match) => isoValues(match[1]));
  const premium2 = arrays.find((values) =>
    values.length === 4 && values.join(',') === 'EG,IN,PK,TR');
  const premium3 = arrays.find((values) =>
    values.length === 4 && values.join(',') === 'EGY,IND,PAK,TUR');
  const ai2 = arrays.find((values) =>
    values.length === 168 && values[0]?.length === 2 && values.includes('NG') && !values.includes('IN'));
  const ai3 = arrays.find((values) =>
    values.length === 168 && values[0]?.length === 3 && values.includes('NGA') && !values.includes('IND'));
  assert.ok(premium2, 'Missing canonical four-market ISO-2 policy array');
  assert.ok(premium3, 'Missing canonical four-market ISO-3 policy array');
  assert.ok(ai2, 'Missing canonical 168-market ISO-2 policy array');
  assert.ok(ai3, 'Missing canonical 168-market ISO-3 policy array');
  assert.equal(ai2.length, ai3.length, 'ISO-2/ISO-3 AI arrays differ in length');
  const entries = [
    ...premium2.map((iso2, index) => [iso2, premium3[index]]),
    ...ai2.map((iso2, index) => [iso2, ai3[index]]),
  ];
  const map = Object.fromEntries(entries);
  assert.equal(Object.keys(map).length, 172, 'Canonical territory map must contain 172 markets');
  return {
    premiumOnlyIso2: premium2,
    premiumAiCoachIso2: ai2,
    iso2ToIso3: map,
  };
}

export function extractTerritoryMap(sqlText) {
  return extractTerritoryPolicy(sqlText).iso2ToIso3;
}

export function parsePrice(value) {
  if (typeof value !== 'string' || value.trim() === '' || value.includes('—')) return null;
  const match = value.match(/[0-9][0-9.,]*/);
  if (!match) return null;
  let numeric = match[0];
  const comma = numeric.lastIndexOf(',');
  const dot = numeric.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    const decimalSeparator = comma > dot ? ',' : '.';
    const thousandsSeparator = decimalSeparator === ',' ? '.' : ',';
    numeric = numeric.split(thousandsSeparator).join('').replace(decimalSeparator, '.');
  } else if (comma >= 0) {
    const fractionLength = numeric.length - comma - 1;
    numeric = fractionLength === 2
      ? numeric.replace(',', '.')
      : numeric.replaceAll(',', '');
  } else if (dot >= 0) {
    const fractionLength = numeric.length - dot - 1;
    if (fractionLength === 3) numeric = numeric.replaceAll('.', '');
  }
  const number = Number(numeric);
  if (!Number.isFinite(number) || number <= 0) return null;
  return {
    display: value.trim(),
    amount: number,
    normalizedAmount: Number.isInteger(number) ? String(number) : String(number),
  };
}

function productMarketIso2(product, split) {
  switch (product.territoryPolicy) {
    case 'premiumOnlyIso2': return split.premiumOnlyIso2;
    case 'premiumAiCoachIso2': return split.premiumAiCoachIso2;
    case 'allLaunchIso2': return split.allLaunchIso2;
    default: throw new Error(`Unknown territory policy: ${product.territoryPolicy}`);
  }
}

export function buildCatalog({ policyDocument = policy } = {}) {
  const canonicalPricing = readJson(
    projectPath(policyDocument.authoritativeSources.canonicalPricing),
  );
  const migrationText = fs.readFileSync(
    projectPath(policyDocument.authoritativeSources.marketPolicy),
    'utf8',
  );
  const bindingsText = fs.readFileSync(
    projectPath(policyDocument.authoritativeSources.productBindings),
    'utf8',
  );
  const architectureText = fs.readFileSync(
    projectPath(policyDocument.authoritativeSources.commerceContract),
    'utf8',
  );
  const territoryPolicy = extractTerritoryPolicy(migrationText);
  const iso2ToIso3 = territoryPolicy.iso2ToIso3;
  const premiumOnlyIso2 = [...policyDocument.availability.premiumOnlyIso2];
  const heldIso2 = [...policyDocument.availability.heldIso2];
  const premiumAiCoachIso2 = [...territoryPolicy.premiumAiCoachIso2];
  const allLaunchIso2 = [...premiumOnlyIso2, ...premiumAiCoachIso2];
  const split = { premiumOnlyIso2, premiumAiCoachIso2, allLaunchIso2 };

  const products = policyDocument.products.map((product) => {
    const iso2List = productMarketIso2(product, split);
    const pricing = canonicalPricing.products[product.pricingPolicyId];
    return {
      ...product,
      territoryCount: iso2List.length,
      territories: iso2List.map((iso2) => ({ iso2, iso3: iso2ToIso3[iso2] })),
      pricing,
      appleReferencePrice: pricing ? {
        iso2: pricing.appleReferenceTerritory,
        iso3: iso2ToIso3[pricing.appleReferenceTerritory],
        currency: 'USD',
        businessTargetAmount: Number(pricing.businessTargetUsd),
        appleReferenceAmount: Number(pricing.appleReferencePriceUsd),
        selection: pricing.applePriceSelection,
        localization: pricing.localization,
      } : null,
    };
  });

  return {
    policy: policyDocument,
    canonicalPricing,
    iso2ToIso3,
    sourceTexts: { bindingsText, architectureText, migrationText },
    territoryPolicy,
    split: { ...split, heldIso2 },
    products,
  };
}

export function validateCatalog(catalog) {
  const {
    policy: p,
    products,
    split,
    iso2ToIso3,
    sourceTexts,
    canonicalPricing,
    territoryPolicy,
  } = catalog;
  const errors = [];
  const warnings = [];
  const check = (condition, message) => { if (!condition) errors.push(message); };

  check(canonicalPricing.status === 'canonical',
    'Active pricing source must be explicitly canonical');
  check(canonicalPricing.pricingAuthority === 'device_store_localized_metadata',
    'Localized prices must remain device-store authoritative');
  check(canonicalPricing.displayPolicy?.annualBadgeText === '30% OFF',
    'Canonical annual campaign badge must be exactly 30% OFF');
  check(canonicalPricing.displayPolicy?.hardcodedFlutterPricesAllowed === false,
    'Canonical policy must forbid hardcoded Flutter prices');
  check(split.allLaunchIso2.length === p.availability.expectedAppleLaunchCount,
    `Expected ${p.availability.expectedAppleLaunchCount} launch markets, found ${split.allLaunchIso2.length}`);
  check(split.premiumOnlyIso2.length === p.availability.expectedPremiumOnlyCount,
    `Expected ${p.availability.expectedPremiumOnlyCount} Premium-only markets`);
  check(split.premiumAiCoachIso2.length === p.availability.expectedPremiumAiCoachCount,
    `Expected ${p.availability.expectedPremiumAiCoachCount} AI markets`);
  check(new Set(split.allLaunchIso2).size === split.allLaunchIso2.length,
    'Launch territory list contains duplicates');
  check(split.heldIso2.every((iso2) => !split.allLaunchIso2.includes(iso2)),
    'A held market appears in launch availability');
  check(split.allLaunchIso2.every((iso2) => Boolean(iso2ToIso3[iso2])),
    'At least one launch market is missing an Apple ISO-3 territory ID');
  check(JSON.stringify(split.premiumOnlyIso2) === JSON.stringify(territoryPolicy.premiumOnlyIso2),
    'Policy manifest and canonical migration disagree on Premium markets');
  check(JSON.stringify(split.premiumOnlyIso2) ===
      JSON.stringify(canonicalPricing.marketPolicy.premiumOnlyIso2),
    'Policy manifest and canonical pricing source disagree on Premium markets');
  check(JSON.stringify(split.premiumAiCoachIso2) ===
      JSON.stringify(territoryPolicy.premiumAiCoachIso2),
    'Policy manifest and canonical migration disagree on AI Coach markets');

  const expectedTrialDecision = 'BOTH_AI_PRODUCTS_NO_PREMIUM_TRIAL';
  const expectedTrialProducts = [
    'bil_premium_ai_coach',
    'bil_premium_ai_coach_annual',
  ];
  const expectedNonTrialProducts = ['bil_premium', 'bil_premium_annual'];
  check(p.trialPolicy?.decision === expectedTrialDecision,
    `Trial policy must be ${expectedTrialDecision}`);
  check(JSON.stringify(p.trialPolicy?.eligibleProductIds) ===
      JSON.stringify(expectedTrialProducts),
    'Trial policy must include both and only the AI Coach products');
  check(JSON.stringify(p.trialPolicy?.ineligibleProductIds) ===
      JSON.stringify(expectedNonTrialProducts),
    'Trial policy must explicitly exclude both regular Premium products');
  check(p.trialPolicy?.offersCreatedByThisPolicy === false,
    'Catalog policy must remain declarative and must not create offers');

  const expectedIds = new Set([
    'bil_premium',
    'bil_premium_annual',
    'bil_premium_ai_coach',
    'bil_premium_ai_coach_annual',
    'bil_ai_boost',
  ]);
  check(products.length === expectedIds.size, 'Catalog must contain exactly five products');
  for (const product of products) {
    check(expectedIds.has(product.productId), `Unexpected product ID: ${product.productId}`);
    check(sourceTexts.bindingsText.includes(`'${product.productId}'`),
      `Product ${product.productId} is absent from StoreCatalogConfiguration`);
    check(product.territories.every((entry) => entry.iso2 && entry.iso3),
      `${product.productId} contains an invalid territory mapping`);
    check(Boolean(product.pricing),
      `${product.productId} is absent from canonical pricing`);
    check(Number.isFinite(product.appleReferencePrice?.businessTargetAmount) &&
      product.appleReferencePrice.businessTargetAmount > 0,
    `${product.productId} contains a missing or invalid business target`);
    check(Number.isFinite(product.appleReferencePrice?.appleReferenceAmount) &&
      product.appleReferencePrice.appleReferenceAmount > 0,
    `${product.productId} contains a missing or invalid Apple reference price`);
    if (expectedTrialProducts.includes(product.productId)) {
      check(product.introductoryOffer?.decision === expectedTrialDecision &&
          product.introductoryOffer?.state === 'DECLARED_NOT_CREATED',
        `${product.productId} must declare AI trial eligibility without creating an offer`);
    }
    if (expectedNonTrialProducts.includes(product.productId)) {
      check(product.introductoryOffer?.decision === expectedTrialDecision &&
          product.introductoryOffer?.state === 'INELIGIBLE_BY_POLICY',
        `${product.productId} must remain ineligible for the AI trial`);
    }
  }
  check(sourceTexts.architectureText.includes('seven-day Premium AI Coach trial'),
    'Commerce architecture no longer contains the documented AI trial truth');
  check(sourceTexts.architectureText.includes('store is the sole source'),
    'Commerce architecture no longer declares the store as pricing authority');

  const unresolved = [
    {
      code: 'ASC_LOCALIZATIONS_NOT_SNAPSHOTTED',
      products: [...expectedIds],
      detail: p.metadata.appStoreLocalizations.reason,
    },
  ];
  if (p.availability.subscriptionPlanType !== 'UPFRONT') {
    errors.push('Standard BIL subscriptions must use UPFRONT, not Apple monthly-commitment billing');
  }
  warnings.push('Dry-run records only canonical USD reference prices. Every customer-facing local price must come from Apple equalization/store metadata.');
  warnings.push('Apple has no exact USD 2.50 tier for the Premium monthly and Boost targets; the canonical Apple reference is USD 2.49, never above the business target.');
  warnings.push('This package never submits for review, publishes a version, or changes availability/prices in dry-run/inspect modes.');
  warnings.push('Trial policy is declarative only; this utility has no introductory-offer mutation path.');
  return { errors, warnings, unresolved, valid: errors.length === 0, applyReady: errors.length === 0 && unresolved.length === 0 };
}

function summarizeProduct(product, includeTargets) {
  const summary = {
    productId: product.productId,
    appStoreConnectId: product.appStoreConnectId,
    referenceName: product.referenceName,
    kind: product.kind,
    plan: product.plan ?? null,
    subscriptionPeriod: product.subscriptionPeriod ?? null,
    groupLevel: product.groupLevel ?? null,
    territoryCount: product.territoryCount,
    introductoryOffer: product.introductoryOffer ?? null,
    pricing: product.pricing ?? null,
    appleReferencePrice: product.appleReferencePrice ?? null,
  };
  if (includeTargets) summary.territories = product.territories;
  else summary.territoryExamples = product.territories.slice(0, 5);
  return summary;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function createJwt({ keyId, issuerId, privateKey }) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = base64Url(JSON.stringify({ iss: issuerId, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }));
  const signingInput = `${header}.${payload}`;
  const signature = crypto.sign('sha256', Buffer.from(signingInput), {
    key: privateKey,
    dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
  return `${signingInput}.${signature}`;
}

export class AscClient {
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

export function clientFromEnvironment() {
  const keyId = process.env.ASC_KEY_ID?.trim();
  const issuerId = process.env.ASC_ISSUER_ID?.trim();
  const keyPath = process.env.ASC_PRIVATE_KEY_PATH?.trim();
  if (!keyId || !issuerId || !keyPath) {
    throw new Error('Live ASC mode requires ASC_KEY_ID, ASC_ISSUER_ID, and ASC_PRIVATE_KEY_PATH');
  }
  return new AscClient({
    keyId,
    issuerId,
    privateKey: fs.readFileSync(path.resolve(keyPath), 'utf8'),
  });
}

async function inspectLiveCatalog(client, catalog) {
  const bundleId = catalog.policy.app.bundleId;
  const apps = await client.all(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}&limit=10`);
  if (apps.length !== 1) throw new Error(`Expected one ASC app for ${bundleId}; found ${apps.length}`);
  const app = apps[0];
  const groups = await client.all(`/v1/apps/${app.id}/subscriptionGroups?limit=200`);
  const group = groups.find((item) =>
    item.id === catalog.policy.subscriptionGroup.appStoreConnectGroupId ||
    item.attributes?.referenceName === catalog.policy.subscriptionGroup.referenceName);
  if (!group) throw new Error(`Subscription group not found: ${catalog.policy.subscriptionGroup.referenceName}`);
  const subscriptions = await client.all(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=200`);
  const iaps = await client.all(`/v1/apps/${app.id}/inAppPurchasesV2?limit=200`);
  const byProductId = new Map([
    ...subscriptions.map((item) => [item.attributes?.productId, item]),
    ...iaps.map((item) => [item.attributes?.productId, item]),
  ]);
  const products = [];
  for (const expected of catalog.products) {
    const live = byProductId.get(expected.productId);
    const result = {
      productId: expected.productId,
      exists: Boolean(live),
      id: live?.id ?? null,
      type: live?.type ?? null,
      attributes: live?.attributes ?? null,
      localizations: [],
    };
    if (live) {
      const localizationPaths = expected.kind === 'subscription'
        ? [`/v1/subscriptions/${live.id}/subscriptionLocalizations?limit=200`]
        : [
            `/v2/inAppPurchases/${live.id}/inAppPurchaseLocalizations?limit=200`,
            `/v1/inAppPurchasesV2/${live.id}/inAppPurchaseLocalizations?limit=200`,
            `/v1/inAppPurchases/${live.id}/inAppPurchaseLocalizations?limit=200`,
          ];
      for (const resource of localizationPaths) {
        try {
          result.localizations = await client.all(resource);
          break;
        } catch (error) {
          result.localizationInspectionError = String(error.message);
        }
      }
    }
    products.push(result);
  }
  return {
    inspectedAt: new Date().toISOString(),
    app: { id: app.id, attributes: app.attributes },
    subscriptionGroup: { id: group.id, attributes: group.attributes },
    products,
  };
}

async function applyShells(client, catalog, live) {
  if (process.env.ASC_ALLOW_MUTATION !== 'YES') {
    throw new Error('Mutation refused. Set ASC_ALLOW_MUTATION=YES only after reviewing dry-run and live inspection.');
  }
  const actions = [];
  const liveById = new Map(live.products.map((item) => [item.productId, item]));
  for (const expected of catalog.products) {
    const current = liveById.get(expected.productId);
    if (!current?.exists) {
      if (expected.kind === 'subscription') {
        const body = {
          data: {
            type: 'subscriptions',
            attributes: {
              name: expected.referenceName,
              productId: expected.productId,
              subscriptionPeriod: expected.subscriptionPeriod,
              groupLevel: expected.groupLevel,
            },
            relationships: {
              group: { data: { type: 'subscriptionGroups', id: live.subscriptionGroup.id } },
            },
          },
        };
        const created = await client.request('POST', '/v1/subscriptions', body);
        actions.push({ productId: expected.productId, action: 'created_subscription_shell', id: created.data.id });
      } else {
        const body = {
          data: {
            type: 'inAppPurchases',
            attributes: {
              name: expected.referenceName,
              productId: expected.productId,
              inAppPurchaseType: expected.inAppPurchaseType,
            },
            relationships: {
              app: { data: { type: 'apps', id: live.app.id } },
            },
          },
        };
        const created = await client.request('POST', '/v2/inAppPurchases', body);
        actions.push({ productId: expected.productId, action: 'created_consumable_shell', id: created.data.id });
      }
      continue;
    }
    if (expected.kind !== 'subscription') {
      actions.push({ productId: expected.productId, action: 'unchanged_existing_shell', id: current.id });
      continue;
    }
    const attributes = {};
    if (current.attributes?.name !== expected.referenceName) attributes.name = expected.referenceName;
    if (current.attributes?.groupLevel !== expected.groupLevel) attributes.groupLevel = expected.groupLevel;
    if (current.attributes?.subscriptionPeriod !== expected.subscriptionPeriod) {
      throw new Error(`Refusing to rewrite immutable/unsafe period for ${expected.productId}: live=${current.attributes?.subscriptionPeriod}, expected=${expected.subscriptionPeriod}`);
    }
    if (Object.keys(attributes).length === 0) {
      actions.push({ productId: expected.productId, action: 'unchanged_existing_shell', id: current.id });
      continue;
    }
    await client.request('PATCH', `/v1/subscriptions/${current.id}`, {
      data: { type: 'subscriptions', id: current.id, attributes },
    });
    actions.push({ productId: expected.productId, action: 'patched_subscription_shell', id: current.id, attributes });
  }
  return actions;
}

function createReport(catalog, validation, { includeTargets = false, live = null, actions = null } = {}) {
  return {
    generatedAt: new Date().toISOString(),
    mode: actions ? 'apply-shells' : live ? 'inspect' : 'dry-run',
    valid: validation.valid,
    applyReady: validation.applyReady,
    mutationPerformed: Boolean(actions?.length),
    app: catalog.policy.app,
    subscriptionGroup: catalog.policy.subscriptionGroup,
    canonicalPricing: {
      effectiveDate: catalog.canonicalPricing.effectiveDate,
      pricingAuthority: catalog.canonicalPricing.pricingAuthority,
      annualBadgeText: catalog.canonicalPricing.displayPolicy.annualBadgeText,
    },
    trialPolicy: catalog.policy.trialPolicy,
    marketSplit: {
      appleLaunch: catalog.split.allLaunchIso2.length,
      premiumOnly: catalog.split.premiumOnlyIso2,
      premiumAiCoachCount: catalog.split.premiumAiCoachIso2.length,
      held: catalog.split.heldIso2,
    },
    products: catalog.products.map((product) => summarizeProduct(product, includeTargets)),
    errors: validation.errors,
    warnings: validation.warnings,
    unresolved: validation.unresolved,
    live,
    actions,
  };
}

function parseArgs(argv) {
  const args = new Set(argv.slice(2));
  const modes = ['--dry-run', '--inspect', '--apply-shells'].filter((mode) => args.has(mode));
  if (modes.length > 1) throw new Error(`Choose one mode, received: ${modes.join(', ')}`);
  const mode = modes[0] ?? '--dry-run';
  const outputIndex = argv.indexOf('--output');
  const output = outputIndex >= 0 ? argv[outputIndex + 1] : null;
  if (outputIndex >= 0 && !output) throw new Error('--output requires a path');
  return { mode, includeTargets: args.has('--include-targets'), output };
}

function writeReport(output, report) {
  if (!output) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    return;
  }
  const target = path.resolve(output);
  if (path.parse(target).root.toUpperCase() !== 'G:\\') {
    throw new Error(`Report output must stay on G:, received ${target}`);
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  process.stdout.write(`Wrote ${target}\n`);
}

export async function main(argv = process.argv) {
  const options = parseArgs(argv);
  const catalog = buildCatalog();
  const validation = validateCatalog(catalog);
  if (!validation.valid) {
    writeReport(options.output, createReport(catalog, validation, { includeTargets: options.includeTargets }));
    process.exitCode = 2;
    return;
  }
  if (options.mode === '--dry-run') {
    writeReport(options.output, createReport(catalog, validation, { includeTargets: options.includeTargets }));
    return;
  }
  const client = clientFromEnvironment();
  const live = await inspectLiveCatalog(client, catalog);
  let actions = null;
  if (options.mode === '--apply-shells') actions = await applyShells(client, catalog, live);
  writeReport(options.output, createReport(catalog, validation, {
    includeTargets: options.includeTargets,
    live,
    actions,
  }));
}

if (process.argv[1] && path.resolve(process.argv[1]) === scriptPath) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  });
}
