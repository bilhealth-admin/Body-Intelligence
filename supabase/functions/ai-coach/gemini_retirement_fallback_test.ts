import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canonicalGeminiModel,
  independentGeminiFallback,
} from "./coach_reasoning.ts";
import { geminiCall, geminiCallWithFallback } from "./server.ts";

const vertex = "https://aiplatform.googleapis.com/v1beta1/publishers/google";

async function withCurrentConfiguration(run: () => Promise<void>) {
  const values: Record<string, string | undefined> = {
    BIL_GEMINI_API_KEY: "UNIT_PROVIDER_SECRET",
    BIL_GEMINI_TEXT_MODEL: "gemini-3.8-flash",
    BIL_GEMINI_TEXT_FALLBACK_MODEL: "gemini-3.7-flash",
    BIL_GEMINI_VISION_ENDPOINT: vertex,
    BIL_GEMINI_TEXT_ENDPOINT: undefined,
  };
  const previous = Object.fromEntries(
    Object.keys(values).map((key) => [key, Deno.env.get(key)]),
  );
  try {
    for (const [key, value] of Object.entries(values)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
    await run();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
}

function transportCall(fetcher: typeof fetch): typeof geminiCall {
  return (...args) => geminiCall(
    args[0], args[1], args[2], args[3], args[4], args[5], fetcher,
    args[7], args[8],
  );
}

Deno.test("retirement: aliases and independent fallbacks belong to the endpoint product", () => {
  assertEquals(canonicalGeminiModel("gemini-3.7-flash"), "gemini-3.8-flash");
  assertEquals(canonicalGeminiModel("gemini-3.7-flash", "vertex"), "gemini-3.7-flash");
  assertEquals(canonicalGeminiModel("gemini-3.5-flash", "vertex"), "gemini-3.5-flash");
  for (const retiring of ["gemini-3.6-flash", "models/gemini-3.7-flash"]) {
    assertEquals(independentGeminiFallback("gemini-3.8-flash", retiring, "vertex"), "");
    assertEquals(independentGeminiFallback("gemini-3.7-flash", retiring, "vertex"), "gemini-3.8-flash");
  }
  assertEquals(independentGeminiFallback("gemini-3.8-flash", "gemini-3.5-flash", "vertex"), "gemini-3.5-flash");
  assertEquals(independentGeminiFallback("gemini-3.8-flash", "gemini-3.5-flash-lite"), "gemini-3.5-flash-lite");
  assertEquals(independentGeminiFallback("gemini-3.7-flash", undefined, "developer"), "");
});

Deno.test("retirement: actual 3.8 primary and Vertex 3.7 override fail503 after one transport call", async () => {
  await withCurrentConfiguration(async () => {
    const urls: string[] = [];
    const call = transportCall(async (url) => {
      urls.push(String(url));
      return new Response(JSON.stringify({ error: { status: "UNAVAILABLE" } }), { status: 503 });
    });
    await assertRejects(
      () => geminiCallWithFallback(call, "gemini-3.8-flash", [], "unit", 32),
      Error,
      "provider_http_503_unavailable",
    );
    assertEquals(urls, [`${vertex}/models/gemini-3.8-flash:generateContent`]);
  });
});

Deno.test("retirement: Vertex 3.7 transient failure recovers once on independent 3.8", async () => {
  await withCurrentConfiguration(async () => {
    const urls: string[] = [];
    const call = transportCall(async (url) => {
      urls.push(String(url));
      return urls.length === 1
        ? new Response(JSON.stringify({ error: { status: "UNAVAILABLE" } }), { status: 503 })
        : new Response(JSON.stringify({}));
    });
    const result = await geminiCallWithFallback(call, "gemini-3.7-flash", [], "unit", 32);
    assertEquals(urls, [
      `${vertex}/models/gemini-3.7-flash:generateContent`,
      `${vertex}/models/gemini-3.8-flash:generateContent`,
    ]);
    assertEquals(result.model, "gemini-3.8-flash");
    assertEquals(result.fallbackUsed, true);
    assertEquals(result.provider.attempts, 2);
  });
});

Deno.test("retirement: HTTP404 is permanent even when an independent fallback exists", async () => {
  await withCurrentConfiguration(async () => {
    let calls = 0;
    const call = transportCall(async () => {
      calls += 1;
      return new Response(JSON.stringify({ error: { status: "NOT_FOUND" } }), { status: 404 });
    });
    await assertRejects(
      () => geminiCallWithFallback(call, "gemini-3.7-flash", [], "unit", 32),
      Error,
      "provider_http_404_not_found",
    );
    assertEquals(calls, 1);
  });
});

Deno.test("retirement: malformed200 JSON never invokes an independent fallback", async () => {
  await withCurrentConfiguration(async () => {
    let calls = 0;
    const call = transportCall(async () => {
      calls += 1;
      return new Response("malformed JSON");
    });
    await assertRejects(
      () => geminiCallWithFallback(call, "gemini-3.7-flash", [], "unit", 32),
      SyntaxError,
    );
    assertEquals(calls, 1);
  });
});

Deno.test("retirement: safety and provider-contract failures never invoke fallback", async () => {
  await withCurrentConfiguration(async () => {
    for (const code of ["ai_safety_blocked", "provider_invalid_response", "provider_http_400_invalid_argument"]) {
      let calls = 0;
      await assertRejects(
        () => geminiCallWithFallback(() => {
          calls += 1;
          return Promise.reject(new Error(code));
        }, "gemini-3.7-flash", [], "unit", 32),
        Error,
        code,
      );
      assertEquals(calls, 1);
    }
  });
});
