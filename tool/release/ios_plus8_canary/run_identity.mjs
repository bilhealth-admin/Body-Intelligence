import { requiredEnv } from './runtime.mjs';

function numericRunPart(name) {
  const value = requiredEnv(name).replaceAll(/[^0-9]/g, '');
  if (!value) throw new Error(`invalid_github_run_identity:${name}`);
  return value;
}

export function runKey() {
  return `${numericRunPart('GITHUB_RUN_ID')}-${numericRunPart('GITHUB_RUN_ATTEMPT')}`;
}

export function reviewerRunMarkers() {
  const key = runKey();
  return {
    reviewerMessage: `BIL QA reviewer ${key}`,
    ownerMessage: `BIL QA owner ${key}`,
    rejectedPost: `BIL QA rejected ${key}`,
  };
}

export function disposableRunEmail() {
  return `ios-plus8-canary+${runKey()}@bilhealth.com`;
}
