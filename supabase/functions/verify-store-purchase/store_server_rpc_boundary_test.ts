import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const backendUrl = new URL("./store_backend.ts", import.meta.url);
const migrationUrl = new URL(
  "../../migrations/20260920120000_store_server_rpc_boundaries.sql",
  import.meta.url,
);

Deno.test("store backend keeps sensitive table access behind server-only RPCs", async () => {
  const source = await Deno.readTextFile(backendUrl);
  assertEquals((source.match(/\badmin\.from\s*\(/g) ?? []).length, 0);
  for (const rpc of [
    "bil_lookup_store_subscription_owner",
    "bil_list_store_subscriptions_page",
    "bil_record_store_entitlement_audit",
    "bil_lookup_ai_boost_purchase",
  ]) {
    assert(source.includes(`\"${rpc}\"`), `missing RPC boundary: ${rpc}`);
  }
});

Deno.test("store RPC migration denies client execution and grants only service_role", async () => {
  const sql = await Deno.readTextFile(migrationUrl);
  for (const functionName of [
    "bil_lookup_store_subscription_owner",
    "bil_list_store_subscriptions_page",
    "bil_record_store_entitlement_audit",
    "bil_lookup_ai_boost_purchase",
  ]) {
    assert(sql.includes(`create or replace function public.${functionName}`));
    assert(sql.includes(`revoke all on function public.${functionName}`));
    assert(sql.includes(`grant execute on function public.${functionName}`));
  }
  assert(sql.includes("security definer"));
  assert(sql.includes("auth.jwt()->>'role'") && sql.includes("service_role"));
  assert(sql.includes("set search_path = public, pg_temp"));
});
