# BIL iOS 1.0.0 build 34 — final prebuild source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 34`

## Candidate lineage

iOS 34 is the next signed candidate after the accepted iOS 33 source and is
bound to the exact same audited source commit as Android 31.

## Included corrections and activations

- Profile Edit recovers stale account-scoped local storage after auth-owner
  transitions rather than leaving the reviewer on a blank retry screen.
- Community request count and request-list visibility now share the same
  authoritative friendship rows even when the other member has no public
  Community profile.
- Community welcome timing is 2.2 seconds, matching AI Coach while network
  loading continues behind the branded entry surface.
- Today date navigation no longer flashes meal/calorie/macro loading shells,
  and the seven day circles show complete date numbers.
- StoreKit 2 subscription checkout performs a fresh selected-product query,
  verifies and reconciles matching unfinished transactions before creating a
  second transaction, handles duplicate-product errors with one bounded
  recovery, and finishes only receipts accepted by the server. AI Boost keeps
  its existing consumable path.
- Production Google Mobile Ads remains present in the signed iOS plugin graph.
  UMP is the consent authority and production app/banner identifiers are bound
  to the single owner-confirmed publisher. Premium tiers and sensitive health
  logging surfaces remain ad-free.
- The public `app-ads.txt` source contains the owner-confirmed Google DIRECT
  record.

## Store verification evidence

The deployed production `verify-store-purchase` function is ACTIVE. Its
StoreKit backend and Apple ownership/reconciliation modules were read back and
matched the repository source used by this candidate. Client-side callbacks
never grant paid access without server verification.

The final physical-device/TestFlight purchase gate remains required because a
real StoreKit sheet and sandbox transaction cannot be certified by host tests.

## Immutable release bindings

`BIL_IOS_V34_AUDITED_SOURCE_SHA` and
`BIL_ANDROID_V31_AUDITED_SOURCE_SHA` must both name the same final audited
source commit selected after final code QA.

`BIL_IOS_V34_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256 in that audited source commit.

The signed workflow must not build another source SHA or remove the production
Google Mobile Ads plugin from the signed IPA.

No IPA build, TestFlight upload, or App Store submission is authorized merely
by this manifest. The owner updates the final release variables/secrets and
explicitly starts the signed build only after the prebuild gates are complete.
