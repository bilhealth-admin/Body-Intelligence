import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import { deleteBilUserStorage } from "./account_deletion_storage.ts";

type DeletionRequest = { id: string; user_id: string };

function createAdminClient(url: string, serviceRoleKey: string) {
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

type AdminClient = ReturnType<typeof createAdminClient>;

const staleAfterMs = 15 * 60 * 1000;

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

function bearerToken(request: Request) {
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  return match?.[1]?.trim() ?? "";
}

function secretMatches(
  presented: string | null,
  configured: string | undefined,
) {
  if (!presented || !configured) return false;
  const left = new TextEncoder().encode(presented);
  const right = new TextEncoder().encode(configured);
  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (left[index] ?? 0) ^ (right[index] ?? 0);
  }
  return difference === 0;
}

async function internalRequestIsAuthorized(
  client: AdminClient,
  request: Request,
) {
  const presented = request.headers.get("x-bil-deletion-secret");
  if (!presented) return false;

  // Prefer an Edge Function secret when one is configured. Hosted deployments
  // may instead keep the shared value exclusively in Vault and validate it
  // through this service-role-only RPC, so the value is never duplicated in
  // dashboard configuration or source control.
  const configured = Deno.env.get("BIL_INTERNAL_DELETION_SECRET");
  if (configured) return secretMatches(presented, configured);

  const { data, error } = await client.rpc(
    "bil_validate_account_deletion_secret",
    { p_presented: presented },
  );
  return !error && data === true;
}

async function resetRequest(
  client: AdminClient,
  requestId: string,
  failureCode: string,
) {
  await client
    .from("bil_account_deletion_requests")
    .update({
      status: "pending",
      processing_started_at: null,
      failure_code: failureCode,
    })
    .eq("id", requestId)
    .eq("status", "processing");
}

async function claimRequest(
  client: AdminClient,
  item: DeletionRequest,
) {
  const { data, error } = await client
    .from("bil_account_deletion_requests")
    .update({
      status: "processing",
      processing_started_at: new Date().toISOString(),
      failure_code: null,
    })
    .eq("id", item.id)
    .eq("user_id", item.user_id)
    .eq("status", "pending")
    .select("id,user_id")
    .maybeSingle();
  if (error) throw new Error("request_claim_failed");
  return data as DeletionRequest | null;
}

async function processRequest(
  client: AdminClient,
  item: DeletionRequest,
) {
  const claimed = await claimRequest(client, item);
  if (!claimed) return { status: "skipped" as const, removed: 0 };

  let removed = 0;
  try {
    // Supabase requires Storage API deletion before Auth deletion. Direct SQL
    // deletion of storage.objects would orphan the underlying object bytes.
    removed = await deleteBilUserStorage(client.storage, claimed.user_id);
  } catch (_error) {
    await resetRequest(client, claimed.id, "storage_cleanup_failed");
    return { status: "failed" as const, failure: "storage_cleanup_failed" };
  }

  const { error: deletionError } = await client.auth.admin.deleteUser(
    claimed.user_id,
    false,
  );
  if (deletionError) {
    await resetRequest(client, claimed.id, "auth_deletion_failed");
    return { status: "failed" as const, failure: "auth_deletion_failed" };
  }

  return { status: "completed" as const, removed };
}

async function authenticatedUserId(
  client: AdminClient,
  request: Request,
) {
  const token = bearerToken(request);
  if (!token) return null;
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}

async function recoverStaleClaims(client: AdminClient) {
  const cutoff = new Date(Date.now() - staleAfterMs).toISOString();
  const { error } = await client
    .from("bil_account_deletion_requests")
    .update({
      status: "pending",
      processing_started_at: null,
      failure_code: "stale_worker_recovered",
    })
    .eq("status", "processing")
    .lt("processing_started_at", cutoff);
  if (error) throw new Error("stale_claim_recovery_failed");
}

export async function handleAccountDeletion(request: Request) {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "cloud_not_configured" }, 503);

  const client = createAdminClient(url, key);
  const internal = await internalRequestIsAuthorized(client, request);
  const userId = internal ? null : await authenticatedUserId(client, request);
  if (!internal && !userId) return json({ error: "unauthorized" }, 401);

  let body: Record<string, unknown> = {};
  try {
    const parsed = await request.json();
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      body = parsed as Record<string, unknown>;
    }
  } catch (_error) {
    // An internal batch request legitimately has no body.
  }

  try {
    await recoverStaleClaims(client);
  } catch (_error) {
    return json({ error: "request_recovery_failed" }, 503);
  }

  if (!internal) {
    let query = client
      .from("bil_account_deletion_requests")
      .select("id,user_id")
      .eq("user_id", userId!)
      .eq("status", "pending");
    const requestedId = typeof body.request_id === "string"
      ? body.request_id.trim()
      : "";
    if (requestedId) query = query.eq("id", requestedId);
    const { data: item, error } = await query
      .order("requested_at", { ascending: true })
      .limit(1)
      .maybeSingle();
    if (error) return json({ error: "request_read_failed" }, 503);
    if (!item) return json({ error: "deletion_request_not_found" }, 404);

    const result = await processRequest(client, item as DeletionRequest);
    if (result.status === "completed") {
      return json({
        status: "completed",
        request_id: item.id,
        removed_storage_objects: result.removed,
      });
    }
    if (result.status === "skipped") {
      return json({ status: "processing", request_id: item.id }, 409);
    }
    return json(
      { status: "pending", request_id: item.id, error: result.failure },
      503,
    );
  }

  const { data: requests, error } = await client
    .from("bil_account_deletion_requests")
    .select("id,user_id")
    .eq("status", "pending")
    .order("requested_at", { ascending: true })
    .limit(25);
  if (error) return json({ error: "request_read_failed" }, 503);

  let completed = 0;
  let failed = 0;
  let skipped = 0;
  let removedStorageObjects = 0;
  for (const item of (requests ?? []) as DeletionRequest[]) {
    const result = await processRequest(client, item);
    if (result.status === "completed") {
      completed += 1;
      removedStorageObjects += result.removed;
    } else if (result.status === "failed") {
      failed += 1;
    } else {
      skipped += 1;
    }
  }
  return json({
    processed: requests?.length ?? 0,
    completed,
    failed,
    skipped,
    removed_storage_objects: removedStorageObjects,
  });
}
