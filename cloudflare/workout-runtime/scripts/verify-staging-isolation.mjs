import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

function nonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function looksPlaceholder(value) {
  return /(?:<[^>]+>|example\.|todo|replace[_ -]?me)/i.test(value);
}

function normalizedValue(value) {
  return nonEmptyString(value) ? value.trim() : "";
}

function normalizedUrl(value) {
  try {
    const url = new URL(normalizedValue(value));
    return `${url.protocol}//${url.host}${url.pathname.replace(/\/+$/, "")}`;
  } catch {
    return normalizedValue(value);
  }
}

function bucketBindings(environment) {
  const bindings = new Map();
  const duplicates = [];
  for (const entry of environment?.r2_buckets ?? []) {
    if (!nonEmptyString(entry?.binding) || !nonEmptyString(entry?.bucket_name)) {
      continue;
    }
    const binding = entry.binding.trim();
    const bucket = entry.bucket_name.trim().toLowerCase();
    if (bindings.has(binding)) {
      duplicates.push(binding);
    } else {
      bindings.set(binding, bucket);
    }
  }
  return { bindings, duplicates };
}

export function stagingIsolationErrors(config) {
  const errors = [];
  const staging = config?.env?.staging;
  if (staging == null || typeof staging !== "object") {
    return ["env.staging is missing"];
  }

  if (!nonEmptyString(config.name) || !nonEmptyString(staging.name)) {
    errors.push("production and staging Worker names must be explicit");
  } else if (config.name === staging.name) {
    errors.push("staging Worker name matches production");
  }

  if (staging.workers_dev !== true) {
    errors.push("staging must use workers_dev=true");
  }
  if (!Array.isArray(staging.routes) || staging.routes.length !== 0) {
    errors.push("staging must not have production/custom-domain routes");
  }

  for (const key of ["SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY"]) {
    const productionValue = config?.vars?.[key];
    const stagingValue = staging?.vars?.[key];
    if (!nonEmptyString(stagingValue)) {
      errors.push(`staging ${key} is missing`);
    } else if (looksPlaceholder(stagingValue)) {
      errors.push(`staging ${key} is a placeholder`);
    } else if (
      (key === "SUPABASE_URL"
        ? normalizedUrl(stagingValue) === normalizedUrl(productionValue)
        : normalizedValue(stagingValue) === normalizedValue(productionValue))
    ) {
      errors.push(`staging ${key} matches production`);
    }
  }

  const productionBuckets = bucketBindings(config);
  const stagingBuckets = bucketBindings(staging);
  if (stagingBuckets.bindings.size === 0) {
    errors.push("staging R2 bucket bindings are missing");
  }
  for (const duplicate of stagingBuckets.duplicates) {
    errors.push(`staging R2 binding is duplicated: ${duplicate}`);
  }
  for (const [binding, productionBucket] of productionBuckets.bindings) {
    if (!stagingBuckets.bindings.has(binding)) {
      errors.push(`staging R2 binding is missing: ${binding}`);
      continue;
    }
    const bucket = stagingBuckets.bindings.get(binding);
    if (looksPlaceholder(bucket)) {
      errors.push(`staging R2 bucket is a placeholder: ${bucket}`);
    }
    if (bucket === productionBucket) {
      errors.push(`staging R2 bucket matches production: ${bucket}`);
    }
  }

  return errors;
}

export async function verifyStagingIsolation(configPath) {
  let config;
  try {
    config = JSON.parse(await readFile(configPath, "utf8"));
  } catch (error) {
    throw new Error(
      `Cannot parse ${configPath}; keep the deployment config valid strict JSON so the safety guard can inspect it`,
      { cause: error },
    );
  }

  const errors = stagingIsolationErrors(config);
  if (errors.length > 0) {
    throw new Error(
      `Staging deployment blocked because it is not isolated:\n- ${errors.join("\n- ")}`,
    );
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const configPath = process.argv[2] ?? new URL("../wrangler.jsonc", import.meta.url);
  try {
    await verifyStagingIsolation(configPath);
    console.log("Cloudflare staging isolation verified.");
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
