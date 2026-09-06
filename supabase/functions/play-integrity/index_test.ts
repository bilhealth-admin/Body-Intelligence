import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { evaluatePlayIntegrityVerdict, handler } from "./index.ts";

const packageName = "com.bilhealth.bodyintelligencelog";
const requestHash = "request-bound-hash";
const now = Date.parse("2026-09-05T12:00:00Z");
const ownerId = "00000000-0000-4000-8000-000000000001";
const duplicateRequestId = "pi-00000000-0000-4000-8000-000000000001";
const protectedAction = "ai_coach.request";
const payloadDigest = "a".repeat(64);

function validPayload() {
  return {
    requestDetails: {
      requestPackageName: packageName,
      requestHash,
      timestampMillis: String(now - 1_000),
    },
    accountDetails: { appLicensingVerdict: "LICENSED" },
    appIntegrity: {
      appRecognitionVerdict: "PLAY_RECOGNIZED",
      packageName,
      certificateSha256Digest: ["A".repeat(43)],
      versionCode: "42",
    },
    deviceIntegrity: {
      deviceRecognitionVerdict: ["MEETS_DEVICE_INTEGRITY"],
    },
  };
}

type DuplicateEvent = {
  action: string;
  payload_digest: string;
  request_hash: string;
  mode: string;
  decision: string;
  reason: string;
  app_licensing_verdict: string;
  app_recognition_verdict: string;
  device_recognition_verdict: string[];
};

type GrantCandidate = {
  id: string;
  owner_id: string;
  platform: string;
  source_id: string;
  action: string;
  payload_digest: string;
  expires_at: string;
  consumed_at: string | null;
};

function duplicateEvent(
  overrides: Partial<DuplicateEvent> = {},
): DuplicateEvent {
  return {
    action: protectedAction,
    payload_digest: payloadDigest,
    request_hash: requestHash,
    mode: "enforce",
    decision: "enforce_allow",
    reason: "all_core_verdicts_pass",
    app_licensing_verdict: "LICENSED",
    app_recognition_verdict: "PLAY_RECOGNIZED",
    device_recognition_verdict: ["MEETS_DEVICE_INTEGRITY"],
    ...overrides,
  };
}

function grantCandidate(
  overrides: Partial<GrantCandidate> = {},
): GrantCandidate {
  return {
    id: "10000000-0000-4000-8000-000000000001",
    owner_id: ownerId,
    platform: "android",
    source_id: duplicateRequestId,
    action: protectedAction,
    payload_digest: payloadDigest,
    expires_at: "2999-01-01T00:00:00.000Z",
    consumed_at: null,
    ...overrides,
  };
}

function duplicateRequest(overrides: Record<string, unknown> = {}) {
  return new Request("https://example.test/play-integrity", {
    method: "POST",
    headers: {
      authorization: "Bearer test-session",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      request_id: duplicateRequestId,
      action: protectedAction,
      payload_digest: payloadDigest,
      request_hash: requestHash,
      integrity_token: "opaque-token",
      ...overrides,
    }),
  });
}

function duplicateHarness({
  event,
  grant,
}: {
  event: DuplicateEvent;
  grant: GrantCandidate | null;
}) {
  const observations = {
    verifierCalls: 0,
    grantWrites: 0,
    grantFilters: [] as Array<{
      operator: "eq" | "is" | "gt";
      column: string;
      value: unknown;
    }>,
  };

  function query(table: string) {
    const filters: typeof observations.grantFilters = [];
    const builder = {
      select: (_columns: string) => builder,
      eq: (column: string, value: unknown) => {
        filters.push({ operator: "eq" as const, column, value });
        return builder;
      },
      is: (column: string, value: unknown) => {
        filters.push({ operator: "is" as const, column, value });
        return builder;
      },
      gt: (column: string, value: unknown) => {
        filters.push({ operator: "gt" as const, column, value });
        return builder;
      },
      maybeSingle: () => {
        if (table === "bil_play_integrity_events") {
          return Promise.resolve({ data: event, error: null });
        }
        observations.grantFilters.push(...filters);
        const matches = grant != null && filters.every((filter) => {
          const actual = grant[filter.column as keyof GrantCandidate];
          if (filter.operator === "gt") {
            return String(actual) > String(filter.value);
          }
          return actual === filter.value;
        });
        return Promise.resolve({ data: matches ? grant : null, error: null });
      },
      upsert: () => {
        observations.grantWrites += 1;
        throw new Error("duplicate path must never issue a grant");
      },
    };
    return builder;
  }

  return {
    observations,
    dependencies: {
      clients: (() => ({
        auth: {
          auth: {
            getUser: () =>
              Promise.resolve({
                data: { user: { id: ownerId } },
                error: null,
              }),
          },
          rpc: () => Promise.resolve({ data: null, error: null }),
        },
        admin: { from: (table: string) => query(table) },
      })) as never,
      decodeIntegrityToken: (() => {
        observations.verifierCalls += 1;
        return Promise.reject(new Error("duplicate path must not reverify"));
      }) as never,
    },
  };
}

Deno.test("Play Integrity accepts a fresh, request-bound core verdict", () => {
  const result = evaluatePlayIntegrityVerdict({
    payload: validPayload(),
    packageName,
    requestHash,
    expectedRequestHash: requestHash,
    now,
  });

  assertEquals(result.failures, []);
});

Deno.test("Play Integrity denies request binding and app identity mismatches", () => {
  const payload = validPayload();
  payload.requestDetails.requestHash = "other-hash";
  payload.appIntegrity.packageName = "com.example.imposter";
  payload.appIntegrity.certificateSha256Digest = [];

  const result = evaluatePlayIntegrityVerdict({
    payload,
    packageName,
    requestHash,
    expectedRequestHash: "server-computed-other-hash",
    now,
  });

  assertStringIncludes(result.failures.join(","), "server_hash_mismatch");
  assertStringIncludes(result.failures.join(","), "google_hash_mismatch");
  assertStringIncludes(result.failures.join(","), "app_package_mismatch");
  assertStringIncludes(
    result.failures.join(","),
    "app_certificate_digest_invalid",
  );
});

Deno.test("Play Integrity denies stale or incomplete verdicts", () => {
  const payload = validPayload();
  payload.requestDetails.timestampMillis = String(now - 5 * 60_000 - 1);
  payload.accountDetails.appLicensingVerdict = "UNEVALUATED";
  payload.deviceIntegrity.deviceRecognitionVerdict = [];

  const result = evaluatePlayIntegrityVerdict({
    payload,
    packageName,
    requestHash,
    expectedRequestHash: requestHash,
    now,
  });

  assertStringIncludes(result.failures.join(","), "stale_or_invalid_timestamp");
  assertStringIncludes(result.failures.join(","), "license_unevaluated");
  assertStringIncludes(result.failures.join(","), "device_integrity_not_met");
});

Deno.test("Play Integrity never upgrades a legacy observe event to a grant", async () => {
  const harness = duplicateHarness({
    event: duplicateEvent({
      mode: "observe",
      decision: "observe_allow",
    }),
    grant: null,
  });

  const response = await handler(duplicateRequest(), harness.dependencies);
  const body = await response.json();

  assertEquals(response.status, 403);
  assertEquals(body.allowed, false);
  assertEquals(body.reason, "cached_verdict_not_grantable");
  assertEquals(harness.observations.grantFilters, []);
  assertEquals(harness.observations.grantWrites, 0);
  assertEquals(harness.observations.verifierCalls, 0);
});

Deno.test("Play Integrity rejects duplicate event field mismatch", async () => {
  const harness = duplicateHarness({
    event: duplicateEvent({ action: "store.verify_purchase" }),
    grant: grantCandidate(),
  });

  const response = await handler(duplicateRequest(), harness.dependencies);

  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "request_id_reuse_mismatch" });
  assertEquals(harness.observations.grantFilters, []);
  assertEquals(harness.observations.grantWrites, 0);
  assertEquals(harness.observations.verifierCalls, 0);
});

Deno.test("Play Integrity rejects expired, consumed, or mismatched duplicate grants", async () => {
  for (
    const scenario of [
      {
        name: "expired",
        grant: grantCandidate({ expires_at: "2000-01-01T00:00:00.000Z" }),
      },
      {
        name: "consumed",
        grant: grantCandidate({
          consumed_at: "2026-09-05T12:00:00.000Z",
        }),
      },
      {
        name: "mismatched",
        grant: grantCandidate({ payload_digest: "b".repeat(64) }),
      },
    ]
  ) {
    const harness = duplicateHarness({
      event: duplicateEvent(),
      grant: scenario.grant,
    });

    const response = await handler(duplicateRequest(), harness.dependencies);
    const body = await response.json();

    assertEquals(response.status, 409, scenario.name);
    assertEquals(body.allowed, false, scenario.name);
    assertEquals(body.reason, "integrity_grant_not_available", scenario.name);
    assertEquals(
      harness.observations.grantFilters.slice(0, 6),
      [
        { operator: "eq", column: "owner_id", value: ownerId },
        { operator: "eq", column: "platform", value: "android" },
        {
          operator: "eq",
          column: "source_id",
          value: duplicateRequestId,
        },
        { operator: "eq", column: "action", value: protectedAction },
        {
          operator: "eq",
          column: "payload_digest",
          value: payloadDigest,
        },
        { operator: "is", column: "consumed_at", value: null },
      ],
      scenario.name,
    );
    assertEquals(
      harness.observations.grantFilters[6]?.operator,
      "gt",
      scenario.name,
    );
    assertEquals(
      harness.observations.grantFilters[6]?.column,
      "expires_at",
      scenario.name,
    );
    assertEquals(harness.observations.grantWrites, 0, scenario.name);
    assertEquals(harness.observations.verifierCalls, 0, scenario.name);
  }
});

Deno.test("Play Integrity returns only an exact outstanding duplicate grant", async () => {
  const grant = grantCandidate();
  const harness = duplicateHarness({ event: duplicateEvent(), grant });

  const response = await handler(duplicateRequest(), harness.dependencies);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.allowed, true);
  assertEquals(body.duplicate, true);
  assertEquals(body.grant, { id: grant.id, expires_at: grant.expires_at });
  assertEquals(harness.observations.grantWrites, 0);
  assertEquals(harness.observations.verifierCalls, 0);
});

Deno.test("Play Integrity issue limiting rejects before verifier or persistence", async () => {
  for (
    const scenario of [
      {
        message: "rate limit exceeded",
        status: 429,
        reason: "rate_limited",
      },
      {
        message: "database unavailable",
        status: 503,
        reason: "rate_limit_unavailable",
      },
    ]
  ) {
    const rateCalls: Array<Record<string, unknown>> = [];
    let verifierCalls = 0;
    let persistenceCalls = 0;
    const response = await handler(
      new Request("https://example.test/play-integrity", {
        method: "POST",
        headers: {
          authorization: "Bearer test-session",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          request_id: "pi-00000000-0000-4000-8000-000000000001",
          action: "ai_coach.request",
          payload_digest: "a".repeat(64),
          request_hash: "request-bound-hash",
          integrity_token: "opaque-token",
        }),
      }),
      {
        clients: (() => ({
          auth: {
            auth: {
              getUser: () =>
                Promise.resolve({
                  data: {
                    user: { id: "00000000-0000-4000-8000-000000000001" },
                  },
                  error: null,
                }),
            },
            rpc: (name: string, params: Record<string, unknown>) => {
              rateCalls.push({ name, ...params });
              return Promise.resolve({
                data: null,
                error: { message: scenario.message },
              });
            },
          },
          admin: {
            from: () => {
              persistenceCalls += 1;
              throw new Error("persistence must not run");
            },
          },
        })) as never,
        decodeIntegrityToken: (() => {
          verifierCalls += 1;
          return Promise.reject(new Error("verifier must not run"));
        }) as never,
      },
    );

    assertEquals(response.status, scenario.status);
    assertEquals(await response.json(), {
      allowed: false,
      mode: "enforce",
      trustworthy: false,
      reason: scenario.reason,
    });
    assertEquals(rateCalls, [{
      name: "bil_consume_rate_limit",
      p_action: "play_integrity_issue",
      p_limit: 60,
      p_window_seconds: 3600,
    }]);
    assertEquals(verifierCalls, 0);
    assertEquals(persistenceCalls, 0);
  }
});
