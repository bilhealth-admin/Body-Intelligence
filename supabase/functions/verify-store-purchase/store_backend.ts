import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  SignJWT,
  compactVerify,
  decodeJwt,
  decodeProtectedHeader,
  importPKCS8,
  importX509,
} from 'npm:jose@6.1.0';

type Provider = 'google' | 'apple';
type Lifecycle =
  | 'pending' | 'trial' | 'active' | 'grace_period' | 'billing_retry'
  | 'account_hold' | 'paused' | 'suspended' | 'deferred' | 'cancelled'
  | 'expired' | 'refunded' | 'revoked';

type VerifiedPurchase = {
  provider: Provider;
  productId: string;
  originalTransactionId: string;
  transactionId: string;
  packageOrBundleId: string;
  environment: 'sandbox' | 'production';
  lifecycle: Lifecycle;
  startedAt?: string;
  expiresAt?: string;
  gracePeriodEndsAt?: string;
  autoRenews?: boolean;
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
});

const env = (name: string) => Deno.env.get(name)?.trim() ?? '';
const bytesToHex = (value: ArrayBuffer) =>
  [...new Uint8Array(value)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
const digest = async (value: string) =>
  bytesToHex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)));
const digestBytes = async (value: Uint8Array) =>
  bytesToHex(await crypto.subtle.digest('SHA-256', value));
const fingerprint = async (value: string) => (await digest(value)).slice(0, 24);

const decodeBase64Bytes = (value: string) =>
  Uint8Array.from(atob(value), (character) => character.charCodeAt(0));

function clients(authorization?: string) {
  const url = env('SUPABASE_URL');
  const anon = env('SUPABASE_ANON_KEY');
  const service = env('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) throw new Error('server_not_configured');
  return {
    auth: createClient(url, anon, authorization
      ? { global: { headers: { Authorization: authorization } } }
      : undefined),
    admin: createClient(url, service),
  };
}

async function googleAccessToken() {
  const raw = env('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('google_credentials_missing');
  const account = JSON.parse(raw);
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/androidpublisher',
  }).setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt().setExpirationTime('5m').sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
  });
  if (!response.ok) throw new Error('google_oauth_failed');
  return String((await response.json()).access_token ?? '');
}

function googleLifecycle(state: string, lineItem: Record<string, unknown>): Lifecycle {
  if (lineItem.expiryTime && new Date(String(lineItem.expiryTime)) < new Date()) return 'expired';
  return ({
    SUBSCRIPTION_STATE_PENDING: 'pending',
    SUBSCRIPTION_STATE_ACTIVE: 'active',
    SUBSCRIPTION_STATE_PAUSED: 'paused',
    SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'grace_period',
    SUBSCRIPTION_STATE_ON_HOLD: 'account_hold',
    SUBSCRIPTION_STATE_CANCELED: 'cancelled',
    SUBSCRIPTION_STATE_EXPIRED: 'expired',
  } as Record<string, Lifecycle>)[state] ?? 'suspended';
}

async function verifyGoogle(packageName: string, purchaseToken: string): Promise<VerifiedPurchase> {
  if (packageName !== env('GOOGLE_PLAY_PACKAGE_NAME')) throw new Error('wrong_package');
  const token = await googleAccessToken();
  const endpoint = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(endpoint, { headers: { authorization: `Bearer ${token}` } });
  if (!response.ok) throw new Error('google_verification_failed');
  const data = await response.json();
  const line = data.lineItems?.[0] ?? {};
  const environment = data.testPurchase ? 'sandbox' : 'production';
  const expectedEnvironment = env('BIL_STORE_ENVIRONMENT') === 'sandbox'
    ? 'sandbox' : 'production';
  if (environment !== expectedEnvironment) throw new Error('wrong_environment');
  return {
    provider: 'google',
    productId: String(line.productId ?? ''),
    originalTransactionId: String(data.linkedPurchaseToken ?? purchaseToken),
    transactionId: purchaseToken,
    packageOrBundleId: packageName,
    environment,
    lifecycle: googleLifecycle(String(data.subscriptionState ?? ''), line),
    startedAt: data.startTime,
    expiresAt: line.expiryTime,
    autoRenews: Boolean(line.autoRenewingPlan?.autoRenewEnabled),
  };
}

async function googleVoidedPurchaseTokens(): Promise<Set<string>> {
  const packageName = env('GOOGLE_PLAY_PACKAGE_NAME');
  const token = await googleAccessToken();
  const tokens = new Set<string>();
  let pageToken = '';
  do {
    const endpoint = new URL(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/voidedpurchases`,
    );
    if (pageToken) endpoint.searchParams.set('token', pageToken);
    const response = await fetch(endpoint, {
      headers: { authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new Error('google_voided_purchase_query_failed');
    const data = await response.json();
    for (const purchase of data.voidedPurchases ?? []) {
      const purchaseToken = String(purchase.purchaseToken ?? '');
      if (purchaseToken) tokens.add(purchaseToken);
    }
    pageToken = String(data.tokenPagination?.nextPageToken ?? '');
  } while (pageToken);
  return tokens;
}

async function verifyAppleJws(jws: string): Promise<Record<string, unknown>> {
  const header = decodeProtectedHeader(jws);
  if (header.alg !== 'ES256' || !Array.isArray(header.x5c) || header.x5c.length < 2) {
    throw new Error('invalid_apple_jws_header');
  }
  const pinnedRoot = env('APPLE_ROOT_CA_SHA256').toLowerCase().replaceAll(':', '');
  if (!pinnedRoot) throw new Error('apple_root_pin_missing');
  // Certificate pins are SHA-256 fingerprints of the raw DER certificate,
  // never of a UTF-8 reinterpretation of its binary bytes.
  const rootDigest = await digestBytes(decodeBase64Bytes(header.x5c.at(-1)!));
  if (rootDigest !== pinnedRoot) throw new Error('apple_chain_untrusted');
  const leaf = `-----BEGIN CERTIFICATE-----\n${header.x5c[0]}\n-----END CERTIFICATE-----`;
  const key = await importX509(leaf, 'ES256');
  const verified = await compactVerify(jws, key, { algorithms: ['ES256'] });
  return JSON.parse(new TextDecoder().decode(verified.payload));
}

function appleLifecycle(payload: Record<string, unknown>): Lifecycle {
  if (payload.revocationDate) return 'revoked';
  const expires = Number(payload.expiresDate ?? 0);
  if (expires > 0 && expires <= Date.now()) return 'expired';
  return 'active';
}

async function verifyApple(transactionJws: string): Promise<VerifiedPurchase> {
  const payload = await verifyAppleJws(transactionJws);
  const bundleId = String(payload.bundleId ?? '');
  if (bundleId !== env('APPLE_BUNDLE_ID')) throw new Error('wrong_bundle');
  const environment = String(payload.environment ?? '').toLowerCase() === 'sandbox'
    ? 'sandbox' : 'production';
  if (environment !== (env('BIL_STORE_ENVIRONMENT') === 'sandbox' ? 'sandbox' : 'production')) {
    throw new Error('wrong_environment');
  }
  return {
    provider: 'apple',
    productId: String(payload.productId ?? ''),
    originalTransactionId: String(payload.originalTransactionId ?? ''),
    transactionId: String(payload.transactionId ?? ''),
    packageOrBundleId: bundleId,
    environment,
    lifecycle: appleLifecycle(payload),
    startedAt: payload.purchaseDate ? new Date(Number(payload.purchaseDate)).toISOString() : undefined,
    expiresAt: payload.expiresDate ? new Date(Number(payload.expiresDate)).toISOString() : undefined,
  };
}

async function appleServerToken() {
  const issuer = env('APPLE_ISSUER_ID');
  const keyId = env('APPLE_KEY_ID');
  const privateKey = env('APPLE_PRIVATE_KEY').replaceAll('\\n', '\n');
  const bundleId = env('APPLE_BUNDLE_ID');
  if (!issuer || !keyId || !privateKey || !bundleId) {
    throw new Error('apple_server_credentials_missing');
  }
  const key = await importPKCS8(privateKey, 'ES256');
  return new SignJWT({ bid: bundleId })
    .setProtectedHeader({ alg: 'ES256', kid: keyId, typ: 'JWT' })
    .setIssuer(issuer).setAudience('appstoreconnect-v1')
    .setIssuedAt().setExpirationTime('5m').sign(key);
}

async function reconcileApple(originalTransactionId: string) {
  const sandbox = env('BIL_STORE_ENVIRONMENT') === 'sandbox';
  const host = sandbox ? 'api.storekit-sandbox.itunes.apple.com' : 'api.storekit.itunes.apple.com';
  const response = await fetch(
    `https://${host}/inApps/v1/subscriptions/${encodeURIComponent(originalTransactionId)}`,
    { headers: { authorization: `Bearer ${await appleServerToken()}` } },
  );
  if (!response.ok) throw new Error('apple_server_api_failed');
  const data = await response.json();
  const groups = data.data ?? [];
  const transactions = groups.flatMap((group: Record<string, unknown>) =>
    (group.lastTransactions as Array<Record<string, unknown>> | undefined) ?? []);
  const latest = transactions[0];
  if (!latest?.signedTransactionInfo) throw new Error('apple_transaction_missing');
  const purchase = await verifyApple(String(latest.signedTransactionInfo));
  purchase.lifecycle = appleServerStatusLifecycle(
    Number(latest.status ?? 0),
    purchase.lifecycle,
  );
  if (latest.signedRenewalInfo) {
    const renewal = await verifyAppleJws(String(latest.signedRenewalInfo));
    const graceEnds = Number(renewal.gracePeriodExpiresDate ?? 0);
    purchase.gracePeriodEndsAt = graceEnds > 0
      ? new Date(graceEnds).toISOString()
      : undefined;
    purchase.autoRenews = Number(renewal.autoRenewStatus ?? 0) === 1;
  }
  return purchase;
}

function appleServerStatusLifecycle(
  status: number,
  verifiedLifecycle: Lifecycle,
): Lifecycle {
  return ({
    1: 'active',
    2: 'expired',
    3: 'billing_retry',
    4: 'grace_period',
    5: 'revoked',
  } as Record<number, Lifecycle>)[status] ?? verifiedLifecycle;
}

async function persistVerified(
  admin: ReturnType<typeof createClient>, ownerId: string, purchase: VerifiedPurchase,
) {
  if (!purchase.productId || !purchase.originalTransactionId || !purchase.transactionId) {
    throw new Error('incomplete_store_result');
  }
  const { data: registry } = await admin.from('bil_store_product_registry')
    .select('product_id,provider,package_or_bundle_id,plan_id,enabled')
    .eq('product_id', purchase.productId).eq('provider', purchase.provider)
    .eq('package_or_bundle_id', purchase.packageOrBundleId).eq('enabled', true).maybeSingle();
  if (!registry) throw new Error('product_not_enabled');
  const active = ['trial', 'active', 'grace_period'].includes(purchase.lifecycle);
  const row = {
    owner_id: ownerId,
    provider: purchase.provider,
    product_id: purchase.productId,
    plan_id: registry.plan_id,
    lifecycle: purchase.lifecycle,
    original_transaction_id: purchase.originalTransactionId,
    latest_transaction_id: purchase.transactionId,
    environment: purchase.environment,
    started_at: purchase.startedAt,
    expires_at: purchase.expiresAt,
    grace_period_ends_at: purchase.gracePeriodEndsAt,
    auto_renews: purchase.autoRenews,
    verified_at: new Date().toISOString(),
  };
  const { error } = await admin.from('bil_subscriptions').upsert(row, { onConflict: 'owner_id' });
  if (error) throw new Error(error.code === '23505' ? 'purchase_owned_by_another_account' : 'persistence_failed');
  await admin.from('bil_entitlements').upsert({
    owner_id: ownerId,
    entitlement_id: `plan:${registry.plan_id}`,
    product_id: purchase.productId,
    provider: purchase.provider,
    active,
    starts_at: purchase.startedAt ?? new Date().toISOString(),
    expires_at: purchase.expiresAt,
    source_transaction_id: purchase.transactionId,
    server_updated_at: new Date().toISOString(),
  }, { onConflict: 'owner_id,entitlement_id' });
  await admin.from('bil_store_entitlement_audit').insert({
    owner_id: ownerId,
    provider: purchase.provider,
    product_id: purchase.productId,
    lifecycle: purchase.lifecycle,
    reason: 'store_verification',
    transaction_fingerprint: await fingerprint(purchase.transactionId),
  });
  return active;
}

async function authenticatedUser(request: Request) {
  const authorization = request.headers.get('authorization') ?? '';
  if (!authorization) throw new Error('authentication_required');
  const { auth, admin } = clients(authorization);
  const { data, error } = await auth.auth.getUser();
  if (error || !data.user) throw new Error('invalid_session');
  return { user: data.user, auth, admin };
}

async function verifyPurchase(request: Request, body: Record<string, unknown>) {
  const { user, auth, admin } = await authenticatedUser(request);
  const { error: rateError } = await auth.rpc('bil_consume_rate_limit', {
    p_action: 'store_purchase_verification',
    p_limit: 20,
    p_window_seconds: 3600,
  });
  if (rateError) throw new Error('rate_limited');
  const source = String(body.source ?? '');
  const verification = String(body.verification_data ?? '');
  if (!verification) throw new Error('invalid_receipt_payload');
  let purchase: VerifiedPurchase;
  if (source === 'app_store') {
    // The device JWS is only the lookup proof. Entitlement truth comes from a
    // fresh App Store Server API response over authenticated TLS.
    const deviceTransaction = await verifyApple(verification);
    purchase = await reconcileApple(deviceTransaction.originalTransactionId);
    if (purchase.originalTransactionId !== deviceTransaction.originalTransactionId) {
      throw new Error('apple_transaction_mismatch');
    }
  } else if (source === 'google_play') {
    purchase = await verifyGoogle(env('GOOGLE_PLAY_PACKAGE_NAME'), verification);
  } else {
    throw new Error('invalid_store_source');
  }
  if (purchase.productId !== String(body.product_id ?? '')) throw new Error('wrong_product');
  const active = await persistVerified(admin, user.id, purchase);
  return json({ verified: true, entitlement_active: active, lifecycle: purchase.lifecycle });
}

async function verifyGooglePush(request: Request, body: Record<string, unknown>) {
  const bearer = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '') ?? '';
  const tokenInfo = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(bearer)}`);
  if (!tokenInfo.ok) throw new Error('invalid_pubsub_identity');
  const identity = await tokenInfo.json();
  if (identity.aud !== env('GOOGLE_PUBSUB_AUDIENCE') || identity.email !== env('GOOGLE_PUBSUB_SERVICE_ACCOUNT')) {
    throw new Error('invalid_pubsub_identity');
  }
  const encoded = String((body.message as Record<string, unknown>)?.data ?? '');
  const notice = JSON.parse(atob(encoded));
  const purchaseToken = String(notice.subscriptionNotification?.purchaseToken ?? '');
  const notificationId = String((body.message as Record<string, unknown>)?.messageId ?? '');
  const { admin } = clients();
  const { data: claimed } = await admin.rpc('bil_claim_store_notification', {
    p_provider: 'google', p_notification_id: notificationId,
    p_payload_digest: await digest(encoded), p_environment: env('BIL_STORE_ENVIRONMENT'),
  });
  if (!claimed) return json({ accepted: true, duplicate: true });
  const purchase = await verifyGoogle(env('GOOGLE_PLAY_PACKAGE_NAME'), purchaseToken);
  const existing = await admin.from('bil_subscriptions').select('owner_id')
    .eq('provider', 'google').eq('original_transaction_id', purchase.originalTransactionId).maybeSingle();
  if (existing.data?.owner_id) await persistVerified(admin, existing.data.owner_id, purchase);
  return json({ accepted: true });
}

async function verifyAppleNotification(body: Record<string, unknown>) {
  const signedPayload = String(body.signedPayload ?? '');
  const notification = await verifyAppleJws(signedPayload);
  const notificationId = String(notification.notificationUUID ?? '');
  if (String(notification.notificationType ?? '') === 'TEST') {
    return json({ accepted: true, test: true });
  }
  const data = notification.data as Record<string, unknown>;
  const transactionJws = String(data?.signedTransactionInfo ?? '');
  const { admin } = clients();
  const { data: claimed } = await admin.rpc('bil_claim_store_notification', {
    p_provider: 'apple', p_notification_id: notificationId,
    p_payload_digest: await digest(signedPayload), p_environment: data?.environment,
  });
  if (!claimed) return json({ accepted: true, duplicate: true });
  const notificationTransaction = await verifyApple(transactionJws);
  const purchase = await reconcileApple(
    notificationTransaction.originalTransactionId,
  );
  if (purchase.originalTransactionId !== notificationTransaction.originalTransactionId) {
    throw new Error('apple_transaction_mismatch');
  }
  const notificationType = String(notification.notificationType ?? '');
  const subtype = String(notification.subtype ?? '');
  purchase.lifecycle = appleNotificationLifecycle(
    notificationType,
    subtype,
    purchase.lifecycle,
  );
  const existing = await admin.from('bil_subscriptions').select('owner_id')
    .eq('provider', 'apple').eq('original_transaction_id', purchase.originalTransactionId).maybeSingle();
  if (existing.data?.owner_id) await persistVerified(admin, existing.data.owner_id, purchase);
  return json({ accepted: true });
}

function appleNotificationLifecycle(
  notificationType: string,
  subtype: string,
  verifiedLifecycle: Lifecycle,
): Lifecycle {
  if (notificationType === 'REFUND') return 'refunded';
  if (notificationType === 'REVOKE') return 'revoked';
  if (notificationType === 'EXPIRED' || notificationType === 'GRACE_PERIOD_EXPIRED') {
    return 'expired';
  }
  if (notificationType === 'DID_FAIL_TO_RENEW') {
    return subtype === 'GRACE_PERIOD' ? 'grace_period' : 'billing_retry';
  }
  return verifiedLifecycle;
}

async function reconcile(request: Request) {
  const supplied = request.headers.get('x-bil-reconciliation-secret') ?? '';
  const expected = env('BIL_RECONCILIATION_SECRET');
  if (!expected || supplied.length !== expected.length) throw new Error('reconciliation_forbidden');
  const left = new TextEncoder().encode(supplied);
  const right = new TextEncoder().encode(expected);
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) mismatch |= left[index] ^ right[index];
  if (mismatch !== 0) throw new Error('reconciliation_forbidden');
  const { admin } = clients();
  const { data: subscriptions, error } = await admin.from('bil_subscriptions')
    .select('owner_id,provider,original_transaction_id,latest_transaction_id')
    .limit(500);
  if (error) throw new Error('reconciliation_read_failed');
  let voidedGoogleTokens = new Set<string>();
  try {
    voidedGoogleTokens = await googleVoidedPurchaseTokens();
  } catch {
    // Normal per-subscription verification still runs. The failure is visible
    // in reconciliation audit rather than silently granting new access.
  }
  let reconciled = 0;
  for (const row of subscriptions ?? []) {
    try {
      if (row.provider === 'google' && voidedGoogleTokens.has(row.latest_transaction_id)) {
        await admin.from('bil_subscriptions').update({
          lifecycle: 'revoked',
          verified_at: new Date().toISOString(),
        }).eq('owner_id', row.owner_id);
        await admin.from('bil_entitlements').update({
          active: false,
          server_updated_at: new Date().toISOString(),
        }).eq('owner_id', row.owner_id).like('entitlement_id', 'plan:%');
        await admin.from('bil_store_entitlement_audit').insert({
          owner_id: row.owner_id,
          provider: 'google',
          lifecycle: 'revoked',
          reason: 'google_voided_purchase',
          transaction_fingerprint: await fingerprint(row.latest_transaction_id),
        });
        reconciled += 1;
        continue;
      }
      const purchase = row.provider === 'google'
        ? await verifyGoogle(env('GOOGLE_PLAY_PACKAGE_NAME'), row.latest_transaction_id)
        : await reconcileApple(row.original_transaction_id);
      await persistVerified(admin, row.owner_id, purchase);
      reconciled += 1;
    } catch {
      await admin.from('bil_store_entitlement_audit').insert({
        owner_id: row.owner_id,
        provider: row.provider,
        lifecycle: 'suspended',
        reason: 'scheduled_reconciliation_failed',
        transaction_fingerprint: await fingerprint(row.latest_transaction_id),
      });
    }
  }
  return json({ reconciled, examined: subscriptions?.length ?? 0 });
}

export async function handler(request: Request): Promise<Response> {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  try {
    const body = await request.json() as Record<string, unknown>;
    if (body.action === 'reconcile') return await reconcile(request);
    if (body.signedPayload) return await verifyAppleNotification(body);
    if (body.message) return await verifyGooglePush(request, body);
    if (body.action === 'verify_purchase') return await verifyPurchase(request, body);
    return json({ error: 'invalid_action' }, 400);
  } catch (error) {
    const code = error instanceof Error ? error.message : 'verification_failed';
    const clientCodes = new Set([
      'authentication_required', 'invalid_session', 'invalid_receipt_payload',
      'wrong_product', 'wrong_package', 'wrong_bundle', 'wrong_environment',
      'purchase_owned_by_another_account',
    ]);
    return json({ error: code, verified: false, entitlement_active: false },
      code === 'authentication_required' || code === 'invalid_session' ? 401 :
      clientCodes.has(code) ? 400 : 503);
  }
}
