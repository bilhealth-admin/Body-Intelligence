import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  acceptedWeightHistoryNavigation,
  actionExecutionContract,
  allowedHealthCitationIds,
  answerNeedsHealthCitation,
  boundedMessages,
  extractModelText,
  geminiAttemptTimeoutMs,
  geminiCall,
  geminiCallWithFallback,
  geminiSafetySettings,
  handler,
  healthCitationCatalogVersion,
  healthCitationIdsForVersion,
  isFallbackEligibleGeminiError,
  isRetryableGeminiError,
  isRetryableGeminiStatus,
  parseModelJson,
  recoverExactUserAction,
  rejectRawVoiceAudio,
  requireSafeGeminiCandidate,
  responseLanguage,
  spokenWithinComfortableTurn,
  thinkingConfigForModel,
} from "./server.ts";

// Handler unit tests below isolate consent, metering, provider, and response
// behavior. Mobile-integrity enforcement has its own shared boundary suite.
Deno.env.set("BIL_MOBILE_INTEGRITY_ENFORCEMENT", "off");

Deno.test("model prompt separates proposed actions from execution receipts", () => {
  assertEquals(
    actionExecutionContract.includes("not an execution receipt"),
    true,
  );
  assertEquals(actionExecutionContract.includes("never say"), true);
  assertEquals(
    actionExecutionContract.includes("Never mention a button"),
    true,
  );
});

Deno.test("accepted weight-history offer restores the safe navigation action", () => {
  assertEquals(
    acceptedWeightHistoryNavigation([
      {
        role: "assistant",
        content: "هل تود استعراض تاريخ أوزانك بالكامل؟",
      },
      { role: "user", content: "نعم" },
    ]),
    true,
  );
  assertEquals(
    acceptedWeightHistoryNavigation([
      {
        role: "assistant",
        content: "Would you like to open your weight history?",
      },
      { role: "user", content: "Yes" },
    ]),
    true,
  );
  assertEquals(
    acceptedWeightHistoryNavigation([
      { role: "assistant", content: "Would you like another nutrition tip?" },
      { role: "user", content: "Yes" },
    ]),
    false,
  );
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

Deno.test("raw voice audio is rejected while transcript-only requests remain supported", () => {
  const data = btoa(String.fromCharCode(...new Uint8Array(48)));
  assertEquals(rejectRawVoiceAudio(null), undefined);
  assertThrows(
    () =>
      rejectRawVoiceAudio({
        mime_type: "audio/wav",
        data,
        duration_seconds: 7,
      }),
    Error,
    "raw_voice_audio_not_supported",
  );
  assertThrows(() =>
    rejectRawVoiceAudio({
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
    citations: [],
    requires_health_citation: false,
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
    citations: [],
    requires_health_citation: false,
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
      citations: [],
      requires_health_citation: false,
      proposed_actions: [],
    }))
  );
});

Deno.test("health citations keep only trusted registry identifiers", () => {
  const parsed = parseModelJson(JSON.stringify({
    reply: "CDC uses BMI as an adult screening measure.",
    spoken_reply: "CDC uses BMI as an adult screening measure.",
    reason: "General screening education.",
    confidence: 0.9,
    evidence: [],
    citations: [
      "cdc_adult_bmi",
      "https://untrusted.example/fake-study",
      "invented_study",
      "cdc_adult_bmi",
    ],
    requires_health_citation: true,
    missing_data: [],
    proposed_actions: [],
  }));

  assertEquals(parsed.citations, ["cdc_adult_bmi"]);
});

Deno.test("FDA label references survive parsing without admitting unknown citations", () => {
  const parsed = parseModelJson(
    JSON.stringify({
      reply: "FDA Daily Values are general nutrition label references.",
      spoken_reply: "FDA Daily Values are general nutrition label references.",
      reason: "Label education, not an individual nutrient prescription.",
      confidence: 0.9,
      evidence: [],
      citations: [
        "fda_label_daily_values",
        "https://untrusted.example/fake-study",
        "invented_fda_reference",
        "fda_label_daily_values",
      ],
      requires_health_citation: true,
      missing_data: [],
      proposed_actions: [],
    }),
    false,
    2,
  );
  assertEquals(parsed.citations, ["fda_label_daily_values"]);
  assertEquals(parsed.proposed_actions, []);
});

Deno.test("uncited health recommendations fail closed", () => {
  assertEquals(
    answerNeedsHealthCitation("Your latest weight is 87 kg."),
    false,
  );
  assertEquals(
    answerNeedsHealthCitation("Your recorded total is 1,500 calories."),
    false,
  );
  assertEquals(
    answerNeedsHealthCitation("Most adults need 7 to 9 hours."),
    true,
  );
  for (
    const recommendation of [
      "Vous devriez manger plus de légumes.",
      "Debes comer más verduras.",
      "Du solltest mehr Gemüse essen.",
      "Dovresti mangiare più verdure per la salute.",
      "Ешьте больше овощей для здоровья.",
      "为了健康，建议多吃蔬菜。",
      "健康のために野菜をもっと食べてください。",
      "Sağlığınız için daha fazla sebze yemelisiniz.",
    ]
  ) {
    assertEquals(answerNeedsHealthCitation(recommendation), true);
  }
  assertThrows(
    () =>
      parseModelJson(JSON.stringify({
        reply: "Most adults need 7 to 9 hours of sleep.",
        spoken_reply: "Most adults need 7 to 9 hours of sleep.",
        reason: "General guidance.",
        confidence: 0.9,
        evidence: [],
        citations: [],
        requires_health_citation: true,
        missing_data: [],
        proposed_actions: [],
      })),
    Error,
    "missing_health_citation",
  );
});

Deno.test("spoken health guidance cannot bypass the citation gate", () => {
  assertThrows(
    () =>
      parseModelJson(JSON.stringify({
        reply: "Hello!",
        spoken_reply: "You should eat more vegetables.",
        reason: "General guidance.",
        confidence: 0.9,
        evidence: [],
        citations: [],
        requires_health_citation: true,
        missing_data: [],
        proposed_actions: [],
      })),
    Error,
    "missing_health_citation",
  );
});

Deno.test("structured health citation classification closes every 25-locale path", () => {
  const releaseLocales = [
    "ar",
    "en",
    "fr",
    "es",
    "tr",
    "de",
    "it",
    "pt-BR",
    "pt-PT",
    "ur",
    "fa",
    "hi",
    "id",
    "ms",
    "ja",
    "ko",
    "zh-Hans",
    "zh-Hant",
    "ru",
    "bn",
    "vi",
    "th",
    "pl",
    "nl",
    "uk",
  ];
  assertEquals(releaseLocales.length, 25);
  for (const locale of releaseLocales) {
    assertThrows(
      () =>
        parseModelJson(JSON.stringify({
          reply: `Localized substantive guidance (${locale}).`,
          spoken_reply: `Localized guidance for ${locale}.`,
          reason: "General health guidance.",
          confidence: 0.9,
          evidence: [],
          citations: [],
          requires_health_citation: true,
          missing_data: [],
          proposed_actions: [],
        })),
      Error,
      "missing_health_citation",
    );
  }
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
      citations: [],
      requires_health_citation: false,
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

Deno.test("Gemini provider budget fits the client deadline", async () => {
  assertEquals(geminiAttemptTimeoutMs, 10_000);
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
    await assertRejects(
      () =>
        geminiCall(
          "gemini-test",
          [],
          "test",
          32,
          false,
          "LOW",
          (_url, _init) => {
            rateLimitedCalls += 1;
            return Promise.resolve(
              rateLimitedCalls === 1
                ? new Response(
                  JSON.stringify({ error: { status: "RESOURCE_EXHAUSTED" } }),
                  { status: 429 },
                )
                : providerSuccess(),
            );
          },
        ),
      Error,
      "provider_rate_limited",
    );
    assertEquals(rateLimitedCalls, 1);

    let networkCalls = 0;
    await assertRejects(
      () =>
        geminiCall(
          "gemini-test",
          [],
          "test",
          32,
          false,
          "LOW",
          (_url, _init) => {
            networkCalls += 1;
            if (networkCalls === 1) {
              return Promise.reject(new TypeError("network unavailable"));
            }
            return Promise.resolve(providerSuccess());
          },
        ),
      TypeError,
      "network unavailable",
    );
    assertEquals(networkCalls, 1);
  });
});

Deno.test("Gemini thinking configuration matches the model generation", () => {
  assertEquals(thinkingConfigForModel("gemini-2.5-flash", "MEDIUM"), {
    thinkingBudget: -1,
  });
  assertEquals(thinkingConfigForModel("gemini-3.7-flash", "HIGH"), {
    thinkingLevel: "HIGH",
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
          (_url, _init) => {
            clientErrorCalls += 1;
            return Promise.resolve(
              new Response(
                JSON.stringify({ error: { status: "INVALID_ARGUMENT" } }),
                { status: 400 },
              ),
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
          (_url, _init) => {
            serverErrorCalls += 1;
            return Promise.resolve(new Response("temporary", { status: 503 }));
          },
        ),
      Error,
      "provider_http_503",
    );
    assertEquals(serverErrorCalls, 1);

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
          (_url, _init) => {
            parseCalls += 1;
            return Promise.resolve(new Response("not-json", { status: 200 }));
          },
        ),
      Error,
    );
    assertEquals(parseCalls, 1);
  });
});

Deno.test("Gemini falls back only after a transient primary-model outage", async () => {
  assertEquals(
    isFallbackEligibleGeminiError(new Error("provider_http_503")),
    true,
  );
  assertEquals(
    isFallbackEligibleGeminiError(new Error("provider_rate_limited")),
    true,
  );
  assertEquals(
    isFallbackEligibleGeminiError(new Error("provider_http_400")),
    false,
  );

  const models: string[] = [];
  const recovered = await geminiCallWithFallback(
    (model) => {
      models.push(model);
      if (models.length === 1) {
        return Promise.reject(new Error("provider_http_503"));
      }
      return Promise.resolve({ data: {}, attempts: 1 });
    },
    "gemini-primary",
    [],
    "test",
    32,
  );
  assertEquals(models, ["gemini-primary", "gemini-3.7-flash"]);
  assertEquals(recovered.model, "gemini-3.7-flash");
  assertEquals(recovered.fallbackUsed, true);

  let permanentFailureCalls = 0;
  await assertRejects(
    () =>
      geminiCallWithFallback(
        () => {
          permanentFailureCalls += 1;
          return Promise.reject(new Error("provider_http_400"));
        },
        "gemini-primary",
        [],
        "test",
        32,
      ),
    Error,
    "provider_http_400",
  );
  assertEquals(permanentFailureCalls, 1);
});

Deno.test("explicit app actions recover without treating bare values as writes", () => {
  assertEquals(
    recoverExactUserAction([
      { role: "user", content: "سجل وزني اليوم" },
      { role: "assistant", content: "كم وزنك؟" },
      { role: "user", content: "٨٣٫٥" },
    ]),
    null,
  );
  assertEquals(
    recoverExactUserAction([
      { role: "user", content: "أضف ماء" },
      { role: "assistant", content: "كم شربت؟" },
      { role: "user", content: "0.75 لتر" },
    ]),
    null,
  );
  assertEquals(
    recoverExactUserAction([
      { role: "user", content: "سجل وزني ٨٣٫٥ كيلو" },
    ]),
    {
      type: "log_weight",
      arguments: { weightKg: 83.5 },
      requires_confirmation: true,
    },
  );
  assertEquals(
    recoverExactUserAction([
      { role: "user", content: "أضف 0.75 لتر ماء" },
    ]),
    {
      type: "log_water",
      arguments: { amountMl: 750 },
      requires_confirmation: true,
    },
  );
  assertEquals(
    recoverExactUserAction([
      { role: "user", content: "سجل فطوري اليوم" },
      { role: "assistant", content: "ما مكونات الوجبة؟" },
      { role: "user", content: "بيض وخبز" },
    ]),
    {
      type: "open_meals",
      arguments: {},
      requires_confirmation: true,
    },
  );
  assertEquals(
    recoverExactUserAction([
      { role: "user", content: "أكلت بيض وخبز" },
    ]),
    null,
  );
});

Deno.test("completed or cancelled actions never recover stale writes", () => {
  const user = (content: string) => ({ role: "user" as const, content });
  const assistant = (content: string) => ({
    role: "assistant" as const,
    content,
  });
  for (
    const messages of [
      [
        user("Log my weight 83 kg"),
        assistant("The weight entry is complete."),
        user("Explain how a waist measurement of 99 cm relates to health."),
      ],
      [
        user("Log my weight 83 kg"),
        assistant("The weight entry is complete."),
        user("What does my waist measurement mean?"),
        assistant("What is your waist circumference in cm?"),
        user("99"),
      ],
      [
        user("Log my weight 83 kg"),
        assistant("The weight entry is complete."),
        user("Help me think about my target weight."),
        assistant("What target weight would you like to reach?"),
        user("79"),
      ],
      [
        user("سجل وزني 83 كيلو"),
        assistant("انتهت عملية تسجيل الوزن."),
        user("ساعدني أفكر بهدف الوزن."),
        assistant("ما الوزن المستهدف الذي تريد الوصول إليه؟"),
        user("٧٩"),
      ],
      [
        user("Log my weight"),
        assistant("What is your weight?"),
        user(
          "Cancel recording my weight. Let us discuss my target weight only.",
        ),
        assistant("What is your target weight?"),
        user("79"),
      ],
      [
        user("Log water 500 ml"),
        assistant("Your water entry is complete."),
        user("Help me understand the milk in my breakfast meal."),
        assistant("How much milk did your breakfast contain?"),
        user("250 ml"),
      ],
      [
        user("Log my weight 83 kg"),
        assistant(
          "Please confirm the weight entry. What target weight would you like to reach?",
        ),
        user("79"),
      ],
      [
        user("سجل وزني 83 كيلو"),
        assistant(
          "أكد إدخال الوزن من البطاقة. ما الوزن المستهدف الذي تريد الوصول إليه؟",
        ),
        user("٧٩"),
      ],
      [
        user("Log water 500 ml"),
        assistant(
          "Please confirm the water entry. How much milk did your breakfast contain?",
        ),
        user("250 ml"),
      ],
      [
        user("سجل ماء 500 مل"),
        assistant(
          "أكد تسجيل الماء من البطاقة. كم كمية الحليب التي تناولتها مع الفطور؟",
        ),
        user("٢٥٠ مل"),
      ],
      [
        user("Log my weight 83 kg"),
        assistant("The weight entry is complete."),
        user("How many calories are in 250 grams of chicken?"),
      ],
      [user("Do not log my weight 83 kg")],
      [
        user("سجل وزني 83 كيلو"),
        assistant("تم حفظ القياس."),
        user("كم سعرة في 250 غرام دجاج؟"),
      ],
      [
        user("سجل وزني 83 كيلو"),
        assistant("تم حفظ القياس."),
        user("هل محيط خصري مناسب؟"),
        assistant("كم محيط خصرك بالسنتيمتر؟"),
        user("٩٩"),
      ],
      [
        user("Log my breakfast"),
        assistant("The breakfast task is complete."),
        user("What is dark mode?"),
      ],
    ]
  ) {
    assertEquals(recoverExactUserAction(messages), null);
  }
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
      (_url, init) => {
        sentBody = JSON.parse(String(init?.body)) as Record<string, unknown>;
        return Promise.resolve(providerSuccess());
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
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
        },
      },
      admin: {
        rpc: (name: string, params: Record<string, unknown>) => {
          if (name === "bil_has_remote_ai_consent") {
            return Promise.resolve({ data: true, error: null });
          }
          if (name === "bil_reserve_ai_usage") {
            return Promise.resolve({
              data: reservations.shift() ??
                { duplicate: true, state: "succeeded" },
              error: null,
            });
          }
          settlements.push(params);
          return Promise.resolve({
            data: { state: params.p_succeeded ? "succeeded" : "refunded" },
            error: null,
          });
        },
      },
    }),
  };
}

Deno.test("provider timeout refunds exactly one established reservation", async () => {
  const fake = fakeClients([{ duplicate: false, state: "reserved" }]);
  const response = await handler(requestBody(), {
    clients: fake.create as never,
    geminiCall: () => {
      return Promise.reject(new Error("provider_timeout"));
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
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
        },
      },
      admin: {
        rpc: (name: string) => {
          if (name === "bil_has_remote_ai_consent") {
            return Promise.resolve({ data: true, error: null });
          }
          if (name === "bil_reserve_ai_usage") {
            return Promise.resolve({
              data: { duplicate: false, state: "reserved" },
              error: null,
            });
          }
          settlementCalls += 1;
          return Promise.reject(new Error("database unavailable"));
        },
      },
    })) as never,
    geminiCall: () => {
      return Promise.reject(new Error("provider_timeout"));
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
    geminiCall: () => {
      providerCalls += 1;
      return Promise.resolve({
        attempts: 1,
        data: {
          promptFeedback: {
            blockReason: "SAFETY",
            blockReasonMessage: "provider-private-detail",
          },
          candidates: [],
        },
      });
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
    geminiCall: () =>
      Promise.resolve({
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
                  citations: ["sleep_foundation_adult_duration"],
                  requires_health_citation: true,
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
    geminiCall: () =>
      Promise.resolve({
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
    geminiCall: () => {
      providerCalls += 1;
      return Promise.reject(new Error("must_not_run"));
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
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
        },
      },
      admin: {
        rpc: (name: string, params: Record<string, unknown>) => {
          if (name === "bil_has_remote_ai_consent") {
            return Promise.resolve({ data: true, error: null });
          }
          if (name === "bil_reserve_ai_usage") {
            return Promise.resolve({
              data: null,
              error: { message: "database unavailable" },
            });
          }
          settlements.push(params);
          return Promise.resolve({ data: null, error: null });
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
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
        },
      },
      admin: {
        rpc: (name: string) => {
          if (name === "bil_has_remote_ai_consent") {
            return Promise.resolve({ data: true, error: null });
          }
          if (name === "bil_reserve_ai_usage") {
            return Promise.resolve({
              data: null,
              error: { message: "ai_usage_exhausted" },
            });
          }
          settlementCalls += 1;
          return Promise.resolve({ data: null, error: null });
        },
      },
    })) as never,
    geminiCall: () => {
      providerCalls += 1;
      return Promise.reject(new Error("must_not_run"));
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
            getUser: () =>
              Promise.resolve({
                data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
                error: null,
              }),
          },
        },
        admin: {
          rpc: (name: string) =>
            Promise.resolve(
              name === "bil_has_remote_ai_consent"
                ? { data: true, error: null }
                : { data: null, error: { message } },
            ),
        },
      })) as never,
      geminiCall: () => {
        providerCalls += 1;
        return Promise.reject(new Error("must_not_run"));
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
          getUser: () =>
            Promise.resolve({
              data: { user: { id: "00000000-0000-4000-8000-000000000001" } },
              error: null,
            }),
        },
      },
      admin: {
        rpc: (name: string) => {
          if (name === "bil_has_remote_ai_consent") {
            return Promise.resolve({ data: false, error: null });
          }
          reservationCalls += 1;
          return Promise.resolve({ data: null, error: null });
        },
      },
    })) as never,
    geminiCall: () => {
      providerCalls += 1;
      return Promise.reject(new Error("must_not_run"));
    },
  });
  assertEquals(response.status, 403);
  assertEquals(await response.json(), { error: "ai_consent_required" });
  assertEquals(reservationCalls, 0);
  assertEquals(providerCalls, 0);
});

Deno.test("raw voice audio is rejected before consent, reservation, or Gemini", async () => {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  let providerCalls = 0;
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
          getUser: () =>
            Promise.resolve({
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
                    maybeSingle: () =>
                      Promise.resolve({
                        data: { granted: true, policy_version: "2" },
                        error: null,
                      }),
                  }),
                }),
              }),
            }),
          }),
        }),
        rpc: (name: string, params: Record<string, unknown>) => {
          if (name === "bil_has_remote_ai_consent") {
            return Promise.resolve({ data: true, error: null });
          }
          calls.push({ name, params });
          if (name === "bil_reserve_ai_voice") {
            return Promise.resolve({
              data: { duplicate: false, state: "reserved" },
              error: null,
            });
          }
          return Promise.resolve({ data: { state: "succeeded" }, error: null });
        },
      },
    })) as never,
    geminiCall: () => {
      providerCalls += 1;
      return Promise.reject(new Error("must_not_run"));
    },
  });
  assertEquals(response.status, 400);
  assertEquals(await response.json(), {
    error: "raw_voice_audio_not_supported",
  });
  assertEquals(calls.length, 0);
  assertEquals(providerCalls, 0);
});

function citationContractReply(citations: string[]) {
  const reply = citations.includes("fda_label_daily_values")
    ? "FDA Daily Values are label references, not personal requirements."
    : "Include vegetables in a varied diet.";
  return {
    reply,
    spoken_reply: reply,
    reason: "Use only the client's supported in-app reference catalog.",
    confidence: 0.8,
    evidence: [],
    citations,
    requires_health_citation: true,
    missing_data: [],
    proposed_actions: [],
  };
}

// The exact preserved 3f0085 handler/provider exports can be passed here.
// This exercises original code with isolated dependencies, not an old-server stub.
export async function exerciseHealthCitationHandlerContract({
  handlerUnderTest = handler,
  geminiUnderTest = geminiCall,
  version,
  citations = ["cdc_healthy_eating"],
  failPrimaryOnce = false,
}: {
  handlerUnderTest?: typeof handler;
  geminiUnderTest?: typeof geminiCall;
  version?: unknown;
  citations?: string[];
  failPrimaryOnce?: boolean;
} = {}) {
  const rpcCalls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const providerRequests: Array<Record<string, unknown>> = [];
  const fake = fakeClients([{ duplicate: false, state: "reserved" }]);
  const baseRequest = requestBody("coach-citation-contract-fixture");
  const body = await baseRequest.json() as Record<string, unknown>;
  if (version !== undefined) body.health_citation_catalog_version = version;
  const request = new Request(baseRequest.url, {
    method: "POST",
    headers: baseRequest.headers,
    body: JSON.stringify(body),
  });
  return await withGeminiTestKey(async () => {
    const response = await handlerUnderTest(request, {
      clients: ((authorization: string) => {
        const client = fake.create(authorization);
        const rpc = client.admin.rpc;
        client.admin.rpc = (name, params) => {
          rpcCalls.push({ name, params });
          return rpc(name, params);
        };
        return client;
      }) as never,
      requireIntegrity: async ({ body }) => body,
      geminiCall: (
        model,
        contents,
        system,
        maxOutputTokens,
        requireTranscript,
        thinkingLevel,
        _fetcher,
        catalogVersion,
      ) =>
        geminiUnderTest(
          model,
          contents,
          system,
          maxOutputTokens,
          requireTranscript,
          thinkingLevel,
          (_url, init) => {
            providerRequests.push(
              JSON.parse(String(init?.body)) as Record<string, unknown>,
            );
            if (failPrimaryOnce && providerRequests.length === 1) {
              return Promise.resolve(
                new Response(
                  JSON.stringify({
                    error: { status: "UNAVAILABLE" },
                  }),
                  { status: 503 },
                ),
              );
            }
            return Promise.resolve(
              new Response(
                JSON.stringify({
                  candidates: [{
                    finishReason: "STOP",
                    content: {
                      parts: [{
                        text: JSON.stringify(citationContractReply(citations)),
                      }],
                    },
                  }],
                  usageMetadata: {
                    promptTokenCount: 20,
                    candidatesTokenCount: 10,
                  },
                }),
                { status: 200 },
              ),
            );
          },
          catalogVersion,
        ),
    });
    return {
      response,
      payload: await response.json() as Record<string, unknown>,
      providerRequests,
      rpcCalls,
      settlements: fake.settlements,
    };
  });
}

function requestedCitationIds(request: Record<string, unknown>) {
  const config = request.generationConfig as Record<string, unknown>;
  const schema = config.responseSchema as Record<string, unknown>;
  const properties = schema.properties as Record<string, unknown>;
  const citations = properties.citations as Record<string, unknown>;
  return (citations.items as Record<string, unknown>).enum as string[];
}

function requestedCitationPrompt(request: Record<string, unknown>) {
  const instruction = request.systemInstruction as Record<string, unknown>;
  const parts = instruction.parts as Array<Record<string, unknown>>;
  return String(parts[0].text);
}

Deno.test("citation catalog versions retain legacy22 and explicit current23", () => {
  assertEquals(healthCitationCatalogVersion(undefined), 1);
  assertEquals(healthCitationCatalogVersion(1), 1);
  assertEquals(healthCitationCatalogVersion(2), 2);
  assertEquals(healthCitationIdsForVersion().size, 22);
  assertEquals(healthCitationIdsForVersion(1).size, 22);
  assertEquals(healthCitationIdsForVersion(2).size, 23);
  assertEquals(allowedHealthCitationIds.size, 23);
  assertEquals(
    healthCitationIdsForVersion().has("fda_label_daily_values"),
    false,
  );
  assertEquals(
    healthCitationIdsForVersion(2).has("fda_label_daily_values"),
    true,
  );
  for (
    const invalid of [null, 0, -1, 3, 2.1, "2", true, [], {}, NaN, Infinity]
  ) {
    assertThrows(
      () => healthCitationCatalogVersion(invalid),
      Error,
      "invalid_health_citation_catalog_version",
    );
  }
});

Deno.test("legacy parser never aliases FDA to DRI or delivers an uncited health reply", () => {
  const raw = JSON.stringify(citationContractReply(["fda_label_daily_values"]));
  assertThrows(() => parseModelJson(raw), Error, "missing_health_citation");
  assertThrows(
    () => parseModelJson(raw, false, 1),
    Error,
    "missing_health_citation",
  );
  assertEquals(parseModelJson(raw, false, 2).citations, [
    "fda_label_daily_values",
  ]);
  assertThrows(
    () =>
      parseModelJson(
        JSON.stringify(citationContractReply([
          "unknown_id",
          "https://example.invalid/reference",
        ])),
        false,
        2,
      ),
    Error,
    "missing_health_citation",
  );
});

Deno.test("legacy request keeps prompt schema parser on 22 supported references", async () => {
  const result = await exerciseHealthCitationHandlerContract();
  assertEquals(result.response.status, 200);
  assertEquals(result.payload.citations, ["cdc_healthy_eating"]);
  assertEquals(result.providerRequests.length, 1);
  assertEquals(requestedCitationIds(result.providerRequests[0]).length, 22);
  assertEquals(
    requestedCitationIds(result.providerRequests[0]).includes(
      "fda_label_daily_values",
    ),
    false,
  );
  assertEquals(
    requestedCitationPrompt(result.providerRequests[0]).includes(
      "fda_label_daily_values",
    ),
    false,
  );
  assertEquals(result.settlements.length, 1);
  assertEquals(result.settlements[0].p_succeeded, true);
  assertEquals(
    Object.hasOwn(result.payload, "health_citation_catalog_version"),
    false,
  );
});

Deno.test("version2 request permits FDA through actual handler fetch schema and parser", async () => {
  const result = await exerciseHealthCitationHandlerContract({
    version: 2,
    citations: [
      "fda_label_daily_values",
      "invented_study",
      "fda_label_daily_values",
    ],
  });
  assertEquals(result.response.status, 200);
  assertEquals(result.payload.citations, ["fda_label_daily_values"]);
  assertEquals(result.providerRequests.length, 1);
  assertEquals(requestedCitationIds(result.providerRequests[0]).length, 23);
  assertEquals(
    requestedCitationIds(result.providerRequests[0]).includes(
      "fda_label_daily_values",
    ),
    true,
  );
  assertEquals(
    requestedCitationPrompt(result.providerRequests[0]).includes(
      "fda_label_daily_values",
    ),
    true,
  );
  assertEquals(result.settlements.length, 1);
  assertEquals(result.settlements[0].p_succeeded, true);
  const legacy = await exerciseHealthCitationHandlerContract();
  assertEquals(
    Object.keys(result.payload).sort(),
    Object.keys(legacy.payload).sort(),
  );
});

Deno.test("unexpected FDA response for a legacy request refunds instead of delivering health text", async () => {
  const result = await exerciseHealthCitationHandlerContract({
    citations: ["fda_label_daily_values"],
  });
  assertEquals(result.response.status, 503);
  assertEquals(result.payload, { error: "missing_health_citation" });
  assertEquals(result.settlements.length, 1);
  assertEquals(result.settlements[0].p_succeeded, false);
});

Deno.test("invalid citation catalog version fails before reservation provider or settlement", async () => {
  for (const version of [null, 0, 3, 2.1, "2", true, [], {}]) {
    const result = await exerciseHealthCitationHandlerContract({ version });
    assertEquals(result.response.status, 400);
    assertEquals(result.payload, {
      error: "invalid_health_citation_catalog_version",
    });
    assertEquals(result.rpcCalls, []);
    assertEquals(result.providerRequests, []);
    assertEquals(result.settlements, []);
  }
});

Deno.test("version2 fallback preserves the same citation catalog across both real fetch calls", async () => {
  const result = await exerciseHealthCitationHandlerContract({
    version: 2,
    citations: ["fda_label_daily_values"],
    failPrimaryOnce: true,
  });
  assertEquals(result.response.status, 200);
  assertEquals(result.payload.citations, ["fda_label_daily_values"]);
  assertEquals(result.providerRequests.length, 2);
  for (const request of result.providerRequests) {
    assertEquals(requestedCitationIds(request).length, 23);
    assertEquals(
      requestedCitationIds(request).includes("fda_label_daily_values"),
      true,
    );
    assertEquals(
      requestedCitationPrompt(request).includes("fda_label_daily_values"),
      true,
    );
  }
  assertEquals(result.settlements.length, 1);
  assertEquals(result.settlements[0].p_succeeded, true);
});
