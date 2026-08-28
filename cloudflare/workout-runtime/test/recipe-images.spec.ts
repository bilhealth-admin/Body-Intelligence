import {
  createExecutionContext,
  waitOnExecutionContext,
} from "cloudflare:test";
import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

import worker from "../src/index";
import {
  recipeImageDeliveryPath,
  recipeImageManifestSha256,
  recipeImageObjectCount,
  recipeImageObjectsForContract,
  resolveRecipeImage,
} from "../src/recipe-images";

function incoming(path: string, init?: RequestInit): Request {
  return new Request(`https://workouts.bilhealth.com${path}`, init);
}

async function dispatch(request: Request): Promise<Response> {
  const ctx = createExecutionContext();
  const response = await worker.fetch(request, env, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

const smallestImage = recipeImageObjectsForContract().reduce((smallest, image) =>
  image.sizeBytes < smallest.sizeBytes ? image : smallest,
);

describe("recipe image delivery manifest", () => {
  it("is an exact immutable 1500-object canonical allowlist", () => {
    const objects = recipeImageObjectsForContract();

    expect(recipeImageManifestSha256).toBe(
      "e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3",
    );
    expect(recipeImageObjectCount).toBe(1500);
    expect(objects).toHaveLength(1500);
    expect(new Set(objects.map((object) => object.canonicalId))).toHaveLength(
      1500,
    );
    expect(new Set(objects.map((object) => object.objectKey))).toHaveLength(1500);
    expect(new Set(objects.map((object) => object.sha256))).toHaveLength(1500);
    expect(objects.every((object) => object.access === "public-preview")).toBe(
      true,
    );
    expect(
      objects.every(
        (object) => resolveRecipeImage(recipeImageDeliveryPath(object)) === object,
      ),
    ).toBe(true);
  });

  it("does not accept object keys, aliases, encodings, or stale digests", () => {
    const path = recipeImageDeliveryPath(smallestImage);
    const wrongDigest = `${smallestImage.sha256.slice(0, -1)}${
      smallestImage.sha256.endsWith("0") ? "1" : "0"
    }`;

    expect(resolveRecipeImage(path)).toBe(smallestImage);
    expect(resolveRecipeImage(`/v3/recipes/images/${smallestImage.objectKey}`)).toBeNull();
    expect(
      resolveRecipeImage(
        `/v3/recipes/images/${smallestImage.canonicalId}/${wrongDigest}`,
      ),
    ).toBeNull();
    expect(resolveRecipeImage(path.replace("overnight", "%6fvernight"))).toBeNull();
    expect(resolveRecipeImage(`${path}/extra`)).toBeNull();
  });
});

describe("recipe image Worker route", () => {
  it("streams a public digest-pinned preview without consulting bearer auth", async () => {
    const bytes = new Uint8Array(smallestImage.sizeBytes);
    await env.RECIPES.put(smallestImage.objectKey, bytes, {
      httpMetadata: {
        contentDisposition: "inline",
        contentType: smallestImage.mimeType,
      },
    });

    const response = await dispatch(
      incoming(recipeImageDeliveryPath(smallestImage), {
        headers: { authorization: "Bearer deliberately-not-consumed" },
      }),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe(
      "public, max-age=31536000, immutable",
    );
    expect(response.headers.get("content-type")).toBe(smallestImage.mimeType);
    expect(response.headers.get("content-length")).toBe(
      String(smallestImage.sizeBytes),
    );
    expect(response.headers.get("x-bil-content-sha256")).toBe(
      smallestImage.sha256,
    );
    expect(response.headers.get("vary") ?? "").not.toContain("Authorization");
    expect((await response.arrayBuffer()).byteLength).toBe(
      smallestImage.sizeBytes,
    );
  });

  it("preserves ranges and conditional HEAD requests", async () => {
    await env.RECIPES.put(
      smallestImage.objectKey,
      new Uint8Array(smallestImage.sizeBytes),
      { httpMetadata: { contentType: smallestImage.mimeType } },
    );
    const path = recipeImageDeliveryPath(smallestImage);
    const range = await dispatch(
      incoming(path, { headers: { range: "bytes=7-15" } }),
    );

    expect(range.status).toBe(206);
    expect(range.headers.get("content-range")).toBe(
      `bytes 7-15/${smallestImage.sizeBytes}`,
    );
    expect((await range.arrayBuffer()).byteLength).toBe(9);

    const conditionalHead = await dispatch(
      incoming(path, {
        headers: { "if-none-match": range.headers.get("etag")! },
        method: "HEAD",
      }),
    );
    expect(conditionalHead.status).toBe(304);
    expect((await conditionalHead.arrayBuffer()).byteLength).toBe(0);
  });

  it("fails closed when R2 metadata differs from the signed mapping", async () => {
    await env.RECIPES.put(
      smallestImage.objectKey,
      new Uint8Array(smallestImage.sizeBytes),
      {
        httpMetadata: {
          contentType:
            smallestImage.mimeType === "image/jpeg" ? "image/png" : "image/jpeg",
        },
      },
    );

    const response = await dispatch(
      incoming(recipeImageDeliveryPath(smallestImage)),
    );
    expect(response.status).toBe(502);
    await expect(response.json()).resolves.toEqual({
      error: "media_integrity_unavailable",
    });
  });

  it("never exposes the bucket object-key route", async () => {
    const response = await dispatch(
      incoming(`/v3/recipes/images/${smallestImage.objectKey}`),
    );
    expect(response.status).toBe(404);
  });
});
