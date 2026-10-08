export const BIL_USER_STORAGE_BUCKETS = [
  "profile-avatars",
  "community-post-images",
] as const;

const PAGE_SIZE = 1000;
const MAX_OBJECTS_PER_ACCOUNT = 200000;

type StorageError = { message?: string } | null;

export type BilStorageListEntry = {
  id?: string | null;
  name: string;
  metadata?: unknown;
};

export type BilStorageBucket = {
  list: (
    path: string,
    options: {
      limit: number;
      offset: number;
      sortBy: { column: string; order: "asc" };
    },
  ) => Promise<{ data: BilStorageListEntry[] | null; error: StorageError }>;
  remove: (
    paths: string[],
  ) => Promise<{ data: unknown; error: StorageError }>;
};

export type BilStorageClient = {
  from: (bucket: string) => BilStorageBucket;
};

function safeChildName(name: string) {
  const value = name.trim();
  if (
    value.length === 0 ||
    value === "." ||
    value === ".." ||
    value.includes("/") ||
    value.includes("\\")
  ) {
    throw new Error("unsafe_storage_object_name");
  }
  return value;
}

function isFile(entry: BilStorageListEntry) {
  return Boolean(entry.id) || entry.metadata != null;
}

export async function listBilUserObjectPaths(
  bucket: BilStorageBucket,
  userId: string,
) {
  const pendingPrefixes = [userId];
  const visitedPrefixes = new Set<string>();
  const paths: string[] = [];

  while (pendingPrefixes.length > 0) {
    const prefix = pendingPrefixes.shift()!;
    if (visitedPrefixes.has(prefix)) continue;
    visitedPrefixes.add(prefix);

    for (let offset = 0;; offset += PAGE_SIZE) {
      const { data, error } = await bucket.list(prefix, {
        limit: PAGE_SIZE,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) throw new Error("storage_list_failed");
      const entries = data ?? [];
      for (const entry of entries) {
        const path = `${prefix}/${safeChildName(entry.name)}`;
        if (isFile(entry)) {
          paths.push(path);
          if (paths.length > MAX_OBJECTS_PER_ACCOUNT) {
            throw new Error("storage_object_limit_exceeded");
          }
        } else {
          pendingPrefixes.push(path);
        }
      }
      if (entries.length < PAGE_SIZE) break;
    }
  }

  return paths;
}

export async function deleteBilUserStorage(
  storage: BilStorageClient,
  userId: string,
  buckets: readonly string[] = BIL_USER_STORAGE_BUCKETS,
) {
  let removed = 0;
  for (const bucketName of buckets) {
    const bucket = storage.from(bucketName);
    const paths = await listBilUserObjectPaths(bucket, userId);
    for (let offset = 0; offset < paths.length; offset += PAGE_SIZE) {
      const chunk = paths.slice(offset, offset + PAGE_SIZE);
      const { error } = await bucket.remove(chunk);
      if (error) throw new Error("storage_remove_failed");
      removed += chunk.length;
    }

    // Fail closed: Auth deletion is forbidden until the Storage API confirms
    // that the user's prefix is empty in every BIL-owned bucket.
    const remaining = await listBilUserObjectPaths(bucket, userId);
    if (remaining.length > 0) throw new Error("storage_cleanup_incomplete");
  }
  return removed;
}
