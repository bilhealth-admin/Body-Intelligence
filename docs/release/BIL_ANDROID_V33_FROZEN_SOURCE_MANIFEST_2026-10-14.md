# BIL ANDROID 1.0.0 build 33 — frozen candidate for signed-artifact verification

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 33`

`STORE_SUBMISSION_APPROVED: NO`

`PRODUCTION_RELEASE_APPROVED: NO`

## Scope of approval — 16 October 2026

The owner explicitly authorizes building Android 33 AAB and iOS 36 IPA and uploading iOS to TestFlight for final verification. Frozen/accepted means accepted for constructing a candidate, not accepted by a store or cleared for public distribution. Zero unresolved reviews refers only to the source/build preparation review; it does not close pending store-policy, signed-artifact, device, reviewer-access or sandbox evidence.

Full analysis and the unsharded root suite passed on 36c46e353fafcc3b01451b5fbc122fb1b4875aae: 9,889 successes, zero failure/error/skip, stable_source=true. Evidence: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38826857261 . Later changes through f4a05de5 only repair policy workflow/bootstrap tooling; no application/native/dependency changes. Policy evidence and seven exact Windows plan goldens passed on f4a05de5: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38830053505 . CodeQL also passed. The final preparation commit only updates these records and their contract tests.

## Immutable bindings

Set BIL_ANDROID_V33_AUDITED_SOURCE_SHA and BIL_IOS_V36_AUDITED_SOURCE_SHA to the same final preparation commit. Set BIL_ANDROID_V33_STAGING_MANIFEST_SHA256 to this file's committed-byte SHA-256. Workflow checks enforce matching source, manifest digest and exact build number. Artifact hashes and signer identities must come from the completed jobs, not this preparation document.

## Cloud and outstanding validation

Production reconciliation records 229 applied migrations, including 14 in this follow-up; no historical migrations were deleted. Deployed functions: verify-store-purchase 94, ai-coach 107, analyze-meal 104, food-search 61; deployed file readback matched. See ../qa_next/BIL_20261016_PRODUCTION_FINALIZATION_AR.md for exact evidence and limitations.

Google's five historical enforcement cases remain unresolved officially; Android 32 is unchanged and no appeal is sent by these workflows. Apple iOS 35 privacy objection remains unresolved officially. Full Android Lint/Play Insights remains vendor-blocked; source policy green is not full policy certification. Final artifacts still require signature/certificate validation, merged permissions/SDK inspection, 16 KB Android verification, Apple privacy/ATT/AI-consent alignment, actual reviewer login/access, sandbox purchase/restore and physical health/device journeys. TestFlight upload is authorized; App Review submission and Google upload are not.

No new claim of account authentication, successful purchase, medical accuracy, policy acceptance or final release readiness is made. Failed signing/artifact validation must block upload. Keep protected UX and all prior fixes; no production/account/price/Trial changes are authorized by this file.
