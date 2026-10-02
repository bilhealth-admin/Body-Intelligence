# BIL Android 1.0.0 build 30 — final frozen source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 30`

## Frozen application source

Production baseline shared by iOS 32 / Android 29:
`9f439cae97d72b784880a1b1ac4ef1d33ede30c1`.

Final certified application/test source:
`2184f772468fb36c6ab633c8b79591e3472ebb64`.

The release freeze commit that contains this manifest is documentation-only and
must not change application, native, dependency, or build inputs from the
application/test source above.

## Final automated certification

BIL Final Release Certification #89:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36966056579

Result: **SUCCESS** on `2184f772468fb36c6ab633c8b79591e3472ebb64`.

The run completed the immutable-source gate, both static/security/dependency
passes, both complete eight-shard Flutter test passes, visual + isolated-cloud
passes, pre-final fault/stress/store/security gates, and the Apple + Google
read-only store audit successfully.

BIL RC mobile test builds #55:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36966056600

Result: **SUCCESS** on `2184f772468fb36c6ab633c8b79591e3472ebb64`.

- Android APK/AAB + emulator evidence: **SUCCESS**
- iOS simulator + unsigned production-shaped device evidence: **SUCCESS**
- iOS native integration tests: **SUCCESS**
- iPhone/iPad lifecycle and deep-link evidence: **SUCCESS**

Sapphire #203 executed its test shard successfully (665 success, 0 failure,
0 error in the affected shard) but GitHub returned `ECONNRESET` while uploading
that shard's artifact. That infrastructure upload error is not treated as an
application/test failure; Final Release Certification #89 independently ran
both complete eight-shard suites successfully on the same source.

## Included release corrections

This source retains all accepted changes after iOS 32 / Android 29, including
local-first dashboard continuity when offline, verified paid-entitlement
continuity through transient network failures, prevention of false temporary
Free locks, Community/message unread-count corrections, onboarding/profile
persistence fixes, RTL/navigation polish, connected-health daily history,
explicit user-initiated Apple Health permission timing, and the iOS native
plugin-graph isolation that keeps Windows-only barcode native code out of the
iOS build while preserving iPhone barcode scanning.

## Accepted non-blocking cleanup items

The following are intentionally deferred to a separate post-release cleanup
branch and are not unresolved product defects for build 30:

- The existing iOS CocoaPods integration remains alongside Swift Packages.
  Flutter reports this only as a build-time cleanup opportunity.
- The current Android/Flutter toolchain reports future built-in-Kotlin migration
  advisories for legacy plugin build scripts. Android 30 currently builds and
  passes its release-candidate evidence; cleanup is deferred until after the
  frozen 33/30 release is safely delivered.
- Supabase Leaked Password Protection remains owner-deferred because it requires
  the paid plan; the final certification records this as an accepted
  non-blocking limitation.

## Immutable release bindings

`BIL_ANDROID_V30_AUDITED_SOURCE_SHA` and
`BIL_IOS_V33_AUDITED_SOURCE_SHA` must both name the exact same documentation-only
release freeze commit containing this manifest.

`BIL_ANDROID_V30_STAGING_MANIFEST_SHA256` must equal the SHA-256 of this exact
file in that frozen commit.

A later dispatch-control commit may update only the signed release workflow
binding to that already-frozen source. The signed Android build must check out
the frozen source, not the dispatch-control commit.

Signed-binary, Play/store-sandbox, and physical-device acceptance remain
separate release gates and are intentionally performed after this source freeze.
