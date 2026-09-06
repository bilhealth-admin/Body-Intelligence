#!/usr/bin/env node

/**
 * Wrap the exact full-resolution Google Play screenshots in Apple-valid
 * iPhone and iPad canvases. The complete source image is fitted
 * proportionally, centered, and never cropped or stretched. The solid canvas
 * color is sampled from the dominant color on the source image's outer edge.
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const TARGETS = [
  {
    key: 'iphone67',
    displayType: 'APP_IPHONE_67',
    width: 1290,
    height: 2796,
  },
  {
    key: 'ipad129',
    displayType: 'APP_IPAD_PRO_3GEN_129',
    width: 2048,
    height: 2732,
  },
];

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function inspectPng(bytes) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (bytes.length < 26 || !bytes.subarray(0, 8).equals(signature)) {
    throw new Error('Expected a valid PNG');
  }
  return {
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
    bitDepth: bytes[24],
    colorType: bytes[25],
  };
}

function runFfmpeg(args, { capture = false } = {}) {
  const result = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', ...args], {
    encoding: capture ? null : 'utf8',
    maxBuffer: 32 * 1024 * 1024,
  });
  if (result.status !== 0) {
    const stderr = Buffer.isBuffer(result.stderr)
      ? result.stderr.toString('utf8')
      : String(result.stderr ?? '');
    throw new Error(`ffmpeg failed: ${stderr.trim()}`);
  }
  return result.stdout;
}

function rawRgb(filePath, filterExpression = null) {
  const filter = filterExpression ? ['-vf', filterExpression] : [];
  return runFfmpeg([
    '-i', filePath,
    ...filter,
    '-frames:v', '1',
    '-pix_fmt', 'rgb24',
    '-f', 'rawvideo',
    'pipe:1',
  ], { capture: true });
}

function dominantOuterEdgeColor(raw, width, height, border = 4) {
  const counts = new Map();
  const increment = (x, y) => {
    const offset = (y * width + x) * 3;
    const key = (raw[offset] << 16) | (raw[offset + 1] << 8) | raw[offset + 2];
    counts.set(key, (counts.get(key) ?? 0) + 1);
  };
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (x < border || x >= width - border || y < border || y >= height - border) {
        increment(x, y);
      }
    }
  }
  let bestColor = 0;
  let bestCount = -1;
  for (const [color, count] of counts.entries()) {
    if (count > bestCount) {
      bestColor = color;
      bestCount = count;
    }
  }
  return {
    hex: `#${bestColor.toString(16).padStart(6, '0')}`,
    ffmpeg: `0x${bestColor.toString(16).padStart(6, '0')}`,
    sampledBorderPixels: (width * height) - ((width - border * 2) * (height - border * 2)),
    dominantPixelCount: bestCount,
  };
}

function evenFloor(value) {
  return Math.max(2, Math.floor(value / 2) * 2);
}

function fitGeometry(sourceWidth, sourceHeight, targetWidth, targetHeight) {
  const factor = Math.min(targetWidth / sourceWidth, targetHeight / sourceHeight);
  const width = evenFloor(sourceWidth * factor);
  const height = evenFloor(sourceHeight * factor);
  const left = Math.floor((targetWidth - width) / 2);
  const top = Math.floor((targetHeight - height) / 2);
  const aspectError = Math.abs((width / height) - (sourceWidth / sourceHeight));
  if (width > targetWidth || height > targetHeight || aspectError > 0.001) {
    throw new Error('Unable to fit source proportionally without crop or stretch');
  }
  return {
    width,
    height,
    left,
    top,
    right: targetWidth - width - left,
    bottom: targetHeight - height - top,
    scaleFactor: factor,
    aspectError,
  };
}

function main() {
  const sourceManifestPath = path.resolve(process.argv[2] ?? '');
  const outputRoot = path.resolve(process.argv[3] ?? '');
  if (!sourceManifestPath || !outputRoot) {
    throw new Error(
      'Usage: node prepare_apple_screenshots_from_play.mjs <play-manifest.json> <G:\\output>',
    );
  }
  if (path.parse(outputRoot).root.toUpperCase() !== 'G:\\') {
    throw new Error(`Output must stay on G:, received ${outputRoot}`);
  }
  const sourceManifest = JSON.parse(fs.readFileSync(sourceManifestPath, 'utf8'));
  const locale = sourceManifest.preferredLocale;
  const listing = sourceManifest.listings?.find((item) => item.locale === locale);
  if (!listing || listing.screenshots?.length !== 8) {
    throw new Error(`Expected exactly eight source screenshots for ${locale ?? 'preferred locale'}`);
  }
  fs.mkdirSync(outputRoot, { recursive: true });
  const outputs = [];
  for (const source of listing.screenshots) {
    const sourcePath = path.resolve(source.filePath);
    const sourceBytes = fs.readFileSync(sourcePath);
    const sourcePng = inspectPng(sourceBytes);
    if (sha256(sourceBytes) !== source.sha256 || source.sha256 !== source.googleSha256) {
      throw new Error(`${source.fileName} no longer matches the Google Play SHA-256`);
    }
    const sourcePixels = rawRgb(sourcePath);
    const sourcePixelSha256 = sha256(sourcePixels);
    const edgeColor = dominantOuterEdgeColor(sourcePixels, sourcePng.width, sourcePng.height);
    for (const target of TARGETS) {
      const geometry = fitGeometry(
        sourcePng.width,
        sourcePng.height,
        target.width,
        target.height,
      );
      const targetRoot = path.join(outputRoot, target.key);
      fs.mkdirSync(targetRoot, { recursive: true });
      const outputName =
        `play-en-gb-${String(source.order).padStart(2, '0')}-${target.key}.png`;
      const outputPath = path.join(targetRoot, outputName);
      runFfmpeg([
        '-y',
        '-i', sourcePath,
        '-vf',
        `scale=${geometry.width}:${geometry.height}:flags=lanczos,` +
          `pad=${target.width}:${target.height}:${geometry.left}:${geometry.top}` +
          `:color=${edgeColor.ffmpeg}`,
        '-frames:v', '1',
        '-pix_fmt', 'rgb24',
        outputPath,
      ]);
      const outputBytes = fs.readFileSync(outputPath);
      const outputPng = inspectPng(outputBytes);
      if (outputPng.width !== target.width || outputPng.height !== target.height ||
          outputPng.bitDepth !== 8 || outputPng.colorType !== 2) {
        throw new Error(
          `${outputName} is not an opaque 8-bit RGB ${target.width}x${target.height} PNG`,
        );
      }
      const expectedScaledPixels = rawRgb(
        sourcePath,
        `scale=${geometry.width}:${geometry.height}:flags=lanczos`,
      );
      const embeddedPixels = rawRgb(
        outputPath,
        `crop=${geometry.width}:${geometry.height}:${geometry.left}:${geometry.top}`,
      );
      const expectedScaledPixelSha256 = sha256(expectedScaledPixels);
      const embeddedPixelSha256 = sha256(embeddedPixels);
      if (expectedScaledPixelSha256 !== embeddedPixelSha256) {
        throw new Error(`${outputName} altered the fitted visible-content region`);
      }
      outputs.push({
        order: source.order,
        displayType: target.displayType,
        sourceFileName: source.fileName,
        sourcePath,
        sourceBytes: sourceBytes.length,
        sourceSha256: source.sha256,
        googlePlaySha256: source.googleSha256,
        sourceWidth: sourcePng.width,
        sourceHeight: sourcePng.height,
        outputFileName: outputName,
        outputPath,
        outputBytes: outputBytes.length,
        outputSha256: sha256(outputBytes),
        outputWidth: outputPng.width,
        outputHeight: outputPng.height,
        fittedContent: geometry,
        padding: {
          left: geometry.left,
          right: geometry.right,
          top: geometry.top,
          bottom: geometry.bottom,
          background: edgeColor.hex,
          backgroundSource: 'dominant RGB value in outermost 4px source border',
          sampledBorderPixels: edgeColor.sampledBorderPixels,
          dominantPixelCount: edgeColor.dominantPixelCount,
        },
        sourcePixelSha256,
        expectedScaledPixelSha256,
        embeddedPixelSha256,
        visibleContentMatchesProportionalFit: true,
        cropped: false,
        stretched: false,
        scaledProportionally: true,
      });
    }
  }
  const report = {
    generatedAt: new Date().toISOString(),
    sourceManifestPath,
    sourceStore: 'Google Play live listing via Android Publisher API',
    sourceLocale: locale,
    targetStore: 'Apple App Store Connect',
    targets: TARGETS,
    transformation: 'whole source fitted proportionally and centered; solid background sampled from source edge; no crop or stretch',
    outputs,
  };
  const reportPath = path.join(outputRoot, 'manifest.json');
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  process.stdout.write(`${JSON.stringify({
    sourceLocale: locale,
    countPerTarget: Object.fromEntries(TARGETS.map((target) => [
      target.displayType,
      outputs.filter((item) => item.displayType === target.displayType).length,
    ])),
    allVisibleContentMatchesFit: outputs.every(
      (item) => item.visibleContentMatchesProportionalFit,
    ),
    manifest: reportPath,
  }, null, 2)}\n`);
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.stack ?? error.message}\n`);
  process.exitCode = 1;
}
