# BIL final release-gate audit — 2026-08-31

This is an authenticated external-state and repository configuration audit.
It also performed one narrowly allow-listed Google Play catalog repair: the
accidental monthly base plan under the annual AI product was deactivated, and
the source-contracted seven-day new-customer offers were created and activated
on the two correct AI base plans. It did not build Flutter, upload a binary,
submit a version for review, publish a release, change prices/listings, or
expose, rotate, or create a credential.

## Candidate identity and build state

- Source metadata: `1.0.0+5`.
- Android application ID and Apple bundle ID:
  `com.bilhealth.bodyintelligencelog`.
- Both signed workflows require an explicit numeric build number of at least 5,
  pin Flutter `3.44.6`, pass the same reviewed production Dart defines, verify
  signing/entitlements and SHA-256, and mark physical-device validation as a
  separate required gate.
- The current local APK/AAB files are build 4 from 2026-08-27. They predate the
  current source and are not release candidates.
- There is no local IPA. App Store Connect reports zero uploaded builds and
  zero pre-release versions.
- The worktree is still under QA revision. No source-freeze commit or final
  full-suite result is claimed by this audit.

## App Store Connect — authenticated GET-only result

Evidence refreshed at `2026-08-31T02:05:12Z` under
`artifacts/release/apple/2026-08-30-final-audit/`.

| Area | Live result | Remaining action |
|---|---|---|
| App/version | App `6805349703`; version `1.0.0`; `PREPARE_FOR_SUBMISSION`; manual release | Attach the final signed build only after QA |
| Builds | 0 builds; 0 pre-release versions | Run signed iOS CI and optionally upload to TestFlight, without submitting review |
| Product-page media | 0 screenshot sets | Upload approved real BIL screenshots when the media package is final |
| Version localization | `en-US`; description, keywords, support, marketing and promotional text present | No required text gap found; `What's New` is not required for first version |
| App information | Name, subtitle, privacy URL, privacy choices URL, primary/secondary categories and age declaration present | Reconcile only if shipped source changes |
| App Review Information | Contact, required demo account, demo credentials and notes present; 0 attachments | Attachment optional; never print reviewer credentials |
| Availability | 175/175 selected; new territories enabled; no preorder/scheduled date | 27 EU territories remain blocked by DSA trader status |
| App Privacy | Prior authenticated UI evidence says complete; public ASC API does not expose questionnaire answers | Keep UI evidence; recheck against final binary before submission |
| Agreements/bank/tax | Prior authenticated UI evidence on 2026-08-30: Free/Paid agreements, bank and tax active | Recheck in UI if Apple displays a new warning |

### Apple commerce

| Product | Live period/type | Markets/prices | Offer | API state |
|---|---|---|---|---|
| `bil_premium` | 1 month | EGY 129.99; IND 249; PAK 700; TUR 129.99 | none | `MISSING_METADATA` derived state |
| `bil_premium_annual` | 1 year | EGY 999.99; IND 1,999; PAK 5,900; TUR 999.99 | none | `MISSING_METADATA` derived state |
| `bil_premium_ai_coach` | 1 month | USA 5.99 reference; 168 available territories | 168 one-week free-trial records | `MISSING_METADATA` derived state |
| `bil_premium_ai_coach_annual` | 1 year | USA 49.99 reference; 168 available territories | 168 one-week free-trial records | `MISSING_METADATA` derived state |
| `bil_ai_boost` | consumable | USA 2.49 reference; 172 available territories | none | `READY_TO_SUBMIT` |

Each subscription has one display localization, one completed subscription
version image, one completed review screenshot, review notes, availability and
prices. The prior authenticated UI reconciliation showed all four subscriptions
as **Prepare for Submission** with no inline validation error. Therefore the
four API `MISSING_METADATA` values are recorded, not guessed around or patched.
The first subscriptions and the app version must later be submitted together.

## Google Play — authenticated API result

Two existing service-account credentials independently authenticated to the
Android Publisher API and returned the same catalog state. Their identities and
key material are intentionally omitted. No credential was created or changed.

Evidence:

- catalog after repair:
  `artifacts/release/google/2026-08-31-api-audit/credential-1-after-repair.json`
  and `credential-2-after-repair.json`;
- exact before/operations/after repair records:
  `artifacts/release/google/2026-08-31-exact-catalog-repair/`;
- listing, media, bundle and track audit:
  `artifacts/release/google/2026-08-31-api-audit/release-surface.json`.

| Product | Active base plan | Coverage | Active offer | Live note |
|---|---|---:|---|---|
| `bil_premium` | `monthly` / `P1M` | 4 regions | none | Premium intentionally has no trial |
| `bil_premium_annual` | `annual` / `P1Y` | 4 regions | none | Premium intentionally has no trial |
| `bil_premium_ai_coach` | `monthly` / `P1M` | 168 regions | `trial-7-day`; tag `new-customer`; one free `P7D` cycle | Matches the app's fail-closed offer contract |
| `bil_premium_ai_coach_annual` | `yearly` / `P1Y` | 168 regions | `trial-7-day`; tag `new-customer`; one free `P7D` cycle | Incorrect sibling `annual` / `P1M` is now `INACTIVE`, not deleted |
| `bil_ai_boost` | `standard-2500` consumable | 173 regions | none | Active; current US price is USD 4.99 |

- Belarus (`BY`) is now consistently configured for AI monthly at USD 7.19,
  AI annual at USD 43.19, and Boost at its unchanged live USD 6.00. The monthly
  price came directly from Google's non-persistent current conversion of the
  USD 5.99 reference. BY was also added to the exact free trial, bringing both
  monthly base-plan and trial coverage to 168 regions. No other regional price
  or availability changed. Evidence:
  `artifacts/release/google/2026-08-31-api-audit/by-price-conversion.json` and
  `artifacts/release/google/2026-08-31-by-monthly-repair/`.
- The live `en-GB` listing has an icon, feature graphic and eight phone
  screenshots. Its copy promises fitness/wellness device connectivity only.
  It contains no blood-pressure, oxygen, SpO2, medical-reading or
  medical-device feature promise; the words "medical device" appear only in
  the explicit non-medical disclaimer.
- The `alpha` track has completed release version code 4 and is available in
  176 countries. Production, beta and internal contain no release. Four AABs
  (version codes 1–4) exist; no APK is present. The current `+5` source is not
  uploaded.
- The owner has reported that App Content and Data Safety were completed. The
  Android Publisher API does not provide authoritative GET coverage for all of
  those Console questionnaires; retain the authenticated Console/UI evidence
  and do not recreate them.
- Android signing configuration and an ignored local upload keystore exist,
  but the final AAB still needs workflow certificate equality, signing and hash
  evidence.
- The signed Android workflow creates a private artifact only; it deliberately
  has no Play upload, review-submission or production-rollout step.

## Real-device and hardware gates

No BrowserStack result, final-build physical soak state, or device-lab evidence
directory exists for this candidate. Emulator/simulator screenshots and unit
tests are not substitutes.

Required evidence still includes:

1. representative Android and iPhone real-device smoke coverage, including
   sign-in, navigation, account deletion, offline behavior and localized UI;
2. Health Connect and Wear OS via Health Connect on Android hardware;
3. HealthKit and Apple Watch via HealthKit on Apple hardware;
4. supported fitness-only BLE pairing and measurement import;
5. licensed-test Play Billing and StoreKit Sandbox/TestFlight purchase,
   renewal, cancellation, refund and restore.

The existing append-only soak recorder prevents fabricated/compressed evidence,
but no records currently exist. BrowserStack can cover ordinary real-phone UI
flows; it cannot prove Apple Watch, Wear OS, HealthKit/Health Connect sensors or
external BLE peripherals when the cloud device cannot pair that hardware.

## Exact stop points before any public submission

1. Finish QA, obtain a clean full-suite result, and freeze one source commit.
2. Build signed Android and iOS candidates from that exact commit with build 5
   or a higher unused build number; verify hashes and signing evidence.
3. Complete the real-phone and hardware gates against those exact hashes.
4. Upload the final store screenshots and attach the final iOS build.
5. Verify the repaired Play catalog against the exact final signed build.
6. Resolve Apple DSA trader verification/support case for EU distribution.
7. Reconcile build-dependent export compliance and final privacy/health
   declarations with the signed binaries.
8. Obtain the owner's separate final approval before review submission or
   public rollout.

The exact locked-source workflow inputs, required secret names, no-track Play
upload sequence, TestFlight upload, and no-submit App Store build attachment
sequence are documented in
`docs/release/BIL_NO_SUBMIT_BUILD_UPLOAD_SEQUENCE_2026-08-31.md`.
