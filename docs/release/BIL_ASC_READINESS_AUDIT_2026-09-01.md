# BIL App Store Connect readiness audit — 2026-09-01

This is an authenticated App Store Connect API audit of app `6805349703`,
iOS version `1.0.0`, and the TestFlight configuration prepared for build `5`.
It performed no public submission, review submission, tester invitation,
external-test distribution, or public release. It did not change the existing
subscription catalog.

## Fresh live evidence

The snapshots were generated between `2026-08-31T21:39:23Z` and
`2026-08-31T21:41:27Z` (September 1 in the project timezone):

- `G:\BIL_Temp\asc-readiness-audit-20260901\v1-metadata.json`
  - SHA-256 `89B8AF0E8BB565EDFCA9140AC29721C963C61DCF8EB5B4C9F879F9C62EB1967B`
- `G:\BIL_Temp\asc-readiness-audit-20260901\testflight.json`
  - SHA-256 `8031622801E74B5DF85539C3BE0891986767A90EDDC18D43EA47C8E6339E538C`
- `G:\BIL_Temp\asc-readiness-audit-20260901\commerce.json`
  - SHA-256 `EA29E1E11176606104DEFD91247195F064795222D70DF32ECA4EBA0AF4EC8FEF`
- `G:\BIL_Temp\asc-readiness-audit-20260901\availability.json`
  - SHA-256 `1B6BE86616BD45FD7A4F21940DA3AC6FDFB808277B7B62072B38C06DBD56D2E8`
- `G:\BIL_Temp\asc-readiness-audit-20260901\ios-run-33440642544-job.log`
  - SHA-256 `F5835E495E96A5D89CD76C4976032EB913C51FEAA48E083752A540137015001B`

No reviewer name, email, phone, demo-account value, password, API key, or
private-key material is present in this report.

## TestFlight readiness

| Area | Fresh API result | Decision |
|---|---|---|
| Internal group | `BIL Internal QA`; internal group; feedback enabled; public link not enabled; access-to-all-builds disabled | Correct |
| Testers | `0` | Intentionally unchanged; this audit was not authorized to invite testers |
| Beta localization | `en-US`; beta description, feedback email, marketing URL, and privacy URL present | Complete |
| Beta review information | Contact fields, required demo account, demo-account presence, password presence, and notes all present | Complete; sensitive values were not printed |
| Custom beta license agreement | Absent | Optional; not a blocker |
| Build 5 | Not yet present at the snapshot time | Await the signed workflow upload and Apple processing |
| Build group membership | Empty at the snapshot time | Add only valid build 5 after processing |
| What to Test | Build-scoped, therefore unavailable before build 5 exists | Create `en-US` localization after the valid build appears |
| External testing | Not configured by this audit | Correct; no external review or invitation is authorized |

The independent iOS release monitor owns the build-scoped operation to avoid
conflicting writes. It will require a valid, non-expired build `5`, add the
`en-US` What to Test text if absent, then link only that build to `BIL Internal
QA` and app version `1.0.0`. Auto-notify, tester invitations, external beta
review, App Review submission, and public release remain disabled.

The first manual-signing replacement run, GitHub Actions
`33440642544`, successfully produced the signed archive and IPA for build `5`.
It then stopped in its local evidence gate before App Store validation/upload:
`plutil -extract com.apple.developer.healthkit` interpreted the entitlement's
literal dotted key as a nested key path. Therefore no incomplete delivery was
sent to App Store Connect. The release monitor replaced that parser with a
fail-closed `plistlib` literal-key check and passed its focused/portable
contracts; a clean iOS-only rerun is required before build `5` can appear.

## Public App Store version readiness

| Area | Fresh API result | Decision |
|---|---|---|
| App identity | `Body Intelligence Log`; bundle `com.bilhealth.bodyintelligencelog`; primary locale `en-US` | Complete |
| Version | `1.0.0`; `PREPARE_FOR_SUBMISSION`; manual release | Correct; not submitted |
| Version text | Description, keywords, support URL, marketing URL, and promotional text present | Complete |
| App information | Subtitle, privacy policy URL, privacy choices URL, primary category `HEALTH_AND_FITNESS`, secondary category `LIFESTYLE` present | Complete |
| Public URLs | Marketing, support, privacy, and account-deletion URLs each returned HTTP `200` | Complete |
| App Review information | Contact, required demo-account presence, password presence, and notes complete; attachment count `0` | Complete; attachment is optional |
| Age rating | Declaration present; `SEVENTEEN_PLUS` / developer 18+ override | Configured |
| Availability | `175/175` territories selected; new territories enabled; no preorders | Complete except known DSA account requirement |
| Server notifications | Production and sandbox V2 URLs both present | Complete |
| Build attachment | Empty at the snapshot time | Attach only the valid build 5; do not submit |
| Product-page screenshots | `0` screenshot sets | Confirmed public-version blocker |
| App preview | Not required | Optional; the pending 30-second media asset can be added later |
| App Privacy | Not readable through the public ASC API; prior authenticated UI evidence records it complete | Preserve UI evidence and reconcile against the final binary before submission |
| DSA | `TRADER_STATUS_NOT_PROVIDED` in 27 territories | Known owner/external blocker; explicitly excluded from mutation in this audit |

Because the Xcode target supports device families `1,2`, final truthful product
page media must cover the required iPhone and iPad screenshot classes. Apple
requires at least one and allows up to ten screenshots. No placeholder,
generated substitute, stale build capture, or Premium-locked capture was
uploaded.

## Commerce preservation check

- Subscription group `22343739` / `BIL Membership` exists with one `en-US`
  localization.
- All four subscriptions have one localization, one
  `PREPARE_FOR_SUBMISSION` subscription version, one complete 1024×1024
  subscription image, one complete 1170×2532 review screenshot, review notes,
  availability, and prices.
- Premium monthly/annual cover the intended four territories and have no
  introductory offer.
- AI Coach monthly/annual cover 168 territories and each has 168 one-week free
  trial records.
- `bil_ai_boost` remains `READY_TO_SUBMIT`, localized, available in 172
  territories, priced, and has a complete review screenshot.
- The four parent subscription resources continue to expose the derived
  `MISSING_METADATA` value while all required child resources are present and
  prior authenticated UI reconciliation shows Prepare for Submission with no
  inline validation error. There is still no proven missing field to invent or
  patch.

No commerce mutation was made.

## Confirmed remaining blockers (DSA excluded)

1. Wait for build `5` to upload and reach App Store Connect processing state
   `VALID`; reconcile its export-compliance state.
2. Add build-scoped `en-US` What to Test text, link build `5` to the existing
   internal group, and attach the same build to version `1.0.0` without review
   submission.
3. Upload approved real final-build iPhone and iPad product-page screenshots.
4. Complete physical iPhone/HealthKit/Apple Watch/fitness-BLE and TestFlight
   StoreKit purchase/restore lifecycle evidence against the exact final IPA.

## Current decision

`ASC_ORDINARY_METADATA_READY=PASS`

`TESTFLIGHT_READY_PENDING_BUILD_5=PASS`

`APP_STORE_PUBLIC_SUBMISSION_READY=BLOCKED_BY_BUILD_SCREENSHOTS_PHYSICAL_TESTS_AND_DSA`

Official references:

- <https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds>
- <https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers>
- <https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information>
- <https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots>
- <https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance>
