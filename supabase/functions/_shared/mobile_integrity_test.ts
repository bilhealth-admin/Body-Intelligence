import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canonicalIntegrityValue,
  integrityPayloadDigest,
  MobileIntegrityFailure,
  requireMobileIntegrityGrant,
} from "./mobile_integrity.ts";

Deno.test("semantic request digest is stable across key order", async () => {
  const first = { z: [true, null, 1.5], a: "é" };
  const second = { a: "é", z: [true, null, 1.5] };
  assertEquals(
    canonicalIntegrityValue(first),
    "M2:{K1:a;S2:é;K1:z;L3:[B1;N;D3ff8000000000000;];};",
  );
  assertEquals(
    await integrityPayloadDigest(first),
    await integrityPayloadDigest(second),
  );
  assertEquals(
    await integrityPayloadDigest(first),
    "ecf9a57e9ab1837cee86267e950eb5aae33d3e5b5010699e2adcb4824590f3c4",
  );
});

Deno.test("grant consumption uses the server digest and strips the envelope", async () => {
  const calls: Array<Record<string, unknown>> = [];
  const body = {
    value: 7,
    _integrity: { grant_id: "00000000-0000-4000-8000-000000000001" },
  };
  const result = await requireMobileIntegrityGrant({
    admin: {
      rpc: (name, params) => {
        calls.push({ name, ...params });
        return Promise.resolve({ data: true, error: null });
      },
    },
    ownerId: "00000000-0000-4000-8000-000000000002",
    action: "test.sensitive",
    body,
    enforcement: "enforce",
  });
  assertEquals(result, { value: 7 });
  assertEquals(calls[0].name, "bil_consume_mobile_integrity_grant");
  assertEquals(
    calls[0].p_payload_digest,
    await integrityPayloadDigest({ value: 7 }),
  );
});

Deno.test("missing or rejected grants fail closed", async () => {
  await assertRejects(
    () =>
      requireMobileIntegrityGrant({
        admin: { rpc: () => Promise.resolve({ data: true, error: null }) },
        ownerId: "00000000-0000-4000-8000-000000000002",
        action: "test.sensitive",
        body: { value: 7 },
        enforcement: "enforce",
      }),
    MobileIntegrityFailure,
    "mobile_integrity_grant_required",
  );
  await assertRejects(
    () =>
      requireMobileIntegrityGrant({
        admin: { rpc: () => Promise.resolve({ data: false, error: null }) },
        ownerId: "00000000-0000-4000-8000-000000000002",
        action: "test.sensitive",
        body: {
          value: 7,
          _integrity: { grant_id: "00000000-0000-4000-8000-000000000001" },
        },
        enforcement: "enforce",
      }),
    MobileIntegrityFailure,
    "mobile_integrity_grant_invalid",
  );
});

Deno.test("rollout-off strips envelopes without requiring an unavailable migration", async () => {
  let rpcCalled = false;
  const result = await requireMobileIntegrityGrant({
    admin: {
      rpc: () => {
        rpcCalled = true;
        return Promise.resolve({
          data: false,
          error: { message: "migration absent" },
        });
      },
    },
    ownerId: "00000000-0000-4000-8000-000000000002",
    action: "test.sensitive",
    body: {
      value: 7,
      _integrity: { grant_id: "00000000-0000-4000-8000-000000000001" },
    },
    enforcement: "off",
  });

  assertEquals(result, { value: 7 });
  assertEquals(rpcCalled, false);
});

Deno.test("an unknown rollout mode fails closed instead of downgrading", async () => {
  const name = "BIL_MOBILE_INTEGRITY_ENFORCEMENT";
  const previous = Deno.env.get(name);
  Deno.env.set(name, "observe");
  try {
    await assertRejects(
      () =>
        requireMobileIntegrityGrant({
          admin: {
            rpc: () => Promise.resolve({ data: true, error: null }),
          },
          ownerId: "00000000-0000-4000-8000-000000000002",
          action: "test.sensitive",
          body: { value: 7 },
        }),
      MobileIntegrityFailure,
      "mobile_integrity_server_misconfigured",
    );
  } finally {
    if (previous == null) Deno.env.delete(name);
    else Deno.env.set(name, previous);
  }
});
