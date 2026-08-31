import assert from "node:assert/strict";
import { test } from "node:test";

import {
  BIL_USER_STORAGE_BUCKETS,
  type BilStorageBucket,
  deleteBilUserStorage,
  listBilUserObjectPaths,
} from "./account_deletion_storage.ts";

const owner = "9b7df898-7450-4a6e-8cef-fdd9fa487785";

class FakeBucket implements BilStorageBucket {
  constructor(
    private readonly objects: Set<string>,
    private readonly removeFails = false,
    private readonly retainAfterRemove = false,
  ) {}

  async list(path: string, options: { limit: number; offset: number }) {
    const prefix = `${path}/`;
    const children = new Map<string, boolean>();
    for (const object of this.objects) {
      if (!object.startsWith(prefix)) continue;
      const remainder = object.substring(prefix.length);
      const slash = remainder.indexOf("/");
      const name = slash < 0 ? remainder : remainder.substring(0, slash);
      children.set(name, slash < 0);
    }
    const entries = [...children.entries()]
      .sort(([left], [right]) => left.localeCompare(right))
      .slice(options.offset, options.offset + options.limit)
      .map(([name, file]) => ({
        name,
        id: file ? `id:${name}` : null,
        metadata: file ? { size: 1 } : null,
      }));
    return { data: entries, error: null };
  }

  async remove(paths: string[]) {
    if (this.removeFails) {
      return { data: null, error: { message: "simulated" } };
    }
    if (!this.retainAfterRemove) {
      for (const path of paths) this.objects.delete(path);
    }
    return { data: paths, error: null };
  }
}

test("recursively removes every owned object from every BIL bucket", async () => {
  const avatarObjects = new Set([`${owner}/avatar.webp`]);
  const communityObjects = new Set([
    `${owner}/post-a/image-a.webp`,
    `${owner}/post-b/deeper/image-b.jpg`,
    "someone-else/post/image.png",
  ]);
  const buckets = new Map<string, FakeBucket>([
    ["profile-avatars", new FakeBucket(avatarObjects)],
    ["community-post-images", new FakeBucket(communityObjects)],
  ]);

  const removed = await deleteBilUserStorage({
    from: (bucket) => buckets.get(bucket)!,
  }, owner);

  assert.equal(removed, 3);
  assert.deepEqual([...avatarObjects], []);
  assert.deepEqual([...communityObjects], ["someone-else/post/image.png"]);
  assert.deepEqual(BIL_USER_STORAGE_BUCKETS, [
    "profile-avatars",
    "community-post-images",
  ]);
});

test("storage API removal error fails closed", async () => {
  const bucket = new FakeBucket(new Set([`${owner}/avatar.webp`]), true);
  await assert.rejects(
    () => deleteBilUserStorage({ from: () => bucket }, owner, ["avatars"]),
    /storage_remove_failed/,
  );
});

test("post-delete verification rejects a lingering object", async () => {
  const bucket = new FakeBucket(
    new Set([`${owner}/avatar.webp`]),
    false,
    true,
  );
  await assert.rejects(
    () => deleteBilUserStorage({ from: () => bucket }, owner, ["avatars"]),
    /storage_cleanup_incomplete/,
  );
});

test("unsafe child names are rejected before deletion", async () => {
  const bucket: BilStorageBucket = {
    list: async () => ({
      data: [{ name: "../someone-else", id: "bad", metadata: {} }],
      error: null,
    }),
    remove: async () => ({ data: null, error: null }),
  };
  await assert.rejects(
    () => listBilUserObjectPaths(bucket, owner),
    /unsafe_storage_object_name/,
  );
});
