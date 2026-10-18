import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decodeTranslatedText } from "./translation_text.ts";

const headers = {
  "content-type": "application/json",
  "cache-control": "no-store",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });
export interface TranslationRuntime {
  authorize(
    request: Request,
  ): Promise<"allowed" | "unauthorized" | "limited" | "unavailable">;
  key(): string;
  fetch: typeof fetch;
}
const runtime: TranslationRuntime = {
  key: () =>
    Deno.env.get("BIL_TRANSLATION_API_KEY")?.trim() ||
    Deno.env.get("Translation")?.trim() || "",
  fetch,
  async authorize(request) {
    const token = (request.headers.get("authorization") ?? "").replace(
      /^Bearer\s+/i,
      "",
    ).trim();
    if (!token) return "unauthorized";
    const client = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: { persistSession: false },
      },
    );
    const { data, error } = await client.auth.getUser(token);
    if (error || !data.user) return "unauthorized";
    const { error: quota } = await client.rpc(
      "bil_consume_community_translation_quota",
    );
    if (!quota) return "allowed";
    return quota.message.includes("rate limit exceeded")
      ? "limited"
      : "unavailable";
  },
};

// Explicit user action only. No text logging, persistence, cross-owner cache,
// service-role impersonation, AI credits or model downloads.
export async function handleTranslation(
  request: Request,
  deps = runtime,
): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const reader = request.body?.getReader();
  if (!reader) return json({ error: "invalid_input" }, 400);
  let size = 0;
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 96000) {
        await reader.cancel();
        return json({ error: "too_large" }, 413);
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let at = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, at);
      at += chunk.length;
    }
    const body = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (
      !body || typeof body !== "object" || Array.isArray(body) ||
      !body.texts || typeof body.texts !== "object" ||
      Array.isArray(body.texts) ||
      !/^[a-z]{2,3}(?:-[A-Za-z]{2,8}){0,2}$/.test(body.targetTag ?? "")
    ) {
      return json({ error: "invalid_input" }, 400);
    }
    const entries = Object.entries(body.texts);
    if (
      !entries.length || entries.length > 2 ||
      entries.some(([k, v]) =>
        !["title", "body"].includes(k) || typeof v !== "string" ||
        v.length > 12000
      )
    ) {
      return json({ error: "invalid_input" }, 400);
    }
    let access;
    try {
      access = await deps.authorize(request);
    } catch {
      return json({ error: "authorization_unavailable" }, 503);
    }
    if (access !== "allowed") {
      return json(
        { error: access },
        access === "unauthorized" ? 401 : access === "limited" ? 429 : 503,
      );
    }
    const key = deps.key();
    if (!key) return json({ error: "translation_unavailable" }, 503);
    const active = entries.filter(([, value]) =>
      (value as string).trim().length > 0
    );
    if (!active.length) {
      return json({ texts: body.texts, engine: "google", sameLanguage: true });
    }
    const target = body.targetTag === "zh-Hant"
      ? "zh-TW"
      : body.targetTag.startsWith("zh")
      ? "zh-CN"
      : body.targetTag.split("-")[0];
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await deps.fetch(
        `https://translation.googleapis.com/language/translate/v2?key=${
          encodeURIComponent(key)
        }`,
        {
          method: "POST",
          signal: controller.signal,
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            q: active.map(([, v]) => v),
            target,
            format: "text",
          }),
        },
      );
      if (!response.ok) return json({ error: "translation_unavailable" }, 503);
      const root = await response.json();
      const translated = root?.data?.translations;
      if (
        !Array.isArray(translated) || translated.length !== active.length ||
        translated.some((v) =>
          typeof v?.translatedText !== "string" || !v.translatedText.trim() ||
          v.translatedText.length > 48000
        )
      ) {
        return json({ error: "invalid_translation" }, 502);
      }
      const output = { ...body.texts };
      active.forEach(([name], index) =>
        output[name] = decodeTranslatedText(translated[index].translatedText)
      );
      return json({
        texts: output,
        engine: "google",
        sameLanguage: translated.every((v) =>
          v.detectedSourceLanguage === target
        ),
      });
    } catch {
      return json({ error: "translation_unavailable" }, 503);
    } finally {
      clearTimeout(timer);
    }
  } catch {
    return json({ error: "invalid_input" }, 400);
  }
}
if (import.meta.main) Deno.serve((request) => handleTranslation(request));
