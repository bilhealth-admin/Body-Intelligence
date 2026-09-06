# Advertising correction and native verification

Current disposition: owner explicitly authorized signed +8 upload with AdMob
DEFERRED and a later update if needed. Android native test-banner v4 passed for
the older runtime hash below; production AdMob setup is INCOMPLETE. Neither
iOS native serving nor real UMP forms are verified by that run.

## Required behavior

- Registered, server-verified adult Free users may receive contextual ads only
  with an online device and current Google UMP authorization.
- Premium and Premium + AI Coach are ad-free. Owner/reviewer accounts follow
  the same verified plan policy; no email-based reviewer concealment exists.
- The future ad-enabled update requires production IDs, provider setup, UMP,
  app-ads.txt and truthful store declarations. These are deliberately deferred
  for the latest owner-authorized ad-disabled +8 upload. Debug test fill is not
  revenue activation, real consent-form proof, or actual-account login proof.

## Source checks observed

- Initial corrected ads + workflow-contract suite: 57/57 passed.
  Log: `G:/BIL_Temp/plus8-preflight-20260906/ads-source-contracts-20260906.log`.
- Production identifier/final native manifest/plist validator: 13/13 Python
  tests passed, including sample, zero, mixed-publisher, Unicode-digit and
  missing/duplicate native Android metadata rejection.
- Further async regression suite: 8/8 passed. This covers late consent
  withdrawal at native-handle hand-off, iOS first-party-ID setup timeout,
  SDK initialization timeout, native banner-channel timeout, retry and late
  completion rejection, plus existing paid-plan/account transitions.
  Log: `G:/BIL_Temp/plus8-preflight-20260906/ads-async-regressions-20260906-v2.log`.
- Targeted analysis of those four changed runtime/test files: no issues.
- Expanded final source/contract suite: 73/73 passed, including the live
  privacy-page updates, bounded machine consent reads, overlapping-consent
  generation protection, and native SDK timeout regressions.
  Log: `G:/BIL_Temp/plus8-preflight-20260906/ads-source-contracts-20260906-v2.log`.
  This is host-test evidence, not native-device or production-serving proof.
- The reviewer preflight representation correction passed 26/26 pure Node
  tests plus the existing canary-runtime fetch-injection/scan-cap contract.
  This accepts the existing Premium + active closed-test AI overlay alongside
  the literal Premium AI representation; it preserves authority, expiry,
  usage-floor and non-admin reviewer checks. No account or purchase record
  was changed, and no fresh live canary execution is claimed.
- After the bounded-retry correction, the expanded ads/release-contract suite
  passed 83/83, including ten new fake-time retry/cancellation tests.
  Log: `G:/BIL_Temp/plus8-preflight-20260906/ads-source-contracts-20260906-v3.log`.
- The final focused retry rerun also passed 10/10 after adding consecutive
  owner transitions and late-handle rejection. Final targeted analysis of ads,
  startup, the native harness and associated tests reported no issues (17.6s).
  Logs: `ads-retry-focused-20260906-v3.log` and
  `ads-final-analyze-20260906-v3-final.log` in the same evidence directory.

The initial async test run contained one test-platform mistake: the iOS-only
first-party-ID SDK call was being stalled under Android, where it is a no-op.
That fixture was corrected to iOS and the entire eight-test set rerun. No
production behavior was weakened to satisfy the test.

## Native Android baseline

- Device: existing `emulator-5554`, BIL phone AVD, API 36, x86_64.
- Native debug APK built successfully (cold build 1,382.6 seconds), then
  installed successfully (40.4 seconds).
- Test began, but at 44 seconds its connection ended; Flutter reported
  `did not complete` and `device 'emulator-5554' not found`.
- Result: NOT PASSED. No native banner screenshot or serving claim is based
  on this run. The log does not prove an application crash.
- Subsequent direct `adb` reads found the same device connected and booted,
  with the BIL package still installed. No manual restart or reset was made.
- Both Android boot-reason properties reported
  `kernel_panic,ext4-fs_(device_dm-55):_panic_forced_abugr_error` after the loss.
  This establishes a guest kernel/filesystem reboot; no BIL AndroidRuntime
  fatal exception was found in the inspected crash buffer. It does not
  establish that BIL caused the guest failure.
- Flutter's attempted automatic uninstall failed while the device was
  unavailable. Subsequent runs explicitly use `--no-uninstall` to preserve
  the installed application/data.
- Baseline log:
  `G:/BIL_Temp/plus8-preflight-20260906/ads-android-native-sdk-20260906.log`.

The v2 native run uses `--no-uninstall` and the real connectivity provider,
with host-coordinated emulator Wi-Fi/mobile-data loss and restoration. Its
separate log is
`G:/BIL_Temp/plus8-preflight-20260906/ads-android-native-sdk-20260906-v2.log`.
The v2 runner completed with exit 0 and `00:40 +1: All tests passed!`.
It recorded three successful native Google test-banner loads, both paid-plan
suppression checks, and actual offline/recovery provider transitions. The host
driver restored initial Wi-Fi/mobile-data settings to 1/1, with validated
connectivity afterwards. This is a native programmatic pass only.

**Visual proof rejected:** all four immediate/settled captures were obstructed
by Android's `System UI isn't responding` dialog. The logcat ANR event for
`com.android.systemui` was at 13:00:15 local time, before v2 test execution at
about 13:27. Therefore an `AdWidget`/loaded callback is not sufficient to claim
visible rendering. These screenshots are retained as failure evidence, not
accepted banner screenshots. A fresh unobstructed native run is required.

The existing SystemUI dialog was dismissed by selecting its exact `Wait`
action, not by closing BIL, uninstalling, resetting, or clearing data. A fresh
hierarchy/window read reported zero ANR windows and a stable Android launcher.
The clean launcher screenshot is diagnostic evidence only, not banner proof.

An additional source review found that transport connectivity may recover
before Internet reachability: a failed first request could exhaust the slot's
one-shot attempt flag. The correction retries at most twice, after 30/60 seconds,
only while consented, verified Free, foreground, online and handle-free. A
failure cooldown survives connectivity/plan flaps. Timers are cancelled on
invalidation/disposal; opaque owner scope prevents cross-account handles or
timers. Successful visible banners are never timer-refreshed by BIL. The v2
native result does not certify this subsequent source change; v3 retests it.

The v3 native harness disconnects while a Free banner is displayed, so it
checks actual removal during the outage as well as recovered loading. Screenshot
windows are 15 seconds. Its external driver uses a fresh log cursor, an exclusive
device mutex, bounded adb operations, foreground/ANR checks, unique filenames
and restoration readback. Root must still verify terminal exit 0 and inspect
the actual captured pixels; driver markers and file hashes alone are not enough.

### v3 result and capture correction

The v3 Flutter runner completed with exit 0 and `01:42 +1: All tests passed!`.
It proved four native test-banner loads, paid-plan suppression, visible-banner
removal on actual network loss and a successful recovered load callback/tree.
The first external driver rejected the foreground check because API 36 reports
`topResumedActivity`, not the older field it expected. A separate bounded rescue
driver captured the actual pre-outage banner, performed the radio transitions,
and restored Wi-Fi/mobile data to 1/1. The failed first driver is not a pass.

The pre-outage settled screenshot visibly contains Google's test banner without
an Android overlay. Both recovered screenshots instead contain only the fixture
label and a blank banner area. Recovery **pixel proof is not established by v3**.
The full external report retains these distinctions:
`G:/BIL_Temp/plus8-preflight-20260906/native-ad-runtime/v3/BIL_ADMOB_NATIVE_V3_EVIDENCE.md`.

The harness previously paused in `runAsync` after finding `AdWidget`, which can
precede asynchronous Android PlatformView creation. For v4, the capture helper
settles asynchronous frames and continuously pumps during each 15-second capture
window. This is an evidence-harness correction, not a claim of a runtime rendering
fix. The changed harness was formatted and analyzed with no issues. Its SHA-256
is `830290dbfa49d0a2a899ac03d9fd01bcfe9b1a80827fdcc7f018cce908426629`.
The v4 outcome must be read from its own runner and screenshots, not inherited
from v3 callbacks or earlier images.

### v4 accepted native result

- Root Flutter session `94021` completed with exit 0:
  `00:53 +1: All tests passed!`. The fresh debug build took 66.4 seconds and
  installation with `--no-uninstall` took 4.8 seconds.
- The external transition driver, session `22178`, also completed with exit 0.
  Wi-Fi/mobile data were actually changed to 0/0 and restored to 1/1. Its final
  checks found zero ANR/error windows and validated cellular/Wi-Fi connectivity.
- Four native Google test-banner loads were recorded. Premium and Premium AI
  suppressed the banner; a displayed Free banner was removed when the real
  connectivity provider became offline, and a new banner loaded after recovery.
- The driver agent inspected all four original captures. Root independently
  inspected the initial-settled and recovered-settled images: both visibly
  contain Google's actual test banner with no error overlay. Therefore v4 proves
  recovered pixels, unlike v3. No ad was clicked.
- APK metadata read directly with `aapt`: package
  `com.bilhealth.bodyintelligencelog`, version `1.0.0`, versionCode `8`,
  minSdk 26, target/compile SDK 36. This is a DEBUG integration-test APK, not a
  production-signed AAB/IPA or a store-upload candidate.

Exact v4 evidence:

| Artifact | SHA-256 |
| --- | --- |
| `ads-android-native-sdk-20260906-v4.log` | `733235f5d14b86bd59975fd621de02371b0596f1151ad1c17720d93deedbcc63` |
| `app-debug.apk` | `035d6703574eae4b84d369e5d7d6c4a0d5925032dad81bfc2be7f57ae9186197` |
| Initial settled PNG | `895fba684e9e41f857586b92e024b1b3f184b2dec1a8b63d7722f255b9bf1d22` |
| Recovered settled PNG | `640399d5e28cfe17dd146a6686992837e77408fffb81f06dae4078f19c293f2e` |

The runner log is under `G:/BIL_Temp/plus8-preflight-20260906`. Original PNGs,
transition log, their full filenames/hashes and the independent report are in
`G:/BIL_Temp/plus8-preflight-20260906/native-ad-runtime/v4/BIL_ADMOB_NATIVE_V4_EVIDENCE.md`.
The accepted runtime slot SHA is
`affa6a44b0855cb5fa43eba7a17ff146373c4b5ac59a1c20a1f7816a74d0b758`,
unchanged since the 83-test source suite. `git diff --check` passed after the
capture-helper correction. The repeated Kotlin plugin migration warning did
not fail this build; compatibility with future Flutter upgrades is not inferred.

The integration harness uses the real Google native SDK and official Google
test units, with conspicuously labeled synthetic account/consent fixtures.
It must separately prove banner rendering, paid-plan suppression, and real
emulator connectivity loss/recovery. It does not sign in as the owner or a
reviewer and does not validate production UMP messages or iOS native serving.

## Separate live account evidence

Fresh deployed readback confirms current Premium + AI Coach for the owner,
with active admin/moderator access and no Community suspension. The owner's
grant is time-bounded closed-test/sandbox authority, not a production purchase
receipt. The Apple reviewer also resolves to effective Premium + AI Coach
through ordinary server policy. Redacted proof:
`G:/BIL_Temp/plus8-preflight-20260906/owner-reviewer-ad-entitlement-readback.md`.

## External activation remains open

The BIL Google account is at AdMob signup. Real publisher/app/banner IDs are
not configured; app-ads.txt is a placeholder. No production readiness flag
has been enabled. Native tests must never substitute demo IDs into a signed
release or be described as successful monetization activation.

The earlier +8 signed CI runs were cancelled after the owner's correction;
their source bindings are historical. No AAB/IPA or store upload resulted from
those cancelled runs. Release source must be refrozen and retested after this
correction. External ad activation is deferred by the later owner instruction,
not silently considered complete. +7 remains excluded.

## Post-v4 source corrections and owner-deferred release

Two later source defects were corrected after native v4: overlapping live UMP
reads could publish an older grant after a newer denial; and a banner mounted
while already backgrounded initially assumed it was active. Latest-generation
live verification and an initial lifecycle read now close those boundaries.
The background regression first failed 4/4 against the old implementation.
Three older positive fixtures were then given an explicit resumed lifecycle;
their assertions were preserved. The expanded ads/contracts suite passed 94/94
and targeted analysis reported no issues (18.6 s). Native v4 is not relabeled
as proof of these later source hashes.

| Evidence / source | SHA-256 |
| --- | --- |
| `ads-source-contracts-20260906-v5.log` | `6208b8349e4133d911a827f1610f4654a5f5bbb321eec852a5754771f0a78057` |
| `ads-final-analyze-20260906-v5.log` | `78588ba2f19efdfd8fec60b764f3bbc8cc498ba66cdbdbaea36a1d6a6a2d0384` |
| current banner slot | `7bea4f5c40d87cd5612a77cdf93fa0719d02a24f59a97ac621fb47ff513aeb02` |
| current live UMP gate | `e238e162e197eb8222c865ffbe064cc2a7f3502877e4bda04e1da237832a05f0` |

The owner then explicitly said to defer AdMob until after upload and accepted
a later application update. Both release flags must be false, all five AdMob
defines absent, Android APPLICATION_ID and eager initialization provider absent
from the final merged manifest, and iOS GADApplicationIdentifier absent from the
final signed IPA. Signing, capabilities, Facebook and build-8 gates remain.
`configure_deferred_admob.py` has 14 passing positive/negative native metadata
tests; it mutates only an explicitly named pre-build source file and verifies
final signed-artifact metadata read-only. No dummy app ID is substituted.

The new Android/iOS widget regression uses the real provider/gateway/bootstrap,
an eligible verified adult Free fixture, and traps all Google Ads/UMP channels.
With the exact false build flags, 2/2 cases passed with zero channel calls,
including a two-minute fake-time retry horizon. Its first run failed Flutter's
platform-override cleanup invariant, not an ad request; TargetPlatformVariant
now owns the override lifecycle. Log: `deferred-runtime-regression-v2.log`.
This is host runtime proof, not an iOS native installation claim.
