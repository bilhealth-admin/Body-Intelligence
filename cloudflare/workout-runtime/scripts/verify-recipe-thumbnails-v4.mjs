import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const expectedManifestSha256 =
  "24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029";
const base = new URL(process.argv[2] ?? "");
if (base.protocol !== "https:" || base.pathname !== "/" || base.search || base.hash) {
  throw new Error("Pass one exact HTTPS origin ending in '/'.");
}

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const manifestPath = path.resolve(
  scriptDirectory,
  "../../../assets/catalogs/recipes/v1/recipe-thumbnails-v4.json",
);
const manifestBytes = await readFile(manifestPath);
const manifestSha256 = createHash("sha256").update(manifestBytes).digest("hex");
if (manifestSha256 !== expectedManifestSha256 || manifestBytes.length !== 899684) {
  throw new Error("Local thumbnail manifest bytes differ from the reviewed release.");
}
const manifest = JSON.parse(manifestBytes.toString("utf8"));
if (manifest.schema_version !== 4 || manifest.entries?.length !== 1500) {
  throw new Error("Local thumbnail manifest contract is incomplete.");
}

const failures = [];
let cursor = 0;
const workers = Array.from({ length: 16 }, async () => {
  while (true) {
    const index = cursor++;
    if (index >= manifest.entries.length) return;
    const entry = manifest.entries[index];
    const url = new URL(entry.delivery_path, base);
    try {
      const response = await fetch(url, { method: "HEAD" });
      const valid =
        response.status === 200 &&
        response.headers.get("content-type") === "image/webp" &&
        response.headers.get("content-length") === String(entry.size_bytes) &&
        response.headers.get("x-bil-content-sha256") === entry.sha256 &&
        response.headers.get("cache-control") ===
          "public, max-age=31536000, immutable";
      if (!valid) {
        failures.push({
          id: entry.canonical_id,
          status: response.status,
          contentType: response.headers.get("content-type"),
          contentLength: response.headers.get("content-length"),
          sha256: response.headers.get("x-bil-content-sha256"),
        });
      }
    } catch (error) {
      failures.push({ id: entry.canonical_id, error: error?.name ?? "Error" });
    }
  }
});
await Promise.all(workers);
if (failures.length > 0) {
  console.error(JSON.stringify(failures.slice(0, 10), null, 2));
  throw new Error(`Remote thumbnail HEAD audit failed: ${failures.length}/1500`);
}

for (const index of [0, 749, 1499]) {
  const entry = manifest.entries[index];
  const response = await fetch(new URL(entry.delivery_path, base), {
    headers: { authorization: "Bearer deliberately-not-consumed" },
  });
  const bytes = new Uint8Array(await response.arrayBuffer());
  const sha256 = createHash("sha256").update(bytes).digest("hex");
  if (
    response.status !== 200 ||
    bytes.length !== entry.size_bytes ||
    sha256 !== entry.sha256
  ) {
    throw new Error(`Remote thumbnail byte audit failed: ${entry.canonical_id}`);
  }
}

console.log(
  `RECIPE_THUMBNAILS_V4_REMOTE verified=1500 byteReadbacks=3 manifestSha256=${manifestSha256} origin=${base.origin}`,
);
