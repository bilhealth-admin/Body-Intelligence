import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertGoogleExternalAccountBinding } from "./store_backend.ts";

const owner = "00000000-0000-4000-8000-000000000001";
const otherOwner = "00000000-0000-4000-8000-000000000002";
const expected = "a".repeat(64);

Deno.test("matching Google account and profile hashes permit first binding", () => {
  assertEquals(
    assertGoogleExternalAccountBinding(
      expected,
      expected,
      expected,
      null,
      owner,
    ),
    undefined,
  );
});

Deno.test("a mismatched Google account hash rejects first binding", () => {
  assertThrows(
    () =>
      assertGoogleExternalAccountBinding(
        expected,
        "b".repeat(64),
        expected,
        null,
        owner,
      ),
    Error,
    "purchase_owned_by_another_account",
  );
});

Deno.test("a mismatched Google profile hash rejects first binding", () => {
  assertThrows(
    () =>
      assertGoogleExternalAccountBinding(
        expected,
        expected,
        "b".repeat(64),
        null,
        owner,
      ),
    Error,
    "purchase_owned_by_another_account",
  );
});

Deno.test("legacy purchase without hashes is accepted only for its stored owner", () => {
  assertEquals(
    assertGoogleExternalAccountBinding(
      expected,
      undefined,
      undefined,
      owner,
      owner,
    ),
    undefined,
  );
  assertThrows(
    () =>
      assertGoogleExternalAccountBinding(
        expected,
        undefined,
        undefined,
        otherOwner,
        owner,
      ),
    Error,
    "purchase_owned_by_another_account",
  );
});

Deno.test("unbound purchase without Google hashes fails closed", () => {
  assertThrows(
    () =>
      assertGoogleExternalAccountBinding(
        expected,
        undefined,
        undefined,
        null,
        owner,
      ),
    Error,
    "google_account_binding_missing",
  );
});
