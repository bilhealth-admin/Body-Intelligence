import {
  POLICY_VERSION, WebAdminError, exactOrigins, ownersAllowlist, readBearer,
  verifiedClaims, requireAal2, requireRecentTotp, parseRequest,
  safePage, safeMutationReceipt, safeCommandReceipt, safeAuditPage,
} from './policy.mjs';

const MAX_BODY_BYTES = 8192;
const CORS_HEADERS = 'authorization, apikey, content-type, x-client-info';
const RESPONSE_HEADERS = {
  'cache-control': 'no-store',
  'content-type': 'application/json; charset=utf-8',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'no-referrer',
  'x-frame-options': 'DENY',
};

function reply(body, code = 200, origin = null) {
  const headers = { ...RESPONSE_HEADERS };
  if (origin) {
    headers['access-control-allow-origin'] = origin;
    headers['access-control-allow-methods'] = 'POST, OPTIONS';
    headers['access-control-allow-headers'] = CORS_HEADERS;
    headers['access-control-max-age'] = '300';
    headers['vary'] = 'Origin';
  }
  return new Response(JSON.stringify(body), { status: code, headers });
}
function preflight(origin) {
  const headers = { ...RESPONSE_HEADERS,
    'access-control-allow-origin': origin, 'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': CORS_HEADERS, 'access-control-max-age': '300', 'vary': 'Origin',
  };
  return new Response(null, { status: 204, headers });
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// Injected dependencies permit deterministic tests without ever contacting prod.
// 'env' reads solely Edge-side secrets; the website receives none of them.
export async function handleWebAdmin(request, deps) {
  const getEnv = deps.env || (() => undefined);
  const expectedOrigins = exactOrigins(getEnv('BIL_ADMIN_WEB_ALLOWED_ORIGINS'));
  const origin = request.headers.get('origin') || '';
  const validOrigin = expectedOrigins.includes(origin);
  if (!validOrigin) return reply({ error: 'forbidden_origin' }, 403);
  if (request.method === 'OPTIONS') return preflight(origin);
  if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405, origin);
  if (getEnv('BIL_ADMIN_WEB_ENABLED') !== 'true')
    return reply({ error: 'web_admin_not_enabled' }, 503, origin);

  try {
    const rawToken = readBearer(request.headers.get('authorization'));
    const contentLength = Number(request.headers.get('content-length') || 0);
    if (contentLength > MAX_BODY_BYTES) throw new WebAdminError('request_too_large', 413);
    const bodyString = await request.text();
    if (new TextEncoder().encode(bodyString).byteLength > MAX_BODY_BYTES)
      throw new WebAdminError('request_too_large', 413);
    const contentType = request.headers.get('content-type') || '';
    if (!/^application\/json(?:\s*;|\s*$)/i.test(contentType))
      throw new WebAdminError('content_type_required', 415);
    let rawBody;
    try { rawBody = JSON.parse(bodyString); }
    catch { throw new WebAdminError('invalid_json'); }

    const userClient = deps.makeUserClient(rawToken);
    const userCheck = await userClient.auth.getUser(rawToken);
    const userId = userCheck?.data?.user?.id;
    if (userCheck?.error || typeof userId !== 'string' || !uuid.test(userId))
      throw new WebAdminError('invalid_session', 401);
    const nowSeconds = Math.floor((deps.now?.() ?? Date.now()) / 1000);
    const claims = verifiedClaims(rawToken, userId, nowSeconds);
    requireAal2(claims);

    // Both the backend financial roster AND real SQL administrator grant must match.
    const owners = ownersAllowlist(getEnv('BIL_ADMIN_WEB_FINANCE_OWNER_IDS'));
    if (!owners.has(userId.toLowerCase())) throw new WebAdminError('not_found', 404);
    const authority = await userClient.rpc('bil_can_manage_ai_coach');
    if (authority?.error || authority?.data !== true) throw new WebAdminError('not_found', 404);

    // Reject unauthorized users before even validating the operation shape.
    const body = parseRequest(rawBody);
    const enabledWrite = getEnv('BIL_ADMIN_WEB_WRITE_ENABLED') === 'true';
    let stepUpTimestamp = null;
    if (body.operation === 'status') {
      return reply({ access: 'authorized', policy_version: POLICY_VERSION,
        financial_writes_enabled: enabledWrite,
        mfa: 'aal2', ...{ backend: 'supabase_edge' } }, 200, origin);
    }
    if (!['list','grant','revoke','reconcile','audit'].includes(body.operation))
      throw new WebAdminError('invalid_operation');

    if (body.operation !== 'list' && body.operation !== 'audit' && body.operation !== 'reconcile') {
      if (!enabledWrite) throw new WebAdminError('financial_writes_locked', 423);
      stepUpTimestamp = requireRecentTotp(claims, nowSeconds);
    }

    // Production bil_consume_rate_limit has an immutable contract allowlist.
    // Reuse the EXISTING exact administrative subscription action and limit
    // until a separately reviewed SQL migration authorizes web-specific quotas.
    const limits = { list: 120, grant: 60, revoke: 60, reconcile: 120, audit: 120 };
    // Reconciliation is a read-only operation under the existing list quota.
    const action = `admin_subscription_${['reconcile','audit'].includes(body.operation) ? 'list' : body.operation}`;
    const limitResult = await userClient.rpc('bil_consume_rate_limit', {
      p_action: action, p_limit: limits[body.operation], p_window_seconds: 3600,
    });
    if (limitResult?.error) {
      if (/rate limit exceeded/i.test(limitResult.error.message || ''))
        throw new WebAdminError('rate_limited', 429);
      throw new WebAdminError('rate_check_unavailable', 503);
    }

    const service = deps.makeServiceClient();
    if (body.operation === 'reconcile') {
      const result = await service.rpc('bil_admin_web_reconcile_subscription_command',
        { p_actor_id: userId, p_idempotency_key: body.idempotency_key });
      if (result?.error) {
        if (/administrator_required/i.test(String(result.error.message || '')))
          throw new WebAdminError('not_found', 404);
        throw new WebAdminError('reconciliation_unavailable', 503);
      }
      const receipt = safeCommandReceipt(result.data, body.expected_operation);
      return reply({ state: receipt.found ? 'committed_receipt' : 'no_committed_receipt',
        ...receipt, policy_version: POLICY_VERSION }, 200, origin);
    }
    if (body.operation === 'audit') {
      const result=await service.rpc('bil_admin_web_list_subscription_commands_v2',
        {p_actor_id:userId,p_offset:body.offset});
      if (result?.error) {
        if (/administrator_required/i.test(String(result.error.message||'')))
          throw new WebAdminError('not_found',404);
        throw new WebAdminError('audit_unavailable',503);
      }
      return reply({...safeAuditPage(result.data),policy_version:POLICY_VERSION},200,origin);
    }
    if (body.operation === 'list') {
      const result = await service.rpc('bil_list_admin_subscriptions',
        { p_actor_id: userId, p_offset: body.offset });
      if (result?.error) throw new WebAdminError('list_unavailable', 503);
      return reply({ ...safePage(result.data), policy_version: POLICY_VERSION }, 200, origin);
    }

    const args = { p_actor_id: userId,
      p_step_up_epoch: stepUpTimestamp,
      p_idempotency_key: body.idempotency_key,
      p_operation: body.operation,
      ...(body.operation === 'grant'
        ? { p_email: body.email, p_plan_id: body.plan_id, p_duration_days: body.duration_days, p_reason: body.reason }
        : { p_grant_id: body.grant_id }),
    };
    // One atomic SQL transaction: consume the MFA event and mutate the grant.
    // Never call the legacy grant RPC directly from this web route.
    const result = await service.rpc('bil_admin_web_execute_financial_command', args);
    if (result?.error) {
      const msg = String(result.error.message || '');
      if (/administrator_required/i.test(msg)) throw new WebAdminError('not_found', 404);
      if (/existing_admin_subscription/i.test(msg)) throw new WebAdminError('existing_grant_conflict', 409);
      if (/idempotency_conflict/i.test(msg)) throw new WebAdminError('idempotency_conflict', 409);
      if (/fresh_step_up_already_used/i.test(msg)) throw new WebAdminError('fresh_step_up_already_used', 409);
      if (/financial_cooldown_active/i.test(msg)) throw new WebAdminError('financial_cooldown_active', 429);
      if (/fresh_step_up_required/i.test(msg)) throw new WebAdminError('fresh_mfa_required', 403);
      throw new WebAdminError('write_unavailable', 503);
    }
    const receipt = safeMutationReceipt(result.data);
    if (!receipt.matched) return reply({ state: 'no_matching_recipient', receipt }, 404, origin);

    // SQL returns the authoritative idempotent receipt. Confirm readback when
    // visible, otherwise return an explicit UNKNOWN state rather than "success".
    let verified = false;
    try {
      // Bounded authorized readback: older revoked grants can fall after page 1.
      // Never turn a missing/unavailable page into a fabricated success.
      for (let offset = 0; offset < 250; offset += 50) {
        const readBack = await service.rpc('bil_list_admin_subscriptions',
          { p_actor_id: userId, p_offset: offset });
        if (readBack?.error) break;
        const page = safePage(readBack.data);
        const row = page.rows.find(r => r.id === receipt.grant_id);
        if (row) {
          verified = body.operation === 'grant'
            ? row.status === 'active' && row.email === body.email && row.plan_id === body.plan_id
            : row.status === 'revoked';
          break;
        }
        if (!page.has_more || page.rows.length === 0) break;
      }
    } catch { /* Lack of readback must never be converted to false success. */ }
    return reply({ state: verified ? 'verified' : 'committed_readback_pending',
      receipt, policy_version: POLICY_VERSION }, verified ? 200 : 202, origin);
  } catch (error) {
    // Never echo exception stack, request payloads, user identity, email, jwt,
    // secrets, or provider messages to the calling site or logs.
    if (error instanceof WebAdminError)
      return reply({ error: error.code }, error.status, origin);
    return reply({ error: 'backend_unavailable' }, 503, origin);
  }
}
