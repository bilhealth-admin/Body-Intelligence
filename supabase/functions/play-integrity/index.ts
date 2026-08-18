import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'npm:jose@6.1.0';

type JsonObject = Record<string, unknown>;

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
});
const env = (name: string) => Deno.env.get(name)?.trim() ?? '';

function clients(authorization: string) {
  const url = env('SUPABASE_URL');
  const anon = env('SUPABASE_ANON_KEY');
  const service = env('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) throw new Error('server_not_configured');
  return {
    auth: createClient(url, anon, { global: { headers: { Authorization: authorization } } }),
    admin: createClient(url, service),
  };
}

function base64Url(bytes: Uint8Array) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

async function expectedHash(action: string, requestId: string, payloadDigest: string) {
  const material = `bil-integrity-v2\n${action}\n${requestId}\n${payloadDigest}`;
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(material));
  return base64Url(new Uint8Array(digest));
}

async function googleAccessToken() {
  const raw = env('BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('play_integrity_credentials_missing');
  let account: JsonObject;
  try { account = JSON.parse(raw); } catch { throw new Error('play_integrity_credentials_invalid'); }
  const clientEmail = String(account.client_email ?? '');
  const privateKey = String(account.private_key ?? '').replaceAll('\\n', '\n');
  const projectId = String(account.project_id ?? '');
  if (!clientEmail || !privateKey || projectId !== 'bil-health') {
    throw new Error('play_integrity_credentials_invalid');
  }
  const key = await importPKCS8(privateKey, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/playintegrity' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(clientEmail)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('5m')
    .sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error('play_integrity_oauth_failed');
  const body = await response.json() as JsonObject;
  const accessToken = String(body.access_token ?? '');
  if (!accessToken) throw new Error('play_integrity_oauth_failed');
  return accessToken;
}

async function decodeIntegrityToken(integrityToken: string) {
  const packageName = env('BIL_PLAY_INTEGRITY_PACKAGE_NAME') || 'com.bilhealth.bodyintelligencelog';
  const accessToken = await googleAccessToken();
  const response = await fetch(
    `https://playintegrity.googleapis.com/v1/${encodeURIComponent(packageName)}:decodeIntegrityToken`,
    {
      method: 'POST',
      headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ integrity_token: integrityToken }),
    },
  );
  if (!response.ok) throw new Error(`play_integrity_decode_failed_${response.status}`);
  const decoded = await response.json() as JsonObject;
  const payload = decoded.tokenPayloadExternal && typeof decoded.tokenPayloadExternal === 'object'
    ? decoded.tokenPayloadExternal as JsonObject
    : decoded;
  return { packageName, payload };
}

const text = (value: unknown) => typeof value === 'string' ? value : '';
const stringArray = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string').slice(0, 10) : [];

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  const authorization = request.headers.get('authorization') ?? '';
  if (!authorization) return json({ error: 'authentication_required' }, 401);

  let ownerId = '';
  let requestId = '';
  let action = '';
  let payloadDigest = '';
  let requestHash = '';
  let admin: ReturnType<typeof createClient> | null = null;
  const mode = env('BIL_PLAY_INTEGRITY_MODE') === 'enforce' ? 'enforce' : 'observe';

  try {
    const c = clients(authorization);
    admin = c.admin;
    const { data, error } = await c.auth.auth.getUser();
    if (error || !data.user) return json({ error: 'invalid_session' }, 401);
    ownerId = data.user.id;

    const body = await request.json() as JsonObject;
    requestId = text(body.request_id).trim();
    action = text(body.action).trim();
    payloadDigest = text(body.payload_digest).trim().toLowerCase();
    requestHash = text(body.request_hash).trim();
    const integrityToken = text(body.integrity_token).trim();

    if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(requestId)) return json({ error: 'invalid_request_id' }, 400);
    if (!/^[a-z][a-z0-9_.:-]{1,79}$/.test(action)) return json({ error: 'invalid_action' }, 400);
    if (!/^[0-9a-f]{64}$/.test(payloadDigest)) return json({ error: 'invalid_payload_digest' }, 400);
    if (!requestHash || new TextEncoder().encode(requestHash).byteLength >= 500) return json({ error: 'invalid_request_hash' }, 400);
    if (!integrityToken || integrityToken.length > 32768) return json({ error: 'invalid_integrity_token' }, 400);

    const { data: existing } = await admin.from('bil_play_integrity_events')
      .select('action,payload_digest,request_hash,decision,reason,app_licensing_verdict,app_recognition_verdict,device_recognition_verdict')
      .eq('owner_id', ownerId).eq('request_id', requestId).maybeSingle();
    if (existing) {
      if (existing.action !== action || existing.payload_digest !== payloadDigest || existing.request_hash !== requestHash) {
        return json({ error: 'request_id_reuse_mismatch' }, 409);
      }
      return json({
        allowed: existing.decision !== 'enforce_deny', mode, duplicate: true,
        trustworthy: existing.reason === 'all_core_verdicts_pass', reason: existing.reason,
        verdicts: {
          licensing: existing.app_licensing_verdict,
          app: existing.app_recognition_verdict,
          device: existing.device_recognition_verdict,
        },
      });
    }

    const locallyExpectedHash = await expectedHash(action, requestId, payloadDigest);
    const localHashMatches = locallyExpectedHash === requestHash;
    const { packageName, payload } = await decodeIntegrityToken(integrityToken);

    const requestDetails = (payload.requestDetails ?? {}) as JsonObject;
    const accountDetails = (payload.accountDetails ?? {}) as JsonObject;
    const appIntegrity = (payload.appIntegrity ?? {}) as JsonObject;
    const deviceIntegrity = (payload.deviceIntegrity ?? {}) as JsonObject;

    const verdictPackage = text(requestDetails.requestPackageName);
    const verdictHash = text(requestDetails.requestHash);
    const timestampMillis = Number(requestDetails.timestampMillis ?? NaN);
    const licensing = text(accountDetails.appLicensingVerdict) || 'UNEVALUATED';
    const appVerdict = text(appIntegrity.appRecognitionVerdict) || 'UNEVALUATED';
    const deviceVerdicts = stringArray(deviceIntegrity.deviceRecognitionVerdict);

    const now = Date.now();
    const fresh = Number.isFinite(timestampMillis) && timestampMillis <= now + 60_000 && now - timestampMillis <= 5 * 60_000;
    const failures: string[] = [];
    if (!localHashMatches) failures.push('server_hash_mismatch');
    if (verdictPackage !== packageName) failures.push('package_mismatch');
    if (verdictHash !== requestHash) failures.push('google_hash_mismatch');
    if (!fresh) failures.push('stale_or_invalid_timestamp');
    if (appVerdict !== 'PLAY_RECOGNIZED') failures.push(`app_${appVerdict.toLowerCase()}`);
    if (licensing !== 'LICENSED') failures.push(`license_${licensing.toLowerCase()}`);
    if (!deviceVerdicts.includes('MEETS_DEVICE_INTEGRITY')) failures.push('device_integrity_not_met');

    const trustworthy = failures.length === 0;
    const decision = mode === 'observe' ? 'observe_allow' : trustworthy ? 'enforce_allow' : 'enforce_deny';
    const reason = trustworthy ? 'all_core_verdicts_pass' : failures.join(',');

    const { error: insertError } = await admin.from('bil_play_integrity_events').insert({
      owner_id: ownerId,
      request_id: requestId,
      action,
      payload_digest: payloadDigest,
      request_hash: requestHash,
      mode,
      request_package_name: verdictPackage || null,
      request_timestamp: Number.isFinite(timestampMillis) ? new Date(timestampMillis).toISOString() : null,
      app_licensing_verdict: licensing,
      app_recognition_verdict: appVerdict,
      device_recognition_verdict: deviceVerdicts,
      decision,
      reason,
    });
    if (insertError) throw new Error('integrity_audit_write_failed');

    return json({
      allowed: decision !== 'enforce_deny', mode, trustworthy, reason,
      verdicts: { licensing, app: appVerdict, device: deviceVerdicts },
    }, decision === 'enforce_deny' ? 403 : 200);
  } catch (error) {
    const reason = error instanceof Error ? error.message : 'play_integrity_failed';
    if (admin && ownerId && requestId && action && payloadDigest && requestHash) {
      await admin.from('bil_play_integrity_events').upsert({
        owner_id: ownerId,
        request_id: requestId,
        action,
        payload_digest: payloadDigest,
        request_hash: requestHash,
        mode,
        decision: mode === 'observe' ? 'decode_error' : 'enforce_deny',
        reason,
      }, { onConflict: 'owner_id,request_id' });
    }
    if (mode === 'observe') return json({ allowed: true, mode, trustworthy: false, reason });
    return json({ allowed: false, mode, trustworthy: false, reason }, 403);
  }
});