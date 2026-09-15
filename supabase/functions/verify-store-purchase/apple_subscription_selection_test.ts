import {
  appleServerApiFailureCode,
  selectAppleSubscriptionTransaction,
} from "./store_backend.ts";
import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test(
  "Apple subscription reconciliation selects the matching original transaction",
  () => {
    const expected = {
      originalTransactionId: "expected-original-transaction",
      signedTransactionInfo: "expected-jws",
      status: 1,
    };
    const selected = selectAppleSubscriptionTransaction(
      [
        {
          lastTransactions: [
            {
              originalTransactionId: "other-original-transaction",
              signedTransactionInfo: "other-jws",
              status: 2,
            },
          ],
        },
        { lastTransactions: [expected] },
      ],
      "expected-original-transaction",
    );

    assertEquals(selected, expected);
  },
);

Deno.test("Apple subscription reconciliation rejects absent or ambiguous rows", () => {
  const groups = [
    {
      lastTransactions: [
        {
          originalTransactionId: "transaction-a",
          signedTransactionInfo: "jws-a",
        },
        {
          originalTransactionId: "transaction-a",
          signedTransactionInfo: "jws-a-duplicate",
        },
      ],
    },
  ];

  assertThrows(
    () => selectAppleSubscriptionTransaction(groups, "transaction-missing"),
    Error,
    "apple_transaction_missing",
  );
  assertThrows(
    () => selectAppleSubscriptionTransaction(groups, "transaction-a"),
    Error,
    "apple_transaction_ambiguous",
  );
});

Deno.test("Apple API failures retain a safe actionable HTTP diagnostic", () => {
  assertEquals(appleServerApiFailureCode(401), "apple_server_api_401");
  assertEquals(appleServerApiFailureCode(404), "apple_server_api_404");
  assertEquals(appleServerApiFailureCode(429), "apple_server_api_429");
  assertEquals(appleServerApiFailureCode(0), "apple_server_api_failed");
});
