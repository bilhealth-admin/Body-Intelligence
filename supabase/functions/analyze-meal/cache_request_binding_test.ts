// Read only the local handler source; do not import its serving/network module.
// Execute its actual cached branch so this test detects a lost request binding.
function registerTests() {
  const sourceUrl = new URL("./index.ts", import.meta.url);
  const source = Deno.readTextFileSync(sourceUrl);
  const begin = source.indexOf("  if (reservation?.duplicate === true) {");
  const end = source.indexOf("  let providerAttempts = 0;", begin);
  if (begin < 0 || end <= begin) {
    throw Error("cached branch boundary unavailable");
  }
  // Execute the actual source branch, removing only its TypeScript cast.
  const branch = source.slice(begin, end).replace(
    " as Record<string, unknown>",
    "",
  );
  const run = new Function(
    "reservation",
    "schemaVersion",
    "idempotencyKey",
    "reply",
    branch,
  );
  const reply = (body: unknown, status = 200) => ({ body, status });
  const oldKey = "synthetic_prior_analysis_001";
  const currentKey = "synthetic_current_analysis_002";
  const equal = (a: unknown, b: unknown, why: string) => {
    if (JSON.stringify(a) !== JSON.stringify(b)) throw Error(why);
  };
  const cached = (schema: number) => ({
    schema_version: schema,
    request_id: oldKey,
    response_locale: "ar",
    candidates: [{
      name: "synthetic meal",
      provenance: {
        identification_provider: "gemini",
        model_revision: "synthetic-model",
      },
    }],
    provider_metrics: { provider: "gemini", provider_attempts: 1 },
    quota: { unchanged: true },
  });
  for (const schema of [1, 2]) {
    Deno.test(`schema${schema} fresh cache binds current request while preserving content`, () => {
      const body = cached(schema);
      const before = JSON.stringify(body);
      const reservation = {
        duplicate: true,
        state: "succeeded",
        cache_hit: true,
        response_body: body,
      };
      const actual = run(reservation, schema, currentKey, reply);
      equal(actual.status, 200, "cached reply status changed");
      equal(
        actual.body.request_id,
        currentKey,
        "cached reply retained an older request identity",
      );
      equal(
        actual.body.cache,
        { hit: true, charged: false },
        "cache charge semantics changed",
      );
      equal(
        actual.body.candidates,
        body.candidates,
        "candidate/provenance changed",
      );
      equal(actual.body.response_locale, "ar", "locale changed");
      equal(
        actual.body.provider_metrics,
        body.provider_metrics,
        "provider metrics changed",
      );
      equal(actual.body.quota, body.quota, "quota changed");
      equal(JSON.stringify(body), before, "cached stored object mutated");
      equal(
        run(reservation, schema, currentKey, reply),
        actual,
        "same-key retry changed",
      );
    });
  }
  Deno.test("same-key successful duplicate preserves identity and no-charge flag", () => {
    const body = cached(2);
    body.request_id = currentKey;
    const actual = run(
      {
        duplicate: true,
        state: "succeeded",
        cache_hit: false,
        response_body: body,
      },
      2,
      currentKey,
      reply,
    );
    equal(actual.body.request_id, currentKey, "same-key identity changed");
    equal(
      actual.body.cache,
      { hit: false, charged: false },
      "retry charged or cache flag changed",
    );
  });
  Deno.test("schema2 cannot reinterpret cached schema1", () => {
    equal(
      run(
        {
          duplicate: true,
          state: "succeeded",
          cache_hit: true,
          response_body: cached(1),
        },
        2,
        currentKey,
        reply,
      ),
      { body: { error: "idempotency_payload_mismatch" }, status: 409 },
      "schema guard weakened",
    );
  });
  Deno.test("unsettled duplicate cannot become success", () => {
    equal(run({ duplicate: true, state: "reserved" }, 2, currentKey, reply), {
      body: { error: "request_already_processed", state: "reserved" },
      status: 409,
    }, "pending guard weakened");
  });
}

registerTests();
