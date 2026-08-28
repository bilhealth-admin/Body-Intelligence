import {
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import { env } from "cloudflare:workers";
import { HttpResponse, http } from "msw";
import { describe, expect, it } from "vitest";

import worker from "../src/index";
import { network } from "./network";

const userId = "d9428888-122b-4f5d-b69f-818f58ab0f12";
const hs256Token =
  "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJkOTQyODg4OC0xMjJiLTRmNWQtYjY5Zi04MThmNThhYjBmMTIifQ.signature";
const protectedKey =
  "workouts/v1/home/movements/home-bodyweight-air-squat-standard-7s-original.mp4";

function incoming(path: string, init?: RequestInit): Request {
  return new Request(`https://workouts.bilhealth.com${path}`, init);
}

async function dispatch(request: Request): Promise<Response> {
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

function mockAuthenticated(premium = true): void {
  const requiredHeaders = (headers: { get(name: string): string | null }) => {
    if (
      headers.get("authorization") !== `Bearer ${hs256Token}` ||
      headers.get("apikey") !== env.SUPABASE_PUBLISHABLE_KEY
    ) {
      return HttpResponse.json({ error: "bad_test_headers" }, { status: 401 });
    }
    return null;
  };
  network.use(
    http.get(`${env.SUPABASE_URL}/auth/v1/user`, ({ request }) => {
      return requiredHeaders(request.headers) ?? HttpResponse.json({ id: userId });
    }),
    http.get(`${env.SUPABASE_URL}/rest/v1/bil_subscriptions`, ({ request }) => {
      return (
        requiredHeaders(request.headers) ??
        HttpResponse.json(
          premium
            ? [
                {
                  expires_at: "2099-01-01T00:00:00Z",
                  grace_period_ends_at: null,
                  lifecycle: "active",
                  owner_id: userId,
                  plan_id: "premium",
                  provider: "google",
                  started_at: "2026-01-01T00:00:00Z",
                  verified_at: new Date().toISOString(),
                },
              ]
            : [],
        )
      );
    }),
    http.get(
      `${env.SUPABASE_URL}/rest/v1/bil_ai_closed_test_grants`,
      ({ request }) => requiredHeaders(request.headers) ?? HttpResponse.json([]),
    ),
  );
}

describe("workout runtime Worker", () => {
  it("serves only the exact public SHA-pinned manifest without authentication", async () => {
    const payload = '{"schema_version":2}\n';
    await env.WORKOUTS.put(env.PUBLIC_MANIFEST_KEY, payload, {
      httpMetadata: { contentType: "application/json; charset=utf-8" },
    });
    const filename = env.PUBLIC_MANIFEST_KEY.split("/").at(-1);
    const response = await dispatch(incoming(`/v2/manifest/${filename}`));

    expect(response.status).toBe(200);
    expect(await response.text()).toBe(payload);
    expect(response.headers.get("cache-control")).toContain("public");
    expect(response.headers.get("vary") ?? "").not.toContain("Authorization");
    expect(
      await dispatch(incoming("/v2/manifest/unpinned.json")),
    ).toMatchObject({ status: 404 });
  });

  it("rejects missing authentication and unsafe object paths", async () => {
    const unauthenticated = await dispatch(
      incoming(`/v2/objects/${protectedKey}`),
    );
    expect(unauthenticated.status).toBe(401);
    expect(unauthenticated.headers.get("www-authenticate")).toContain("Bearer");

    for (const path of [
      "/v2/objects/workouts/v2/packs/../../secret.json",
      "/v2/objects/workouts/v2/home/posters/not-content-pinned.webp",
      "/v2/objects/workouts/v2/catalog/unpinned.json",
      `/v2/objects/workouts/v2/packs/bil-workouts-home-v1-v1-${"0".repeat(64)}.json`,
    ]) {
      expect((await dispatch(incoming(path))).status).toBe(404);
    }
  });

  it("verifies Supabase auth and entitlement before streaming an R2 range", async () => {
    mockAuthenticated();
    await env.WORKOUTS.put(protectedKey, "0123456789", {
      httpMetadata: { contentType: "video/mp4" },
    });

    const response = await dispatch(
      incoming(`/v2/objects/${protectedKey}`, {
        headers: {
          authorization: `Bearer ${hs256Token}`,
          range: "bytes=2-5",
        },
      }),
    );

    expect(response.status).toBe(206);
    expect(response.headers.get("content-range")).toBe("bytes 2-5/10");
    expect(response.headers.get("cache-control")).toContain("private");
    expect(new TextDecoder().decode(await response.arrayBuffer())).toBe("2345");

    const staleIfRange = await dispatch(
      incoming(`/v2/objects/${protectedKey}`, {
        headers: {
          authorization: `Bearer ${hs256Token}`,
          "if-range": '"stale-etag"',
          range: "bytes=2-5",
        },
      }),
    );
    expect(staleIfRange.status).toBe(200);
    expect(new TextDecoder().decode(await staleIfRange.arrayBuffer())).toBe(
      "0123456789",
    );

    const conditionalHead = await dispatch(
      incoming(`/v2/objects/${protectedKey}`, {
        headers: {
          authorization: `Bearer ${hs256Token}`,
          "if-none-match": response.headers.get("etag")!,
        },
        method: "HEAD",
      }),
    );
    expect(conditionalHead.status).toBe(304);
  });

  it("returns 403 when authentication succeeds without a premium grant", async () => {
    mockAuthenticated(false);
    const response = await dispatch(
      incoming(`/v2/objects/${protectedKey}`, {
        headers: { authorization: `Bearer ${hs256Token}` },
      }),
    );
    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({
      error: "premium_entitlement_required",
    });
  });
});
