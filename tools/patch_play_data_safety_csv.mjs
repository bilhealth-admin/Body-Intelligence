import fs from 'node:fs';
import path from 'node:path';

const [inputPath, outputPath] = process.argv.slice(2);
if (!inputPath || !outputPath) {
  throw new Error('Usage: node patch_play_data_safety_csv.mjs <input.csv> <output.csv>');
}

const selectedTypes = new Map([
  ['PSL_APPROX_LOCATION', ['PSL_APP_FUNCTIONALITY']],
  ['PSL_NAME', ['PSL_APP_FUNCTIONALITY', 'PSL_ACCOUNT_MANAGEMENT', 'PSL_PERSONALIZATION']],
  ['PSL_EMAIL', ['PSL_APP_FUNCTIONALITY', 'PSL_ACCOUNT_MANAGEMENT', 'PSL_FRAUD_PREVENTION_SECURITY']],
  ['PSL_USER_ACCOUNT', ['PSL_APP_FUNCTIONALITY', 'PSL_ACCOUNT_MANAGEMENT', 'PSL_FRAUD_PREVENTION_SECURITY']],
  ['PSL_PHONE', ['PSL_ACCOUNT_MANAGEMENT']],
  ['PSL_OTHER_PERSONAL', ['PSL_APP_FUNCTIONALITY', 'PSL_PERSONALIZATION']],
  ['PSL_HEALTH', ['PSL_APP_FUNCTIONALITY', 'PSL_PERSONALIZATION']],
  ['PSL_FITNESS', ['PSL_APP_FUNCTIONALITY', 'PSL_PERSONALIZATION']],
  ['PSL_OTHER_MESSAGES', ['PSL_APP_FUNCTIONALITY', 'PSL_PERSONALIZATION']],
  ['PSL_PHOTOS', ['PSL_APP_FUNCTIONALITY']],
  ['PSL_USER_INTERACTION', ['PSL_APP_FUNCTIONALITY', 'PSL_ANALYTICS']],
  ['PSL_USER_GENERATED_CONTENT', ['PSL_APP_FUNCTIONALITY']],
  ['PSL_IN_APP_SEARCH_HISTORY', ['PSL_APP_FUNCTIONALITY']],
  ['PSL_DEVICE_ID', ['PSL_APP_FUNCTIONALITY', 'PSL_ACCOUNT_MANAGEMENT', 'PSL_FRAUD_PREVENTION_SECURITY']],
]);

const removedTypes = new Set([
  'PSL_PURCHASE_HISTORY',
  'PSL_AUDIO',
  'PSL_PERFORMANCE_DIAGNOSTICS',
]);

const source = fs.readFileSync(inputPath, 'utf8');
const bom = source.startsWith('\uFEFF') ? '\uFEFF' : '';
const normalized = bom ? source.slice(1) : source;
const eol = normalized.includes('\r\n') ? '\r\n' : '\n';
const lines = normalized.split(/\r?\n/);

const purposeIds = new Set([
  'PSL_APP_FUNCTIONALITY',
  'PSL_ANALYTICS',
  'PSL_DEVELOPER_COMMUNICATIONS',
  'PSL_FRAUD_PREVENTION_SECURITY',
  'PSL_ADVERTISING',
  'PSL_PERSONALIZATION',
  'PSL_ACCOUNT_MANAGEMENT',
]);

const seenTypeRows = new Set();
const seenUsage = new Map();
const changed = [];

function parseMachineFields(line) {
  const first = line.indexOf(',');
  const second = first < 0 ? -1 : line.indexOf(',', first + 1);
  const third = second < 0 ? -1 : line.indexOf(',', second + 1);
  if (first < 0 || second < 0 || third < 0) return null;
  return {
    questionId: line.slice(0, first),
    responseId: line.slice(first + 1, second),
    value: line.slice(second + 1, third),
    prefix: line.slice(0, second + 1),
    suffix: line.slice(third),
  };
}

function desiredUsageValue(typeId, questionId, responseId) {
  const selectedPurposes = new Set(selectedTypes.get(typeId));
  if (questionId.endsWith(':PSL_DATA_USAGE_COLLECTION_AND_SHARING')) {
    return responseId === 'PSL_DATA_USAGE_ONLY_COLLECTED' ? 'true' : '';
  }
  if (questionId.endsWith(':PSL_DATA_USAGE_EPHEMERAL')) {
    return typeId === 'PSL_IN_APP_SEARCH_HISTORY' ? 'true' : 'false';
  }
  if (questionId.endsWith(':DATA_USAGE_USER_CONTROL')) {
    return responseId === 'PSL_DATA_USAGE_USER_CONTROL_OPTIONAL' ? 'true' : '';
  }
  if (questionId.endsWith(':DATA_USAGE_COLLECTION_PURPOSE')) {
    return purposeIds.has(responseId) && selectedPurposes.has(responseId) ? 'true' : '';
  }
  if (questionId.endsWith(':DATA_USAGE_SHARING_PURPOSE')) return '';
  return '';
}

const outputLines = lines.map((line) => {
  const fields = parseMachineFields(line);
  if (!fields) return line;

  const { questionId, responseId, value, prefix, suffix } = fields;
  let desired = value;

  if (questionId.startsWith('PSL_DATA_TYPES_')) {
    if (selectedTypes.has(responseId)) {
      desired = 'true';
      seenTypeRows.add(responseId);
    } else if (removedTypes.has(responseId)) {
      desired = '';
      seenTypeRows.add(responseId);
    }
  }

  const usagePrefix = 'PSL_DATA_USAGE_RESPONSES:';
  if (questionId.startsWith(usagePrefix)) {
    const rest = questionId.slice(usagePrefix.length);
    const typeId = rest.slice(0, rest.indexOf(':'));
    if (selectedTypes.has(typeId)) {
      desired = desiredUsageValue(typeId, questionId, responseId);
      seenUsage.set(typeId, (seenUsage.get(typeId) ?? 0) + 1);
    } else if (removedTypes.has(typeId)) {
      desired = '';
    }
  }

  if (desired === value) return line;
  changed.push({ questionId, responseId, from: value, to: desired });
  return `${prefix}${desired}${suffix}`;
});

for (const typeId of [...selectedTypes.keys(), ...removedTypes]) {
  if (!seenTypeRows.has(typeId)) throw new Error(`Missing data-type row: ${typeId}`);
}
for (const typeId of selectedTypes.keys()) {
  if (!seenUsage.has(typeId)) throw new Error(`Missing usage block: ${typeId}`);
}

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, bom + outputLines.join(eol), 'utf8');

console.log(JSON.stringify({
  inputRows: lines.length - (lines.at(-1) === '' ? 1 : 0),
  changedCells: changed.length,
  selectedTypes: [...selectedTypes.keys()],
  removedTypes: [...removedTypes],
}, null, 2));
