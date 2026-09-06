# Tester notes closure matrix — 2026-09-04

This document maps the supplied tester screenshots and written reports to the
current source tree. It is a closure record for source work plus an unsigned
Android debug build, not a claim that a release candidate was signed,
installed, uploaded, or accepted by either store.

## Status language

- **Source fixed/verified** — the reported path has an implementation and an
  automated regression contract in the current working tree.
- **Source fixed; signed-device verification required** — the source race,
  navigation, or native bridge is addressed, but only a production-signed
  iPhone/iPad or Play-signed Android device can prove the operating-system
  behavior.
- **External dependency remains** — a provider credential, store-console
  value, backend/Apple security service, third-party catalogue, or production
  delivery result is outside what source tests can prove.

No iOS build, signing, upload, submission, rollout, or current-binary device QA
was performed for this repair batch. The Android debug source build completed
successfully, but it is neither a Play-signed release candidate nor device
proof. Therefore the binary already in review/testing must not be treated as
proof of these source fixes; new signed candidates and the device matrix in
`PLATFORM_PARITY_AUDIT_2026-09-03.md` are still required.

## Screenshot-by-screenshot reconciliation

| Screenshot evidence | Report represented by the image | Current status | Source/test evidence and remaining proof |
|---|---|---|---|
| `IMG_7598.PNG` | iOS reports that “Body Intelligence Log” crashed after an external-capability action. | **Source fixed; signed-device verification required** | Permission and foreground-return handling no longer treats the transient iOS permission sheet as a true background transition. Evidence: `lib/app/services/app_switcher_privacy_shield.dart`, `lib/features/daily_log/daily_log_capture_actions.dart`, `lib/features/intelligence_center/presentation/intelligence_conversation_voice.dart`, `test/apple_preparation/ios_native_runtime_safety_contract_test.dart`. The exact camera/microphone allow, deny, revoke, interruption, background, and relaunch sequence still needs an iPhone build. |
| `IMG_7599.PNG` | A dark privacy shield/app-switcher-looking surface replaces the app during camera, microphone, or barcode work. | **Source fixed; signed-device verification required** | The shield now covers real `hidden`, `paused`, and `detached` states without redacting transient `inactive`. Camera and speech entry points stay inside the app lifecycle. Real iOS scene transitions cannot be certified from Windows tests. |
| `IMG_7602.PNG` | Apps & Devices shows a giant empty watch and an “Unsupported platform” block on iPhone. | **Source fixed; signed-device verification required** | `lib/features/connected_health/connected_health_page.dart` prioritizes the actual native provider/status/actions and renders the large watch only after a synchronized signal. Connected-health widget and localization contracts cover the source presentation; an iPhone/Watch pair must prove the live state. |
| `IMG_7603.PNG` | The Bluetooth/device page is verbose, confusing, and mixes Android/iOS explanations. | **Source fixed; signed-device verification required** | The connected-health UI and 25-locale guidance now distinguish Apple Health, Health Connect, and verified Bluetooth capability. Evidence: `connected_health_page.dart`, `connected_health_copy.dart`, `connected_health_guidance_localization_test.dart`, and `partner_integration_registry_test.dart`. Actual BLE discovery/pairing remains device-specific. |
| `IMG_7604.PNG` | Apple Watch is present and permissions were granted, but no synchronized signal is shown. | **Source fixed; signed-device verification required** | HealthKit denial is treated as indeterminate rather than “granted means data exists”, and first-authorized import resets stale pre-consent anchors. BIL reads Watch-originated measurements through Apple Health on the paired iPhone; this source tree does not contain a watchOS app target. Evidence: `ios/Runner/BILGlobalHealthBridge.swift`, `connected_health_provider.dart`, `ios_health_wearable_provenance_contract_test.dart`. |
| `IMG_7605.PNG` | Quick Add cannot be dismissed by tapping above the sheet. | **Source fixed/verified** | Root cause: the sheet's outer `Align` had no `heightFactor`, so it expanded to the whole viewport and its transparent area intercepted taps intended for the modal barrier. The child is now shrink-wrapped to the visible sheet, so tapping the dimmed area reaches the dismissible barrier. Evidence: `lib/app/router/bil_quick_add_sheet.dart` and `test/responsive_shell_test.dart`. |
| `IMG_7606.PNG`–`IMG_7608.PNG` | The short drag handle moves with the Quick Add content while dragging. | **Source fixed/verified** | Root cause: a local vertical-drag recognizer on the handle stole the gesture from Flutter's modal `BottomSheet`; it could dismiss only after release and could not translate the complete sheet while the pointer moved. The handle retains its 48 px tap target, while vertical dragging is now owned by the framework sheet so the handle and content move together. `responsive_shell_test.dart` proves both in-progress movement and drag dismissal. |
| `IMG_7609.PNG` | Navigation lands on a white page containing only the bottom navigation bar; tapping Dashboard flashes and returns to white. | **Source fixed/verified** | The invalid/blank nested-shell routing path was removed and route fallback is covered by `lib/app/router/app_router.dart`, `responsive_app_shell.dart`, `test/app_router_invalid_route_test.dart`, and `test/sleep_reference_analytics_contract_test.dart`. |
| `IMG_7610.PNG` | Sleep Insights → “Review meals alongside sleep” is the action that precedes the blank screen. | **Source fixed/verified** | `lib/features/wellness/presentation/sleep_tracker_experience.dart` routes to the real Daily Log page instead of an empty shell; `test/sleep_reference_analytics_contract_test.dart` guards the deep link. |
| `IMG_7611.PNG` | A scanned GTIN returns only the product name and a warning that nutrition is missing. | **Source/backend verified; signed camera and external-catalogue proof required** | Name-only data is incomplete, so the resolver now tries trusted online enrichment before showing the honest manual-review path. Evidence: `food_runtime_search_authority.dart`, `regional_barcode_network_resolver.dart`, `barcode_food_review_dialog.dart`, `meal_search_journey_integration_test.dart`. Production `barcode-lookup` v19 returned serving, calories, and macros for tester GTIN `6223000350027`; universal product/ingredient coverage cannot be promised because Open Food Facts/USDA data is external, and USDA fallback still needs a real `BIL_USDA_API_KEY`. |
| `IMG_7615.PNG` | More/Profile values and navigation must remain coherent after goal/profile edits. | **Source fixed/verified**, with photo picking requiring device proof | Profile/goal readers are invalidated after writes and More uses current values. `premium_profile_page.dart`, `settings_page.dart`, `more_latest_weight_test.dart`, and profile summary tests guard the state. The separate Add Photo path is listed below. |
| `IMG_7616.PNG` | Entering AI Coach should open the entitled conversation, not briefly expose a purchase surface. | **Source fixed/verified** | `premium_route_glass_gate.dart` keeps content non-interactive behind a neutral loading state until positive server truth; entitlement/credit RPC errors show retry rather than an upsell. `server_entitlement_repository.dart` now treats the protected subscription lifecycle/expiry as authority and no longer misuses `verified_at` as a 72-hour lease. A read-only production preflight found exactly one active Premium AI Coach subscription for the designated operational account but zero verification timestamps within 72 hours, reproducing the old false lock without exposing account data. Evidence: `ai_coach_credit_access_policy_test.dart`, `admin_role_entitlement_separation_test.dart`, and `premium_ai_market_gate_widget_test.dart`. |
| `IMG_7617.PNG`–`IMG_7619.PNG` | AI Coach remains “thinking” for too long and ends with “The reply did not complete.” | **Source/backend bounded; signed-device/network verification required** | Context reads are concurrent with an 8 s per-source limit; full Coach, cloud client, local model, and Gemini-attempt bounds are 30 s, 28 s, 18 s, and 12 s respectively, with at most two transient provider attempts. Evidence: `intelligence_query_flow.dart`, `supabase/functions/ai-coach/server.ts`, and server contracts. A prior authenticated production request completed in one provider attempt, but real carrier/Wi-Fi latency and final server constants still need telemetry/device proof. |
| `IMG_7620.PNG` | Coach proposes target weight 79 kg and asks for written confirmation, but the confirmed change is not saved. | **Source fixed/verified** | A validated proposal is stored with the conversation for at most 24 hours, restores as confirmation-gated, accepts exact typed confirm/cancel, and commits the profile plus active goal in one transaction before invalidating readers. It is retired only after success or explicit cancellation. Evidence: `intelligence_message.dart`, `intelligence_action_flow.dart`, `intelligence_query_flow.dart`, `local_coach_command_parser.dart`, `intelligence_message_action_persistence_test.dart`, and `ai_coach_tool_parity_contract_test.dart`. |
| `IMG_7621.PNG`–`IMG_7623.PNG` | Coach access/Boost pages show reset and token figures that can become stale or contradictory. | **Source and production backend verified; updated signed-client retest required** | The exact-email/global reset grant is pair-idempotent and adds 2,500 usable non-expiring tokens; any positive total balance keeps Coach open rather than requiring an arbitrary minimum for a particular request. The client refreshes the authoritative balance/reset notice. Evidence: `lib/features/admin`, notification reset services, `ai_coach_global_reset_test.dart`, `ai_coach_reset_token_grants_contract_test.dart`, and production `ai-coach-global-reset` v6. Store-presented Boost price still comes from StoreKit/Play Billing and must be checked in sandbox/license testing. |
| `IMG_7624.PNG` and `IMG_7624-2.png` | Calorie/macronutrient percentages can total 110%, while derived gram rows remain empty. | **Source fixed/verified** | Carbohydrate and fat are anchors and protein is the remainder; saving 950 kcal with 30% carbohydrate and 30% fat yields 40% protein and 71.25 g carbohydrate, 95 g protein, and 31.67 g fat. Legacy invalid splits are repaired atomically and all seven stored values stay coherent. Evidence: `reference_preferences_numeric.dart`, `reference_preferences_numeric_test.dart`, and `nutrition_goals_widget_test.dart`. |
| `IMG_7625.PNG` and `IMG_7625-2.png` | The lower goals area is dominated by unhelpful/repeated dashes instead of meaningful gram values. | **Source fixed/verified for macro-derived values** | The primary macro rows now display the derived grams from the canonical calorie/split snapshot. Additional nutrients remain independently optional because calories cannot safely infer sodium, vitamins, minerals, or fatty-acid subtypes; BIL does not fabricate them. |
| `IMG_7626.PNG` | Exercise-calorie switches are enabled although verified exercise energy is unavailable. | **Source fixed/verified for truth gating; signed health-source proof required** | Goals change only when verified active energy exists from a connected source; “unavailable” does not synthesize calories. The HealthKit/Health Connect source bridges and goal resolver are covered by source contracts, but live Watch/Health Connect energy still needs the signed-device matrix. |
| `IMG_7627.PNG` | Gold tag/badge markers remain beside requested goal features. | **Source fixed/verified** | The requested goal-row badges were removed in `reference_preferences_pages.dart`; `premium_goal_triggers_test.dart` guards against their return. |
| `IMG_7628.PNG` | Scheduled goals request percentages and allow a disconnected/invalid split. | **Source fixed/verified** | The editor now asks for calories plus carbohydrate/protein/fat grams. `NutritionGoalTarget.fromGrams` accepts the plan only when 4/4/9 energy agrees with the calorie target and rejects inconsistent values. Evidence: `nutrition_goal_schedule_page.dart`, `nutrition_goal_schedule_repository.dart`, and their tests. |
| `IMG_7629.PNG`–`IMG_7631.PNG` | Different goals by day and goals by meal do not reliably drive their intended Dashboard/Daily Log targets. | **Source fixed/verified** | Day and meal overrides persist independently, “Use default” removes only that override, and the selected day resolves `scheduled ?? default`. Today, meal cards, and meal detail receive calorie and macro gram targets; a meal uses `mealGoal ?? dailyGoal`. Evidence: `nutrition_goal_schedule_repository_test.dart`, `nutrition_goal_schedule_page_test.dart`, `daily_log_meal_goal_grams_test.dart`, and `daily_log_live_macro_targets_widget_test.dart`. |
| `IMG_7632.HEIC` | Reset notice is visible while the Coach balance remains stale at `0 / 0`. | **Backend/source repair verified; updated signed-client retest required** | The HEIC was decoded only for review in a temporary location; no derivative was added to the repository. The deployed reset-grant migration and v6 reset function return a usable 2,500-token grant, while the client refresh path accepts any positive usable balance. A signed build must prove notification tap → refresh → access on the affected account. |

`IMG_7612`–`IMG_7614` were not among the supplied attachments. No behavior is
invented or attributed to those filenames. The 19-image packet is
`IMG_7615`–`IMG_7631` plus the two `-2` variants; `IMG_7632.HEIC` is separate.

## Written tester notes not represented by one screenshot

| Written note | Current status | Closure boundary |
|---|---|---|
| Barcode from Quick Add returns to Today instead of opening the scanner; camera/photo/microphone/AI voice actions leave the app. | **Source fixed; signed-device verification required** | Camera, in-app barcode, meal photo, profile photo, and speech entry points use dedicated in-app/native flows and lifecycle-safe permission handling. Gallery barcode selection is guarded: an unreadable image or picker failure produces the scanner's recoverable `imageUnreadable` result rather than an uncaught asynchronous failure (`barcode_scanner_helpers.dart`, `barcode_gallery_picker_failure_test.dart`). iOS permission sheets and Android activity recreation still require real-device allow/deny/revoke/background tests. |
| Meal voice permission/recovery text must remain complete and natural in every supported locale. | **Source fixed/verified for the localization contract; signed speech proof required** | `runtime_copy_meal_voice.dart` provides a typed catalogue of 21 meal-voice strings for each of the 25 supported locales, preserving distinct `pt-BR`/`pt-PT` and `zh-Hans`/`zh-Hant` variants. `meal_voice_input_service.dart` resolves permission recovery, open-settings, and continue copy through that catalogue, and `meal_voice_25_locale_copy_test.dart` guards the complete 25 × 21 matrix. Native recognition, permission sheets, and interruption still require devices. |
| AI Coach conversation is erased or silently replaced by a new chat. | **Source fixed/verified for local retention** | The active conversation is restored; creating a new one requires explicit user action; the prior 20-chat cap is removed. Input stays locked until restore completes, saves are serialized, and the latest transcript is flushed on background/dispose. Evidence: `intelligence_conversation_history.dart`, `intelligence_conversation_persistence.dart`, `conversation_history_retention_test.dart`, and `intelligence_center_composer_test.dart`. Cross-device transcript sync is not claimed. |
| AI Coach should read and change app data rather than merely promise a change. | **Source fixed/verified for a bounded tool set** | `BilToolRegistry` exposes typed, validated reads/navigation and confirmation-gated writes such as target goal, measurements, macro/meal edits, water, weight, memory, subscription, and account actions. It has no raw SQL or unrestricted device/app control; arbitrary control would be unsafe to claim. Signed end-to-end mutation testing is still appropriate. |
| Profile “Add Photo” does nothing on iPhone. | **Source fixed; signed-device verification required** | Mobile entry points use `image_picker`/the native system picker through `profile_photo_service.dart`; entry-point and account-isolation tests guard source behavior. Removal deletes only the authenticated owner's `${ownerId}/avatar`, clears that owner's cloud `avatar_url`, and clears local photo/public-URL state only after the cloud operation succeeds; remote-only avatars are covered as well (`profile_photo_account_isolation_test.dart`, `dashboard_profile_photo_removal_test.dart`). The system picker, limited-library mode, camera denial, cancel, and return require iPhone testing. |
| Saving location/time zone returns to More instead of remaining in Profile. | **Source fixed/verified** | `location_settings_page.dart` returns through the profile path and `location_settings_contract_test.dart` protects it. |
| Gender controls are thin, off-center, and show meaningless arrows beside Male/Female. | **Source fixed/verified** | `premium_profile_actions.dart` uses centered selection controls without the redundant arrows; profile widget/contract tests cover the source layout. |
| The selected calorie/macronutrient plan should remain authoritative throughout the app until changed elsewhere. | **Source fixed/verified** | Default, scheduled-day, meal, Dashboard, Today/Daily Log, and Coach readers use the same persisted goal authorities; the Daily Log receives the resolved gram targets rather than recomputing an unrelated split. |
| Goal-by-meal and scheduled goals should be real gram algorithms, not decorative percentage fields. | **Source fixed/verified** | Both paths persist calories and grams, validate 4/4/9 energy agreement, and resolve by selected day/meal. Exercise adjustment applies only verified active energy. |
| Recipe images appear slowly. | **Source and edge delivery verified; signed-device perception remains** | The first eight cards prefetch digest-pinned 512 px v4 WebP thumbnails; detail keeps the original v3 asset. All 1,500 thumbnails were uploaded additively with v3 fallback and production transfer checks. Device cache, poor network, memory pressure, and the final perceived loading state remain to test. See `BIL_RECIPE_THUMBNAILS_V4_DEPLOYMENT_2026-09-04.md`. |
| Android Coach back arrow freezes instead of returning to More. | **Source fixed/verified; Android predictive-back device proof required** | More pushes Coach, Coach pops with a safe Dashboard fallback, and the shell uses `PopScope`. Evidence: `platform_native_navigation_contract_test.dart` and `more_ai_coach_route_contract_test.dart`. |
| Workout videos are repeated; playback opens in a small/pause-covered surface. | **Source fixed/verified for deduplication and full-screen presentation; CDN/device playback remains** | Discovery canonicalizes exact media SHA-256 and assigns each payload to the first section only; the player is a dedicated edge-to-edge `fullscreenDialog` with explicit back/tap controls. Evidence: `workout_videos_wall_test.dart` and `workout_fullscreen_experience_contract_test.dart`. Codec, download, interruption, and relaunch need devices. |
| Android tablet and iPad show an old/incomplete Dashboard or features previously removed. | **Source fixed/verified for one adaptive feature tree; large-screen device proof required** | `premium_dashboard_benchmark.dart` keeps the complete phone feature tree on larger widths within a readable 840 px constraint. Responsive and integrity tests cover source parity. iPad split view, Android freeform/rotation, keyboard, RTL, and 200% text remain in the release matrix. |
| Admin must grant reset tokens by exact email or globally, attach arbitrary notice text, reopen Coach for any positive balance, and alone manage the moderator roster. | **Source and production backend deployed; updated signed-client retest required** | Exact-email/global reset scopes, custom notice payload, idempotent 2,500-token grant, balance refresh, and positive-credit access are implemented. The administrator UI adds/removes moderators only through the authenticated Edge boundary, with just-in-time integrity, rate limits, request idempotency, an immutable audit record, concurrent roster locking, and service-role-only SQL. Administrator authority remains separate from customer purchase truth; the designated operational account receives a separate expiring closed-test grant, while real paid entitlement continues to resolve from store lifecycle/expiry. Migration `20260904030000` and the guarded backend functions, including production `ai-coach-global-reset` v6, are deployed; mobile-integrity enforcement remains `off` until the signed-device rollout is proved. |
| Sign in with Apple must be native, while email verification should stay inside BIL. | **Source fixed; Apple/server and signed-device proof required** | Apple uses the native credential sheet with a one-time nonce and Supabase ID-token exchange; email uses the in-app six-digit OTP path. Credential-state checks exist on sign-in/launch/resume. Apple authorization-code refresh-token custody, server-to-server notifications, and server-side token revocation still require backend/Apple Console work. |
| Google/Facebook authentication should not strand the user outside the app. | **Source callback and production association files verified; provider/device return still required** | Facebook uses a Supabase-generated authorization URL. Android passes only the allow-listed URL to BIL's native `CustomTabsIntent` bridge, which pins a Custom Tabs provider and fails closed rather than falling back to an embedded WebView; iOS uses Supabase `inAppBrowserView` / `SFSafariViewController`. Google keeps the provider-required external browser path. Both return only through allow-listed HTTPS callbacks. On 2026-09-05 the production AASA and `assetlinks.json` were generated from the real Apple Team ID and Play App-signing certificate, deployed to `www.bilhealth.com`, read back exactly as JSON, and independently resolved by Apple's CDN and Google's Digital Asset Links API. The Meta app and Supabase provider/callback configuration are verified; installed signed-build return remains to prove. |
| iPhone should require internal integrity verification. | **Source, grant migration, and guarded functions deployed; enforcement, signing, and physical-device proof required** | The source implements just-in-time App Attest on Apple and Standard Play Integrity on Android for nine sensitive action scopes: Coach, reset/notice administration, moderator roster administration, purchase verification, and AI Boost verification. Migration `20260905010000` and guarded production functions are deployed in compatibility mode, and the server still has `BIL_MOBILE_INTEGRITY_ENFORCEMENT=off`. The App Attest verifier is not deployed and no signed client has proved the flow. Enforcement must therefore remain off until real Apple configuration, signed candidates, staging/device canaries, and the old-client rollout plan are verified. This is not a launch prompt or a client-only trust badge. See `BIL_MOBILE_INTEGRITY_DEPLOYMENT_2026-09-05.md`. |
| Android and iOS must behave as native versions of the same global app. | **Source parity substantially improved; signed platform matrix required** | iOS uses HealthKit/native Apple sign-in/system media permissions; Android uses Health Connect/Play Integrity/predictive-back-aware routing. Shared Flutter UI does not imply identical native APIs, and neither platform can certify the other. See the platform-specific boundaries below. |

## AI Coach privacy correction — 2026-09-05

The final audit found and corrected a material client-side privacy ordering
problem. The Edge Function already refused Gemini processing without consent,
but the older client assembled the broad context and called the BIL Edge
Function before that server-side decision. The current client now fails closed
in this order: authenticated session, current policy-v2 consent receipt,
question-scoped projection, then the Coach invocation. A denied, obsolete,
unreadable, or timed-out consent receipt therefore sends neither the question
nor its personal context to the Edge Function. The server gate remains in place
as defense in depth.

- Nutrition, training, sleep/habits, and weight/goal are independently selected
  in Coach settings; selecting none is valid and does not silently re-enable a
  category.
- Context assembly uses explicit allow-lists for every category. The old
  analytics shortcut that could return the complete computed-health map is
  removed, including for mixed category selections.
- The cloud payload is projected again against the latest question. A weight
  question cannot receive meal or sleep history, for example, and an unrelated
  question receives no personal category merely because that data exists.
- `BIL_LOCAL_AI_URL` is considered on-device only for exact loopback hosts
  (`localhost`, `127.0.0.1`, or `::1`). LAN and Internet URLs always use the
  consent-gated BIL cloud path.
- The settings and legal copy now state that only bounded selected context and
  up to the last 12 conversation turns accompany that request. The current
  mobile voice path submits recognized text, not raw microphone audio; the
  operating-system speech service may process audio under its own settings.

Source evidence is in `coach_context_assembly.dart`,
`local_model_gateway_io.dart`, `ai_coach_settings_page.dart`,
`ai_coach_settings_components.dart`, `intelligence_query_flow.dart`, and
`legal_document_page.dart`. Regression coverage includes
`coach_context_category_isolation_test.dart`,
`coach_remote_consent_preflight_test.dart`,
`ai_consent_and_context_settings_contract_test.dart`,
`cloud_voice_privacy_contract_test.dart`, and
`legal_ai_privacy_truth_contract_test.dart`.

## Recorded targeted verification

- `flutter test --reporter compact test/responsive_shell_test.dart` passed
  **30/30** tests after the Quick Add gesture and barrier repair.
- The combined Dashboard/tablet, Quick Add routing and 25-locale layout,
  app-switcher privacy, iOS native runtime safety, native permission/profile
  photo, recoverable image picker, barcode runtime, and meal-action contract
  run passed **130/130** tests.
- The iOS notification-navigation suite passed **5/5**, and the combined
  Android/iOS notification-navigation pass passed **14/14**. They verify the
  native-to-Dart routing contract and cold-start acknowledgement logic, not a
  real APNs/FCM provider delivery.
- The SwiftPM/permissions contract passed **6/6**. Flutter Swift Package Manager
  is explicitly enabled in `pubspec.yaml`; `permission_handler_apple` 9.5.0
  derives camera, microphone, speech, and photo capabilities from the matching
  iOS usage descriptions, so a fabricated Podfile macro fix was not added.
- The latest final full-tree Flutter run completed with **4,121/4,121 tests
  passed** and **0 failures**.
- The 25-locale meal-voice catalogue is covered across all **21 strings per
  locale**. The final focused closure run also covered gallery-barcode picker
  failure recovery, account-isolated profile-photo removal, Dashboard avatar
  clearing, food/barcode closure, and the visual-evidence truth contract; it
  passed **35/35**.
- The exact current Terms of Service production capture was regenerated and
  then passed an ordinary named golden run. Its baseline is
  `test/visual_closure/goldens/visual_closure_terms_phone.png` (72,722 bytes,
  SHA-256 `8f1dea9fd244a1947105437d26555a2f95339c094392a596057cda89a55f7c84`).
  `dart run tool/visual_reference_evidence_verifier.dart` passed after the
  evidence metadata sync, and its release truth contract passed **2/2**.
- Full `flutter analyze --no-fatal-infos` reported **No issues found**. Final
  `git diff --check` also passed. A post-native-audit run then passed **22/22**
  focused Android/iOS release, privacy, optional-hardware, and health-scope
  contracts, and the analyzer again reported **No issues found**. The
  clean-cache serial Android debug build
  completed with **BUILD SUCCESSFUL** after 760 Gradle tasks. A follow-up
  495-task build also completed after overriding transitive camera declarations
  so `camera`, `camera.any`, autofocus, flash, microphone, location, GPS,
  network location, Bluetooth, and BLE are all optional Play device features.
  The final `build/app/outputs/flutter-apk/app-debug.apk` is 271,082,247 bytes
  with SHA-256
  `7ABADE4F5709BC2688452BF491774AC1B508BE42F49453D9827A8412135781F3`.
  `aapt` confirms package `com.bilhealth.bodyintelligencelog`, version code 5,
  target SDK 36, large/xlarge-screen support, and no required camera feature.
  It remains an unsigned-for-store debug artifact; no signed application binary
  was installed or device-tested by this verification.
- The backend hardening follow-up passed **47/47** focused Flutter
  source/widget/contracts and **23/23** Deno function tests; the complete
  Supabase Deno pass later completed **118/118**. The authorized cloud rollout
  then applied migrations `20260904030000`, `20260904040000`, and
  `20260905010000`. Remote read-back reports `ai-coach` v42,
  `verify-store-purchase` v20, `play-integrity` v16, and
  `ai-coach-global-reset` v6. This is compatibility deployment evidence only:
  `BIL_MOBILE_INTEGRITY_ENFORCEMENT` remains `off`, App Attest is not deployed,
  and the new local community-push dispatcher was not deployed because its
  production provider credentials are absent.

## Native platform delta after the screenshot audit

### iOS / iPadOS

- HealthKit remains the source of Apple Watch-originated measurements on the
  paired iPhone; BIL does not claim a watchOS companion app.
- Native Apple sign-in, system media pickers, camera/microphone rationale,
  scene-aware presentation, and lifecycle shielding are present in source.
- `PrivacyInfo.xcprivacy` declares the UserDefaults required-reason API with
  Apple's `CA92.1` reason. App Attest key identifiers now live in a
  device-only, non-synchronizing Keychain item; app-owned UserDefaults is read
  only to migrate a pre-existing per-account identifier, and the legacy entry
  is removed only after a successful Keychain write. A release contract
  prevents the required-reason declaration from being removed while that
  migration remains in source.
- The APNs bridge now assigns its notification-center delegate before launch
  completes, presents foreground remote notifications, and distinguishes APNs
  taps from local plugin notifications. Warm taps route immediately; cold taps
  remain pending until Dart installs its handler or calls `takeInitialPayload`.
  Dart returns an explicit Boolean acknowledgement, and native clears the
  pending payload only after `true`. Token deletion unregisters remote
  notifications. The unused `remote-notification` background mode was removed;
  no background-content delivery is claimed.
- Flutter SwiftPM is explicitly enabled. With `permission_handler_apple` 9.5.0,
  camera, microphone, speech, and photo capability selection follows the
  matching `Info.plist` descriptions; there is no missing CocoaPods macro fix
  to claim for this project.
- **Production association publication resolved 2026-09-05:**
  `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`
  now return HTTP 200 `application/json`, `nosniff`, and exact generated JSON.
  Apple's association CDN returned the same 431-byte AASA and Google's Digital
  Asset Links API returned the production package/certificate statement. A
  production-signed installed-app OAuth/reset return is still a device gate.
- Still required: a production-signed iPhone/iPad run covering permissions,
  Watch history/live data, StoreKit restore/revoke, audio interruption, APNs
  foreground/cold/warm/terminated taps, universal-link return, iPad split view,
  and account lifecycle.
- App Attest and request-bound Play Integrity are implemented as a separate
  just-in-time security increment. The grant migration and guarded functions
  are deployed in compatibility mode, but server enforcement remains `off` and
  the client release flag remains disabled. App Attest is not deployed; real
  Apple signing/provider values, physical-device canaries, and the old-client
  rollout sequence in `BIL_MOBILE_INTEGRITY_DEPLOYMENT_2026-09-05.md` remain
  required before enforcement.

### Android

- Health Connect now exposes the same 20 canonical read signals as the
  HealthKit bridge: steps, distance, active energy, workouts, sleep, weight,
  body fat, lean mass, heart rate, resting heart rate, HRV, hydration, energy,
  protein, carbohydrate, fat, fibre, sugar, sodium, and potassium.
- Missing nutrition values are not emitted as zeros; imported provenance is
  retained; BIL-authored records are excluded; historical read permission is
  requested only when the installed provider supports it. A grant allows a
  bounded 365-day bootstrap, otherwise the normal 30-day window is used. No
  background-health permission was added.
- Remote push is fail-closed: the placeholder provider reports unconfigured,
  cannot mint a token, and cannot enable server delivery. Cold/warm `deep_link`
  intent handling is bounded and then checked by the Dart route allow-list.
- **External dependency remains:** production Firebase app registration,
  `google-services.json`, messaging dependency/plugin, a real
  `BILPushProvider`, gateway URL/secret, delivery proof, and Play Health/Data
  Safety declarations. See
  `PLATFORM_NATIVE_HEALTH_PUSH_DELTA_2026-09-04.md`.

Health/push outcome boundary: the native HealthKit/Health Connect source
contracts, iOS tap bridge, and Android fail-closed push behavior are present in
this tree, but that does not prove live health import or provider delivery. The
human-moderation, push-delivery-idempotency, and mobile-integrity SQL migrations
are deployed, as are the guarded Coach/store functions and Play Integrity
verifier. The new local community-push dispatcher is not deployed because no
production push provider is configured. Mobile-integrity enforcement remains
`off`, App Attest remains undeployed, and neither integrity path may be
described as production enforcement before the staged physical-device rollout
and authenticated canaries are recorded.

## Release conclusion

The screenshots and written tester notes are accounted for in source. That is
not the same as closing the release candidate. The current decision remains:

1. preserve the now-green full-tree analyzer/test state and the successful
   Android debug source-build evidence;
2. generate new signed iOS and Android candidates containing these changes;
3. execute the phone/tablet/Watch/Health Connect, permission, navigation,
   purchase, and accessibility matrix;
4. supply and verify the listed external identifiers/credentials/declarations;
5. only then promote or submit that new candidate.

Until those steps complete, this report must be read as **source closure with
explicit device/external gates**, not “all bugs proven fixed in production”.
