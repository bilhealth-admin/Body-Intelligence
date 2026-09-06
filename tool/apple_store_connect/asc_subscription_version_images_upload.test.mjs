import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  inspectPng,
  subscriptionImageProducts,
} from "./asc_subscription_version_images_upload.mjs";

const root = path.resolve(import.meta.dirname, "..", "..");
const assets = [
  "bil_premium_subscription_1024.png",
  "bil_premium_ai_coach_subscription_1024.png",
];

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

test("all four Premium subscriptions share one non-coach image", () => {
  assert.deepEqual(
    subscriptionImageProducts.map(({ productId }) => productId),
    [
      "bil_premium",
      "bil_premium_annual",
      "bil_premium_ai_coach",
      "bil_premium_ai_coach_annual",
    ],
  );
  assert.deepEqual(
    [...new Set(subscriptionImageProducts.map(({ file }) => file))],
    ["bil_premium_subscription_1024.png"],
  );
});
