import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { googlePlayServiceAccountJson } from "./store_backend.ts";

function reader(values: Record<string, string>) {
  return (name: string) => values[name] ?? "";
}

Deno.test("dedicated Play Billing credential remains authoritative", () => {
  assertEquals(
    googlePlayServiceAccountJson(
      reader({
        GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: "dedicated-json",
        BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON: "integrity-json",
      }),
    ),
    "dedicated-json",
  );
});

Deno.test("Play Integrity credential is a safe fallback when billing is absent", () => {
  assertEquals(
    googlePlayServiceAccountJson(
      reader({
        GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: "   ",
        BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON: "integrity-json",
      }),
    ),
    "integrity-json",
  );
});

Deno.test("missing Google credentials fail closed", () => {
  assertThrows(
    () => googlePlayServiceAccountJson(reader({})),
    Error,
    "google_credentials_missing",
  );
});
