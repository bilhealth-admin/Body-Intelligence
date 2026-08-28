import releaseManifest from "../../../assets/catalogs/recipes/v1/release-manifest.json";
import sourceManifest from "../../../assets/catalogs/recipes/v1/recipe-images.json";

const deliveryPrefix = "/v3/recipes/images/";
const canonicalIdPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const digestPattern = /^[0-9a-f]{64}$/;
const maximumImageBytes = 8 * 1024 * 1024;

export const recipeImageManifestSha256 =
  "e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3";

export interface RecipeImageObject {
  readonly access: "public-preview";
  readonly canonicalId: string;
  readonly height: number;
  readonly mimeType: "image/jpeg" | "image/png";
  readonly objectKey: string;
  readonly sha256: string;
  readonly sizeBytes: number;
  readonly width: number;
}

const objects = buildRecipeImageObjects(sourceManifest, releaseManifest);
const objectsByCanonicalId = new Map(
  objects.map((object) => [object.canonicalId, object] as const),
);

export const recipeImageObjectCount = objects.length;

export function recipeImageObjectsForContract(): readonly RecipeImageObject[] {
  return objects;
}

export function recipeImageDeliveryPath(object: RecipeImageObject): string {
  return `${deliveryPrefix}${object.canonicalId}/${object.sha256}`;
}

export function resolveRecipeImage(
  pathname: string,
): RecipeImageObject | null {
  if (!pathname.startsWith(deliveryPrefix) || pathname.includes("%")) {
    return null;
  }
  const parts = pathname.slice(deliveryPrefix.length).split("/");
  const canonicalId = parts[0];
  const digest = parts[1];
  if (
    parts.length !== 2 ||
    canonicalId === undefined ||
    digest === undefined ||
    !canonicalIdPattern.test(canonicalId) ||
    !digestPattern.test(digest)
  ) {
    return null;
  }
  const object = objectsByCanonicalId.get(canonicalId);
  return object?.sha256 === digest ? object : null;
}

function buildRecipeImageObjects(
  rawSource: unknown,
  rawRelease: unknown,
): readonly RecipeImageObject[] {
  if (
    !isRecord(rawRelease) ||
    rawRelease.image_manifest_sha256 !== recipeImageManifestSha256 ||
    rawRelease.image_manifest_path !==
      "assets/catalogs/recipes/v1/recipe-images.json"
  ) {
    throw new Error("recipe_image_release_pin_invalid");
  }
  if (
    !isRecord(rawSource) ||
    !hasExactKeys(rawSource, [
      "entries",
      "excluded_source_files",
      "external_candidate_count",
      "placeholder_count",
      "record_count",
      "schema_version",
    ]) ||
    rawSource.schema_version !== 1 ||
    rawSource.record_count !== 1500 ||
    rawSource.external_candidate_count !== 1500 ||
    rawSource.placeholder_count !== 0 ||
    !Array.isArray(rawSource.entries) ||
    rawSource.entries.length !== 1500
  ) {
    throw new Error("recipe_image_manifest_invalid");
  }

  const ids = new Set<string>();
  const keys = new Set<string>();
  const digests = new Set<string>();
  const result: RecipeImageObject[] = [];
  for (const entry of rawSource.entries) {
    if (
      !isRecord(entry) ||
      !hasExactKeys(entry, [
        "canonical_id",
        "height",
        "mime_type",
        "object_path",
        "review_status",
        "sha256",
        "size_bytes",
        "status",
        "width",
      ]) ||
      typeof entry.canonical_id !== "string" ||
      !canonicalIdPattern.test(entry.canonical_id) ||
      typeof entry.object_path !== "string" ||
      typeof entry.sha256 !== "string" ||
      !digestPattern.test(entry.sha256) ||
      (entry.mime_type !== "image/jpeg" && entry.mime_type !== "image/png") ||
      !positiveInteger(entry.size_bytes, maximumImageBytes) ||
      !positiveInteger(entry.width, 8192) ||
      !positiveInteger(entry.height, 8192) ||
      entry.status !== "external_candidate" ||
      entry.review_status !== "review_evidence_unbound"
    ) {
      throw new Error("recipe_image_entry_invalid");
    }
    const extension = entry.mime_type === "image/png" ? ".png" : ".jpg";
    if (
      entry.object_path !==
        `recipes/v1/images/${entry.canonical_id}${extension}` ||
      !ids.add(entry.canonical_id) ||
      !keys.add(entry.object_path) ||
      !digests.add(entry.sha256)
    ) {
      throw new Error("recipe_image_allowlist_not_canonical");
    }
    result.push(
      Object.freeze({
        access: "public-preview" as const,
        canonicalId: entry.canonical_id,
        height: entry.height,
        mimeType: entry.mime_type,
        objectKey: entry.object_path,
        sha256: entry.sha256,
        sizeBytes: entry.size_bytes,
        width: entry.width,
      }),
    );
  }
  if (ids.size !== 1500 || keys.size !== 1500 || digests.size !== 1500) {
    throw new Error("recipe_image_allowlist_count_invalid");
  }
  return Object.freeze(result);
}

function hasExactKeys(
  value: Readonly<Record<string, unknown>>,
  expected: readonly string[],
): boolean {
  const actual = Object.keys(value).sort();
  const canonicalExpected = [...expected].sort();
  return (
    actual.length === canonicalExpected.length &&
    actual.every((key, index) => key === canonicalExpected[index])
  );
}

function positiveInteger(value: unknown, maximum: number): value is number {
  return Number.isSafeInteger(value) && Number(value) > 0 && Number(value) <= maximum;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
