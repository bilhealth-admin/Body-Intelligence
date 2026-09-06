# BIL Apple +8 store gate audit — 2026-09-05

This addendum records a read-only code/signing audit plus narrowly scoped live
App Store Connect preparation. It supersedes older observations about release
mode, product state, and empty review-contact fields. It contains no private
key material, reviewer credentials, or owner contact values.

The final same-day authenticated read-back also supersedes the earlier
deployment caveats lower in this dated audit: the Apple token-custody migration
and its two follow-up fixes are remote/live; `apple-sign-in-token` and
`apple-sign-in-notifications` are both `ACTIVE` v2; Apple's server-to-server
notification registration is configured; `app-attest` is `ACTIVE` v2 with JWT
verification; the production/build-8 configuration and active distribution
profile pass; and the three App Store Connect GitHub bindings were updated and
read back successfully. The same-day subscription-availability correction also
now reads back ordinary Premium in exactly EGY/NGA/PAK/TUR and AI Premium in
the other 168 launch markets, including IND and excluding NGA. Enforcement
intentionally remains off until a signed build-8 canary. These facts close
deployment/configuration gates only, not the signed iPhone/iPad lifecycle tests.

## Non-negotiable release boundary

- Build `+8` has not been uploaded to App Store Connect or TestFlight.
- Build `+7` remains the latest uploaded build and must not be submitted or
  released as the repaired candidate.
- No IPA was built or uploaded during this audit, and the version was not added
  to App Review.
- The release must remain blocked until the clean unified `+8` commit is signed,
  its embedded entitlements and provisioning profile pass the workflow gates,
  and the signed-device matrix is completed.

## Live App Store Connect state

Observed through the official App Store Connect API on 2026-09-05:

- App version `1.0.0` is in `DEVELOPER_REJECTED`, representing the developer's
  withdrawal of the earlier candidate rather than an Apple review rejection.
- The selected uploaded build is `+7`; uploads `+5`, `+6`, and `+7` exist. There
  is no `+8` build.
- The version's release mode was safely changed from `AFTER_APPROVAL` to
  `MANUAL`, then read back as `MANUAL`. No review or upload action accompanied
  this change. Under Apple's manual-release model, an approved version waits in
  Pending Developer Release until the owner releases it.
- App Review contact first name, last name, phone, and email are present.
  Sign-in is marked required, and demo username, password, and review notes are
  present. Their values were deliberately not copied into this report.
- A fresh private reviewer credential was actually authenticated against the
  production identity service, then saved/read back in both stores. Live
  boolean checks prove one active confirmed identity, Premium + AI entitlement,
  at least 2,500 usable tokens, a 12-month review grant, and denial of both
  administrator and moderator roles. The exact signed `+8` app session remains
  a separate device gate.
- The subscription group contains the four intended products
  (`bil_premium`, `bil_premium_annual`, `bil_premium_ai_coach`, and
  `bil_premium_ai_coach_annual`), all currently `READY_TO_SUBMIT`.
- The consumable `bil_ai_boost` is `READY_TO_SUBMIT`.
- App availability covers 175 storefronts and is enabled for new territories.

Official references:

- [Select an App Store version release option](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/)
- [Platform version information and App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Choose a build to submit](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/)

## TestFlight gate

- Build `+7` is valid and App Store eligible, but it is not the release
  candidate.
- The only test group is the internal `BIL Internal QA` group; it has one
  tester and includes builds `+5` and `+7`.
- Build `+7` is `IN_BETA_TESTING` internally and
  `READY_FOR_BETA_SUBMISSION` externally. No external beta review submission
  exists and no external group exists.
- The English beta-app localization has description, feedback email,
  marketing URL, and privacy URL. The build's English `What to Test` text is
  empty.
- A prior authenticated UI observation recorded six crashes for build `+7`.
  That UI metric was not available in the current API response and is retained
  only as earlier evidence; it must not be treated as +8 validation.

Required for `+8`: upload only after the release gates pass, add focused
`What to Test` instructions, run internal signed-device tests first, then use
external TestFlight only if the release plan requires it.

Official references:

- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)

## Subscription prices and the savings claim

The controlling live prices and availability relevant to the current request
are:

| Product pair | Live availability | Price evidence |
|---|---|---|
| AI Premium / Coach | Exactly 168 markets, including IND and excluding NGA | United States: USD 5.99 monthly / USD 49.99 annual / rounded saving 30% |
| Ordinary Premium | Exactly EGY/NGA/PAK/TUR (4) | Each price point was validated before the availability update; localized values are intentionally not duplicated in this report. |

The earlier same-day read-back exposed ordinary Premium in EG/IN/PK/TR. The
fail-closed `subscriptionPlanAvailabilities` update removed India, added
Nigeria for both monthly and annual Premium, and then immediately read back
both periods. Both availability objects use `UPFRONT` and
`availableInNewTerritories=false`. The corrected EG/NG/PK/TR set is the final
owner contract and now matches Google; the old snapshot is historical change
evidence, not a current blocker.

Repository/backend policy is aligned without rewriting deployed history:

- `tool/apple_store_connect/canonical_store_pricing_2026-09-05.json` and
  `tool/apple_store_connect/apple_catalog_policy.json` encode EG/NG/PK/TR and
  AI-168;
- forward migration
  `supabase/migrations/20260905170000_owner_store_market_policy_nigeria_alignment.sql`
  is live; its database read-back is `enabled=172`, `premium=4`, `ai=168`, with
  EG/NG/PK/TR Premium, IN AI, and CN `not_for_sale`; and
- `test/features/commerce/final_store_market_policy_alignment_test.dart`
  asserts the active September 5 files. The August canonical file and earlier
  deployed migration remain immutable historical evidence.

The US AI calculation is
`round((12 * 5.99 - 49.99) / (12 * 5.99) * 100) = 30%`. The requested
USD 5.99 monthly and USD 49.99 annual prices are therefore already correct and
need no live price mutation.

The AI pair is available and priced in all 168 configured storefronts (37
currencies), but Apple-localized price points do not produce one universal
percentage: the observed rounded savings range from 17% to 40%. Consequently,
`Save 30%` is truthful for the US storefront and its US-specific review asset,
but must not be a hard-coded global claim.

Production source already follows the safe rule:

- `lib/features/commerce/domain/store_price_comparison.dart:20-47` pairs the
  annual offer only with the same product kind, a `P1M` offer, and the same
  currency, then derives the percentage from `12 * monthly` versus annual.
- `lib/features/commerce/presentation/bil_dynamic_store_plan_components.dart:387-396`
  renders that computed storefront-specific percentage.
- `test/features/commerce/store_price_comparison_test.dart:6-145` covers the
  30%, market-specific, non-fixed, and fail-closed cases.

The four-country Premium products are fully priced in exactly their four live
storefronts. No broader Premium availability is claimed.

Official reference:

- [Manage pricing for auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/)

## App ID, Sign in with Apple, Associated Domains, and App Attest

Verified facts:

- The live App ID prefix matches the Xcode signing team and the current
  provisioning profile's application identifier. The prefix is intentionally
  omitted here.
- The exact bundle ID is `com.bilhealth.bodyintelligencelog`.
- The initial API snapshot returned In-App Purchase, Push Notifications, Sign
  in with Apple (`PRIMARY_APP_CONSENT`), and HealthKit. After that snapshot,
  the owner enabled Associated Domains and App Attest on the App ID.
- Apple's public capability API exposes Associated Domains and Sign in with
  Apple, but does not expose App Attest as a mutable `CapabilityType`. App
  Attest therefore must not be guessed or toggled through that API.
- After enabling both capabilities, the owner regenerated, inspected, and
  replaced the iOS App Store profile used by GitHub. Authenticated profile
  inspection passes the exact App ID/team and App Attest, Associated Domains,
  HealthKit, IAP, Push and Sign in with Apple capabilities; the final signed
  `+8` artifact must still prove its embedded entitlements independently.
- Release/Profile source uses `ios/Runner/Runner.entitlements`, which correctly
  requests `applinks:www.bilhealth.com` and production App Attest. Debug source
  uses `ios/Runner/RunnerDebug.entitlements`, which requests development App
  Attest.
- `.github/workflows/bil_ios_signed_release.yml:140-176` independently rejects
  a profile lacking the exact application identifier, HealthKit, Sign in with
  Apple, `applinks:www.bilhealth.com`, production push, or production App
  Attest. The regenerated profile has passed this authorization gate; the clean
  `+8` IPA has not yet run it.

Completed owner action (Account Holder/Admin): Associated Domains and App
Attest were enabled together, then the distribution profile was regenerated,
inspected, and replaced in GitHub. Remaining proof: inspect the signed `+8`
IPA's final entitlements; source and profile checks alone do not prove the
signed artifact.

Apple notes that capability changes can invalidate provisioning profiles, which
is why both capabilities should be enabled before regenerating once.

Official references:

- [Enable app capabilities](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
- [About Sign in with Apple](https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple/)
- [App Attest environment entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.devicecheck.appattest-environment)
- [Supported capabilities for iOS](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)
- [App Store Connect API CapabilityType](https://developer.apple.com/documentation/appstoreconnectapi/capabilitytype)

## AASA and authentication order

- `https://www.bilhealth.com/.well-known/apple-app-site-association` returned
  HTTP 200 as JSON with no redirect and exactly matched the repository file.
- Its `appID` uses the verified App ID prefix and bundle ID, and its components
  cover `/auth/callback` and `/auth/reset-password`.
- The public AASA file is correct and the replacement profile is reported to
  carry the newly enabled capability. The signed `+8` return path remains the
  definitive device-level proof.
- `lib/features/auth/premium_login_page.dart:248-307` renders Google, then the
  native Sign in with Apple button on iOS, then Facebook. This satisfies the
  required Apple-before-Facebook ordering.
- `.github/workflows/bil_ios_signed_release.yml:312-313` compiles the signed
  release with both Facebook flags enabled and ready. The final device OAuth
  return remains a signed-device gate, not a source-only claim.

Official reference:

- [Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)

## App Attest backend gate

- `supabase/functions/app-attest/index.ts:420-441` requires an explicit
  `BIL_APP_ATTEST_APP_ID`, allowed environments, and bundle-version allowlist.
- `supabase/functions/app-attest/index.ts:521-523,678-680` verifies the RP ID
  hash against that configured App ID for both attestation and assertions.
- The exact server App ID is the verified App ID prefix plus `.` plus the bundle
  ID; it must never be inferred from the Team ID.
- Production is configured for the production App Attest environment and build
  version `8`. The live `app-attest` function is `ACTIVE` v2 with
  `verify_jwt=true`; its reviewed source hash and non-secret configuration were
  read back successfully.
- The immutable mobile-integrity backend release binding now exists and is read
  back by CI. Enforcement correctly remains off until a genuine signed `+8`
  registration/assertion/replay canary passes; deployment alone cannot justify
  enabling it.

Official references:

- [Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Validating apps that connect to your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)

## App Store Connect API key and GitHub secrets

An existing least-privilege Developer-role CI upload key is available locally
and was successfully authenticated against App Store Connect to read this app
and its build list. Apple's role matrix allows the Developer role to upload
builds. A broader replacement key should not be created.

The following repository Actions secrets were populated from that existing CI
key, updated through the GitHub API and successfully read back by presence and
timestamp without copying values into Git, logs, or documentation:

- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` (strict Base64 of the `.p8` bytes)

This secret-name/configuration gate is **PASS**. The workflow must still verify
the final signed IPA and App Store Connect validation; a secret's presence is
not artifact evidence. Never print, rotate or replace these working values just
to refresh a report.

Official references:

- [App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)
- [Create API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [Role permissions](https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions)

## DSA / trader status (EU storefront scope)

The latest authenticated UI audit still shows **Set Up** for Digital Services
Act status and **Complete Compliance Requirements** in Business/Agreements.
This could not be re-opened in this pass because the browser-control helper
failed twice; no blind mutation was attempted.

This is a legal/account-holder decision and must not be fabricated. It is not a
global build, signing, TestFlight, or non-EU release blocker. It must be closed
before making the app available in affected EU storefronts. The Account
Holder/Admin must:

1. Complete the compliance flow and accurately declare trader status.
2. If a trader, enter and verify the public-facing address (or valid PO box),
   phone, and email, and upload any requested legal/address documents.
3. Confirm the app-specific DSA status under App Information.
4. Capture the completed state as release evidence before EU availability.

Official reference:

- [Manage EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)

## Final +8 go/no-go list

Ready now:

- Manual release mode is live and verified.
- US AI subscription prices are USD 5.99 monthly and USD 49.99 annual.
- The runtime savings badge is derived from matching StoreKit offers and is not
  a hard-coded worldwide 30%.
- Review contact/demo fields exist without exposing their values.
- Sign in with Apple is live on the App ID, present in source/profile, native on
  iOS, and ordered before Facebook.
- Production AASA is reachable, non-redirecting, and byte-matches source.
- Associated Domains and App Attest are owner-confirmed enabled, and the
  regenerated distribution profile has been inspected and replaced in GitHub.
- A least-privilege CI API key exists and authenticates.
- All three App Store Connect GitHub bindings are present and were read back
  successfully without exposing their values.
- The Apple token-custody migration/fixes and both Apple lifecycle Edge
  functions are live; the server-to-server notification registration is
  configured.
- The private reviewer identity was freshly authenticated and its live
  Premium/AI/token/non-admin contract passes server-side.
- Ordinary Premium monthly/annual now read back in exactly EG/NG/PK/TR; AI
  monthly/annual read back in the other 168 launch markets. The September 5
  canonical files/test and live forward migration match that split.

Blocking release/submission:

- No clean signed `+8` artifact exists in App Store Connect/TestFlight.
- First/return/private-relay Sign in with Apple, server-to-server revocation and
  both deletion paths still require exact signed-device proof even though their
  backend deployment/configuration gates now pass.
- `+8` needs focused TestFlight `What to Test` text and signed-device validation
  for Apple/Facebook return, App Attest registration/assertion/replay denial,
  reviewer no-paywall/no-ad access, HealthKit/Apple Watch, StoreKit sandbox,
  permissions, and account deletion on both iPhone and iPad.
- Only after those gates pass should `+8` be selected for version `1.0.0` and
  added to App Review. Manual release must remain selected.

Deferred region-specific item: DSA/trader compliance remains incomplete or
unconfirmed and must be resolved before enabling affected EU storefronts. It
does not block the rest of the release pipeline.

## Evidence and checks

Read-only API snapshots were stored outside the repository at:

- `G:/BIL_Toolchains/Codex/scratch/apple-plus8-2026-09-05/v1-metadata.json`
- `G:/BIL_Toolchains/Codex/scratch/apple-plus8-2026-09-05/v1-metadata-recheck.json`
- `G:/BIL_Toolchains/Codex/scratch/apple-plus8-2026-09-05/catalog.json`
- `G:/BIL_Toolchains/Codex/scratch/apple-plus8-2026-09-05/app-availability.json`

Focused Node checks completed with 12/12 passing:

```text
node --test tool/apple_store_connect/asc_catalog_sync.test.mjs \
  tool/apple_store_connect/asc_price_schedule.test.mjs
```

After the same-day market reconciliation, focused Flutter contract tests for
`final_store_market_policy_alignment_test.dart` and
`store_price_comparison_test.dart` completed with 9/9 passing. This proves the
checked-in policy/formula contract; authenticated live read-back proves store
configuration, while signed StoreKit sessions remain a separate gate.

No Flutter build, signed artifact, upload, or App Review submission was run.
