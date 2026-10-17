// BIL Admin Web v1: pure validation and server-side policy, no configuration secrets.
export const POLICY_VERSION = '2026-10-17-staging-v7';
export const PLAN_IDS = Object.freeze(['premium', 'premium_ai_coach']);
export const GRANT_DAYS = Object.freeze([30, 90, 365]);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const keyRE = /^[A-Za-z0-9:_-]{16,128}$/;
const emailRE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export class WebAdminError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

export function exactOrigins(raw) {
  const entries = String(raw ?? '').split(',').map(x => x.trim()).filter(Boolean);
  if (!entries.length || entries.length > 8) return [];
  const origins = [];
  for (const value of entries) {
    let url;
    try { url = new URL(value); } catch { return []; }
    if (url.protocol !== 'https:' || url.origin !== value || url.username || url.password || url.search || url.hash || url.pathname !== '/' || url.port && !['443'].includes(url.port)) return [];
    if (!origins.includes(value)) origins.push(value);
  }
  return origins;
}

export function ownersAllowlist(raw) {
  const entries = String(raw ?? '').split(',').map(x => x.trim().toLowerCase()).filter(Boolean);
  if (!entries.length || entries.some(x => !uuid.test(x))) return new Set();
  return new Set(entries);
}

export function readBearer(header) {
  const m = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(String(header || ''));
  if (!m) throw new WebAdminError('authentication_required', 401);
  return m[1];
}

// JWT claims are treated as untrusted unless the real Auth service has first
// verified the same token via auth.getUser(token) and returned that exact user.
export function verifiedClaims(token, verifiedUserId, nowSeconds) {
  let claims;
  try {
    let b64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    b64 += '='.repeat((4 - (b64.length % 4)) % 4);
    claims = JSON.parse(atob(b64));
  } catch { throw new WebAdminError('invalid_session', 401); }
  if (!claims || typeof claims !== 'object' || claims.sub !== verifiedUserId ||
      claims.role !== 'authenticated' || !Number.isFinite(claims.exp) ||
      claims.exp <= nowSeconds || (typeof claims.nbf === 'number' && claims.nbf > nowSeconds)) {
    throw new WebAdminError('invalid_session', 401);
  }
  return claims;
}

export function requireAal2(claims) {
  if (claims.aal !== 'aal2') throw new WebAdminError('mfa_required', 403);
}

export function requireRecentTotp(claims, nowSeconds, maxAgeSeconds = 90) {
  requireAal2(claims);
  const verifiedAt = Array.isArray(claims.amr) ? claims.amr.find(x =>
    x && x.method === 'totp' && Number.isSafeInteger(x.timestamp) &&
    x.timestamp <= nowSeconds + 30 && x.timestamp >= nowSeconds - maxAgeSeconds)?.timestamp : undefined;
  if (!Number.isSafeInteger(verifiedAt)) throw new WebAdminError('fresh_mfa_required', 403);
  // The service-side transaction consumes this exact signed MFA timestamp once.
  // Only a safe retry carrying the identical operation/key can reuse the stamp.
  return verifiedAt;
}

const plain = x => x && typeof x === 'object' && !Array.isArray(x) && Object.getPrototypeOf(x) === Object.prototype;
export function requireObject(body) {
  if (!plain(body)) throw new WebAdminError('invalid_request');
  return body;
}

export function parseRequest(body) {
  requireObject(body);
  const op = body.operation;
  if (op === 'status') return { operation: op };
  if (op === 'reconcile') {
    if (typeof body.idempotency_key !== 'string' || !keyRE.test(body.idempotency_key) ||
        !['grant', 'revoke'].includes(body.expected_operation))
      throw new WebAdminError('invalid_reconciliation_request');
    return {operation: op, idempotency_key: body.idempotency_key,
      expected_operation: body.expected_operation};
  }
  if (op === 'list' || op === 'audit') {
    if (body.offset != null && (!Number.isInteger(body.offset) || body.offset < 0 || body.offset > 10000))
      throw new WebAdminError('invalid_offset');
    return { operation: op, offset: body.offset ?? 0 };
  }
  if (op === 'grant') {
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const reason = typeof body.reason === 'string' ? body.reason.trim() : '';
    if (!emailRE.test(email) || email.length > 254 ||
        !PLAN_IDS.includes(body.plan_id) || !GRANT_DAYS.includes(body.duration_days) ||
        [...reason].length < 10 || [...reason].length > 160 || /[\x00-\x1F\x7F]/.test(reason) ||
        body.confirm_email !== email || body.confirm_plan !== body.plan_id ||
        body.acknowledge_external_grant !== true ||
        typeof body.idempotency_key !== 'string' || !keyRE.test(body.idempotency_key)) {
      throw new WebAdminError('invalid_grant_request');
    }
    return { operation: op, email, plan_id: body.plan_id,
      duration_days: body.duration_days, reason, idempotency_key: body.idempotency_key };
  }
  if (op === 'revoke') {
    if (typeof body.grant_id !== 'string' || !uuid.test(body.grant_id) ||
        body.confirm_grant_id !== body.grant_id ||
        typeof body.idempotency_key !== 'string' || !keyRE.test(body.idempotency_key)) {
      throw new WebAdminError('invalid_revoke_request');
    }
    return { operation: op, grant_id: body.grant_id, idempotency_key: body.idempotency_key };
  }
  throw new WebAdminError('invalid_operation');
}

export function safePage(data) {
  if (!plain(data) || !Array.isArray(data.rows) || data.rows.length > 50 || typeof data.has_more !== 'boolean')
    throw new WebAdminError('invalid_server_response', 503);
  return {
    has_more: data.has_more,
    rows: data.rows.map(row => {
      if (!plain(row) || typeof row.id !== 'string' || !uuid.test(row.id) ||
          typeof row.email !== 'string' || !emailRE.test(row.email) ||
          !PLAN_IDS.includes(row.plan_id) || !['active','revoked','expired'].includes(row.status) ||
          typeof row.created_at !== 'string' ||
          (row.expires_at != null && typeof row.expires_at !== 'string')) {
        throw new WebAdminError('invalid_server_response', 503);
      }
      return { id: row.id, email: row.email, plan_id: row.plan_id,
        status: row.status, created_at: row.created_at, expires_at: row.expires_at ?? null };
    }),
  };
}

export function safeMutationReceipt(data) {
  if (!plain(data) || typeof data.matched !== 'boolean' ||
      typeof data.changed !== 'boolean' || (!data.matched && data.changed) ||
      ((data.matched && (typeof data.grant_id !== 'string' || !uuid.test(data.grant_id))) ||
       (!data.matched && data.grant_id !== null)))
    throw new WebAdminError('invalid_server_response', 503);
  return { matched: data.matched, changed: data.changed, grant_id: data.grant_id };
}


/** Read-only SQL command receipt, scoped in Postgres by the verified admin actor. */
export function safeCommandReceipt(data, expectedOperation) {
  if (!plain(data) || typeof data.found !== 'boolean')
    throw new WebAdminError('invalid_server_response', 503);
  if (!data.found) return { found: false };
  if (!['grant','revoke'].includes(expectedOperation) ||
      data.operation !== expectedOperation)
    throw new WebAdminError('reconciliation_mismatch', 409);
  return { found: true, operation: data.operation,
    receipt: safeMutationReceipt(data.receipt) };
}


/** Audit rows contain only who, when, which operation, and its result. */
export function safeAuditPage(data) {
  if (!plain(data) || !Array.isArray(data.rows) ||
      data.rows.length > 50 || typeof data.has_more !== 'boolean')
    throw new WebAdminError('invalid_server_response', 503);
  return {
    has_more: data.has_more,
    rows: data.rows.map(row => {
      if (!plain(row) || typeof row.id !== 'string' || !uuid.test(row.id) ||
          typeof row.actor_id !== 'string' || !uuid.test(row.actor_id) ||
          !['grant','revoke'].includes(row.operation) ||
          typeof row.created_at !== 'string' ||
          typeof row.matched !== 'boolean' || typeof row.changed !== 'boolean' ||
          (row.matched && (!uuid.test(row.grant_id || ''))) ||
          (!row.matched && row.grant_id !== null))
        throw new WebAdminError('invalid_server_response',503);
      return {id:row.id, actor_id:row.actor_id, operation:row.operation,
        created_at:row.created_at, matched:row.matched, changed:row.changed,
        grant_id:row.grant_id};
    }),
  };
}
