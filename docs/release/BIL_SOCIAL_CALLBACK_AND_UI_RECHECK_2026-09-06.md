# Social callback and UI recheck — 2026-09-06

## Scope

Fresh source, host-test and public-network checks of the current working tree.
This is **not** an installed signed +8, native consent, store purchase or complete
multi-account journey certificate. No build, upload, publication, user-account
mutation or provider-setting change was performed in these checks.

## Live public configuration, approximately 03:08–03:12 UTC

- Supabase `/auth/v1/settings`: Facebook=true, Google=true, Apple=true. The
  request used the app's existing public publishable key; no privileged key.
- Facebook authorize endpoint returned **302** to `www.facebook.com/dialog/oauth`.
  Returned client ID: `1384055070498598`; callback points to the same Supabase
  project's `/auth/v1/callback`; response type is code; requested scope is email.
  Redirect state was neither printed nor saved. The provider consent page was
  not submitted, so this is configuration evidence, not a completed login.
- `https://www.bilhealth.com/.well-known/apple-app-site-association`: **200**, JSON;
  app ID `43F9Y5Y96K.com.bilhealth.bodyintelligencelog`; exact callback and
  password-reset paths are present.
- `https://www.bilhealth.com/.well-known/assetlinks.json`: **200**, JSON; Android
  package `com.bilhealth.bodyintelligencelog`; fingerprint
  `DE:CA:D2:7C:36:64:0E:2E:07:54:63:2A:BE:EF:A9:ED:ED:ED:9E:F6:D7:93:D9:50:0A:EB:B4:49:3D:43:08:F4`.
  This matches the fingerprint recorded by the prior authenticated Play audit;
  that console itself was not re-read by this check.

## iOS callback gap repaired

Inspection of the pinned `supabase_flutter` 2.16.0 and `url_launcher_ios` 6.4.1
showed that opening SFSafariViewController completes the launch future after
initial load, while dismissal is a separate native operation. BIL disables
Supabase's own app-link observer and owns callback exchange in `main.dart`.
Previously that resolver exchanged/navigated without dismissing the native
browser overlay.

- Added `lib/features/auth/oauth_browser_return.dart` and wired it into the
  controller's validated resolver before `getSessionFromUrl`.
- iOS-only native dismissal; Android Custom Tabs and web are untouched.
- Only allow-listed credential-bearing callbacks reach the resolver. Added
  rejection of callback URLs containing user-info and adversarial tests.
- Success and provider-error callbacks both reveal the app's own outcome UI.
- Native close failure or a one-second close timeout cannot veto the actual
  exchange. The authentication result still comes from Supabase, not cleanup.
- Strengthened Android bridge tests for duplicate provider/redirect parameters
  and false/null unavailable-browser responses.

API reference: [Flutter url_launcher closeInAppWebView](https://pub.dev/documentation/url_launcher/latest/url_launcher/closeInAppWebView.html).
This closes a source lifecycle gap. Device-level reproduction/verification is
still part of the signed iPhone return-path check.

## Test runs completed

### Whole-project analysis

`flutter analyze --no-pub`: **No issues found**, exit 0, 266.7 seconds.
This run preceded the subsequently requested enhanced streaming/player UI;
that new work requires its own analysis and regression pass.

### Integrated Facebook-enabled and UI run

`flutter test --reporter compact --dart-define=BIL_FACEBOOK_LOGIN_ENABLED=true --dart-define=BIL_FACEBOOK_LOGIN_READY=true`
with the following **20 files**: **155 passed, 0 failed**, exit 0, displayed test
time 2:44. The four golden comparisons ran normally, without updating baselines.

```text
test/features/auth/oauth_browser_return_test.dart
test/features/auth/facebook_oauth_platform_contract_test.dart
test/features/auth/facebook_login_visibility_test.dart
test/premium_login_oauth_contract_test.dart
test/bil_auth_callback_controller_test.dart
test/auth_callback_retry_test.dart
test/auth_callback_completion_contract_test.dart
test/bil_semantic_icons_test.dart
test/dashboard_meals_timeline_test.dart
test/features/wellness/workout_entry_chooser_page_test.dart
test/features/profile/premium_profile_page_test.dart
test/platform_readiness/native_profile_photo_entry_points_contract_test.dart
test/features/dashboard/dashboard_preferences_widget_test.dart
test/features/notifications/notification_settings_runtime_contract_test.dart
test/features/intelligence_center/conversation_history_retention_test.dart
test/architecture_source_file_size_guard_test.dart
test/responsive_shell_test.dart
test/responsive_shell_accessibility_test.dart
test/quick_add_semantic_colors_test.dart
test/visual_closure/quick_add_golden_test.dart
```

### Default flags, deep links and Apple lifecycle

`flutter test --reporter expanded` with these **4 files**:
**32 passed, 0 failed**, exit 0, displayed test time 0:09.

```text
test/features/auth/facebook_login_visibility_test.dart
test/launch_readiness/deep_link_exhaustive_source_contract_test.dart
test/features/auth/apple_credential_lifecycle_test.dart
test/features/community/community_deep_link_test.dart
```

### Independent tester-feedback QA

The separate QA agent ran **17 existing test files**, including coach mutation,
history, credit access, goal grams/schedules, profile photos, location return,
notifications, recipes and videos: **88 passed, 0 failed**, exit 0, measured wall
time 127.780 seconds. No paths were missing and no product file was edited by
that QA run. Some tests overlap the integrated run; do not present the sum as a
unique coverage count.

## Remote media checks

- Existing `verify-recipe-thumbnails-v4.mjs` checked all **1500** deployed
  thumbnail HEAD responses for status, media type, byte length, content hash
  header and immutable cache policy. **1500 verified**, exit 0.
- Three GET samples had their actual downloaded bytes/length/SHA-256 compared
  with the reviewed manifest; **3 matched**. No image was stored locally.
- FFprobe successfully read a current public workout preview directly from the
  production endpoint: H.264, yuv420p, 720x1280, 30 fps, 10 seconds, 18,669,598
  bytes. This proves one readable encoded network asset, not mobile playback,
  all protected videos, offline restoration or an entire app download journey.
- All **15 unique public preview MP4s** returned HTTP 200 to HEAD, positive
  content length, video/mp4 and Accept-Ranges: bytes. No protected playback or
  full-byte proof is inferred from these header checks.

### Download-stall regression

`wellness_media_cache_test.dart`, `workout_videos_wall_test.dart` and
`workout_video_explicit_media_test.dart`: **23 passed, 0 failed**, exit 0,
displayed test time 0:35. Added cases cover stalled connection, stalled headers
followed by a successful explicit retry, cancelled stalled body with partial
bytes removed, and a slow progressing download exceeding the idle timeout in
total. The default is a 30-second *idle* timeout, not a total-download limit.
This run preceded the new progressive-player wiring requested afterwards.

### Rejected branding regression

`release_metadata_test.dart` and the then-current
`workout_fullscreen_experience_contract_test.dart`: **3 passed, 0 failed**,
exit 0. Branding checks pin the approved source icon SHA-256 and assert absence
of all 22 explicitly rejected historical files. See
`BIL_REJECTED_BRAND_ASSET_RETIREMENT_2026-09-06.md` for recoverable Git provenance.

### Later fullscreen/video follow-up

The subsequent requested fullscreen/stream/recovery implementation is tracked
separately in `BIL_VIDEO_PLAYBACK_RECHECK_2026-09-06.md`: a single nine-file run
passed **74/74**, an explicitly enabled public HEAD/range check passed **1/1**,
and whole-project `flutter analyze --no-pub` reported **No issues found** in
158.1 seconds (`session 2010`). These later results do not replace or inflate
the earlier authentication counts and do not imply native-decoder proof.

## Still required

Current source freeze, exact signed artifact identity, real native
success/cancel/error/logout/reinstall returns, and the complete reviewer/owner
test matrix remain distinct gates. Instagram feasibility is documented in
`BIL_INSTAGRAM_LOGIN_SCOPE_DECISION_2026-09-06.md` as a conditional decision, not
as a newly delivered login provider. Store acceptance is not guaranteed by
these checks.
