import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { type RuntimeFetch } from "../src/auth";
import { EntitlementError, verifyPremiumEntitlement } from "../src/entitlement";

const owner = "d9428888-122b-4f5d-b69f-818f58ab0f12";
const user = { id: owner, token: "header.payload.signature" };
const now = new Date("2026-09-10T12:00:00Z");
const gift = {
  owner_id: owner,
  plan_id: "premium",
  created_at: "2026-09-01T12:00:00Z",
  expires_at: null,
  access_until: "2026-09-10T12:05:00Z",
};
const paid = {
  owner_id: owner,
  provider: "apple",
  plan_id: "premium",
  lifecycle: "active",
  started_at: "2026-09-01T12:00:00Z",
  verified_at: "2026-09-01T12:00:00Z",
  expires_at: "2026-10-01T12:00:00Z",
};

function responses(options: {
  subscription?: unknown;
  grant?: unknown;
  failedTable?: string;
}): RuntimeFetch {
  return (input, init) => {
    const url = new URL(input.toString());
    const table = url.pathname.split("/").at(-1);
    const headers = new Headers(init?.headers);
    expect(headers.get("authorization")).toBe(`Bearer ${user.token}`);
    expect(headers.get("apikey")).toBe(env.SUPABASE_PUBLISHABLE_KEY);
    expect(init?.redirect).toBe("manual");
    if (table === options.failedTable) {
      return Promise.resolve(new Response(null, { status: 503 }));
    }
    if (table === "bil_get_my_admin_subscription") {
      // Owner identity is supplied by auth.uid(), never by a caller parameter.
      expect(url.search).toBe("");
      return Promise.resolve(Response.json(options.grant ?? null));
    }
    expect(url.searchParams.get("owner_id")).toBe(`eq.${owner}`);
    return Promise.resolve(Response.json(
      table === "bil_subscriptions" ? (options.subscription ?? []) : [],
    ));
  };
}

describe("authoritative entitlement consistency", () => {
  for (const plan of ["premium", "premium_ai_coach"]) {
    it(`recognizes the current owner-scoped admin ${plan} lease`, async () => {
      expect(await verifyPremiumEntitlement(user, env, responses({
        grant: { ...gift, plan_id: plan },
      }), now)).toBe(true);
    });
  }

  it("does not revoke an active paid month after 72 hours", async () => {
    expect(await verifyPremiumEntitlement(user, env, responses({
      subscription: [paid],
    }), now)).toBe(true);
  });

  for (const invalid of [
    null,
    [],
    { ...gift, owner_id: "another-owner" },
    { ...gift, plan_id: "free" },
    { ...gift, created_at: "invalid" },
    { ...gift, created_at: "2026-09-11T00:00:00Z" },
    { ...gift, access_until: "invalid" },
    { ...gift, access_until: now.toISOString() },
    { ...gift, access_until: "2026-09-10T12:07:00Z" },
    { ...gift, expires_at: "invalid" },
    { ...gift, expires_at: now.toISOString() },
    { ...gift, expires_at: "2026-09-10T12:04:00Z" },
  ]) {
    it(`rejects an invalid/revoked lease: ${JSON.stringify(invalid)}`, async () => {
      expect(await verifyPremiumEntitlement(user, env, responses({
        grant: invalid,
      }), now)).toBe(false);
    });
  }

  for (const mutation of [
    { expires_at: now.toISOString() },
    { expires_at: "2026-09-09T00:00:00Z" },
    { verified_at: "invalid" },
    { verified_at: "2026-09-11T00:00:00Z" },
    { lifecycle: "expired" },
    { lifecycle: "revoked" },
    { provider: "untrusted" },
    { owner_id: "another-owner" },
  ]) {
    it(`fails closed for invalid paid state: ${JSON.stringify(mutation)}`, async () => {
      expect(await verifyPremiumEntitlement(user, env, responses({
        subscription: [{ ...paid, verified_at: now.toISOString(), ...mutation }],
      }), now)).toBe(false);
    });
  }

  it("does not deny valid store access if the admin endpoint is unavailable", async () => {
    expect(await verifyPremiumEntitlement(user, env, responses({
      subscription: [paid], failedTable: "bil_get_my_admin_subscription",
    }), now)).toBe(true);
  });

  it("does not deny a verified gift if the store endpoint is unavailable", async () => {
    expect(await verifyPremiumEntitlement(user, env, responses({
      grant: gift, failedTable: "bil_subscriptions",
    }), now)).toBe(true);
  });

  it("reports unavailability instead of inventing access or a definitive denial", async () => {
    await expect(verifyPremiumEntitlement(user, env, responses({
      failedTable: "bil_get_my_admin_subscription",
    }), now)).rejects.toBeInstanceOf(EntitlementError);
  });
});
