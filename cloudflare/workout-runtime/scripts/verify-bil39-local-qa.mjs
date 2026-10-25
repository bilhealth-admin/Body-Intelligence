import { readFile } from "node:fs/promises";
import { stagingIsolationErrors } from "./verify-staging-isolation.mjs";

const production = JSON.parse(await readFile(new URL("../wrangler.jsonc", import.meta.url), "utf8"));
const fixture = JSON.parse(await readFile(new URL("../wrangler.bil39-qa.jsonc", import.meta.url), "utf8"));
const errors = [
  ...stagingIsolationErrors(fixture),
  ...stagingIsolationErrors({ ...production, env: fixture.env }),
];
for (const environment of [fixture, fixture.env.staging]) {
  if (!environment.name.startsWith("bil39-local-") || environment.routes.length !== 0) {
    errors.push("local QA cannot name or route a production Worker");
  }
  if (!new URL(environment.vars.SUPABASE_URL).hostname.endsWith(".invalid")) {
    errors.push("local QA Auth must be a non-routable synthetic host");
  }
  if (environment.r2_buckets.some((bucket) => bucket.remote === true)) {
    errors.push("local QA cannot enable remote R2 bindings");
  }
}
if (errors.length) throw new Error(errors.join("\n"));
console.log("BIL39 local Worker bindings isolated from production; no deployment.");
