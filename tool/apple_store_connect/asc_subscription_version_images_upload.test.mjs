import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  inspectPng,
  subscriptionImageProducts,
} from "./asc_subscription_version_images_upload.mjs";

const root = path.resolve(import.meta.dirname, "..", "..");
const imageRoot = path.join(root, "store_assets", "review", "apple", "subscription_images");
const assets = subscriptionImageProducts.map(({ file }) => file);

test("Apple subscription promotion assets are opaque 1024px RGB PNGs", () => {
  for (const file of assets) {
    const filePath = path.join(
      root,
      "store_assets",
      "review",
      "apple",
      "subscription_images",
      file,
    );
    const metadata = inspectPng(fs.readFileSync(filePath));
    assert.deepEqual(metadata, {
      width: 1024,
      height: 1024,
      bitDepth: 8,
      colorType: 2,
    });
  }
});

test("each subscription has its own bound original artwork without writing", () => {
  assert.deepEqual(
    subscriptionImageProducts.map(({ productId }) => productId),
    [
      "bil_premium",
      "bil_premium_annual",
      "bil_premium_ai_coach",
      "bil_premium_ai_coach_annual",
    ],
  );
  const manifest = JSON.parse(fs.readFileSync(path.join(imageRoot, "textfree-original-artwork-manifest.json"), "utf8"));
  assert.equal(new Set(assets).size, 4);
  const hashes = new Set();
  for (const product of subscriptionImageProducts) {
    const record = manifest.images.find(({ productId }) => productId === product.productId);
    assert.ok(record, product.productId);
    assert.equal(product.file, record.file);
    const raw = fs.readFileSync(path.join(imageRoot, product.file));
    const digest = createHash("sha256").update(raw).digest("hex");
    assert.equal(raw.length, record.bytes);
    assert.equal(digest, record.sha256);
    hashes.add(digest);
  }
  assert.equal(hashes.size, 4, "Distinct products must not silently share one generic image");
});
