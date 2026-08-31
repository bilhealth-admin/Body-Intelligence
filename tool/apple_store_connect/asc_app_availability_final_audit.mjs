#!/usr/bin/env node

/** Read-only app availability/price audit for the BIL iOS app. */

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { clientFromEnvironment } from './asc_catalog_sync.mjs';

const APP_ID = '6805349703';
const outputIndex = process.argv.indexOf('--output');
const output = outputIndex >= 0 ? process.argv[outputIndex + 1] : null;
if (!output) throw new Error('--output is required');
const target = path.resolve(output);
if (path.parse(target).root.toUpperCase() !== 'G:\\') throw new Error('Output must stay on G:');
const client = clientFromEnvironment();
const capture = async (work) => {
  try { return { ok: true, value: await work() }; }
  catch (error) { return { ok: false, error: String(error?.message ?? error) }; }
};

const availability = await client.request('GET', `/v1/apps/${APP_ID}/appAvailabilityV2`);
const related = availability.data.relationships.territoryAvailabilities.links.related;
const territories = await client.all(`${related}?include=territory&limit=200`);
const priceSchedule = await capture(() => client.request(
  'GET',
  `/v1/apps/${APP_ID}/appPriceSchedule?include=baseTerritory,manualPrices,automaticPrices&limit[manualPrices]=50&limit[automaticPrices]=50`,
));
const result = {
  generatedAt: new Date().toISOString(),
  mode: 'read-only',
  mutationPerformed: false,
  appId: APP_ID,
  availability: availability.data,
  territoryAvailabilities: territories,
  appPriceSchedule: priceSchedule,
};
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
process.stdout.write(`Wrote ${target}\n`);
