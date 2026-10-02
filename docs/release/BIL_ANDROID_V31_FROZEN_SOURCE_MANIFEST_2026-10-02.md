# BIL Android 1.0.0 build 31 — final prebuild source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 31`

## Candidate lineage

Android 31 is the next signed candidate after the accepted Android 30 source.
It preserves all previously accepted application behavior and adds only the
reviewed 2026-10-02 stabilization changes carried by the audited source SHA.

## Included corrections and activations

- Profile Edit recovers an auth/database owner-namespace race instead of
  remaining on a blank `Try again` surface.
- Community friend requests remain visible when the requesting account has not
  yet created a public Community profile; the production RPC uses a LEFT JOIN
  and still exposes no private account identity fields.
- Community entry welcome remains visible for the same 2.2-second minimum as
  AI Coach without delaying the feed request.
- Today date navigation keeps calorie, macro, and meal-card shells mounted
  while the selected day resolves, and every week circle shows its date number.
- iOS StoreKit 2 subscription checkout is hardened in the shared source:
  fresh catalog validation, verified unfinished-transaction reconciliation,
  duplicate-product recovery, and verified completion fallback. Android
  purchase behavior remains on the existing Play Billing path.
- Production AdMob/UMP is compiled for the next signed candidate using the
  owner-confirmed publisher, Android/iOS app IDs, and Banner unit IDs. Ads
  remain restricted to verified adult Free accounts and reviewed
  non-sensitive placements; Premium tiers remain ad-free.
- The public `app-ads.txt` source contains the owner-confirmed Google DIRECT
  record.

## Production cloud alignment

Production Supabase contains the forward Community connection RPC correction
corresponding to
`20261002163500_fix_friend_request_visibility_without_public_profile.sql`.

The deployed `verify-store-purchase` function was read back against the
repository source before freeze. The Apple StoreKit verification backend,
ownership-token validation, product registry, and reconciliation modules match
the repository bytes used by this candidate.

## Immutable release bindings

`BIL_ANDROID_V31_AUDITED_SOURCE_SHA` and
`BIL_IOS_V34_AUDITED_SOURCE_SHA` must both name the same final audited source
commit selected after final code QA.

`BIL_ANDROID_V31_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256 in that audited source commit.

The signed workflow must not build another source SHA or substitute test/demo
AdMob identifiers.

No AAB build, Play rollout, or store submission is authorized merely by this
manifest. The owner updates the final release variables/secrets and explicitly
starts the signed build only after the prebuild gates are complete.
