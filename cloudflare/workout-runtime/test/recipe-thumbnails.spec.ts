import {
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

import worker from "../src/index";
import {
  recipeThumbnailDeliveryPath,
  recipeThumbnailManifestSha256,
  recipeThumbnailObjectCount,
  recipeThumbnailObjectsForContract,
  resolveRecipeThumbnail,
} from "../src/recipe-thumbnails";

function incoming(path: string, init?: RequestInit): Request {
  return new Request(`https://workouts.bilhealth.com${path}`, init);
}

async function dispatch(request: Request): Promise<Response> {
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

const smallest = recipeThumbnailObjectsForContract().reduce((candidate, object) =>
  object.sizeBytes < candidate.sizeBytes ? object : candidate,
);

describe("recipe thumbnail v4 manifest", () => {
  it("is an additive, exact 1500-object source-pinned allowlist", () => {
    const objects = recipeThumbnailObjectsForContract();

    expect(recipeThumbnailManifestSha256).toBe(
      "24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029",
    );
    expect(recipeThumbnailObjectCount).toBe(1500);
    expect(objects).toHaveLength(1500);
    expect(new Set(objects.map((object) => object.canonicalId))).toHaveLength(1500);
    expect(new Set(objects.map((object) => object.objectKey))).toHaveLength(1500);
    expect(objects.every((object) => object.mimeType === "image/webp")).toBe(true);
    expect(objects.every((object) => object.width <= 512 && object.height <= 512)).toBe(
      true,
    );
    expect(
      objects.every(
        (object) =>
          resolveRecipeThumbnail(recipeThumbnailDeliveryPath(object)) === object,
      ),
    ).toBe(true);
  });

  it("rejects bucket keys, stale digests, encodings, aliases, and extra segments", () => {
    const path = recipeThumbnailDeliveryPath(smallest);
    const wrongDigest = `${smallest.sha256.slice(0, -1)}${
      smallest.sha256.endsWith("0") ? "1" : "0"
    }`;

    expect(resolveRecipeThumbnail(path)).toBe(smallest);
    expect(resolveRecipeThumbnail(`/v4/recipes/thumbnails/${smallest.objectKey}`)).toBeNull();
    expect(
      resolveRecipeThumbnail(
        `/v4/recipes/thumbnails/${smallest.canonicalId}/${wrongDigest}.webp`,
      ),
    ).toBeNull();
    expect(resolveRecipeThumbnail(path.replace("/v4/", "/%764/"))).toBeNull();
    expect(resolveRecipeThumbnail(path.replace(".webp", ".png"))).toBeNull();
    expect(resolveRecipeThumbnail(`${path}/extra`)).toBeNull();
  });
});

describe("recipe thumbnail v4 Worker route", () => {
  it("streams exact WebP metadata and supports byte ranges", async () => {
    await env.RECIPES.put(smallest.objectKey, new Uint8Array(smallest.sizeBytes), {
      httpMetadata: { contentDisposition: "inline", contentType: "image/webp" },
    });
    const path = recipeThumbnailDeliveryPath(smallest);
    const full = await dispatch(
      incoming(path, { headers: { authorization: "Bearer deliberately-not-consumed" } }),
    );

    expect(full.status).toBe(200);
    expect(full.headers.get("content-type")).toBe("image/webp");
    expect(full.headers.get("content-length")).toBe(String(smallest.sizeBytes));
    expect(full.headers.get("x-bil-content-sha256")).toBe(smallest.sha256);
    expect(full.headers.get("cache-control")).toBe(
      "public, max-age=31536000, immutable",
    );
    expect((await full.arrayBuffer()).byteLength).toBe(smallest.sizeBytes);

    const range = await dispatch(incoming(path, { headers: { range: "bytes=3-9" } }));
    expect(range.status).toBe(206);
    expect(range.headers.get("content-range")).toBe(`bytes 3-9/${smallest.sizeBytes}`);
    expect((await range.arrayBuffer()).byteLength).toBe(7);
  });

  it("fails closed if R2 size or MIME differs from the signed mapping", async () => {
    await env.RECIPES.put(smallest.objectKey, new Uint8Array(smallest.sizeBytes - 1), {
      httpMetadata: { contentType: "image/png" },
    });

    const response = await dispatch(
      incoming(recipeThumbnailDeliveryPath(smallest), {
        headers: { authorization: "Bearer deliberately-not-consumed" },
      }),
    );
    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toEqual({
      error: "media_integrity_unavailable",
    });
  });
});
