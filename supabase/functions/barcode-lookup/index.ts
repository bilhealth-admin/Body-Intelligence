import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  canonicalBarcodeLocale, hasCompleteCore, lookupGtinCandidates, normalizeLookupGtin,
  Product, record, responseProduct, sameGtin, text,
} from "./gtin_lookup.ts";
import { lookupOff, lookupUsda } from "./providers.ts";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "content-type": "application/json", "cache-control": "no-store" },
});
const env = (name: string) => Deno.env.get(name)?.trim() ?? "";
export type BarcodeAccess =
  | { ok: false; error: string; status: number }
  | { ok: true; getCached(gtin: string): Promise<unknown>;
      putCached(gtin: string, source: string, payload: Product): Promise<void> };
export interface BarcodeRuntime {
  authorize(request: Request): Promise<BarcodeAccess>;
  openFacts(gtin: string, locale: string): Promise<Product | null>;
  usda(gtin: string): Promise<Product | null>;
}

async function authorize(request: Request): Promise<BarcodeAccess> {
  const url = env("SUPABASE_URL"), service = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !service) return { ok: false, error: "server_not_configured", status: 503 };
  const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return { ok: false, error: "invalid_session", status: 401 };
  const admin = createClient(url, service);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return { ok: false, error: "invalid_session", status: 401 };
  // Coverage work must not silently change the existing commerce entitlement.
  const { data: allowed, error: gateError } = await admin.rpc(
    "bil_has_premium_barcode_access", { p_owner_id: data.user.id },
  );
  if (gateError) return { ok: false, error: "entitlement_unavailable", status: 503 };
  if (allowed !== true) return { ok: false, error: "premium_required", status: 403 };
  return {
    ok: true,
    getCached: async (gtin) => {
      const { data, error } = await admin.rpc("bil_get_cached_barcode", { p_gtin: gtin });
      if (error) throw new Error("cache_unavailable");
      return data;
    },
    putCached: async (gtin, source, payload) => {
      const { error } = await admin.rpc("bil_put_cached_barcode", {
        p_gtin: gtin, p_source: source, p_payload: payload, p_ttl_days: 30,
      });
      if (error) throw new Error("cache_unavailable");
    },
  };
}
const production: BarcodeRuntime = {
  authorize,
  openFacts: (gtin, locale) => lookupOff(gtin, locale),
  usda: (gtin) => lookupUsda(gtin, env("BIL_USDA_API_KEY") || env("USDA")),
};

async function boundedBody(request: Request): Promise<Product | Response> {
  if (!request.body) return json({ error: "invalid_request" }, 400);
  const reader = request.body.getReader();
  const parts: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 4096) {
      await reader.cancel().catch(() => undefined);
      return json({ error: "request_too_large" }, 413);
    }
    parts.push(value);
  }
  try {
    const bytes = new Uint8Array(size);
    let at = 0;
    for (const part of parts) { bytes.set(part, at); at += part.byteLength; }
    const body = record(JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)));
    return body ?? json({ error: "invalid_request" }, 400);
  } catch { return json({ error: "invalid_request" }, 400); }
}

function validProduct(value: unknown, gtin: string): Product | null {
  const product = record(value);
  return product && sameGtin(product.gtin, gtin) && text(product.name) &&
      ["open_facts", "usda"].includes(text(product.provider)) ? product : null;
}

export async function handleBarcodeRequest(request: Request, runtime: BarcodeRuntime = production): Promise<Response> {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (Number(request.headers.get("content-length") ?? 0) > 4096) {
    return json({ error: "request_too_large" }, 413);
  }
  let access: BarcodeAccess;
  try { access = await runtime.authorize(request); }
  catch { return json({ error: "authorization_unavailable" }, 503); }
  if (!access.ok) return json({ error: access.error }, access.status);
  const body = await boundedBody(request);
  if (body instanceof Response) return body;
  const gtin = normalizeLookupGtin(body.gtin);
  if (!gtin) return json({ error: "invalid_gtin" }, 400);
  const locale = canonicalBarcodeLocale(body.locale);
  const found = (payload: Product, cacheHit: boolean) => json({
    status: "found", gtin, source: payload.provider, cache_hit: cacheHit,
    payload: responseProduct(payload, locale),
  });
  let fallback: Product | null = null;
  let fallbackFromCache = false;
  for (const candidate of lookupGtinCandidates(gtin)) {
    try {
      const cached = record(await access.getCached(candidate));
      const payload = validProduct(cached?.payload, gtin);
      if (payload && hasCompleteCore(payload)) return found(payload, true);
      if (payload && !fallback) { fallback = payload; fallbackFromCache = true; }
    } catch { break; } // A cache outage is not a failed product lookup.
  }
  let unavailable = false;
  for (const lookup of [
    () => runtime.openFacts(gtin, locale), () => runtime.usda(gtin),
  ]) {
    try {
      const raw = await lookup();
      const payload = validProduct(raw, gtin);
      if (raw !== null && !payload) { unavailable = true; continue; }
      if (!payload) continue;
      if (hasCompleteCore(payload)) {
        try { await access.putCached(gtin, text(payload.provider), payload); }
        catch { /* Product evidence remains usable without a cache write. */ }
        return found(payload, false);
      }
      if (!fallback) { fallback = payload; fallbackFromCache = false; }
    } catch { unavailable = true; }
  }
  if (fallback) {
    // Keep one provider's evidence intact; do not blend different label versions.
    // Do not renew an incomplete record's TTL after a failed enrichment attempt.
    return found(fallback, fallbackFromCache);
  }
  if (unavailable) return json({ error: "barcode_providers_unavailable" }, 503);
  return json({ status: "unresolved", gtin, cache_hit: false,
    next_step: "capture_product_label",
    notice: "No trusted product record matched. Scan the product label; BIL will not invent nutrition." }, 404);
}
if (import.meta.main) Deno.serve((request) => handleBarcodeRequest(request));
