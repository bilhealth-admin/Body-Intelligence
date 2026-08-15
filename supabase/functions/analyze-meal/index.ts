// The Deno runtime resolves URL imports; the workspace TypeScript server does
// not unless the Deno VS Code extension is active.
// @ts-ignore Deno URL import
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type DenoRuntime = {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};
const deno = (globalThis as unknown as { Deno: DenoRuntime }).Deno;

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type',
};
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, 'content-type': 'application/json' },
});
type VisionCandidate = { name: string; confidence: number; evidence: string };
const allowedMimeTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
const base64Pattern = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;
const candidate = (value: unknown): VisionCandidate | null => {
  if (!value || typeof value !== 'object') return null;
  const row = value as Record<string, unknown>;
  const name = typeof row.name === 'string' ? row.name.trim() : '';
  const confidence = typeof row.confidence === 'number' ? row.confidence : NaN;
  const evidence = typeof row.evidence === 'string' ? row.evidence.trim() : '';
  if (!name || name.length > 160 || evidence.length > 500 ||
    !Number.isFinite(confidence) || confidence < 0 || confidence > 1) return null;
  return { name, confidence, evidence };
};

deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405);
  const authorization = request.headers.get('authorization');
  const idempotencyKey = request.headers.get('x-idempotency-key')?.trim() ?? '';
  const url = deno.env.get('SUPABASE_URL');
  const anonKey = deno.env.get('SUPABASE_ANON_KEY');
  const gatewayUrl = deno.env.get('BIL_MEAL_VISION_GATEWAY_URL');
  const gatewaySecret = deno.env.get('BIL_MEAL_VISION_GATEWAY_SECRET');
  if (!authorization) return reply({ error: 'authentication_required' }, 401);
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey)) {
    return reply({ error: 'idempotency_key_required' }, 400);
  }
  if (!url || !anonKey || !gatewayUrl || !gatewaySecret) return reply({ error: 'vision_not_configured' }, 503);
  const auth = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data, error } = await auth.auth.getUser();
  if (error || !data.user) return reply({ error: 'invalid_session' }, 401);
  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(contentLength) && contentLength > 17 * 1024 * 1024) {
    return reply({ error: 'image_size_out_of_range' }, 413);
  }
  const body = await request.json().catch(() => null);
  if (!body || body.schema_version !== 1 || typeof body.image_base64 !== 'string' ||
    typeof body.mime_type !== 'string' || !allowedMimeTypes.has(body.mime_type)) {
    return reply({ error: 'invalid_image_payload' }, 400);
  }
  if (!base64Pattern.test(body.image_base64)) {
    return reply({ error: 'invalid_image_payload' }, 400);
  }
  const digestBytes = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`${body.mime_type}:${body.image_base64}`),
  );
  const payloadDigest = Array.from(new Uint8Array(digestBytes))
    .map((value) => value.toString(16).padStart(2, '0')).join('');
  const { data: claimed, error: claimError } = await auth.rpc(
    'bil_claim_sensitive_request',
    {
      p_action: 'meal_image_analysis',
      p_idempotency_key: idempotencyKey,
      p_payload_digest: payloadDigest,
    },
  );
  if (claimError) return reply({ error: 'request_limited' }, 429);
  if (claimed !== true) return reply({ error: 'request_already_processed' }, 409);
  const estimatedBytes = Math.floor(body.image_base64.length * 0.75);
  if (estimatedBytes < 1 || estimatedBytes > 12 * 1024 * 1024) return reply({ error: 'image_size_out_of_range' }, 413);
  const requestedLocale = typeof body.requested_locale === 'string' &&
      /^[a-z]{2,3}$/i.test(body.requested_locale)
    ? body.requested_locale.toLowerCase()
    : 'en';
  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), 25_000);
  let upstream: Response;
  try {
    upstream = await fetch(gatewayUrl, {
      method: 'POST',
      signal: abort.signal,
      headers: { 'content-type': 'application/json', authorization: `Bearer ${gatewaySecret}` },
      body: JSON.stringify({
        schema_version: 1,
        image_base64: body.image_base64,
        mime_type: body.mime_type,
        requested_locale: requestedLocale,
        rules: { identify_visible_food_only: true, no_nutrition_estimation: true, no_medical_claims: true, maximum_candidates: 8 },
      }),
    });
  } catch (_) {
    return reply({ error: 'vision_gateway_failed' }, 502);
  } finally {
    clearTimeout(timer);
  }
  if (!upstream.ok) return reply({ error: 'vision_gateway_failed' }, 502);
  const upstreamText = await upstream.text();
  if (new TextEncoder().encode(upstreamText).byteLength > 256 * 1024) {
    return reply({ error: 'invalid_vision_response' }, 502);
  }
  const decoded = (() => {
    try { return JSON.parse(upstreamText); } catch (_) { return null; }
  })();
  const raw: unknown[] | null =
    decoded && Array.isArray(decoded.candidates) ? decoded.candidates : null;
  if (!raw || raw.length > 8) return reply({ error: 'invalid_vision_response' }, 502);
  const candidates = raw.map(candidate);
  if (candidates.some((item: VisionCandidate | null) => item === null)) {
    return reply({ error: 'invalid_vision_response' }, 502);
  }
  return reply({
    schema_version: 1,
    candidates: candidates as VisionCandidate[],
    notice: candidates.length === 0
      ? 'No food could be identified reliably. Add the meal manually.'
      : 'Confirm each visible food and serving. Nutrition is resolved separately from verified food records.',
  });
});
