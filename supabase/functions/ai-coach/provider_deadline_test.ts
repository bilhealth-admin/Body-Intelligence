import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { geminiCall, handler } from "./server.ts";

const owner = "00000000-0000-4000-8000-000000000001";
const privateText = "PRIVATE_QA_CONTEXT_NEVER_LOG";
function fixture() {
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  return {
    calls,
    clients: () => ({
      auth: {
        auth: {
          getUser: async () => ({ data: { user: { id: owner } }, error: null }),
        },
      },
      admin: {
        rpc: async (name: string, params: Record<string, unknown>) => {
          calls.push({ name, params });
          if (name === "bil_has_remote_ai_consent") {
            return {
              data: true,
              error: null,
            };
          }
          if (name === "bil_reserve_ai_usage") {
            return {
              data: { duplicate: false, state: "reserved" },
              error: null,
            };
          }
          if (name !== "bil_settle_ai_usage") {
            throw Error("Unexpected operation");
          }
          return {
            data: { state: params.p_succeeded ? "succeeded" : "refunded" },
            error: null,
          };
        },
      },
    }),
  };
}
const request = () =>
  new Request("https://unit.test/coach", {
    method: "POST",
    headers: {
      authorization: "Bearer UNIT_SECRET",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      request_id: "coach-deadline-private-request-0001",
      locale: "en",
      context: { privateText },
      messages: [{ role: "user", content: privateText }],
    }),
  });
const integrity = async ({ body }: { body: Record<string, unknown> }) => body;
function provider(reply = "Ready.") {
  return {
    attempts: 1,
    data: {
      candidates: [{
        finishReason: "STOP",
        content: {
          parts: [{
            text: JSON.stringify({
              reply,
              spoken_reply: "Ready.",
              reason: "Test",
              confidence: 1,
              evidence: [],
              citations: [],
              requires_health_citation: false,
              missing_data: [],
              proposed_actions: [],
            }),
          }],
        },
      }],
      usageMetadata: { promptTokenCount: 20, candidatesTokenCount: 10 },
    },
  };
}

// Exercise the real fetch/AbortSignal wiring with a logical transport clock;
// no wall-clock13s wait, network grant, key, or model request is required.
async function withTimedTransport<T>(
  run: (transport: {
    fetcher: typeof fetch;
    now: () => number;
    deadlines: number[];
  }) => Promise<T>,
) {
  const previousKey = Deno.env.get("BIL_GEMINI_API_KEY");
  const originalTimeout = AbortSignal.timeout;
  let clock = 0, deadline = 0;
  const deadlines: number[] = [];
  Deno.env.set("BIL_GEMINI_API_KEY", "UNIT_PROVIDER_SECRET");
  AbortSignal.timeout = (milliseconds: number) => {
    deadlines.push(milliseconds);
    deadline = milliseconds;
    return new AbortController().signal;
  };
  const fetcher: typeof fetch = async () => {
    const completion = 13_000;
    clock += Math.min(completion, deadline);
    if (completion >= deadline) {
      throw new DOMException("unit deadline", "TimeoutError");
    }
    return new Response(JSON.stringify(provider().data));
  };
  try {
    return await run({ fetcher, now: () => clock, deadlines });
  } finally {
    AbortSignal.timeout = originalTimeout;
    if (previousKey === undefined) Deno.env.delete("BIL_GEMINI_API_KEY");
    else Deno.env.set("BIL_GEMINI_API_KEY", previousKey);
  }
}

Deno.test("provider deadline: real13s transport fails old10s but succeeds under14s once", async () => {
  await withTimedTransport(async (transport) => {
    let oldCode = "";
    try {
      await geminiCall(
        "gemini-3.8-flash",
        [],
        "unit",
        4096,
        false,
        "MEDIUM",
        transport.fetcher,
        1,
        10_000,
      );
    } catch (error) {
      oldCode = (error as Error).message;
    }
    assertEquals(oldCode, "provider_timeout");
    const f = fixture(), summaries: Array<Record<string, unknown>> = [];
    const response = await handler(request(), {
      clients: f.clients as never,
      requireIntegrity: integrity,
      now: transport.now,
      geminiCall: (...args) =>
        geminiCall(
          args[0],
          args[1],
          args[2],
          args[3],
          args[4],
          args[5],
          transport.fetcher,
          args[7],
          args[8],
        ),
      providerDiagnosticLog: (event) =>
        summaries.push(event as unknown as Record<string, unknown>),
      diagnosticLog: () => {},
    });
    assertEquals(response.status, 200);
    assertEquals((await response.json()).attempts, 1);
    assertEquals(transport.deadlines, [10_000, 14_000]);
    assertEquals(f.calls.map((row) => row.name), [
      "bil_has_remote_ai_consent",
      "bil_reserve_ai_usage",
      "bil_settle_ai_usage",
    ]);
    assertEquals(f.calls[2].params.p_succeeded, true);
    assertEquals(summaries.length, 1);
    assertEquals(summaries[0].provider_trace, [{
      model: "gemini-3.8-flash",
      thinking: "LOW",
      budget_ms: 14_000,
      elapsed_ms: 13_000,
      error_code: null,
    }]);
  });
});

Deno.test("provider deadline: late14s primary answer is discarded, never accepted as success", async () => {
  const f = fixture();
  let clock = 0, calls = 0;
  const diagnostics: Array<Record<string, unknown>> = [];
  const response = await handler(request(), {
    clients: f.clients as never,
    requireIntegrity: integrity,
    now: () => clock,
    diagnosticLog: (event) =>
      diagnostics.push(event as unknown as Record<string, unknown>),
    geminiCall: async () => {
      if (++calls === 1) {
        clock += 14_001;
        return provider("Late answer must not be shown.");
      }
      clock = 24_001;
      throw Error("provider_timeout");
    },
  });
  assertEquals(response.status, 503);
  assertEquals(await response.json(), { error: "provider_timeout" });
  assertEquals(calls, 2);
  assertEquals(f.calls[2].params.p_succeeded, false);
  assertEquals(
    (diagnostics[0].provider_trace as Array<Record<string, unknown>>)[0]
      .error_code,
    "provider_timeout",
  );
});

Deno.test("provider deadline:14s primary timeout leaves10s independent fallback within24s", async () => {
  const f = fixture();
  let clock = 0, calls = 0;
  const models: string[] = [], deadlines: Array<number | undefined> = [];
  const summaries: Array<Record<string, unknown>> = [];
  const response = await handler(request(), {
    clients: f.clients as never,
    requireIntegrity: integrity,
    now: () => clock,
    providerDiagnosticLog: (event) =>
      summaries.push(event as unknown as Record<string, unknown>),
    geminiCall: async (...args) => {
      models.push(args[0]);
      deadlines.push(args[8]);
      if (++calls === 1) {
        clock += 14_000;
        throw Error("provider_timeout");
      }
      clock += 9000;
      return provider();
    },
  });
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.latency_ms, 23_000);
  assertEquals(data.fallback_used, true);
  assertEquals(models, ["gemini-3.8-flash", "gemini-3.6-flash"]);
  assertEquals(deadlines, [undefined, 10_000]);
  assertEquals(
    f.calls.filter((row) => row.name === "bil_reserve_ai_usage").length,
    1,
  );
  assertEquals(
    f.calls.filter((row) => row.name === "bil_settle_ai_usage").length,
    1,
  );
  assertEquals(f.calls[2].params.p_input_tokens, 20);
  assertEquals(f.calls[2].params.p_output_tokens, 10);
  assertEquals(
    (summaries[0].provider_trace as Array<Record<string, unknown>>).map((row) =>
      row.budget_ms
    ),
    [14_000, 10_000],
  );
});

Deno.test("provider deadline: both failures stop at24s with one refund and no fourth call", async () => {
  const f = fixture();
  let clock = 0, calls = 0;
  const response = await handler(request(), {
    clients: f.clients as never,
    requireIntegrity: integrity,
    now: () => clock,
    diagnosticLog: () => {},
    geminiCall: async () => {
      clock += ++calls === 1 ? 14_000 : 10_000;
      throw Error("provider_timeout");
    },
  });
  assertEquals(response.status, 503);
  assertEquals(clock, 24_000);
  assertEquals(calls, 2);
  assertEquals(f.calls.map((row) => row.name), [
    "bil_has_remote_ai_consent",
    "bil_reserve_ai_usage",
    "bil_settle_ai_usage",
  ]);
  assertEquals(f.calls[2].params.p_succeeded, false);
});

Deno.test("provider deadline: trace redacts unknown model and arbitrary errors, no private fields", async () => {
  const f = fixture();
  const diagnostics: Array<Record<string, unknown>> = [];
  const previous = Deno.env.get("BIL_GEMINI_TEXT_MODEL");
  Deno.env.set("BIL_GEMINI_TEXT_MODEL", "PRIVATE_MODEL_SECRET invalid");
  try {
    const response = await handler(request(), {
      clients: f.clients as never,
      requireIntegrity: integrity,
      diagnosticLog: (event) =>
        diagnostics.push(event as unknown as Record<string, unknown>),
      geminiCall: async () => {
        throw Error("PRIVATE_ERROR_SECRET " + privateText);
      },
    });
    assertEquals(response.status, 503);
    const trace = diagnostics[0].provider_trace as Array<
      Record<string, unknown>
    >;
    assertEquals(trace[0].model, "unrecognized_model");
    assertEquals(trace[0].error_code, "coach_failed");
    const serialized = JSON.stringify(diagnostics);
    for (
      const excluded of [
        privateText,
        owner,
        "UNIT_SECRET",
        "PRIVATE_MODEL_SECRET",
        "PRIVATE_ERROR_SECRET",
        "coach-deadline-private-request-0001",
      ]
    ) assertEquals(serialized.includes(excluded), false);
  } finally {
    if (previous === undefined) Deno.env.delete("BIL_GEMINI_TEXT_MODEL");
    else Deno.env.set("BIL_GEMINI_TEXT_MODEL", previous);
  }
});

Deno.test("provider deadline: diagnostic sink failure cannot change accepted answer or settlement", async () => {
  const f = fixture();
  const response = await handler(request(), {
    clients: f.clients as never,
    requireIntegrity: integrity,
    providerDiagnosticLog: () => {
      throw Error("logger unavailable");
    },
    geminiCall: async () => provider(),
  });
  assertEquals(response.status, 200);
  assertEquals(f.calls[2].params.p_succeeded, true);
  assertEquals(f.calls.length, 3);
});
