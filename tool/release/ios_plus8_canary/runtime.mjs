import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

export const root = process.cwd();
export const statePath = requiredEnv('BIL_QA_STATE_PATH');
export const evidenceDir = requiredEnv('BIL_EVIDENCE_DIR');
export const startedPath = `${statePath}.started`;

export function requiredEnv(name) {
  const value = String(process.env[name] ?? '').trim();
  if (!value) throw new Error(`required_environment_missing:${name}`);
  return value;
}

function configuration() {
  const source = fs.readFileSync(
    path.join(root, 'lib/app/environment/app_environment.dart'),
    'utf8',
  );
  const url = source.match(
    /supabaseUrl\s*=\s*String\.fromEnvironment\([\s\S]*?defaultValue:\s*'(https:\/\/[^']+)'/,
  )?.[1];
  const anon = source.match(
    /supabaseAnonKey\s*=\s*String\.fromEnvironment\([\s\S]*?defaultValue:\s*'(sb_publishable_[^']+)'/,
  )?.[1];
  if (!url || !anon) throw new Error('supabase_public_configuration_missing');
  return { url, anon };
}

export const supabaseConfig = configuration();

export function evidence(name, lines) {
  fs.mkdirSync(evidenceDir, { recursive: true });
  const target = path.join(evidenceDir, name);
  fs.writeFileSync(target, `${lines.join('\n')}\n`, {
    encoding: 'utf8',
    mode: 0o600,
  });
}

export function appendEvidence(name, lines) {
  fs.mkdirSync(evidenceDir, { recursive: true });
  fs.appendFileSync(path.join(evidenceDir, name), `${lines.join('\n')}\n`, {
    encoding: 'utf8',
    mode: 0o600,
  });
}

export function atomicWriteState(state) {
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  const temporary = `${statePath}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(state)}\n`, {
    encoding: 'utf8',
    mode: 0o600,
  });
  fs.chmodSync(temporary, 0o600);
  fs.renameSync(temporary, statePath);
  fs.chmodSync(statePath, 0o600);
}

export function readState() {
  const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  if (state.schema !== 2 || typeof state.runId !== 'string') {
    throw new Error('invalid_private_canary_state');
  }
  return state;
}

export function digest(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function commandEscape(value) {
  return String(value)
    .replaceAll('%', '%25')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A');
}

export function mask(...values) {
  for (const value of values.flat(Infinity)) {
    if (value == null || String(value).length === 0) continue;
    process.stdout.write(`::add-mask::${commandEscape(value)}\n`);
  }
}

export function letters(byteLength = 18) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  return [...crypto.randomBytes(byteLength)]
    .map((value) => alphabet[value % alphabet.length])
    .join('');
}

export async function request({
  method = 'GET',
  route,
  token,
  body,
  allowed = [200],
  prefer,
}) {
  const headers = {
    apikey: supabaseConfig.anon,
    Accept: 'application/json',
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (prefer) headers.Prefer = prefer;
  const response = await fetch(`${supabaseConfig.url}${route}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    redirect: 'error',
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  if (!allowed.includes(response.status)) {
    const code = data && typeof data === 'object'
      ? String(data.code ?? data.error ?? 'unknown')
      : 'non_json_response';
    const error = new Error(
      `request_failed:${method}:${route.split('?')[0]}:${response.status}:${code}`,
    );
    error.status = response.status;
    error.code = code;
    throw error;
  }
  return { status: response.status, data, headers: response.headers };
}

export async function signIn(email, password) {
  const result = await request({
    method: 'POST',
    route: '/auth/v1/token?grant_type=password',
    body: { email, password },
  });
  const accessToken = String(result.data?.access_token ?? '');
  const refreshToken = String(result.data?.refresh_token ?? '');
  const userId = String(result.data?.user?.id ?? '');
  if (!accessToken || !refreshToken || !uuid(userId)) {
    throw new Error('private_qa_authentication_invalid');
  }
  return { email: email.trim().toLowerCase(), accessToken, refreshToken, userId };
}

export async function refresh(account) {
  const result = await request({
    method: 'POST',
    route: '/auth/v1/token?grant_type=refresh_token',
    body: { refresh_token: account.refreshToken },
  });
  const accessToken = String(result.data?.access_token ?? '');
  const refreshToken = String(result.data?.refresh_token ?? '');
  if (!accessToken || !refreshToken) throw new Error('private_session_refresh_failed');
  account.accessToken = accessToken;
  account.refreshToken = refreshToken;
  mask(accessToken, refreshToken);
}

export function uuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function params(values) {
  return new URLSearchParams(values).toString();
}

export async function select(token, table, values) {
  const result = await request({
    route: `/rest/v1/${table}?${params(values)}`,
    token,
  });
  if (!Array.isArray(result.data)) throw new Error(`invalid_select_result:${table}`);
  return result.data;
}

export async function rpc(token, name, body = {}) {
  return (await request({
    method: 'POST',
    route: `/rest/v1/rpc/${name}`,
    token,
    body,
  })).data;
}

export async function ownerAdmin(token, body, allowed = [200]) {
  return await request({
    method: 'POST',
    route: '/functions/v1/ai-coach-global-reset',
    token,
    body,
    allowed,
  });
}

export function pairFilter(ownerId, reviewerId) {
  return `(and(requester_id.eq.${ownerId},addressee_id.eq.${reviewerId}),and(requester_id.eq.${reviewerId},addressee_id.eq.${ownerId}))`;
}

export async function friendships(state) {
  return await select(state.owner.accessToken, 'bil_friendships', {
    select: 'id,requester_id,addressee_id,status,created_at,responded_at',
    or: pairFilter(state.owner.userId, state.reviewer.userId),
  });
}

export async function blocks(state) {
  const ownerRows = await select(state.owner.accessToken, 'bil_blocks', {
    select: 'blocker_id,blocked_id,created_at',
    blocker_id: `eq.${state.owner.userId}`,
    blocked_id: `eq.${state.reviewer.userId}`,
  });
  const reviewerRows = await select(state.reviewer.accessToken, 'bil_blocks', {
    select: 'blocker_id,blocked_id,created_at',
    blocker_id: `eq.${state.reviewer.userId}`,
    blocked_id: `eq.${state.owner.userId}`,
  });
  return [...ownerRows, ...reviewerRows];
}

export async function postsForMarker(
  state,
  marker,
  account = state.reviewer,
  token = account.accessToken,
) {
  return await select(token, 'bil_community_posts', {
    select: 'id,author_id,body,moderation_status,reviewed_at,deleted_at',
    author_id: `eq.${account.userId}`,
    body: `eq.${marker}`,
  });
}

export async function messagesForMarker(
  state,
  marker,
  token = state.owner.accessToken,
) {
  return await select(token, 'bil_messages', {
    select: 'id,sender_id,recipient_id,body,deleted_by_sender_at,deleted_by_recipient_at',
    body: `eq.${marker}`,
    or: pairFilter(state.owner.userId, state.reviewer.userId)
      .replaceAll('requester_id', 'sender_id')
      .replaceAll('addressee_id', 'recipient_id'),
  });
}

export async function suspendedMembers(token) {
  const result = await ownerAdmin(token, {
    operation: 'community_member_list',
    idempotency_key: `list:${crypto.randomUUID()}`,
  });
  if (!Array.isArray(result.data)) throw new Error('invalid_suspended_member_list');
  return result.data;
}

export async function creditBalance(token, userId) {
  const rows = await select(token, 'bil_ai_credit_balances', {
    select: 'granted,used,reserved',
    owner_id: `eq.${userId}`,
  });
  if (rows.length > 1) throw new Error('invalid_credit_balance_cardinality');
  const row = rows[0] ?? {};
  const balance = {
    granted: Number(row.granted ?? 0),
    used: Number(row.used ?? 0),
    reserved: Number(row.reserved ?? 0),
  };
  if (Object.values(balance).some((value) => !Number.isFinite(value))) {
    throw new Error('invalid_credit_balance_values');
  }
  return balance;
}
