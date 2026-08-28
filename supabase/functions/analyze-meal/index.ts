// The Deno runtime resolves URL imports; the workspace TypeScript server does
// not unless the Deno VS Code extension is active.
// @ts-ignore Deno URL import
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { resolveBilLocale } from '../_shared/bcp47.ts';
import { buildProviderRequest } from './providers/builders.ts';
import { loadProviderConfig } from './providers/config.ts';
import { normalizeProviderResponse } from './providers/normalize.ts';
import { ProviderConfig, VisionProviderError, VisionProviderName } from './providers/types.ts';

type DenoRuntime = {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};
const deno = (globalThis as unknown as { Deno: DenoRuntime }).Deno;

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type, x-idempotency-key',
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
  const serviceKey = deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const gatewayUrl = deno.env.get('BIL_MEAL_VISION_GATEWAY_URL');
  const gatewaySecret = deno.env.get('BIL_MEAL_VISION_GATEWAY_SECRET');
  const providerChoice = (deno.env.get('BIL_MEAL_VISION_PROVIDER') ?? 'legacy_gateway').trim().toLowerCase();
  const directProvider = new Set(['openai', 'gemini', 'mistral']).has(providerChoice)
    ? providerChoice as VisionProviderName
    : null;
  let directConfig: ProviderConfig | null = null;
  if (directProvider) {
    try { directConfig = loadProviderConfig(directProvider, (name) => deno.env.get(name)); }
    catch (_) { return reply({ error: 'vision_not_configured' }, 503); }
  } else if (providerChoice !== 'legacy_gateway') {
    return reply({ error: 'vision_provider_not_supported' }, 503);
  }
  const providerLabel = directConfig?.provider ??
    deno.env.get('BIL_MEAL_VISION_PROVIDER_LABEL') ?? 'configured-provider';
  const modelRevision = directConfig?.model ??
    deno.env.get('BIL_MEAL_VISION_MODEL_REVISION') ?? 'server-managed';
  if (!authorization) return reply({ error: 'authentication_required' }, 401);
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey)) {
    return reply({ error: 'idempotency_key_required' }, 400);
  }
  if (!url || !anonKey || !serviceKey || (!directConfig && (!gatewayUrl || !gatewaySecret))) {
    return reply({ error: 'vision_not_configured' }, 503);
  }
  const auth = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const admin = createClient(url, serviceKey);
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
  const estimatedBytes = Math.floor(body.image_base64.length * 0.75);
  if (estimatedBytes < 1 || estimatedBytes > 12 * 1024 * 1024) {
    return reply({ error: 'image_size_out_of_range' }, 413);
  }
  const digestBytes = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`${body.mime_type}:${body.image_base64}`),
  );
  const payloadDigest = Array.from(new Uint8Array(digestBytes))
    .map((value) => value.toString(16).padStart(2, '0')).join('');
  const { data: throttle, error: throttleError } = await admin.rpc(
    'bil_check_vision_nonfood_throttle',
    { p_owner_id: data.user.id },
  );
  if (throttleError) return reply({ error: 'vision_quota_unavailable' }, 503);
  if (throttle?.allowed === false) {
    return reply({
      error: 'vision_nonfood_throttled',
      retry_after_seconds: throttle.retry_after_seconds,
    }, 429);
  }
  const { data: reservation, error: reserveError } = await admin.rpc(
    'bil_reserve_ai_vision',
    {
      p_owner_id: data.user.id,
      p_request_id: idempotencyKey,
      p_image_digest: payloadDigest,
    },
  );
  if (reserveError) {
    const message = reserveError.message ?? '';
    if (message.includes('ai_boost_required')) return reply({ error: 'ai_boost_required' }, 402);
    if (message.includes('ai_usage_exhausted')) return reply({ error: 'vision_quota_exhausted' }, 429);
    if (message.includes('duplicate_image')) return reply({ error: 'duplicate_image' }, 409);
    if (message.includes('idempotency_payload_mismatch')) return reply({ error: 'idempotency_payload_mismatch' }, 409);
    return reply({ error: 'vision_quota_unavailable' }, 503);
  }
  if (reservation?.duplicate === true) {
    if (reservation.state === 'succeeded' && reservation.response_body) {
      const cached = reservation.response_body as Record<string, unknown>;
      return reply({ ...cached, cache: {
        hit: reservation.cache_hit === true,
        charged: false,
      } });
    }
    return reply({ error: 'request_already_processed', state: reservation.state }, 409);
  }
  let providerAttempts = 0;
  const settle = async (succeeded: boolean, metrics: Record<string, unknown> = {}, responseBody: unknown = null) =>
    await admin.rpc('bil_settle_ai_vision', {
      p_owner_id: data.user.id,
      p_request_id: idempotencyKey,
      p_succeeded: succeeded,
      p_provider: providerLabel,
      p_model: modelRevision,
      p_latency_ms: metrics.latency_ms ?? null,
      p_input_tokens: metrics.input_tokens ?? null,
      p_output_tokens: metrics.output_tokens ?? null,
      p_cost_usd: metrics.cost_usd ?? null,
      p_response_body: responseBody,
      p_provider_attempts: providerAttempts,
      p_cost_source: metrics.cost_source ?? 'unavailable',
    });
  const requestedLocale = resolveBilLocale(body.requested_locale);
  let upstream: Response | null = null;
  const startedAt = Date.now();
  // Gemini image requests regularly exceed 12 seconds even when healthy.
  // Keep each attempt bounded, but allow one normal high-latency response to
  // finish before using the single retry and risking duplicate provider cost.
  const providerAttemptTimeoutMs = 25_000;
  const transientStatus = (status: number) => [408, 429, 500, 502, 503, 504].includes(status);
  for (let attempt = 1; attempt <= 2; attempt++) {
    providerAttempts = attempt;
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), providerAttemptTimeoutMs);
    try {
      if (directConfig) {
        const providerRequest = buildProviderRequest(directConfig, {
          imageBase64: body.image_base64,
          mimeType: body.mime_type,
          requestedLocale,
        });
        upstream = await fetch(providerRequest.url, {
          method: 'POST', signal: abort.signal,
          headers: providerRequest.headers, body: providerRequest.body,
        });
      } else {
        upstream = await fetch(gatewayUrl!, {
          method: 'POST', signal: abort.signal,
          headers: { 'content-type': 'application/json', authorization: `Bearer ${gatewaySecret!}` },
          body: JSON.stringify({
            schema_version: 1, image_base64: body.image_base64,
            mime_type: body.mime_type, requested_locale: requestedLocale,
            rules: { identify_visible_food_only: true, no_nutrition_estimation: true, no_medical_claims: true, maximum_candidates: 8 },
          }),
        });
      }
      if (upstream.ok || !transientStatus(upstream.status) || attempt === 2) break;
      await upstream.body?.cancel();
    } catch (_) {
      upstream = null;
      if (attempt === 2) break;
    } finally {
      clearTimeout(timer);
    }
  }
  if (!upstream) {
    await settle(false, { latency_ms: Date.now() - startedAt });
    return reply({ error: directConfig ? 'vision_provider_failed' : 'vision_gateway_failed' }, 502);
  }
  if (!upstream.ok) {
    await settle(false, { latency_ms: Date.now() - startedAt });
    const failureText = await upstream.text().catch(() => '');
    let providerErrorCode: string | number | null = null;
    try {
      const failure = JSON.parse(failureText) as Record<string, unknown>;
      const nested = failure.error && typeof failure.error === 'object'
        ? failure.error as Record<string, unknown>
        : failure;
      const rawCode = nested.status ?? nested.code;
      if (typeof rawCode === 'string' || typeof rawCode === 'number') {
        providerErrorCode = rawCode;
      }
    } catch (_) {
      // Never return or log an unstructured upstream body.
    }
    return reply({
      error: directConfig ? 'vision_provider_failed' : 'vision_gateway_failed',
      provider_status: upstream.status,
      provider_error_code: providerErrorCode,
    }, 502);
  }
  const upstreamText = await upstream.text();
  if (new TextEncoder().encode(upstreamText).byteLength > 256 * 1024) {
    await settle(false, { latency_ms: Date.now() - startedAt });
    return reply({ error: 'invalid_vision_response' }, 502);
  }
  const decoded: unknown = (() => {
    try { return JSON.parse(upstreamText); } catch (_) { return null; }
  })();
  let candidates: Array<VisionCandidate & {
    amount: number | null; unit: string | null;
    alternatives: Array<{ name: string; confidence: number }>;
    uncertainty: string | null; warnings: string[];
  }>;
  let providerUsage: { input_tokens: number | null; output_tokens: number | null; cost_usd: number | null };
  const safeMetric = (key: string): number | null => {
    const root = decoded && typeof decoded === 'object' ? decoded as Record<string, unknown> : {};
    const usage = root.usage && typeof root.usage === 'object' ? root.usage as Record<string, unknown> : {};
    const value = usage[key];
    return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null;
  };
  if (directConfig) {
    try {
      const normalized = normalizeProviderResponse(decoded, directConfig);
      candidates = normalized.candidates;
      providerUsage = normalized.usage;
    } catch (error) {
      await settle(false, { latency_ms: Date.now() - startedAt });
      const providerFailure = error instanceof VisionProviderError && error.code === 'provider_error';
      return reply({
        error: providerFailure ? 'vision_provider_failed' : 'invalid_vision_response',
        provider_validation_code: error instanceof VisionProviderError ? error.code : 'unknown',
        provider_validation_reason: error instanceof VisionProviderError ? error.message : 'Unknown normalization failure',
      }, 502);
    }
  } else {
    const root = decoded && typeof decoded === 'object' ? decoded as Record<string, unknown> : null;
    const raw = root && Array.isArray(root.candidates) ? root.candidates : null;
    if (!raw || raw.length > 8) {
      await settle(false, { latency_ms: Date.now() - startedAt });
      return reply({ error: 'invalid_vision_response' }, 502);
    }
    const legacy = raw.map(candidate);
    if (legacy.some((item: VisionCandidate | null) => item === null)) {
      await settle(false, { latency_ms: Date.now() - startedAt });
      return reply({ error: 'invalid_vision_response' }, 502);
    }
    candidates = (legacy as VisionCandidate[]).map((item) => ({
      ...item, amount: null, unit: null, alternatives: [], uncertainty: null,
      warnings: [],
    }));
    providerUsage = {
      input_tokens: safeMetric('input_tokens'),
      output_tokens: safeMetric('output_tokens'),
      cost_usd: safeMetric('cost_usd'),
    };
  }
  let costSource = providerUsage.cost_usd === null ? 'unavailable' : 'provider';
  if (providerUsage.cost_usd === null && providerUsage.input_tokens !== null &&
      providerUsage.output_tokens !== null) {
    const { data: estimatedCost } = await auth.rpc('bil_estimate_vision_cost', {
      p_provider: providerLabel,
      p_model: modelRevision,
      p_input_tokens: providerUsage.input_tokens,
      p_output_tokens: providerUsage.output_tokens,
    });
    const parsedCost = typeof estimatedCost === 'number'
      ? estimatedCost
      : typeof estimatedCost === 'string' ? Number(estimatedCost) : NaN;
    if (Number.isFinite(parsedCost) && parsedCost >= 0) {
      providerUsage.cost_usd = parsedCost;
      costSource = 'pricing_table';
    }
  }
  const responseBody = {
    schema_version: 1,
    request_id: idempotencyKey,
    candidates: candidates.map((item) => ({
      ...item,
      provenance: {
        identification_provider: providerLabel,
        model_revision: modelRevision,
        nutrition_resolution: 'requires_verified_food_match',
      },
    })),
    notice: candidates.length === 0
      ? 'No food could be identified reliably. Add the meal manually.'
      : 'Confirm each visible food and serving. Nutrition is resolved separately from verified food records.',
    provider_metrics: {
      provider: providerLabel,
      model_revision: modelRevision,
      latency_ms: Date.now() - startedAt,
      input_tokens: providerUsage.input_tokens,
      output_tokens: providerUsage.output_tokens,
      cost_usd: providerUsage.cost_usd,
      cost_source: costSource,
      provider_attempts: providerAttempts,
    },
    quota: reservation,
  };
  if (candidates.length === 0) {
    const { data: nonFoodPolicy, error: policyError } = await admin.rpc(
      'bil_decide_unknown_nonfood_settlement',
      { p_owner_id: data.user.id, p_request_id: idempotencyKey },
    );
    if (policyError) return reply({ error: 'vision_receipt_failed' }, 503);
    const courtesyRefund = nonFoodPolicy?.courtesy_refund === true;
    const { error: refundError } = await settle(!courtesyRefund, {
      latency_ms: Date.now() - startedAt,
      input_tokens: providerUsage.input_tokens,
      output_tokens: providerUsage.output_tokens,
      cost_usd: providerUsage.cost_usd,
      cost_source: costSource,
    });
    if (refundError) return reply({ error: 'vision_receipt_failed' }, 503);
    return reply({
      error: 'non_food_or_unrecognized',
      notice: courtesyRefund
        ? 'No food could be identified reliably. This courtesy attempt was not charged.'
        : 'No food could be identified reliably. This analyzed attempt was charged.',
      charged: !courtesyRefund,
      courtesy_refund: courtesyRefund,
      provider_metrics: responseBody.provider_metrics,
    }, 422);
  }
  const { error: foodMarkError } = await admin.rpc('bil_mark_ai_vision_food', {
    p_owner_id: data.user.id,
    p_request_id: idempotencyKey,
  });
  if (foodMarkError) return reply({ error: 'vision_receipt_failed' }, 503);
  const { error: settleError } = await settle(true, {
    latency_ms: Date.now() - startedAt,
    input_tokens: providerUsage.input_tokens,
    output_tokens: providerUsage.output_tokens,
    cost_usd: providerUsage.cost_usd,
    cost_source: costSource,
  }, responseBody);
  if (settleError) return reply({ error: 'vision_receipt_failed' }, 503);
  return reply(responseBody);
});
