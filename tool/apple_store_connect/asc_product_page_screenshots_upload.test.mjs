import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import {
  DISPLAY_TYPE,
  EXPECTED_HEIGHT,
  EXPECTED_WIDTH,
  SCREENSHOT_COUNT,
  assertNoExistingScreenshotSet,
  screenshotRoot,
  selectScreenshotFiles,
  validateScreenshot,
} from './asc_product_page_screenshots_upload.mjs';

test('selects exactly the first eight sorted English PNGs', () => {
  const selected = selectScreenshotFiles().map((file) => path.basename(file));
  assert.deepEqual(selected, [
    'epic15_iphone_69_en_00_onboarding.png',
    'epic15_iphone_69_en_01_dashboard.png',
    'epic15_iphone_69_en_02_daily_log.png',
    'epic15_iphone_69_en_025_food_search.png',
    'epic15_iphone_69_en_03_progress.png',
    'epic15_iphone_69_en_04_plans.png',
    'epic15_iphone_69_en_05_connected_health.png',
    'epic15_iphone_69_en_06_privacy_settings.png',
  ]);
  assert.equal(selected.length, SCREENSHOT_COUNT);
});

test('all selected assets are accepted-size opaque RGB PNGs', () => {
  for (const file of selectScreenshotFiles()) {
    const asset = validateScreenshot(file);
    assert.equal(asset.width, EXPECTED_WIDTH);
    assert.equal(asset.height, EXPECTED_HEIGHT);
    assert.equal(asset.bitDepth, 8);
    assert.equal(asset.colorType, 2);
    assert.ok(asset.bytes.length > 0);
    assert.equal(path.dirname(file), screenshotRoot);
    assert.ok(fs.existsSync(file));
  }
});

test('refuses mutation when any screenshot set already exists', () => {
  assert.doesNotThrow(() => assertNoExistingScreenshotSet([]));
  assert.throws(
    () => assertNoExistingScreenshotSet([{
      id: 'existing-set',
      attributes: { screenshotDisplayType: DISPLAY_TYPE },
    }]),
    /Mutation refused/,
  );
});
