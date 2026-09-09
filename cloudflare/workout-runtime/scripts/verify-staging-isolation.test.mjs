import assert from "node:assert/strict";
import test from "node:test";

import { stagingIsolationErrors } from "./verify-staging-isolation.mjs";

function configWith(stagingOverrides = {}) {
  return {
    name: "bil-workout-runtime",
    vars: {
      SUPABASE_URL: "https://production.supabase.co",
      SUPABASE_PUBLISHABLE_KEY: "production-key",
    },
    r2_buckets: [{ binding: "WORKOUTS", bucket_name: "workouts-production" }],
    env: {
      staging: {
        name: "bil-workout-runtime-staging",
        workers_dev: true,
        routes: [],
        vars: {
          SUPABASE_URL: "https://staging.supabase.co",
          SUPABASE_PUBLISHABLE_KEY: "staging-key",
        },
        r2_buckets: [
          { binding: "WORKOUTS", bucket_name: "workouts-staging" },
        ],
        ...stagingOverrides,
      },
    },
  };
}

test("accepts a staging Worker with isolated Supabase and R2 bindings", () => {
  assert.deepEqual(stagingIsolationErrors(configWith()), []);
});

test("rejects production Supabase and R2 resources in staging", () => {
  const errors = stagingIsolationErrors(
    configWith({
      vars: {
        SUPABASE_URL: "https://production.supabase.co",
        SUPABASE_PUBLISHABLE_KEY: "production-key",
      },
      r2_buckets: [
        { binding: "WORKOUTS", bucket_name: "workouts-production" },
      ],
    }),
  );

  assert.deepEqual(errors, [
    "staging SUPABASE_URL matches production",
    "staging SUPABASE_PUBLISHABLE_KEY matches production",
    "staging R2 bucket matches production: workouts-production",
  ]);
});

test("normalizes URLs and bucket names before comparing resources", () => {
  const errors = stagingIsolationErrors(
    configWith({
      vars: {
        SUPABASE_URL: "https://production.supabase.co/",
        SUPABASE_PUBLISHABLE_KEY: " production-key ",
      },
      r2_buckets: [
        { binding: "WORKOUTS", bucket_name: "WORKOUTS-PRODUCTION" },
      ],
    }),
  );

  assert.ok(errors.includes("staging SUPABASE_URL matches production"));
  assert.ok(
    errors.includes("staging SUPABASE_PUBLISHABLE_KEY matches production"),
  );
  assert.ok(
    errors.includes(
      "staging R2 bucket matches production: workouts-production",
    ),
  );
});

test("rejects missing or duplicate staging R2 bindings", () => {
  const errors = stagingIsolationErrors(
    configWith({
      r2_buckets: [
        { binding: "OTHER", bucket_name: "other-staging" },
        { binding: "OTHER", bucket_name: "other-staging-two" },
      ],
    }),
  );

  assert.ok(errors.includes("staging R2 binding is duplicated: OTHER"));
  assert.ok(errors.includes("staging R2 binding is missing: WORKOUTS"));
});

test("rejects staging custom-domain routes and placeholders", () => {
  const errors = stagingIsolationErrors(
    configWith({
      routes: [{ pattern: "staging.example.com", custom_domain: true }],
      vars: {
        SUPABASE_URL: "https://example.invalid",
        SUPABASE_PUBLISHABLE_KEY: "replace-me",
      },
      r2_buckets: [{ binding: "WORKOUTS", bucket_name: "<staging-bucket>" }],
    }),
  );

  assert.ok(errors.includes("staging must not have production/custom-domain routes"));
  assert.ok(errors.includes("staging SUPABASE_URL is a placeholder"));
  assert.ok(errors.includes("staging SUPABASE_PUBLISHABLE_KEY is a placeholder"));
  assert.ok(
    errors.includes("staging R2 bucket is a placeholder: <staging-bucket>"),
  );
});
