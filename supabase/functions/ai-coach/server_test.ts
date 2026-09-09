import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  actionExecutionContract,
  boundedMessages,
  boundedVoiceAudio,
  extractModelText,
  geminiAttemptTimeoutMs,
  geminiCall,
  geminiSafetySettings,
  handler,
  isRetryableGeminiError,
  isRetryableGeminiStatus,
  parseModelJson,
  requireSafeGeminiCandidate,
  responseLanguage,
  spokenWithinComfortableTurn,
} from "./server.ts";

Deno.test("model prompt separates proposed actions from execution receipts", () => {
  assertEquals(
    actionExecutionContract.includes("not an execution receipt"),
    true,
  );
  assertEquals(actionExecutionContract.includes("never say"), true);
});

Deno.test("structured response ignores thought parts and joins visible text", () => {
  assertEquals(
    extractModelText([
      { thought: true, text: "private reasoning" },
      { text: '{"reply":"Ready",' },
      { text: '"spoken_reply":"Ready"}' },
    ]),
    '{"reply":"Ready","spoken_reply":"Ready"}',
  );
});

Deno.test("message contract is bounded and ends with a user message", () => {
  assertEquals(
    boundedMessages([
      { role: "assistant", content: "ready" },
      { role: "user", content: "hello" },
    ]).length,
    2,
  );
  assertThrows(() => boundedMessages([{ role: "assistant", content: "done" }]));
  assertThrows(() =>
    boundedMessages([{ role: "user", content: "x".repeat(4001) }])
  );
});

Deno.test("voice payload is WAV-only, short-lived, and size bounded", () => {
  const data = btoa(String.fromCharCode(...new Uint8Array(48)));
  assertEquals(
    boundedVoiceAudio({
      mime_type: "audio/wav",
      data,
      duration_seconds: 7,
    })?.durationSeconds,
    7,
  );
  assertThrows(() =>
    boundedVoiceAudio({
      mime_type: "audio/mp3",
      data,
      duration_seconds: 7,
    })
  );
  assertThrows(() =>
    boundedVoiceAudio({
      mime_type: "audio/wav",
      data,
      duration_seconds: 46,
    })
  );
});

Deno.test("response language is independent from interface locale", () => {
  assertEquals(
    responseLanguage([
      { role: "user", content: "أعطني نصيحة عامة قصيرة لتحسين النوم" },
    ], "en"),
    "ar",
  );
  assertEquals(
    responseLanguage([
      { role: "user", content: "Give me one short general sleep tip" },
    ], "ar"),
    "en",
  );
  assertEquals(
    responseLanguage([
      { role: "user", content: "Скільки калорій залишилось?" },
    ], "en"),
    "uk",
  );
  assertEquals(
    responseLanguage([
      { role: "user", content: "assalamualaikum" },
    ], "en"),
    "ar",
  );
  assertEquals(
    responseLanguage(
      [
        { role: "user", content: "protein 30 g" },
      ],
      "en",
      "el-GR",
    ),
    "el-GR",
  );
  assertEquals(
    responseLanguage([
      { role: "user", content: "una frase breve" },
    ], "en"),
    "auto",
  );
  assertEquals(
    responseLanguage(
      [{ role: "user", content: "hi" }],
      "ar",
      "en",
    ),
    "en",
  );
  assertEquals(
    responseLanguage(
      [{ role: "user", content: "protein 30 g" }],
      "tr",
      "ar",
    ),
    "ar",
  );
});

Deno.test("weight history stays a proposed client action, not a receipt", () => {
  const parsed = parseModelJson(JSON.stringify({
    reply: "Use the action below to open weight history.",
    spoken_reply: "Use the action below to open weight history.",
    reason: "The user requested a read-only screen.",
    confidence: 0.95,
    evidence: [],
    missing_data: [],
    proposed_actions: [{
      type: "open_weight_log",
      arguments: {},
      requires_confirmation: false,
    }],
  }));
  assertEquals(parsed.proposed_actions, [{
    type: "open_weight_log",
    arguments: {},
    requires_confirmation: true,
  }]);
  assertEquals(parsed.reply.includes("opened"), false);
});

Deno.test("model actions are allow-listed and confirmation-gated", () => {
  const parsed = parseModelJson(JSON.stringify({
    reply: "I can prepare that.",
    spoken_reply: "I can prepare that after your confirmation.",
    reason: "The request includes an exact amount.",
    confidence: 0.9,
    evidence: ["context.waterHistory"],
    missing_data: [],
    proposed_actions: [
      {
        type: "log_water",
        arguments: { amountMl: 250 },
        requires_confirmation: false,
      },
      { type: "run_sql", arguments: { sql: "drop table profiles" } },
    ],
  }));
  assertEquals(parsed.proposed_actions, [{
    type: "log_water",
    arguments: { amountMl: 250 },
    requires_confirmation: true,
  }]);
  assertEquals(
    parsed.spoken_reply,
    "I can prepare that after your confirmation.",
  );
  assertEquals(parsed.confidence, 0.9);
  assertEquals(parsed.evidence, ["context.waterHistory"]);
  assertThrows(() =>
    parseModelJson(JSON.stringify({
      reply: "Safe written answer.",
      spoken_reply: "* not a spoken sentence",
      proposed_actions: [],
    }))
  );
});

Deno.test("spoken summary is bounded to a comfortable voice turn", () => {
  assertEquals(
    spokenWithinComfortableTurn("Sleep seven to nine hours each night."),
    true,
  );
  assertEquals(
    spokenWithinComfortableTurn(Array(48).fill("word").join(" ")),
    true,
  );
  assertEquals(
    spokenWithinComfortableTurn(Array(49).fill("word").join(" ")),
    false,
  );
  assertThrows(() =>
    parseModelJson(JSON.stringify({
      reply: "A detailed answer remains visible.",
      spoken_reply: Array(49).fill("word").join(" "),
      proposed_actions: [],
    }))
  );
});

Deno.test("HTTP boundary rejects unsupported methods and missing auth", async () => {
  assertEquals(
    (await handler(new Request("https://example.test", { method: "GET" })))
      .status,
    405,
  );
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: "{}",
      headers: { "content-type": "application/json" },
    }),
  );
  assertEquals(response.status, 401);
  assertEquals(await response.json(), { error: "authentication_required" });
});

async function withGeminiTestKey<T>(run: () => Promise<T>) {
  const previous = Deno.env.get("BIL_GEMINI_API_KEY");
  Deno.env.set("BIL_GEMINI_API_KEY", "test-gemini-key");
  try {
    return await run();
  } finally {
    if (previous == null) Deno.env.delete("BIL_GEMINI_API_KEY");
    else Deno.env.set("BIL_GEMINI_API_KEY", previous);
  }
}

function providerSuccess() {
  return new Response(JSON.stringify({ candidates: [] }), { status: 200 });
}

Deno.test("Gemini retry policy bounds each attempt and retries only transient failures", async () => {
  assertEquals(geminiAttemptTimeoutMs, 12_000);
  assertEquals(isRetryableGeminiStatus(429), true);
  assertEquals(isRetryableGeminiStatus(503), true);
  assertEquals(isRetryableGeminiStatus(400), false);
  assertEquals(isRetryableGeminiError(new TypeError("network")), true);
  assertEquals(
    isRetryableGeminiError(new DOMException("timed out", "TimeoutError")),
    true,
  );
  assertEquals(isRetryableGeminiError(new Error("malformed JSON")), false);

  await withGeminiTestKey(async () => {
    let rateLimitedCalls = 0;
    const recovered = await geminiCall(
      "gemini-test",
      [],
      "test",
      32,
      false,
      "LOW",
      async (_url, _init) => {
        rateLimitedCalls += 1;
        return rateLimitedCalls === 1
          ? new Response(
            JSON.stringify({ error: { status: "RESOURCE_EXHAUSTED" } }),
            { status: 429 },
          )
          : providerSuccess();
      },
    );
    assertEquals(recovered.attempts, 2);
    assertEquals(rateLimitedCalls, 2);

    let networkCalls = 0;
    const networkRecovered = await geminiCall(
      "gemini-test",
      [],
      "test",
      32,
      false,
      "LOW",
      async (_url, _init) => {
        networkCalls += 1;
        if (networkCalls === 1) throw new TypeError("network unavailable");
        return providerSuccess();
      },
    );
    assertEquals(networkRecovered.attempts, 2);
    assertEquals(networkCalls, 2);
  });
});

Deno.test("Gemini retry policy does not repeat client or parse errors", async () => {
  await withGeminiTestKey(async () => {
    let clientErrorCalls = 0;
    await assertRejects(
      () =>
        geminiCall(
          "gemini-test",
          [],
          "test",
          32,
          false,
          "LOW",
          async (_url, _init) => {
            clientErrorCalls += 1;
            return new Response(
              JSON.stringify({ error: { status: "INVALID_ARGUMENT" } }),
              { status: 400 },
            );
          },
        ),
      Error,
      "provider_http_400_invalid_argument",
    );
    assertEquals(clientErrorCalls, 1);

    let serverErrorCalls = 0;
    await assertRejects(
      () =>
        geminiCall(
          "gemini-test",
          [],
          "test",
          32,
          false,
          "LOW",
          async (_url, _init) => {
            serverErrorCalls += 1;
            return new Response("temporary", { status: 503 });
          },
        ),
      Error,
      "provider_http_503",
    );
    assertEquals(serverErrorCalls, 2);

    let parseCalls = 0;
    await assertRejects(
      () =>
        geminiCall(
          "gemini-test",
          [],
          "test",
          32,
          false,
          "LOW",
          async (_url, _init) => {
            parseCalls += 1;
            return new Response("not-json", { status: 200 });
          },
        ),
      Error,
    );
    assertEquals(parseCalls, 1);
  });
});

Deno.test("Gemini request always carries the four explicit conservative safety settings", async () => {
  assertEquals(geminiSafetySettings, [
    {
      category: "HARM_CATEGORY_HARASSMENT",
      threshold: "BLOCK_ONLY_HIGH",
    },
    {
      category: "HARM_CATEGORY_HATE_SPEECH",
      threshold: "BLOCK_ONLY_HIGH",
    },
    {
      category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
      threshold: "BLOCK_ONLY_HIGH",
    },
    {
      category: "HARM_CATEGORY_DANGEROUS_CONTENT",
      threshold: "BLOCK_ONLY_HIGH",
    },
  ]);

  await withGeminiTestKey(async () => {
    let sentBody: Record<string, unknown> = {};
    await geminiCall(
      "gemini-test",
      [],
      "test",
      32,
      false,
      "LOW",
      async (_url, init) => {
        sentBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
        return providerSuccess();
      },
    );
    assertEquals(sentBody.safetySettings, geminiSafetySettings);
    assertEquals(
      (sentBody.generationConfig as Record<string, unknown>).safetySettings,
      undefined,
    );
  });
});

Deno.test("Gemini prompt and candidate safety metadata fail closed", async () => {
  await assertRejects(
    () =>
      Promise.resolve().then(() =>
        requireSafeGeminiCandidate({
          promptFeedback: { blockReason: "SAFETY" },
          candidates: [],
        })
      ),
    Error,
    "ai_safety_blocked",
  );
  for (
    const candidate of [
      { finishReason: "SAFETY" },
      { finishReason: "STOP", safetyRatings: [{ blocked: true }] },
    ]
  ) {
    await assertRejects(
      () =>
        Promise.resolve().then(() =>
          requireSafeGeminiCandidate({ candidates: [candidate] })
        ),
      Error,
      "ai_safety_blocked",
    );
  }
  for (const finishReason of [undefined, "MAX_TOKENS", "FUTURE_REASON"]) {
    await assertRejects(
      () =>
        Promise.resolve().then(() =>
          requireSafeGeminiCandidate({ candidates: [{ finishReason }] })
        ),
      Error,
      "provider_incomplete_response",
    );
  }
  const safe = { finishReason: "STOP", safetyRatings: [{ blocked: false }] };
  assertEquals(
    requireSafeGeminiCandidate({
      promptFeedback: { safetyRatings: [{ blocked: false }] },
      candidates: [safe],
    }),
    safe,
  );
});

function requestBody(requestId = "coach-test-request-0001") {
  return new Request("https://example.test", {
    method: "POST",
    headers: {
      authorization: "Bearer test",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      request_id: requestId,
      locale: "en",
      messages: [{ role: "user", content: "Give one short sleep tip" }],
      context: {},
    }),
  });
}

function fakeClients(reservations: Array<Record<string, unknown>>) {
  const settlements: Array<Record<string, unknown>> = [];
  return {
    settlements,
    create: (_authorization: string) => ({
      auth: {
        auth: {
          getUser: async () => ({
            data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
            error: null,
          }),
        },
      },
      admin: {
        rpc: async (name: string, params: Record<string, unknown>) => {
          if (name === "bil_has_remote_ai_consent") {
            return { data: true, error: null };
          }
          if (name === "bil_reserve_ai_usage") {
            return {
              data: reservations.shift() ??
                { duplicate: true, state: "succeeded" },
              error: null,
            };
          }
          settlements.push(params);
          return {
            data: { state: params.p_succeeded ? "succeeded" : "refunded" },
            error: null,
          };
        },
      },
    }),
  };
}

Deno.test("provider timeout refunds exactly one established reservation", async () => {
  const fake = fakeClients([{ duplicate: false, state: "reserved" }]);
  const response = await handler(requestBody(), {
    clients: fake.create as never,
    geminiCall: async () => {
      throw new Error("provider_timeout");
    },
    now: (() => {
      let value = 1000;
      return () => value += 10;
    })(),
  });
  assertEquals(response.status, 503);
  assertEquals(fake.settlements.length, 1);
  assertEquals(fake.settlements[0].p_succeeded, false);
});

Deno.test("settlement outage does not hide the original provider failure", async () => {
  let settlementCalls = 0;
  const response = await handler(requestBody("coach-test-settlement-outage"), {
    clients: ((_authorization: string) => ({
      auth: {
        auth: {
          getUser: async () => ({
            data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
            error: null,
          }),
        },
      },
      admin: {
        rpc: async (name: string) => {
          if (name === "bil_has_remote_ai_consent") {
            return { data: true, error: null };
          }
          if (name === "bil_reserve_ai_usage") {
            return {
              data: { duplicate: false, state: "reserved" },
              error: null,
            };
          }
          settlementCalls += 1;
          throw new Error("database unavailable");
        },
      },
    })) as never,
    geminiCall: async () => {
      throw new Error("provider_timeout");
    },
  });

  assertEquals(response.status, 503);
  assertEquals((await response.json()).error, "provider_timeout");
  assertEquals(settlementCalls, 1);
});

Deno.test("prompt safety block returns only the stable 422 code and refunds once", async () => {
  const fake = fakeClients([{ duplicate: false, state: "reserved" }]);
  let providerCalls = 0;
  const response = await handler(requestBody("coach-test-safety-block"), {
    clients: fake.create as never,
    geminiCall: async () => {
      providerCalls += 1;
      return {
        attempts: 1,
        data: {
          promptFeedback: {
            blockReason: "SAFETY",
            blockReasonMessage: "provider-private-detail",
          },
          candidates: [],
        },
      };
    },
  });

  assertEquals(response.status, 422);
  assertEquals(await response.json(), { error: "ai_safety_blocked" });
  assertEquals(providerCalls, 1);
  assertEquals(fake.settlements.length, 1);
  assertEquals(fake.settlements[0].p_succeeded, false);
});

Deno.test("successful response exposes the metered request id for feedback correlation", async () => {
  const requestId = "coach-test-feedback-correlation";
  const fake = fakeClients([{ duplicate: false, state: "reserved" }]);
  const response = await handler(requestBody(requestId), {
    clients: fake.create as never,
    geminiCall: async () => ({
      attempts: 1,
      data: {
        candidates: [{
          finishReason: "STOP",
          content: {
            parts: [{
              text: JSON.stringify({
                reply: "Keep a consistent sleep window.",
                spoken_reply: "Keep a consistent sleep window.",
                reason: "Consistency supports sleep timing.",
                confidence: 0.8,
                evidence: [],
                missing_data: [],
                proposed_actions: [],
              }),
            }],
          },
        }],
        usageMetadata: {
          promptTokenCount: 20,
          candidatesTokenCount: 10,
          thoughtsTokenCount: 5,
        },
      },
    }),
  });
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.response_id, requestId);
  assertEquals(fake.settlements.length, 1);
  assertEquals(fake.settlements[0].p_succeeded, true);
  assertEquals(fake.settlements[0].p_output_tokens, 15);
  assertEquals(body.usage.visible_output_tokens, 10);
  assertEquals(body.usage.thinking_tokens, 5);
  assertEquals(body.usage.billed_output_tokens, 15);
});

Deno.test("malformed provider JSON refunds rather than charging", async () => {
  const fake = fakeClients([{ duplicate: false, state: "reserved" }]);
  const response = await handler(requestBody(), {
    clients: fake.create as never,
    geminiCall: async () => ({
      attempts: 1,
      data: {
        candidates: [{
          finishReason: "STOP",
          content: { parts: [{ text: '{"reply":"missing spoken"}' }] },
        }],
      },
    }),
  });
  assertEquals(response.status, 503);
  assertEquals(fake.settlements.length, 1);
  assertEquals(fake.settlements[0].p_succeeded, false);
});

Deno.test("duplicate request never calls provider or settles twice", async () => {
  const fake = fakeClients([{ duplicate: true, state: "succeeded" }]);
  let providerCalls = 0;
  const response = await handler(requestBody("coach-test-request-duplicate"), {
    clients: fake.create as never,
    geminiCall: async () => {
      providerCalls += 1;
      throw new Error("must_not_run");
    },
  });
  assertEquals(response.status, 409);
  assertEquals(providerCalls, 0);
  assertEquals(fake.settlements.length, 0);
});

Deno.test("reservation failure does not attempt settlement", async () => {
  const settlements: Array<Record<string, unknown>> = [];
  const response = await handler(requestBody("coach-test-reserve-failure"), {
    clients: ((_authorization: string) => ({
      auth: {
        auth: {
          getUser: async () => ({
            data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
            error: null,
          }),
        },
      },
      admin: {
        rpc: async (name: string, params: Record<string, unknown>) => {
          if (name === "bil_has_remote_ai_consent") {
            return { data: true, error: null };
          }
          if (name === "bil_reserve_ai_usage") {
            return { data: null, error: { message: "database unavailable" } };
          }
          settlements.push(params);
          return { data: null, error: null };
        },
      },
    })) as never,
  });
  assertEquals(response.status, 503);
  assertEquals(settlements.length, 0);
});

Deno.test("exhausted total fails closed with a distinguishable Boost route code", async () => {
  let providerCalls = 0;
  let settlementCalls = 0;
  const response = await handler(requestBody("coach-test-credits-required"), {
    clients: ((_authorization: string) => ({
      auth: {
        auth: {
          getUser: async () => ({
            data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
            error: null,
          }),
        },
      },
      admin: {
        rpc: async (name: string) => {
          if (name === "bil_has_remote_ai_consent") {
            return { data: true, error: null };
          }
          if (name === "bil_reserve_ai_usage") {
            return {
              data: null,
              error: { message: "ai_usage_exhausted" },
            };
          }
          settlementCalls += 1;
          return { data: null, error: null };
        },
      },
    })) as never,
    geminiCall: async () => {
      providerCalls += 1;
      throw new Error("must_not_run");
    },
  });

  assertEquals(response.status, 402);
  assertEquals((await response.json()).error, "ai_usage_exhausted");
  assertEquals(providerCalls, 0);
  assertEquals(settlementCalls, 0);
});

Deno.test("quota aliases cannot masquerade as exhausted AI credit", async () => {
  for (
    const message of [
      "not_ai_usage_exhausted",
      "ai_usage_exhausted_alias",
      "AI_USAGE_EXHAUSTED",
    ]
  ) {
    let providerCalls = 0;
    const response = await handler(requestBody(`coach-test-${message}`), {
      clients: ((_authorization: string) => ({
        auth: {
          auth: {
            getUser: async () => ({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
          },
        },
        admin: {
          rpc: async (name: string) =>
            name === "bil_has_remote_ai_consent"
              ? { data: true, error: null }
              : { data: null, error: { message } },
        },
      })) as never,
      geminiCall: async () => {
        providerCalls += 1;
        throw new Error("must_not_run");
      },
    });
    assertEquals(response.status, 503);
    assertEquals((await response.json()).error, "reservation_failed");
    assertEquals(providerCalls, 0);
  }
});

Deno.test("missing remote AI consent blocks before reservation and provider", async () => {
  let providerCalls = 0;
  let reservationCalls = 0;
  const response = await handler(requestBody("coach-test-no-consent"), {
    clients: ((_authorization: string) => ({
      auth: {
        auth: {
          getUser: async () => ({
            data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
            error: null,
          }),
        },
      },
      admin: {
        rpc: async (name: string) => {
          if (name === "bil_has_remote_ai_consent") {
            return { data: false, error: null };
          }
          reservationCalls += 1;
          return { data: null, error: null };
        },
      },
    })) as never,
    geminiCall: async () => {
      providerCalls += 1;
      throw new Error("must_not_run");
    },
  });
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { error: "ai_consent_required" });
  assertEquals(reservationCalls, 0);
  assertEquals(providerCalls, 0);
});

Deno.test("voice uses v2 consent and one voice-seconds reservation", async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  let providerContents: unknown[] = [];
  const audioData = btoa(String.fromCharCode(...new Uint8Array(48)));
  const request = new Request("https://example.test", {
    method: "POST",
    headers: {
      authorization: "Bearer test",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      request_id: "coach-voice-test-request-0001",
      locale: "en",
      messages: [{ role: "user", content: "Spoken question" }],
      context: {},
      audio: {
        mime_type: "audio/wav",
        data: audioData,
        duration_seconds: 7,
      },
    }),
  });
  const response = await handler(request, {
    clients: ((_authorization: string) => ({
      auth: {
        auth: {
          getUser: async () => ({
            data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
            error: null,
          }),
        },
      },
      admin: {
        from: () => ({
          select: () => ({
            eq: () => ({
              eq: () => ({
                order: () => ({
                  limit: () => ({
                    maybeSingle: async () => ({
                      data: { granted: true, policy_version: "2" },
                      error: null,
                    }),
                  }),
                }),
              }),
            }),
          }),
        }),
        rpc: async (name: string, params: Record<string, unknown>) => {
          if (name === "bil_has_remote_ai_consent") {
            return { data: true, error: null };
          }
          calls.push({ name, params });
          if (name === "bil_reserve_ai_voice") {
            return {
              data: { duplicate: false, state: "reserved" },
              error: null,
            };
          }
          return { data: { state: "succeeded" }, error: null };
        },
      },
    })) as never,
    geminiCall: async (_model, contents) => {
      providerContents = contents;
      return {
        attempts: 1,
        data: {
          candidates: [{
            finishReason: "STOP",
            content: {
              parts: [{
                text: JSON.stringify({
                  transcript: "اشرح لي لماذا وزني ثابت هذا الأسبوع",
                  reply: "سأراجع اتجاه الوزن والالتزام خلال الأسبوع.",
                  spoken_reply: "سأراجع اتجاه وزنك وبيانات هذا الأسبوع.",
                  reason: "السؤال يطلب تفسير ثبات الوزن.",
                  confidence: 0.8,
                  evidence: [],
                  missing_data: [],
                  proposed_actions: [],
                }),
              }],
            },
          }],
          usageMetadata: { promptTokenCount: 20, candidatesTokenCount: 10 },
        },
      };
    },
  });
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.transcript, "اشرح لي لماذا وزني ثابت هذا الأسبوع");
  assertEquals(calls[0].name, "bil_reserve_ai_voice");
  assertEquals(calls[0].params.p_estimated_seconds, 7);
  assertEquals(calls[1].name, "bil_settle_ai_voice");
  assertEquals(calls[1].params.p_actual_seconds, 7);
  assertEquals(JSON.stringify(providerContents).includes("inlineData"), true);
  assertEquals(
    calls.some((call) => call.name === "bil_reserve_ai_usage"),
    false,
  );
});
