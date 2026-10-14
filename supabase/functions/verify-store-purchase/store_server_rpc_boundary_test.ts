import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const backendUrl = new URL("./store_backend.ts", import.meta.url);
const migrationUrl = new URL(
  "../../migrations/20260927150000_cross_store_subscription_snapshots.sql",
  import.meta.url,
);
const lineageGuardUrl = new URL(
  "../../migrations/20260927172703_apple_store_lineage_ordering_guard.sql",
  import.meta.url,
);
const boostTombstoneReadUrl = new URL(
  "../../migrations/20261012204610_boost_refund_tombstone_service_read.sql",
  import.meta.url,
);

Deno.test("store backend uses RPCs and its sole server-only refund tombstone read", async () => {
  const source = await Deno.readTextFile(backendUrl);
  const directReads = [...source.matchAll(/\badmin\.from\s*\(\s*[\"']([^\"']+)/g)]
    .map((match) => match[1]);
  assertEquals(directReads, ["bil_ai_boost_store_state"]);
  for (
    const rpc of [
      "bil_lookup_store_subscription_owner",
      "bil_list_store_subscription_snapshots_page",
      "bil_record_store_entitlement_audit",
      "bil_lookup_ai_boost_purchase",
    ]
  ) {
    assert(source.includes(`\"${rpc}\"`), `missing RPC boundary: ${rpc}`);
  }
  const tombstoneRead = await Deno.readTextFile(boostTombstoneReadUrl);
  assert(tombstoneRead.includes("c.relrowsecurity"));
  assert(tombstoneRead.includes("has_table_privilege('anon'"));
  assert(tombstoneRead.includes("has_table_privilege('authenticated'"));
  assert(tombstoneRead.includes(
    "grant select on table public.bil_ai_boost_store_state to service_role",
  ));
});

Deno.test("store RPC migration denies client execution and grants only service_role", async () => {
  const sql = await Deno.readTextFile(migrationUrl);
  for (
    const functionName of [
      "bil_lookup_store_subscription_owner",
      "bil_list_store_subscription_snapshots_page",
    ]
  ) {
    assert(sql.includes(`create or replace function public.${functionName}`));
    assert(sql.includes(`revoke all on function public.${functionName}`));
    assert(sql.includes(`grant execute on function public.${functionName}`));
  }
  assert(sql.includes("security definer"));
  assert(sql.includes("auth.jwt()->>'role'") && sql.includes("service_role"));
  assert(/set search_path\s*=\s*public,\s*pg_temp/.test(sql));
});

Deno.test("cross-store persistence derives one canonical entitlement from per-chain snapshots", async () => {
  const sql = await Deno.readTextFile(migrationUrl);
  assert(
    sql.includes(
      "create table if not exists public.bil_store_subscription_snapshots",
    ),
  );
  assert(
    sql.includes("primary key (owner_id,provider,original_transaction_id)"),
  );
  assert(sql.includes("unique (provider,original_transaction_id)"));
  assert(sql.includes("bil_persist_verified_store_purchase_single_snapshot"));
  assert(sql.includes("from public.bil_store_subscription_snapshots s"));
  assert(
    sql.includes(
      "s.lifecycle in ('trial','active','grace_period','cancelled')",
    ),
  );
  assert(sql.includes("when 'premium_ai_coach' then 2"));
  assert(sql.includes("bil_persist_verified_store_purchase_unordered"));
  assert(
    sql.includes("v_current.revision is distinct from p_expected_revision"),
  );
});

Deno.test("Apple ordering compares signed dates only inside one lineage", async () => {
  const sql = await Deno.readTextFile(lineageGuardUrl);
  assert(
    sql.includes(
      "v_existing.original_transaction_id=p_original_transaction_id",
    ),
  );
  assert(sql.includes("v_existing.environment=p_environment"));
  assert(sql.includes("v_existing.store_signed_at is not null"));
  assert(sql.includes("unexpected_single_snapshot_persistence_definition"));
  assert(sql.includes("required_single_snapshot_persistence_missing"));
  assert(
    sql.includes(
      "revoke all on function private.bil_persist_verified_store_purchase_single_snapshot",
    ),
  );
});
