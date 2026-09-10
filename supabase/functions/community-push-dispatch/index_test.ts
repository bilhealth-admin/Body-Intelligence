import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const dispatcherUrl = new URL("./server.ts", import.meta.url);
const duplicateUrl = new URL("../community_push_dispatch.ts", import.meta.url);
const migrationUrl = new URL(
  "../../migrations/20260904040000_push_delivery_idempotency.sql",
  import.meta.url,
);

Deno.test("push entry points share the canonical invalid-token contract", async () => {
  const source = await Deno.readTextFile(dispatcherUrl);
  const entry = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const duplicate = await Deno.readTextFile(duplicateUrl);

  assertStringIncludes(entry, 'import { handler } from "./server.ts"');
  assertStringIncludes(
    duplicate,
    'import { handler } from "./community-push-dispatch/server.ts"',
  );
  for (const shim of [entry, duplicate]) {
    assertStringIncludes(shim, "Deno.serve((request) => handler(request))");
    assertEquals(shim.includes("bil_push_outbox"), false);
  }
  assertStringIncludes(source, 'response.headers.get("x-bil-token-status")');
  assertStringIncludes(source, "[400, 404, 410].includes(response.status)");
  assertStringIncludes(source, '===\n    "invalid"');
  assertStringIncludes(source, "p_permanent_token_failure");
  assertStringIncludes(source, "token: token.provider_token");
});

Deno.test("push SQL applies bounded backoff and service-only RPCs", async () => {
  const sql = await Deno.readTextFile(migrationUrl);

  assertStringIncludes(sql, "max_attempts integer not null default 5");
  assertStringIncludes(sql, "attempt.attempt_count < v_max_attempts");
  assertStringIncludes(sql, "v_attempt_count >= v_max_attempts");
  assertStringIncludes(sql, "pg_catalog.power");
  assertStringIncludes(sql, "set search_path = ''");
  assertStringIncludes(sql, "from public, anon, authenticated, service_role");
  assertStringIncludes(sql, "set enabled = false");
  assertStringIncludes(sql, "not application-layer ciphertext");
});
