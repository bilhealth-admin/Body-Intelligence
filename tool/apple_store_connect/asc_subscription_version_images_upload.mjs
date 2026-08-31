#!/usr/bin/env node

/**
 * Idempotent BIL subscription-version promotion-image uploader.
 *
 * The App Store Connect API 4.4.1+ stores reviewable subscription images on
 * a draft subscription version. This utility refuses to overwrite or delete
 * an existing version image and requires an explicit mutation gate.
 */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const projectRoot = path.resolve(import.meta.dirname, '..', '..');
const imageRoot = path.join(
  projectRoot,
  'store_assets',
  'review',
  'apple',
  'subscription_images',
);

const products = [
  {
    productId: 'bil_premium',
    subscriptionId: '6806555342',
    file: 'bil_premium_subscription_1024.png',
  },
  {
    productId: 'bil_premium_annual',
    subscriptionId: '6806555198',
    file: 'bil_premium_subscription_1024.png',
  },
  {
    productId: 'bil_premium_ai_coach',
    subscriptionId: '6806555282',
    file: 'bil_premium_ai_coach_subscription_1024.png',
  },
  {
    productId: 'bil_premium_ai_coach_annual',
    subscriptionId: '6806555344',
    file: 'bil_premium_ai_coach_subscription_1024.png',
  },
];

export function inspectPng(buffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (buffer.length < 26 || !buffer.subarray(0, 8).equals(signature)) {
    throw new Error('Asset is not a valid PNG');
  }
  const width = buffer.readUInt32BE(16);
  const height = buffer.readUInt32BE(20);
  const bitDepth = buffer[24];
  const colorType = buffer[25];
  return { width, height, bitDepth, colorType };
}

function validateAsset(filePath) {
  const bytes = fs.readFileSync(filePath);
  const png = inspectPng(bytes);
  if (png.width !== 1024 || png.height !== 1024) {
    throw new Error(`${path.basename(filePath)} must be exactly 1024x1024`);
  }
  if (png.bitDepth !== 8 || png.colorType !== 2) {
    throw new Error(
      `${path.basename(filePath)} must be flattened 8-bit RGB PNG without alpha; ` +
      `received bitDepth=${png.bitDepth}, colorType=${png.colorType}`,
    );
  }
  return bytes;
}

async function uploadOperations(operations, bytes) {
  for (const operation of operations ?? []) {
    const start = Number(operation.offset ?? 0);
    const end = start + Number(operation.length ?? bytes.length);
    const body = bytes.subarray(start, end);
    const headers = Object.fromEntries(
      (operation.requestHeaders ?? []).map(({ name, value }) => [name, value]),
    );
    const response = await fetch(operation.url, {
      method: operation.method ?? 'PUT',
      headers,
      body,
    });
    if (!response.ok) {
      throw new Error(`Apple asset upload failed with HTTP ${response.status}`);
    }
  }
}

async function waitForComplete(client, id) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const current = await client.request('GET', `/v2/subscriptionImages/${id}`);
    const delivery = current.data.attributes?.assetDeliveryState;
    if (delivery?.state === 'COMPLETE') return current.data;
    if (delivery?.state === 'FAILED') {
      throw new Error(`Apple rejected subscription image ${id}`);
    }
    await new Promise((resolve) => setTimeout(resolve, 1_000));
  }
  throw new Error(`Timed out waiting for subscription image ${id}`);
}

async function uploadProduct(client, product) {
  const versions = await client.all(
    `/v1/subscriptions/${product.subscriptionId}/versions?filter[state]=PREPARE_FOR_SUBMISSION&limit=20`,
  );
  if (versions.length !== 1) {
    throw new Error(
      `${product.productId}: expected one PREPARE_FOR_SUBMISSION version, found ${versions.length}`,
    );
  }
  const version = versions[0];
  const existing = await client.all(
    `/v1/subscriptionVersions/${version.id}/images?limit=50`,
  );
  if (existing.length > 0) {
    return {
      productId: product.productId,
      versionId: version.id,
      action: 'unchanged_existing_version_image',
      imageCount: existing.length,
      states: existing.map((image) => image.attributes?.assetDeliveryState?.state ?? null),
    };
  }

  const filePath = path.join(imageRoot, product.file);
  const bytes = validateAsset(filePath);
  const reservation = await client.request('POST', '/v2/subscriptionImages', {
    data: {
      type: 'subscriptionImages',
      attributes: {
        fileName: `${product.productId}.png`,
        fileSize: bytes.length,
      },
      relationships: {
        version: {
          data: { type: 'subscriptionVersions', id: version.id },
        },
      },
    },
  });
  const image = reservation.data;
  await uploadOperations(image.attributes?.uploadOperations, bytes);
  await client.request('PATCH', `/v2/subscriptionImages/${image.id}`, {
    data: {
      type: 'subscriptionImages',
      id: image.id,
      attributes: { uploaded: true },
    },
  });
  const completed = await waitForComplete(client, image.id);
  return {
    productId: product.productId,
    versionId: version.id,
    action: 'uploaded_version_image',
    imageId: completed.id,
    state: completed.attributes?.assetDeliveryState?.state ?? null,
    width: completed.attributes?.imageAsset?.width ?? null,
    height: completed.attributes?.imageAsset?.height ?? null,
  };
}

export async function main() {
  if (process.env.ASC_ALLOW_SUBSCRIPTION_IMAGE_UPLOAD !== 'YES') {
    throw new Error('Mutation refused: set ASC_ALLOW_SUBSCRIPTION_IMAGE_UPLOAD=YES');
  }
  const client = clientFromEnvironment();
  const results = [];
  for (const product of products) results.push(await uploadProduct(client, product));
  const report = {
    generatedAt: new Date().toISOString(),
    mutation: 'subscription_version_images',
    deletionsPerformed: false,
    results,
  };
  const output = process.argv[2];
  if (output) {
    const target = path.resolve(output);
    if (path.parse(target).root.toUpperCase() !== 'G:\\') {
      throw new Error(`Report output must stay on G:, received ${target}`);
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  }
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(import.meta.filename)) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  });
}

