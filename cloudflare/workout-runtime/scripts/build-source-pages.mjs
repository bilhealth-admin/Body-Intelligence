import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const root = new URL("../../../artifacts/workout_media/cloudflare_runtime_v2/", import.meta.url);
const allowlist = JSON.parse(await readFile(new URL("protected_object_keys_v2.json", root), "utf8"));
const videoKeys = new Set(allowlist.keys.filter((key) => key.endsWith(".mp4")));
const entries = {};
const sources = [];
for (const name of ["bil-workouts-home-v1-v1.json", "bil-workouts-gym-six-month-v1-v1.json"]) {
  const bytes = await readFile(new URL(`packs/${name}`, root));
  sources.push({ name, sha256: createHash("sha256").update(bytes).digest("hex") });
  const pack = JSON.parse(bytes.toString("utf8"));
  for (const item of pack.items) {
    const url = new URL(item.source_url);
    const key = url.pathname.replace(/^\/v2\/objects\//u, "");
    if (url.origin !== "https://workouts.bilhealth.com" || url.search || url.hash ||
      !url.pathname.startsWith("/v2/objects/") || !videoKeys.has(key) || entries[key] ||
      item.media?.video?.url !== item.source_url || item.verified !== true ||
      item.license_url !== "https://www.bilhealth.com/terms" ||
      typeof item.title !== "string" || item.title.length < 1 || item.title.length > 160 ||
      typeof item.publisher !== "string" || item.publisher.length > 100 ||
      typeof item.synthetic_performer !== "boolean") {
      throw new Error(`Unverified source-page metadata: ${item.id}`);
    }
    entries[key] = { title: item.title, publisher: item.publisher,
      syntheticPerformer: item.synthetic_performer, termsUrl: item.license_url };
  }
}
if (Object.keys(entries).length !== videoKeys.size) throw new Error("Source metadata coverage mismatch");
const output = JSON.stringify({ schema: "bil.workout-source-information.v1", sources,
  entries: Object.fromEntries(Object.entries(entries).sort(([a], [b]) => a.localeCompare(b, "en"))) }, null, 2) + "\n";
const target = new URL("workout_source_pages_v1.json", root);
if (process.argv.includes("--check")) {
  if (await readFile(target, "utf8") !== output) throw new Error("Source-page metadata is stale");
} else {
  await writeFile(target, output);
}
console.log(`Verified ${videoKeys.size} metadata-only source pages: ${fileURLToPath(target)}`);
