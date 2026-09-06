import thumbnailManifest from "../../../assets/catalogs/recipes/v1/recipe-thumbnails-v4.json";
import {
  recipeImageManifestSha256,
  recipeImageObjectsForContract,
} from "./recipe-images";

const deliveryPrefix = "/v4/recipes/thumbnails/";
const canonicalIdPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const digestPattern = /^[0-9a-f]{64}$/;
const maximumThumbnailBytes = 512 * 1024;

export const recipeThumbnailManifestSha256 =
  "24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029";

export interface RecipeThumbnailObject {
  readonly access: "public-preview";
  readonly canonicalId: string;
  readonly height: number;
  readonly mimeType: "image/webp";
  readonly objectKey: string;
  readonly sha256: string;
  readonly sizeBytes: number;
  readonly sourceSha256: string;
  readonly width: number;
}

const objects = buildRecipeThumbnailObjects(thumbnailManifest);
const objectsByCanonicalId = new Map(
  objects.map((object) => [object.canonicalId, object] as const),
);

export const recipeThumbnailObjectCount = objects.length;

export function recipeThumbnailObjectsForContract(): readonly RecipeThumbnailObject[] {
  return objects;
}

export function recipeThumbnailDeliveryPath(
  object: RecipeThumbnailObject,
): string {
  return `${deliveryPrefix}${object.canonicalId}/${object.sha256}.webp`;
}

export function resolveRecipeThumbnail(
  pathname: string,
): RecipeThumbnailObject | null {
  if (!pathname.startsWith(deliveryPrefix) || pathname.includes("%")) {
    return null;
  }
  const parts = pathname.slice(deliveryPrefix.length).split("/");
  const canonicalId = parts[0];
  const filename = parts[1];
  if (
    parts.length !== 2 ||
    canonicalId === undefined ||
    filename === undefined ||
    !canonicalIdPattern.test(canonicalId)
  ) {
    return null;
  }
  const match = /^([0-9a-f]{64})\.webp$/.exec(filename);
  if (match === null) return null;
  const digest = match[1];
  if (digest === undefined) return null;
  const object = objectsByCanonicalId.get(canonicalId);
  return object?.sha256 === digest ? object : null;
}

function buildRecipeThumbnailObjects(raw: unknown): readonly RecipeThumbnailObject[] {
  if (
    !isRecord(raw) ||
    !hasExactKeys(raw, [
      "entries",
      "record_count",
      "schema_version",
      "source_image_manifest_sha256",
      "total_size_bytes",
      "transformation",
    ]) ||
    raw.schema_version !== 4 ||
    raw.record_count !== 1500 ||
    raw.source_image_manifest_sha256 !== recipeImageManifestSha256 ||
    !positiveInteger(raw.total_size_bytes, 512 * 1024 * 1500) ||
    !isRecord(raw.transformation) ||
    !hasExactKeys(raw.transformation, [
      "codec",
      "fit",
      "max_height",
      "max_width",
      "method",
      "quality",
      "resampling",
      "version",
    ]) ||
    raw.transformation.codec !== "libwebp" ||
    raw.transformation.fit !== "contain-no-upscale" ||
    raw.transformation.max_height !== 512 ||
    raw.transformation.max_width !== 512 ||
    raw.transformation.method !== 6 ||
    raw.transformation.quality !== 78 ||
    raw.transformation.resampling !== "lanczos" ||
    raw.transformation.version !== 1 ||
    !Array.isArray(raw.entries) ||
    raw.entries.length !== 1500
  ) {
    throw new Error("recipe_thumbnail_manifest_invalid");
  }

  const sourceByCanonicalId = new Map(
    recipeImageObjectsForContract().map((object) => [object.canonicalId, object] as const),
  );
  const ids = new Set<string>();
  const keys = new Set<string>();
  const result: RecipeThumbnailObject[] = [];
  let totalSizeBytes = 0;
  for (const entry of raw.entries) {
    if (
      !isRecord(entry) ||
      !hasExactKeys(entry, [
        "canonical_id",
        "delivery_path",
        "height",
        "mime_type",
        "object_path",
        "sha256",
        "size_bytes",
        "source_sha256",
        "width",
      ]) ||
      typeof entry.canonical_id !== "string" ||
      !canonicalIdPattern.test(entry.canonical_id) ||
      typeof entry.sha256 !== "string" ||
      !digestPattern.test(entry.sha256) ||
      typeof entry.source_sha256 !== "string" ||
      !digestPattern.test(entry.source_sha256) ||
      entry.mime_type !== "image/webp" ||
      !positiveInteger(entry.size_bytes, maximumThumbnailBytes) ||
      !positiveInteger(entry.width, 512) ||
      !positiveInteger(entry.height, 512)
    ) {
      throw new Error("recipe_thumbnail_entry_invalid");
    }
    const source = sourceByCanonicalId.get(entry.canonical_id);
    if (
      source === undefined ||
      source.sha256 !== entry.source_sha256 ||
      entry.object_path !==
        `recipes/v4/thumbnails/512/${entry.canonical_id}-${entry.sha256}.webp` ||
      entry.delivery_path !==
        `${deliveryPrefix}${entry.canonical_id}/${entry.sha256}.webp` ||
      !ids.add(entry.canonical_id) ||
      !keys.add(entry.object_path)
    ) {
      throw new Error("recipe_thumbnail_allowlist_not_canonical");
    }
    totalSizeBytes += entry.size_bytes;
    result.push(
      Object.freeze({
        access: "public-preview" as const,
        canonicalId: entry.canonical_id,
        height: entry.height,
        mimeType: entry.mime_type,
        objectKey: entry.object_path,
        sha256: entry.sha256,
        sizeBytes: entry.size_bytes,
        sourceSha256: entry.source_sha256,
        width: entry.width,
      }),
    );
  }
  if (
    ids.size !== 1500 ||
    keys.size !== 1500 ||
    totalSizeBytes !== raw.total_size_bytes
  ) {
    throw new Error("recipe_thumbnail_allowlist_count_invalid");
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
