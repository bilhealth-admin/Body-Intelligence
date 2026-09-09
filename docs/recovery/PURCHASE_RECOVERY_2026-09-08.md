# Purchase recovery — 8 September 2026

## Scope

This review covered only the in-app route from a selected paid plan to the
`Continue` checkout action. It did not change production data, invoke a store,
submit a build, restore a receipt, or grant an entitlement.

## Finding and root cause

`BilStorePlansPage` had already been updated to pass truthful purchase state
(`purchaseInProgress`, `purchaseEnabled`, and purchase feedback) into
`BilDynamicStoreOffers`, but that widget did not declare or consume those
inputs. This was both a compile-time mismatch and a user-visible broken
boundary: the Continue CTA did not visibly enter a pending state, did not
explain a verification failure, and did not explicitly disable a second tap
while the native sheet or server verification was in progress.

The existing purchase service remains deliberately fail-closed:

- It requires a signed-in user, a configured store, and an eligible loaded
  product before it can call the native billing API.
- It sends subscriptions through `buyNonConsumable` and Boost through
  `buyConsumable(autoConsume: false)`.
- A local store callback does not unlock access. The service waits for
  `verify-store-purchase` and then refreshes the server-owned entitlement.
- Failed, unavailable, cancelled, and verification-failed paths grant no
  entitlement.

## Safe repair

The UI now accepts and renders the existing purchase state:

- Continue dispatches only the currently selected `BilStoreOfferMetadata`.
- The CTA is disabled and shows progress while a purchase handoff is active.
- A live, accessible status line reports pending, verified, or no-access
  failure truthfully; five primary locales have copy and remaining locales use
  the existing English fallback.
- A store-owned `canStartPurchase` gate controls whether a loaded offer may be
  tapped; the presentation layer does not infer availability.
- The in-flight guard remains in both page and verified purchase service, so
  repeat taps cannot start a second native request.

Changed files:

- `lib/features/commerce/presentation/bil_store_plans_page.dart`
- `lib/features/commerce/presentation/bil_dynamic_store_offers.dart`
- `lib/features/commerce/presentation/bil_dynamic_store_components.dart`
- `lib/features/commerce/presentation/bil_store_copy.dart`
- `test/features/commerce/bil_store_plans_dynamic_contract_test.dart`

## Verification

The focused Flutter command completed successfully on the host:

```text
flutter test --no-pub \
  test/features/commerce/bil_dynamic_store_offers_test.dart \
  test/features/commerce/bil_store_plans_dynamic_contract_test.dart \
  test/features/commerce/commerce_paywall_widget_test.dart \
  test/features/commerce/paywall_controller_test.dart \
  test/features/commerce/store_provider_boundaries_regression_test.dart

26 tests passed.
```

The new regression, `Continue dispatches exactly one selected store offer`,
asserts that Continue sends the selected offer once, announces progress, and
is unavailable until the request settles. Existing focused checks retain
catalog fail-closed behavior, restore UI, price presentation, trial policy,
and purchase-boundary contracts.

## Real E2E boundary still required

No Windows-source or widget test can prove a native StoreKit or Google Play
transaction. Release readiness still requires recorded device evidence for:

1. iOS signed build on a real device with an App Store Sandbox tester:
   purchase, cancel, pending, restore, StoreKit transaction completion, and
   server receipt verification.
2. Android signed AAB in Play Internal Testing on a real Play-enabled device:
   purchase, cancel, pending/deferred state, acknowledgement/consumption,
   Restore/query-past-purchases, Real-time Developer Notification delivery,
   and idempotent server verification.
3. A verified entitlement refresh after each successful server response, plus
   evidence that invalid receipts and unavailable integrity/verification do
   not unlock any paid feature.

Until that evidence exists, the app must not be described as store-release
ready. No production purchase, receipt, entitlement, subscription, or
customer record was changed by this recovery item.
