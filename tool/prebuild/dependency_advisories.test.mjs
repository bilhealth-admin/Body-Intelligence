import assert from "node:assert/strict";
import { test } from "node:test";
import { coordinates } from "./audit_locked_advisories.mjs";

test("Deno npm and CDN coordinates keep scoped names and pinned versions", () => {
  const result = coordinates(
    JSON.stringify({
      npm: { "@scope/package@2.3.4_peer@1": {} },
      remote: {
        "https://esm.sh/@scope/package@2.3.4/module.js": "digest",
        "https://esm.sh/other@1.2.3?target=denonext": "digest",
      },
    }),
    "npm",
  );
  assert.deepEqual(result, [{
    name: "@scope/package",
    version: "2.3.4",
    ecosystem: "npm",
  }, { name: "other", version: "1.2.3", ecosystem: "npm" }]);
});
test("Maven checks resolved, not evicted versions, and deduplicates coordinates", () => {
  assert.deepEqual(
    coordinates(
      "+--- a.b:lib:1.0 -> 2.0\n|  +--- a.b:lib:{prefer 1.0} -> 2.0 (*)\n\\--- a.b:lib:2.0 (*)\nBUILD SUCCESSFUL",
      "Maven",
    ),
    [{ name: "a.b:lib", version: "2.0", ecosystem: "Maven" }],
  );
});
test("incomplete, unpinned, unsupported or empty scans never pass", () => {
  for (
    const [source, kind] of [
      ["+--- a:b:1 FAILED\nBUILD SUCCESSFUL", "Maven"],
      ["+--- a:b:1", "Maven"],
      ["+--- a:b:1.+\nBUILD SUCCESSFUL", "Maven"],
      ["{}", "npm"],
      ["{}", "unknown"],
    ]
  ) assert.throws(() => coordinates(source, kind));
});
