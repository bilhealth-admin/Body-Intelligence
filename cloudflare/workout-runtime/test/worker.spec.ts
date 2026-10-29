import {
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import { env } from "cloudflare:workers";
import { HttpResponse, http } from "msw";
import { describe, expect, it, vi } from "vitest";

import worker from "../src/index";
import { recipeImageDeliveryPath, recipeImageObjectsForContract } from "../src/recipe-images";
import { recipeThumbnailDeliveryPath, recipeThumbnailObjectsForContract } from "../src/recipe-thumbnails";
import approvedObjects from "../../../artifacts/workout_media/cloudflare_runtime_v2/protected_object_keys_v2.json";
import freePreviews from "../../../artifacts/workout_media/cloudflare_runtime_v2/free_preview_keys_v1.json";
import { network } from "./network";

const userId = "d9428888-122b-4f5d-b69f-818f58ab0f12";
const hs256Token =
  "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJkOTQyODg4OC0xMjJiLTRmNWQtYjY5Zi04MThmNThhYjBmMTIifQ.signature";
const freePreviewKey = freePreviews.videoObjectKeys[0]!;
const freePreviewPosterKey = freePreviews.groups[0]!.posterObjectKey;
const paidVideoKey = approvedObjects.keys.find(
  (key) => key.endsWith(".mp4") && !freePreviews.videoObjectKeys.includes(key),
)!;

function incoming(path: string, init?: RequestInit): Request {
  return new Request(`https://workouts.bilhealth.com${path}`, init);
}

async function dispatch(request: Request, runtimeEnv: Env = env): Promise<Response> {
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, runtimeEnv, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

function withBucketGet(binding: "WORKOUTS" | "RECIPES", get: R2Bucket["get"]): Env {
  return {
    ...env,
    [binding]: new Proxy(env[binding], {
      get(target, property) {
        if (property === "get") return get;
        const value = Reflect.get(target, property, target);
        return typeof value === "function" ? value.bind(target) : value;
      },
    }),
  };
}

async function expectContainedStorageError(
  request: Request,
  runtimeEnv: Env,
): Promise<void> {
  const logged = vi.spyOn(console, "error").mockImplementation(() => undefined);
  try {
    const response = await dispatch(request, runtimeEnv);
    expect(response.status).toBe(500);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(await response.json()).toEqual({ error: "internal_error" });
    expect(logged).toHaveBeenCalledTimes(1);
    expect(logged).toHaveBeenCalledWith(JSON.stringify({
      error: "TypeError",
      message: "workout_runtime_request_failed",
      path: new URL(request.url).pathname,
      ray: "fixture-storage-ray",
    }));
    expect(JSON.stringify(logged.mock.calls)).not.toContain("private-storage-detail");
  } finally {
    logged.mockRestore();
  }
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
    http.get(
      `${env.SUPABASE_URL}/rest/v1/rpc/bil_get_my_admin_subscription`,
      ({ request }) => requiredHeaders(request.headers) ?? HttpResponse.json(null),
    ),
  );
}

describe("workout runtime Worker", () => {
  for (const surface of ["manifest", "preview", "paid", "recipe-image", "recipe-thumbnail"] as const) {
    it(`contains an asynchronous R2 get rejection on the ${surface} route`, async () => {
      if (surface === "paid") mockAuthenticated();
      const key = surface === "manifest"
        ? `/v2/manifest/${env.PUBLIC_MANIFEST_KEY.split("/").at(-1)}`
        : surface === "recipe-image"
        ? recipeImageDeliveryPath(recipeImageObjectsForContract()[0]!)
        : surface === "recipe-thumbnail"
        ? recipeThumbnailDeliveryPath(recipeThumbnailObjectsForContract()[0]!)
        : `/v2/objects/${surface === "paid" ? paidVideoKey : freePreviewKey}`;
      const get = vi.fn<R2Bucket["get"]>().mockRejectedValue(
        new TypeError("private-storage-detail: get unavailable"),
      );
      await expectContainedStorageError(
        incoming(key, {
          method: "HEAD",
          headers: {
            "cf-ray": "fixture-storage-ray",
            ...(surface === "paid" ? { authorization: `Bearer ${hs256Token}` } : {}),
          },
        }),
        withBucketGet(surface.startsWith("recipe-") ? "RECIPES" : "WORKOUTS", get),
      );
      expect(get).toHaveBeenCalledTimes(1);
    });
  }

  for (const paid of [false, true]) {
    it(`contains an asynchronous HEAD stream cancellation rejection, paid=${paid}`, async () => {
      if (paid) mockAuthenticated();
      const key = paid ? paidVideoKey : freePreviewKey;
      await env.WORKOUTS.put(key, "0123456789", {
        httpMetadata: { contentType: "video/mp4" },
      });
      const object = await env.WORKOUTS.get(key);
      if (object === null) throw new Error("Missing local R2 fixture");
      await object.body.cancel();
      const cancel = vi.fn().mockRejectedValue(
        new TypeError("private-storage-detail: cancellation unavailable"),
      );
      const body = new ReadableStream<Uint8Array>({ cancel });
      const failingObject = new Proxy(object, {
        get(target, property) {
          if (property === "body") return body;
          const value = Reflect.get(target, property, target);
          return typeof value === "function" ? value.bind(target) : value;
        },
      });
      const get = vi.fn<R2Bucket["get"]>().mockResolvedValue(failingObject);
      await expectContainedStorageError(
        incoming(`/v2/objects/${key}`, {
          method: "HEAD",
          headers: {
            "cf-ray": "fixture-storage-ray",
            ...(paid ? { authorization: `Bearer ${hs256Token}` } : {}),
          },
        }),
        withBucketGet("WORKOUTS", get),
      );
      expect(get).toHaveBeenCalledTimes(1);
      expect(cancel).toHaveBeenCalledTimes(1);
    });
  }

  for (const authenticated of [false, true]) {
    it(`does not reach R2 when paid access is denied, authenticated=${authenticated}`, async () => {
      if (authenticated) mockAuthenticated(false);
      const get = vi.fn<R2Bucket["get"]>().mockRejectedValue(
        new TypeError("private-storage-detail: must not be reached"),
      );
      const response = await dispatch(
        incoming(`/v2/objects/${paidVideoKey}`, {
          method: "HEAD",
          ...(authenticated ? { headers: { authorization: `Bearer ${hs256Token}` } } : {}),
        }),
        withBucketGet("WORKOUTS", get),
      );
      expect(response.status).toBe(authenticated ? 403 : 401);
      expect(get).not.toHaveBeenCalled();
    });
  }

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
      incoming(`/v2/objects/${paidVideoKey}`),
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

  it("serves only exact generated free previews without account sync", async () => {
    mockAuthenticated(false);
    await env.WORKOUTS.put(freePreviewKey, "0123456789", {
      httpMetadata: { contentType: "video/mp4" },
    });
    await env.WORKOUTS.put(freePreviewPosterKey, "poster", {
      httpMetadata: { contentType: "image/webp" },
    });
    await env.WORKOUTS.put(paidVideoKey, "premium", {
      httpMetadata: { contentType: "video/mp4" },
    });

    const preview = await dispatch(
      incoming(`/v2/objects/${freePreviewKey}`, {
        headers: {
          range: "bytes=1-3",
        },
      }),
    );
    expect(preview.status).toBe(206);
    expect(preview.headers.get("content-range")).toBe("bytes 1-3/10");
    expect(preview.headers.get("cache-control")).toContain("public");
    expect(preview.headers.get("vary") ?? "").not.toContain("Authorization");
    expect(new TextDecoder().decode(await preview.arrayBuffer())).toBe("123");
    expect(
      (
        await dispatch(incoming(`/v2/objects/${freePreviewPosterKey}`))
      ).status,
    ).toBe(200);

    const paid = await dispatch(
      incoming(`/v2/objects/${paidVideoKey}`, {
        headers: { authorization: `Bearer ${hs256Token}` },
      }),
    );
    expect(paid.status).toBe(403);
    await expect(paid.json()).resolves.toEqual({
      error: "premium_entitlement_required",
    });
  });

  it("lets authenticated Free discover exact posters but not pack JSON", async () => {
    mockAuthenticated(false);
    const posterKey = approvedObjects.keys.find((key) => key.endsWith(".webp"))!;
    const packKey = approvedObjects.keys.find(
      (key) => key.startsWith("workouts/v2/packs/") && key.endsWith(".json"),
    )!;
    await env.WORKOUTS.put(posterKey, "poster", {
      httpMetadata: { contentType: "image/webp" },
    });
    await env.WORKOUTS.put(packKey, "pack", {
      httpMetadata: { contentType: "application/json" },
    });

    expect(
      (
        await dispatch(
          incoming(`/v2/objects/${posterKey}`, {
            headers: { authorization: `Bearer ${hs256Token}` },
          }),
        )
      ).status,
    ).toBe(200);
    expect(
      (
        await dispatch(
          incoming(`/v2/objects/${packKey}`, {
            headers: { authorization: `Bearer ${hs256Token}` },
          }),
        )
      ).status,
    ).toBe(403);
  });

  it("verifies Supabase auth and entitlement before streaming an R2 range", async () => {
    mockAuthenticated();
    await env.WORKOUTS.put(paidVideoKey, "0123456789", {
      httpMetadata: { contentType: "video/mp4" },
    });

    const response = await dispatch(
      incoming(`/v2/objects/${paidVideoKey}`, {
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
      incoming(`/v2/objects/${paidVideoKey}`, {
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
      incoming(`/v2/objects/${paidVideoKey}`, {
        headers: {
          authorization: `Bearer ${hs256Token}`,
          "if-none-match": response.headers.get("etag")!,
        },
        method: "HEAD",
      }),
    );
    expect(conditionalHead.status).toBe(304);
  });

  it("fails closed for the exact Premium curl media key if R2 supplies HTML", async () => {
    const bicepsCurlKey =
      "workouts/v1/gym-six-month/movements/resistance-upper-body-dumbbell-biceps-curl-technique.mp4";
    expect(approvedObjects.keys).toContain(bicepsCurlKey);
    expect(freePreviews.videoObjectKeys).not.toContain(bicepsCurlKey);
    mockAuthenticated(true);
    await env.WORKOUTS.put(bicepsCurlKey, "<html>wrong object metadata</html>", {
      httpMetadata: { contentType: "text/html" },
    });
    for (const request of [
      incoming(`/v2/objects/${bicepsCurlKey}`, {
        method: "HEAD",
        headers: { authorization: `Bearer ${hs256Token}` },
      }),
      incoming(`/v2/objects/${bicepsCurlKey}`, {
        headers: {
          authorization: `Bearer ${hs256Token}`,
          range: "bytes=0-9",
        },
      }),
      incoming(`/v2/objects/${bicepsCurlKey}`, {
        headers: { authorization: `Bearer ${hs256Token}` },
      }),
    ]) {
      const response = await dispatch(request);
      expect(response.status).toBe(502);
      expect(response.headers.get("content-type")).toContain("application/json");
      expect(response.headers.get("cache-control")).toBe("no-store");
    }
  });

  it("returns 403 when authentication succeeds without a premium grant", async () => {
    mockAuthenticated(false);
    const response = await dispatch(
      incoming(`/v2/objects/${paidVideoKey}`, {
        headers: { authorization: `Bearer ${hs256Token}` },
      }),
    );
    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({
      error: "premium_entitlement_required",
    });
  });
});
