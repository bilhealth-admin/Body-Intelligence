# BIL iOS / Android parity audit — 2026-09-03

## Decision

Do not submit the currently reviewed binary as the final release candidate. The
source contains substantial fixes for the tester reports, but a new iOS/Android
binary still needs the real-device matrix below. Source tests cannot prove
HealthKit, Health Connect, StoreKit, Play Billing, camera, speech, lifecycle,
or tablet behavior in a signed store build.

This audit distinguishes three states:

- **Proven in source/tests**: the implementation and an automated regression
  contract are present.
- **Implemented; device proof required**: native/store behavior exists, but the
  Windows host cannot execute the relevant signed runtime.
- **Open**: a source, backend, media, or release operation still remains.

## Tester-report coverage

| Tester report | Current status | Evidence |
|---|---|---|
| Quick Add cannot close by tapping above it; handle moves incorrectly | Proven in source/tests | Tapping the dimmed area above the shrink-wrapped sheet reaches the dismissible modal barrier. The handle keeps its 48 px tap target, while the framework `BottomSheet` owns the vertical gesture so the handle and complete sheet translate together during the drag and dismiss after the threshold: `lib/app/router/responsive_app_shell.dart`, `lib/app/router/bil_quick_add_sheet.dart`, `test/quick_add_routing_contract_test.dart`, `test/responsive_shell_test.dart`. |
| Barcode/voice/camera leaves BIL or returns to Today | Implemented; device proof required | `lib/features/nutrition/presentation/food_barcode_scanner_page.dart`, `barcode_scanner_helpers.dart`, `lib/shared/widgets/bil_camera_capture_page.dart`, `lib/features/daily_log/daily_log_capture_actions.dart`, native speech bridges; `test/apple_preparation/ios_native_runtime_safety_contract_test.dart`. Gallery image/picker exceptions now resolve to the recoverable unreadable-image state and are guarded by `test/features/nutrition/barcode_gallery_picker_failure_test.dart`; native lifecycle proof remains external. |
| Barcode returns only a name or treats name-only data as a complete result | Source/tests and production backend verified; universal coverage is impossible to claim | `lib/features/nutrition/services/food_runtime_search_authority.dart`, `lib/features/nutrition/services/regional_barcode_network_resolver.dart`, `lib/features/nutrition/presentation/barcode_food_review_dialog.dart`, `test/features/nutrition/meal_search_journey_integration_test.dart`. Name-only data is treated as incomplete and the resolver tries trusted online enrichment. Production `barcode-lookup` v19 passed free/premium authorization and exact-GTIN checks; tester GTIN `6223000350027` returned calories, macros, and serving data. Open Food Facts/USDA coverage and label completeness are external; BIL keeps an honest unknown/manual-review path rather than inventing ingredients or nutrients. |
| Sleep Insights meal review opens a blank shell | Proven in source/tests | `lib/features/wellness/presentation/sleep_tracker_experience.dart`, `test/sleep_reference_analytics_contract_test.dart` |
| AI Coach flashes the purchase screen for an entitled user | Proven in source/tests | `lib/features/commerce/presentation/premium_route_glass_gate.dart`, `lib/features/commerce/providers/commerce_providers.dart`, `test/features/commerce/ai_coach_credit_access_policy_test.dart`, and `test/features/commerce/premium_ai_market_gate_widget_test.dart`. Loading remains a neutral checking surface; an entitlement/credit RPC failure is now a neutral retry surface and never falls through to an upsell. Protected Coach content stays non-interactive until positive server truth returns. |
| AI Coach accepts a target weight but does not save it | Proven in source/tests | `lib/features/intelligence_center/services/local_coach_command_parser.dart`, `lib/features/intelligence_center/domain/intelligence_message.dart`, `lib/features/intelligence_center/presentation/intelligence_action_flow.dart`, `lib/features/intelligence_center/presentation/intelligence_query_flow.dart`, `test/features/intelligence_center/intelligence_message_action_persistence_test.dart`, and `test/launch_readiness/ai_coach_tool_parity_contract_test.dart`. A validated target-weight proposal is retained with its conversation for at most 24 hours, always restores confirmation-gated, accepts an exact written confirmation/cancellation, commits profile + active goal in one database transaction, invalidates readers, and retires only after success or explicit cancellation. Other write/destructive actions are not made replayable. |
| AI conversation disappears or starts a new thread automatically; old conversations must not be deleted | Proven for local on-device retention | `lib/features/intelligence_center/presentation/intelligence_conversation_history.dart`, `intelligence_conversation_persistence.dart`, `intelligence_query_flow.dart`, `test/features/intelligence_center/conversation_history_retention_test.dart`, and `test/intelligence_center_composer_test.dart`. The former 20-chat cap is removed, persisted V1 data migrates forward, the active conversation is restored, context changes no longer delete transcripts, and a new chat is created only by an explicit user action. Inputs remain locked until restore finishes so an early turn cannot be overwritten. Saves are serialized, persist the transcript before the context fingerprint, capture repository dependencies before teardown, and flush again on background/dispose so a quick exit does not silently discard the newest turn. This is intentionally local-only storage; cross-device AI transcript sync is not claimed. |
| AI replies are extremely slow / incomplete | Source/backend verified; production telemetry and device/network matrix still required | Context reads run concurrently with an 8 s per-source bound, the full Coach operation is bounded to 30 s, the cloud client to 28 s, the local model to 18 s, and each of at most two transient Gemini attempts to 12 s: `lib/features/intelligence_center/presentation/intelligence_query_flow.dart`, `supabase/functions/ai-coach/server.ts`, `supabase/functions/ai-coach/server_test.ts`. Production `ai-coach` v40 previously passed an authenticated end-to-end call in one Gemini attempt with 5,589 ms provider latency, correct calculation, metering, feedback, and duplicate-request rejection. These code bounds do not prove real-network latency; the updated server timeout constants still require the final Deno/device run. |
| Profile photo action does nothing on iOS | Implemented; device proof required | Mobile entry points use `image_picker` and the system picker: `lib/features/profile/services/profile_photo_service.dart`, `test/platform_readiness/native_profile_photo_entry_points_contract_test.dart`. Removal is owner-scoped in storage/cloud state and clears local avatar state only after cloud success; remote-only removal and Dashboard clearing are guarded by `profile_photo_account_isolation_test.dart` and `dashboard_profile_photo_removal_test.dart`. |
| Meal voice copy is incomplete/inconsistent across languages or permission recovery | Proven in source/tests; native speech proof required | `lib/app/localization/runtime_copy_meal_voice.dart` contains the typed 25-locale × 21-string catalogue, including distinct Portuguese and Chinese variants; `meal_voice_input_service.dart` consumes it for permission recovery/open-settings/continue flows. `test/features/nutrition/meal_voice_25_locale_copy_test.dart` guards the complete matrix. |
| Location/time-zone save returns to More instead of Profile | Proven in source/tests | `lib/features/settings/location_settings_page.dart` |
| Gender selector alignment/arrows | Proven in source/tests | `lib/features/profile/premium_profile_actions.dart` |
| Macro percentages can exceed 100%; grams are not derived | Proven in source/tests | `lib/features/settings/reference_preferences_numeric.dart`, `test/features/settings/reference_preferences_numeric_test.dart`, `test/features/settings/nutrition_goals_widget_test.dart` |
| Scheduled goals and meal goals should use grams and drive Dashboard values | Proven in source/tests | `lib/features/settings/nutrition_goal_schedule_page.dart`, `lib/data/repositories/nutrition_goal_schedule_repository.dart`, `test/features/settings/nutrition_goal_schedule_repository_test.dart`, dashboard goal resolver tests |
| Today/Daily Log ignores scheduled/default macro targets or shows an empty summary instead of live food details | Proven in source/tests | `daily_log_page.dart` now resolves `scheduled ?? default` once for the selected date and passes calorie, carbohydrate, protein, and fat gram targets to Today, meal cards, and meal details. The live compact meal card renders its food items, edit/more actions, optional logged time/insights, net-carbohydrate evidence rules, and gram/progress modes against `mealGoal ?? dailyGoal`: `lib/features/daily_log/presentation/daily_log_meals_list.dart`, `daily_log_meal_detail_items.dart`, `daily_log_summary_widgets.dart`, and `test/features/daily_log/daily_log_live_macro_targets_widget_test.dart`. |
| Premium/tag badges should be removed from the requested goal rows | Proven in source/tests | `lib/features/settings/reference_preferences_pages.dart`, `test/features/settings/premium_goal_triggers_test.dart` |
| Admin needs global reset, exact-email reset, custom all/email notice, and nonzero-credit access | Source and production backend verified; signed-client retest required | `lib/features/admin`, production `ai-coach-global-reset` v4, migrations `20260831151527_*`, `20260831192412_*`, and deployed `20260904010000_ai_coach_reset_token_grants.sql`. The reset grant is pair-idempotent, changes `granted` only, and any positive usable balance keeps Coach open; the account/banner behavior still needs the updated signed client. |
| Recipe images appear late | Source, edge deployment, and production delivery verified; signed-device perception still required | The first eight cards prefetch digest-pinned v4 WebP thumbnails while preserving the same layout dimensions and `BoxFit.cover`; the large 16:9 detail surface deliberately fetches the original v3 asset at full decode resolution. All 1,500 additive thumbnails were uploaded without deleting/overwriting v3, reducing bytes from 3.81 GB to 73.8 MB (98.06%). Production measured a representative v3 asset at 6.316 s versus v4 at 0.326 s, with exact SHA/size/MIME checks and safe v3 fallback. |
| Android AI Coach back arrow freezes | Proven in source/tests | More uses `context.push`, Coach uses `context.pop` with a safe Dashboard fallback, and the shell uses `PopScope`: `settings_page.dart`, `intelligence_center_page.dart`, `responsive_app_shell.dart`, `test/platform_readiness/platform_native_navigation_contract_test.dart` |
| Android tablet/iPad shows an old/incomplete Dashboard | Proven in source/tests after current patch | One complete feature tree is used for all window sizes and constrained to a readable 840 px: the AI entry, Daily Intelligence, calorie/macro overview, weight, quick logging, action, personal health, progress, Body Twin, and discovery sections remain in the same tree. Evidence: `lib/features/dashboard/widgets/premium_dashboard_benchmark.dart`, `test/dashboard_mobile_first/epic_e1_e2_responsive_widget_test.dart`, `test/dashboard_integrity_contract_test.dart` |
| Apple Watch granted access but imported nothing | Implemented; real Watch/iPhone proof required | HealthKit read denial is deliberately treated as indeterminate, and pre-consent anchors are reset before first authorized import: `lib/features/connected_health/providers/connected_health_provider.dart`, `ios/Runner/BILGlobalHealthBridge.swift` |
| Android Health Connect imports fewer categories than Apple Health | Proven in source/tests; signed-device proof required | The Android bridge now exposes the same 20 canonical read signals as HealthKit, including hydration, distance, body composition, energy and individual nutrients. It emits only present requested nutrition values from one nutrition-record query, preserves canonical units plus provider/device provenance, excludes BIL-authored echo records, and uses a 365-day bootstrap only when the optional history permission is supported and granted; otherwise it stays within 30 days. No background-health permission was added. Evidence: `android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt`, `lib/features/global_platform/health_data/unified_health_data_integration.dart`, and `test/features/global_platform/health_connect_runtime_test.dart`. |
| Android remote community notifications appear enabled without a real provider | Proven fail-closed in source; provider/device delivery remains external | The native bridge publishes provider capability, the placeholder reports unconfigured and cannot issue a token, and Dart verifies native provider status before token registration/RPC; the setting is disabled with localized guidance in all 25 locales when compile flags overstate availability. Cold/warm bounded `deep_link` payloads are consumed once and checked again by the Dart route allow-list. A real FCM app, token provider, gateway credentials and killed-process device proof are still absent; no delivery claim is made. The delivery-ledger migration `20260904040000_push_delivery_idempotency.sql` is local and unpublished. Evidence: `BILPushProvider.kt`, `MainActivity.kt`, `community_push_service.dart`, `bil_notification_navigation.dart`, and notification tests. |
| iOS remote notification tap is lost, delayed, or fails to return to BIL | Implemented in source; APNs/provider and signed-device proof required | `AppDelegate.swift` assigns the notification-center delegate before launch completes, handles foreground APNs presentation, and forwards bounded `bil:` deep links for warm taps. Cold-start payloads remain pending until Dart installs its handler or calls `takeInitialPayload`; native clears them only after Dart returns an explicit `true` acknowledgement. Token deletion unregisters APNs. Local-notification callbacks still use the Flutter plugin superclass path. The unused `remote-notification` background mode was removed, so no background-content execution is claimed. Evidence: `ios/Runner/AppDelegate.swift`, `lib/features/notifications/services/bil_notification_navigation.dart`, and `test/features/notifications/ios_notification_navigation_test.dart`. |
| Apps & Devices is confusing and shows a giant empty watch | Proven source fix; visual device proof required | `lib/features/connected_health/connected_health_page.dart` displays the large watch only after a real synchronized signal, prioritizes the native provider/status/actions, and supplies localized guidance across all 25 supported locales. `connectedHealthProvider` now declares its overridden gateway dependency so nested test/runtime scopes resolve the correct platform gateway. |
| Videos are repeated | Implemented locally; targeted source proof present | Discovery first canonicalizes exact SHA-256 payloads, then distributes each SHA globally to the first section that claims it (falling back to `stableId` when media is absent), preserves section order, and omits emptied sections. Evidence: `lib/features/wellness/presentation/bil_workout_videos_wall.dart`, `test/features/wellness/workout_videos_wall_test.dart`. |
| Sign in with Apple must be native | Implemented; signed-device and server-lifecycle proof required | `SupabaseAuthService.signInWithAppleNative()` uses a one-time nonce, the native Apple credential sheet, and Supabase ID-token exchange; `premium_login_page.dart` uses the package's official `SignInWithAppleButton`. The app now retains the owner-scoped Apple subject in secure storage, checks `getCredentialState` after sign-in/launch/resume, and handles Apple's local revocation notification without evicting a replacement or linked non-Apple session. Exchanging the authorization code for a server-held refresh token, Apple server-to-server notifications, and server-side token revocation during account deletion remain a separate backend/Apple-console requirement. |
| Existing account returns to onboarding after changing phones | Source/backend schema verified; real-device restore proof required | `CloudAccountKeyRepository.resolveExisting`, `SupabaseStartupCloudProfileReader`, `StartupCloudProfileRestoreService`, `test/features/startup/startup_cloud_restore_routing_test.dart`, `test/features/cloud_platform/supabase_startup_cloud_restore_reader_test.dart`, and deployed `20260901000000_bil_existing_cloud_key_recovery.sql`. The production migration inventory was aligned at the September 4 deployment checkpoint; the later local human-moderation migration is intentionally listed below as undeployed. Current cloud entities cover profile, weight, hydration, meals, and meal items; generic preferences and local-only AI conversation history are not thereby claimed cross-device. |
| Email/social sign-in leaves the app and does not return | Email/native Apple and production associations verified; provider/device return required | `verify_email_page.dart` verifies the six-digit email OTP inside BIL. Apple uses the native credential sheet. Facebook uses a Supabase-generated URL: Android opens it only through BIL's native, package-pinned `CustomTabsIntent` bridge with no embedded-WebView fallback, while iOS uses Supabase `inAppBrowserView` / `SFSafariViewController`; Google keeps its provider-required external browser path. Both return only through the verified HTTPS links `https://www.bilhealth.com/auth/callback` or `/auth/reset-password`; the callback controller rejects lookalike hosts, nonstandard ports, and legacy custom-scheme auth callbacks. On 2026-09-05 the AASA and `assetlinks.json` were deployed with the real signing identifiers and verified directly plus through Apple/Google association services. Evidence: `facebook_oauth_launcher.dart`, `BILFacebookOAuthBridge.kt`, `supabase_auth_service.dart`, `bil_auth_callback_controller.dart`, `auth_callback_page.dart`, `lib/main.dart`, and the OAuth/platform contracts. Meta and Supabase console configuration are verified; signed-device return remains external. |
| iOS permission/camera/microphone actions show a dark shield or app-switcher-looking screen | Source lifecycle race is addressed; signed-device proof required | `lib/app/services/app_switcher_privacy_shield.dart` deliberately does not redact transient `inactive`, while still shielding `hidden`, `paused`, and `detached`. Camera and speech code also avoid treating iOS permission-sheet inactivity as a real background transition. Evidence includes `test/apple_preparation/ios_native_runtime_safety_contract_test.dart`. This cannot be closed without allow/deny/revoke and background/foreground tests on iPhone. |
| Workout video opens in a small window with a pause overlay, or fails to load | Full-screen presentation is proven in source; download/CDN/device playback remains open | `bil_workout_fullscreen_video.dart` uses a dedicated `fullscreenDialog`, an edge-to-edge surface, tap-to-toggle playback, and a visible back action; `test/features/wellness/workout_fullscreen_experience_contract_test.dart` rejects the old small playback overlay. Actual download, codec, Cloudflare availability, interruption, and relaunch require the signed device/CDN matrix. |
| AI Coach hero/composer/voice roles and microphone sounds | UI and turn policy are proven in source; native audio/speech proof required | `intelligence_center_widgets.dart` and composer tests enforce a compact one-row hero, one-line composer, small back action, “Your BIL Coach” / “Speak your language”, and an icon-only top microphone. `coach_voice_turn_policy_test.dart` separates bottom dictation from the top automatic spoken loop. `BilMicSound`, `BILMicSoundBridge.swift`, and the Android bridge provide separate open/end assets plus haptics. This is a turn-based speech-to-text → bounded Coach request → text-to-speech loop, not a claim of full-duplex Gemini Live audio. |
| AI Coach should read and change app data using tools | A bounded allow-list is implemented; arbitrary app control is neither implemented nor safe to claim | `BilToolRegistry` allows typed navigation, profile/nutrition reads, target-goal, measurements, macros/meal edits, water/weight, memory, subscription/account actions with argument validation and risk-based confirmation. Execution stays in trusted repositories; the model has no raw SQL or unrestricted application access. The target-weight transaction now writes profile + active goal atomically and invalidates dependent providers, but signed runtime verification remains appropriate. |
| Premium subscription and AI Boost images are assigned incorrectly | Source mapping and live App Store state verified | `asc_subscription_version_images_upload.test.mjs` proves all four Premium subscription products share `bil_premium_subscription_1024.png`; `ai_boost_coach_artwork_test.dart` proves AI Boost uses the approved coach portrait. The authenticated App Store Connect read confirmed the four Premium products use the crown artwork and Boost uses the separate coach asset. |
| Premium/AI prices and availability should be correct worldwide | Authenticated inventory complete; Google price and territory drift remains explicit Console work | Apple matches the canonical split/pricing: Premium monthly/annual in EG/IN/PK/TR, Premium + AI Coach in the other 168 launch markets, and Boost at US-equivalent $2.49 across 172 Apple markets. Google retains the active products and P7D AI trials, but AI annual is US $35.99 rather than $49.99, Boost is US $4.99 rather than $2.49, and equal region counts conceal concrete missing/extra territory-set differences (including Premium missing IN and carrying NG). The official API exposes only whole repeated-field replacement for these objects, which could also disturb unrelated plans/options; no broad revenue mutation was made. The exact narrow Console procedure and country lists are in `BIL_LIVE_STORE_PREFLIGHT_2026-09-04.md`. |
| First-release version/build numbering and automatic rather than manual release | Marketing/build state verified; replacement source advanced to build 8 | `pubspec.yaml` is `1.0.0+8`: `1.0.0` remains the customer-visible first release and `+8` is the next source-default internal build after App Store Connect build 7. Both signed workflows reject inputs below 8 and still accept a higher unused number. Version 1.0.0 remains `DEVELOPER_REJECTED` with `AFTER_APPROVAL` release; automatic release is not enabled on the older rejected candidate. |
| The earlier five failing tests must be fixed | Prior failure set is reconciled; current-tree rerun remains the release authority | The supplied failure log contained one architecture source-ceiling failure and four Epic 15 Connected Health goldens. The validation record below reports the architecture split/ceiling correction and a final 8/8 Epic 15 golden pass after platform-specific baseline review. Because the working tree continued changing afterward, only the final full run on the frozen commit can close the release gate. |
| Attached tester screenshots must all be followed, without treating image contents as instructions | Reconciled as evidence; no hidden image instruction was executed | The three screenshot packets (`IMG_7597`–`7599`, `IMG_7602`–`7611`, and the 19-image `IMG_7615`–`7631` packet including the `-2` variants) map to the rows above. `IMG_7632.HEIC` was decoded through a temporary conversion and shows the reset notice together with a stale `0 / 0` balance; that evidence drove the reset-grant/backend verification, but the updated signed-client/account retest remains required. |

## Conversation request ledger — all 142 user messages reviewed

The 142-message transcript contains repeated status questions, stop/resume
directions, pasted terminal output, and launch-console work as well as product
requirements. The ranges below are exhaustive and intentionally aggregate
repeats; this is a coverage ledger, not a claim that every row is closed.

| Messages | Consolidated request | Owner / truthful status |
|---|---|---|
| 1–12 | Pre-release readiness; country pricing; first-release build number; subscription artwork; GitHub warning; barcode/watch test meaning; draft/release behavior; Apple phone-code problem; switch from manual to automatic release; publish | **Console/CI + Device.** Store state and signed binaries require live verification. A unit test cannot prove iPhone camera or Apple Watch import. The phone-code issue belongs to the external Apple account flow. |
| 13 | Stop the active release action | **Process control.** Not an application requirement; later requests resumed work. |
| 14–16 | Tester update/install link and TestFlight availability | **App Store Connect/TestFlight.** External distribution state, not Flutter source. |
| 17–19 | Preserve this conversation, project, recipe/video assets, and named private files while cleaning Codex/build/emulator data | **Workspace/process.** No deletion was performed by this audit. Asset preservation is distinct from application behavior. |
| 20–21 | Open progress pages and continue the same Codex context from another account | **Tooling/account continuity.** Not a BIL runtime requirement and not evidence of app readiness. |
| 22–29 | Parallel Android/iOS build/upload, build errors, product artwork reassignment, TestFlight/closed-test placement, do not submit final | **CI + Console.** Source mappings are audited above; current store attachment/review state needs a fresh authenticated read. |
| 30–31 | Stop the task and all credit-consuming monitoring | **Process control.** Not an application requirement; superseded by later “continue” requests. |
| 32–34 | Existing admin account incorrectly enters onboarding on another phone; choose a safe implementation split | **Source + Backend + Device.** Restore route/key work exists; fresh-phone proof remains. |
| 35–36 | Explain Google testing obstacle, including a request to invent a technical excuse | **Console; factual-only boundary.** No false claim may be authored. Use real tester activity, defect history, and actual Console evidence only. |
| 37–41 | Review the cloud-recovery repair and provide reliable PowerShell validation commands | **Source/tooling.** The pasted formatting failure came from sending SQL to `dart format`, not from an app defect. |
| 42–50 | Admin exact-email/global custom reset, nonzero token access, video full-screen/back, new-phone restore, and validation through success | **Source + Backend + Device.** Implementations/contracts and the September 4 production reset migration/function are verified; signed runtime behavior remains a device gate. |
| 51–56 | Interpret pasted validation, enlarge evidence, fix the five failures, and apply/deploy migrations/functions | **Source + Backend.** The five-test failure set is reconciled. The September 4 reset/product migrations and current AI Coach, reset, barcode, and food-search functions were then deployed and read back from the linked production project. |
| 57–75 | Build 8 artifact/upload scripts, GitHub push and workflow monitoring, merge/editor mistakes, artifact paths, and source-preservation concerns | **CI/workspace.** Operational history only. It must not be converted into a claim that a current signed RC exists. |
| 76–84 | Meta Business review, Google Play post-14-day eligibility/activity, build progress, and whether to wait | **External Console/human review.** Requires current authenticated UI/API evidence. Review duration and approval cannot be guaranteed. |
| 85–97 | Find device farms, test external watch/health connections, assess builds 7/8 and Apple rejection risk, preview | **Device lab + Console.** Browser/device farms may cover ordinary phone UI but cannot prove paired Apple Watch/HealthKit, Wear OS, or arbitrary BLE hardware without suitable physical devices. Apple review is not a substitute for QA and cannot be predicted as “certain.” |
| 98–109 | Compact AI Coach hero/composer, separate dictation/live-call roles, preserve user context, add pleasant open/end sound and haptics | **Source + Device.** Source contracts exist; real microphone, AVAudioSession, Android speech, TTS, sound, and haptic quality need device proof. |
| 110–130 | Install the in-review iOS build, manage TestFlight testers/invitations/codes, and identify accepted testers | **App Store Connect/TestFlight.** External tester state only; it does not modify or validate source. |
| 131–138 | Begin tester fixes; keep email verification internal where appropriate; native Apple sign-in; OAuth return; review decision; iOS/Android mic/camera/barcode lifecycle failures | **Source + Console + Device.** Implemented seams are mapped above. A replacement signed binary and permission/interruption matrix are still required; do not ship the older reviewed binary as the final RC. |
| 139–142 | Reconcile the 19-image iOS tester packet: AI entitlement flash/tools/history/latency, profile, goals, admin reset, recipe/video, navigation, platform parity, Windows error; then continue | **Mixed.** All individual product findings are mapped above or in the original tester table. Backend deployment and authenticated store reads are now recorded; App Attest, production AdMob values, a USDA production key, and physical-device proof remain open. |

## Work ownership and claims that must remain open

| Class | Can be closed here | Must remain external or explicitly limited |
|---|---|---|
| **Application source/tests** | Routing, validation, deterministic calculations, bounded tool schemas, responsive widget structure, local persistence behavior, and platform bridge contracts | These prove implementation intent, not hardware/store behavior or an absence of all defects. |
| **Backend** | Local migrations/function code, Deno contracts, and the September 4 authenticated production deployment/read-back | Signed-client reset delivery and ongoing production telemetry remain external. USDA-backed food search is unavailable until the owner supplies `BIL_USDA_API_KEY`; no demo/fabricated key was installed. |
| **Store/identity consoles** | Local metadata/scripts plus the September 4 authenticated App Store Connect/Google Play inventory | Purchase lifecycle, DSA/trader review, OAuth-provider runtime, and any future submission/rollout still require Console and signed-client evidence. |
| **Signed devices** | Static platform declarations and automated contracts | Camera/photo/mic/speech lifecycle, HealthKit/Health Connect, Watch/BLE, purchases, tablet split view, predictive back, accessibility, and codec/CDN playback require the exact signed-binary matrix. |
| **Impermissible or technically false assurances** | Explain limitations and preserve honest fallback states | Do not promise “every barcode”, complete ingredients/nutrients when providers lack them, zero bugs worldwide, guaranteed Apple/Google acceptance, a real Watch result from a simulator, unrestricted AI control, or a fabricated reason to pass Google review. Do not force Google/Facebook OAuth into an unsafe embedded webview merely to avoid the legitimate system authorization surface. |

## Platform requirements and code verdicts

### Authentication

- Apple requires the Sign in with Apple capability and a conforming button and
  authorization flow. BIL has the entitlement and native credential flow.
- The generic Apple icon button has been replaced with `SignInWithAppleButton`;
  signed-device and App Store configuration proof is still required.
- Native credential-state reconciliation now covers launch, foreground resume,
  and Apple's on-device revocation notification. Apple server-to-server account
  change notifications and server-side refresh-token revocation are not claimed.
- Google/Facebook OAuth uses the system authorization surface and returns through
  exact verified HTTPS universal/app links. Android Facebook has a strict
  native Custom Tabs bridge with no WebView fallback; iOS maps the requested
  in-app browser mode to SFSafariViewController. On 2026-09-05 the website
  association files were generated with Apple Team ID `43F9Y5Y96K` and the
  production Play App Signing certificate, deployed, and read back exactly.
- Independent resolution also passed: Apple's association CDN returned the
  exact AASA and Google's Digital Asset Links API returned the expected package
  and SHA-256 statement. Meta and Supabase allow-lists are verified; the
  OAuth/reset return on a production-signed installed app remains the device
  gate.

Official: [AuthenticationServices](https://developer.apple.com/documentation/authenticationservices/),
[Implementing user authentication with Sign in with Apple](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple),
[ASAuthorizationAppleIDButton](https://developer.apple.com/documentation/authenticationservices/asauthorizationappleidbutton),
[Sign in with Apple HIG](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple).

### Health

- iOS has the HealthKit entitlement and read/write purpose strings. The client
  correctly does not convert an unreadable/empty HealthKit query into a proven
  denial because Apple does not disclose read authorization status.
- Android declares and serializes the same 20 canonical read signals as the
  HealthKit bridge. It requests `READ_HEALTH_DATA_HISTORY` only when the
  installed Health Connect provider reports that feature; a grant enables a
  bounded 365-day bootstrap and denial/unavailability retains the normal
  30-day window. No background-health permission was added.
- Open: signed real-device proof with pre-existing Apple Watch sleep/steps,
  partial permission, denied permission, limited history, no-data, revoke,
  expired change-token recovery, and resync cases.

Official: [Authorizing access to health data](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data),
[Configuring HealthKit access](https://developer.apple.com/documentation/xcode/configuring-healthkit-access),
[Health Connect](https://developer.android.com/health-and-fitness/health-connect),
[Health Connect permissions UX](https://developer.android.com/health-and-fitness/health-connect/ui/permissions),
[Health Connect availability](https://developer.android.com/health-and-fitness/health-connect/availability).

### Camera, photos, microphone, and speech

- iOS has all four purpose strings. Camera/barcode capture stays in BIL; photo
  selection uses the system picker. Native presentation resolves the active
  scene instead of assuming `AppDelegate.window`.
- `pubspec.yaml` explicitly enables Flutter Swift Package Manager. The selected
  `permission_handler_apple` 9.5.0 package derives camera, microphone, speech,
  and photo capabilities from the corresponding `Info.plist` usage
  descriptions. This SwiftPM project does not need a fabricated Podfile macro
  workaround; the source contract passed **6/6**.
- Android requests dangerous permissions in context and uses system photo
  selection without legacy storage permission.
- Open: deny/allow/limited/revoke/interruption/background-return testing on real
  devices. Static contracts cannot prove AVFoundation or speech-session timing.

Official: [AVFoundation capture authorization](https://developer.apple.com/documentation/AVFoundation/requesting-authorization-to-capture-and-save-media),
[PhotoKit picker](https://developer.apple.com/documentation/PhotoKit/selecting-photos-and-videos-in-ios),
[Android runtime permissions](https://developer.android.com/training/permissions/requesting).

### Navigation and adaptive layout

- The app uses `PopScope` for Android's modern back path and one Dashboard
  feature tree across phone, tablet, rotation, and split-window widths.
- Open: device proof of predictive back animation, iPad multitasking widths,
  Android freeform/large-screen resize, keyboard, 200% text, RTL, and state
  preservation during resizing.

Official: [Flutter adaptive best practices](https://docs.flutter.dev/ui/adaptive-responsive/best-practices),
[Flutter platform adaptations](https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations),
[Flutter predictive back migration](https://docs.flutter.dev/release/breaking-changes/android-predictive-back),
[Android large-screen quality](https://developer.android.com/docs/quality-guidelines/large-screen-app-quality),
[Android custom/predictive back](https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture).

### Current release toolchains and binary evidence

- Apple submissions after April 28, 2026 require Xcode 26 and the iOS/iPadOS 26
  SDK. The signed iOS workflow now fails closed unless the selected Xcode and
  `iphoneos` SDK both report major version 26 or newer, and it preserves the
  toolchain evidence as an artifact.
- Android's 16 KB page-size requirement is verified against the final signed
  AAB, not inferred from Gradle configuration: the workflow checksum-pins
  official bundletool 1.18.3, validates the bundle, records bundletool's page-
  alignment verdict, and inspects every packaged native library's ELF `LOAD`
  segments for at least 16 KB alignment. The same pinned bundletool dumps the
  base manifest from that AAB, and a separate fail-closed gate records and
  requires `targetSdkVersion=36`.
- The signed iOS workflow unpacks the exported IPA, requires exactly one
  `Payload/*.app`, runs `codesign --verify --deep --strict` on that final app,
  and extracts both its signed entitlements and embedded provisioning profile.
  The verifier requires the expected team/application identifier, a live
  profile, matching release-critical entitlements, HealthKit, Sign in with
  Apple, production push, and `applinks:www.bilhealth.com`. Archive-only
  evidence is not accepted as proof of the exported IPA.

Official: [Submitting apps to the App Store](https://developer.apple.com/app-store/submitting/),
[Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes),
[Android App Links](https://developer.android.com/training/app-links/about),
[bundletool](https://github.com/google/bundletool).

### Store purchases

- The client listens to purchase updates, supports restore, verifies on the BIL
  backend, and completes/acknowledges only a verified purchase. The backend
  validates product/package/state and persists idempotently.
- Open: App Store sandbox/TestFlight and Play license-tester proof for purchase,
  pending, cancel, interrupted/relaunch, restore, refund/revoke, subscription
  expiry, server notification, and duplicate-token cases. Required production
  credentials and webhook delivery cannot be proven from source.

Official: [StoreKit in-app purchase](https://developer.apple.com/documentation/storekit/in-app-purchase),
[Offering, completing, and restoring purchases](https://developer.apple.com/documentation/StoreKit/offering-completing-and-restoring-in-app-purchases),
[Google Play Billing integration](https://developer.android.com/google/play/billing/integrate),
[Google Play Billing security](https://developer.android.com/google/play/billing/security).

## Live store preflight — 2026-09-04

Authenticated, read-only App Store Connect and Google Play preflight completed
without building, submitting, releasing, or changing rollout state:

- App Store version `1.0.0` is `DEVELOPER_REJECTED`, release mode is
  `AFTER_APPROVAL`, and valid build 7 is linked. The public listing has eight
  complete iPhone and eight complete iPad screenshots. Internal TestFlight has
  one tester and valid builds 5 and 7.
- All five Apple commerce products exist and are `READY_TO_SUBMIT`; intended
  prices, territory split, trials, and Premium-versus-Boost artwork match the
  canonical policy.
- Google production, beta, and internal tracks are empty; closed testing
  contains completed release 7 in 177 countries plus an empty draft. The Play
  listing has eight phone screenshots but no seven- or ten-inch tablet set.
- Google products/offers are active, including the intended P7D AI trials, but
  two prices and the exact territory sets differ from the canonical policy.
  Because the official write endpoints replace complete repeated plan/option
  structures rather than one price row, the audit stopped before mutation.
- Production AdMob remains fail-closed because publisher/app/unit IDs are
  owner inputs and still absent; the live `app-ads.txt` is reachable but still
  contains only the placeholder instruction.

Exact prices, missing/extra territory lists, evidence paths, and the safe
Play Console repair sequence are in
[`BIL_LIVE_STORE_PREFLIGHT_2026-09-04.md`](BIL_LIVE_STORE_PREFLIGHT_2026-09-04.md).

## Integrity / “internal verification” finding

### Implemented source contract

The app now requests integrity **just in time**, only when one of nine protected
operations is submitted: AI Coach, the three administrator reset/notice scopes,
the three moderator-roster administration scopes, purchase verification, or AI
Boost verification. `BilAppAttestService` uses
`DCAppAttestService` through the native Apple bridge; `BilPlayIntegrityService`
uses a Standard Play Integrity request. Both bind the action, request id, and
canonical payload digest rather than trusting a launch-time/client verdict.

The authenticated server flow issues a one-time challenge or verifies the Play
token, stores a short-lived owner/action/payload-bound grant, and atomically
consumes that grant in the guarded function. App Attest validation covers the
Apple certificate chain, nonce/client-data hash, App ID hash, environment,
credential key, bundle-version allowlist, signature, and monotonic assertion
counter. Play Integrity validation covers package, echoed request hash,
freshness, recognition/licensing/device verdicts, and server token decoding.

Account deletion deliberately remains outside the attestation gate so a lost or
unsupported device cannot block the user's privacy right. No visual “verified”
prompt is shown and no unrelated API is claimed as protected.

### Activation boundary

This implementation is **not deployed or enabled** by this source change. The
client define `BIL_MOBILE_INTEGRITY_REQUIRED` defaults to `false` and the server
setting `BIL_MOBILE_INTEGRITY_ENFORCEMENT` defaults to `off`. Activation requires
the integrity migration, exact Apple App ID prefix/environment/build allowlist,
Play-linked Cloud project and service account, guarded-function deployment,
production provisioning evidence, physical-device canaries, and an explicit
old-client/version rollout. A mistyped server mode fails with 503 rather than
silently downgrading enforcement.

The authoritative rollout, failure modes, and exact nine-action boundary are in
`BIL_MOBILE_INTEGRITY_DEPLOYMENT_2026-09-05.md`.

Official: [Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity),
[Validating apps that connect to your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server),
[App Attest object validation](https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide),
[Play Integrity standard requests](https://developer.android.com/google/play/integrity/standard).

## Production backend deployment — 2026-09-04

The repository was matched to the linked production Supabase project
`tgmanzhqulksykhslrzb` (`body-intelligence-log`, `eu-west-1`,
`ACTIVE_HEALTHY`) before any write. Dry-run and post-deployment inventories
showed that only the intended changes were applied:

- migrations `20260904010000_ai_coach_reset_token_grants.sql` and
  `20260904020000_register_google_store_products.sql` applied; the local and
  remote migration lists had zero mismatches at that deployment checkpoint;
  `20260904030000_community_post_human_moderation.sql`,
  `20260904040000_push_delivery_idempotency.sql`, and
  `20260905010000_mobile_integrity_jit_grants.sql` were authored afterward and
  remain local-only/unpublished until a separately authorized deployment;
- `ai-coach` v40, `ai-coach-global-reset` v4, `barcode-lookup` v19, and
  `food-search` v1 are active; all nine locally owned functions are present
  remotely, while the established remote-only reviewer bootstrap was left
  untouched;
- unauthenticated calls stop at HTTP 401, barcode free/premium gates and the
  tester GTIN passed live end-to-end, and AI Coach passed authenticated
  calculation, metering, feedback, duplicate-request, and cleanup checks;
- `BIL_USDA_API_KEY` is not installed. Open Food Facts barcode lookup remains
  available, while USDA exact-GTIN fallback and authenticated food search fail
  closed until the owner supplies a real production key.

Full commands, versions, checks, and the no-secret record are in
[`SUPABASE_DEPLOYMENT_2026-09-04.md`](SUPABASE_DEPLOYMENT_2026-09-04.md).

## Production media deployment — 2026-09-04

Cloudflare Worker v4 recipe thumbnails were deployed additively through
staging version `fc404161-c7af-4fa1-87cd-84817c739f44` and production version
`59cd581f-28a4-4433-af16-a75adcbc548c`:

- 1,500/1,500 content-addressed 512px WebP thumbnails uploaded successfully,
  totaling 73,802,850 bytes versus 3,811,262,661 bytes for the originals;
- every v4 staging and production route passed HEAD metadata verification for
  exact MIME, size, SHA, and immutable cache policy, with full-body SHA
  read-back for first/middle/last objects;
- production range, wrong-digest, private bucket-key, v2 manifest, free/paid
  workout authorization, CORS, and unchanged v3-body regressions passed;
- representative production transfer improved from v3 2,715,891 bytes in
  6.316 s to v4 62,204 bytes in 0.326 s; exact-byte edge cache was also proven
  MISS then HIT;
- v3 images were not deleted or overwritten. The app uses v4 only for compact
  cards/lists and retains full-resolution v3 for the large detail surface and
  as fallback. The on-screen card size is unchanged.

Worker tests passed **23/23**, the direct thumbnail/detail set passed **15/15**,
and all named recipe tests in the deployment audit passed **56/56**. The
previous production Worker version
`55433b52-2450-45e9-8a37-12fc452b1b8c` remains the documented code rollback.
Full publication and rollback evidence is in
[`BIL_RECIPE_THUMBNAILS_V4_DEPLOYMENT_2026-09-04.md`](BIL_RECIPE_THUMBNAILS_V4_DEPLOYMENT_2026-09-04.md).

## External release blockers

These items cannot be truthfully closed by Flutter source tests alone:

1. `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, and the Android
   Gradle fallback still contain placeholder AdMob application IDs. Supply the
   real production IDs through protected build configuration, or ship an
   explicitly ads-disabled build; do not archive the placeholder values.
2. App Attest and request-bound Play Integrity are implemented in source but
   not deployed or enabled. Complete the staged server/signing/device rollout
   described above; do not treat the repository entitlement or client switch
   alone as production integrity evidence.
3. There is no watchOS application target. Apple Watch measurements are read
   indirectly from Apple Health on the paired iPhone; a native watch app would
   be a separate product scope.
4. A real `BIL_USDA_API_KEY` is still required to enable the USDA-backed
   exact-GTIN fallback and food-search function. No demo or fabricated key was
   installed.
5. Google Play still needs the two narrow price repairs and the exact territory
   set repairs documented in the live preflight, followed by authenticated
   read-back. Its listing also needs deliberate seven- and ten-inch tablet
   screenshot coverage before tablet presentation is treated as store-ready.
6. iOS archive/TestFlight proof requires macOS + Xcode with the production
   signing team, capabilities, StoreKit products, HealthKit container, and
   real devices. Android purchase/integrity proof requires a Play-signed build
   and license-test account.
7. Production universal/app-link publication is closed at the web layer. The
   generator `tool/release/generate_app_link_associations.py` used the verified
   Team ID and Play **App signing key** certificate (not the upload certificate),
   emitted the two deployment files, and validated exact read-back. Cloudflare
   Worker version `a2e6fc35-e7a0-4314-9fd3-a2039047d39c` was deployed on
   2026-09-05; both direct endpoints returned HTTP 200 JSON with `nosniff`, and
   Apple CDN/Google Digital Asset Links independently returned the expected
   identities. OAuth/reset-password return still needs the installed signed
   builds; web publication is no longer that blocker.
8. Apple account lifecycle still needs a server-held authorization-code/
   refresh-token flow, Apple server-to-server notifications, and server-side
   revocation on account deletion. The implemented device credential checks do
   not replace those server obligations.
9. `20260904030000_community_post_human_moderation.sql`,
   `20260904040000_push_delivery_idempotency.sql`, and
   `20260905010000_mobile_integrity_jit_grants.sql` are local-only and
   unpublished. Their source/UI, delivery, or integrity contracts must not be
   described as production behavior until an authorized migration/function
   deployment and read-back complete.
10. Google Play Data safety and the Health apps declaration remain blocked on
    owner/legal answers plus the final signed-AAB SDK/network inventory; source
    inference alone is not an acceptable declaration.
11. Android remote push intentionally remains unavailable until a production
    Firebase app, `google-services.json`, messaging dependency/provider,
    gateway URL/secret, and real delivery test are supplied. The current
    fail-closed placeholder must not be described as an FCM implementation.

## Required release-candidate device matrix

1. iPhone + Apple Watch: fresh install, grant all, grant partial, deny, revoke,
   existing historical records, new live record, background/foreground, kill
   and relaunch.
2. iPhone: camera barcode, manual barcode, photo library, camera meal photo,
   profile photo, AI voice, meal voice; test allow/deny/revoke/interruption.
   Also test APNs foreground display plus cold, warm, and terminated-state taps,
   token deletion/unregistration, and local-notification callback preservation.
3. iPad portrait/landscape and split view: every Dashboard section, Quick Add,
   Sleep deep link, AI history/back, profile, goals, and purchase restore.
4. Android phone + tablet: Android 9–13 Health Connect app path where
   supported, Android 14+ integrated path, predictive back, rotation/freeform resize,
   camera/photo/mic/Bluetooth denial and recovery.
5. Store: Sandbox/TestFlight and Play license accounts covering success,
   pending, cancellation, interruption, restore, refund/revoke, expiry, and
   duplicate delivery.
6. Accessibility: RTL, 200% text, screen reader, reduced motion, high contrast,
   and keyboard on both large-screen platforms.

## Windows `CreateFile failed 5`

Windows error 5 means access was denied while the Flutter/Dart tool attempted to
open or create a file. It is a host/toolchain permission or file-lock problem,
not evidence of an iOS/Android application defect. The primary project session
now has working filesystem access: Flutter tests and the full analyzer started
and completed from `G:\BIL_Project\body_intelligence_log`. Some isolated worker
sessions still reported the old denial, so their result was not used as release
evidence. No broad ACL rewrite or destructive cache deletion was performed.

## Codex Remote Control setup finding

The current Codex Desktop log records the actual enrollment failure as HTTP
`403 Forbidden` with `Multi-factor authentication required`. The later
`Remote environment not found` response is a consequence of enrollment never
finishing, not a project or Windows filesystem problem. Enable an MFA method in
ChatGPT **Settings > Security > Multi-factor authentication**, then restart only
the Codex/ChatGPT desktop app and repeat **Settings > Connections > Control this
PC > Set up/Add** before scanning the QR code from the iPhone. VS Code may remain
open, but Remote setup cannot be completed from its Codex extension.

Official: [Remote connections](https://learn.chatgpt.com/docs/remote-connections),
[Enabling or disabling MFA](https://help.openai.com/en/articles/7967234-enabling-or-disabling-multi-factor-authentication-mfa).

## Validation and environment record — updated 2026-09-05

- No iOS, Windows, or web build was run for the latest repair set. The Android
  debug source build completed successfully after a clean-cache, single-worker,
  non-incremental Gradle run: **BUILD SUCCESSFUL**, 760 tasks. A follow-up
  495-task build also succeeded after forcing transitive camera declarations to
  remain optional, preventing unintended Play filtering of tablets and
  Chromebooks. The final APK at
  `build/app/outputs/flutter-apk/app-debug.apk` is 271,082,247 bytes with
  SHA-256
  `7ABADE4F5709BC2688452BF491774AC1B508BE42F49453D9827A8412135781F3`.
  Final `aapt` evidence marks camera, camera.any, autofocus, flash, microphone,
  location, GPS, network location, Bluetooth, and BLE as not required.
  It is not a Play-signed candidate, store upload, installation, or device
  result.
- HealthKit and Health Connect are separate native integrations in source.
  iOS routes through the HealthKit bridge in
  `ios/Runner/BILGlobalHealthBridge.swift`; Android routes through the Health
  Connect bridge in
  `android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt`.
  Validation of one platform does not validate the other.
- The native privacy follow-up found one material Apple declaration gap and
  closed it: `PrivacyInfo.xcprivacy` now lists
  `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`, matching the
  App Attest bridge's one-time migration from its prior app-owned UserDefaults
  key-id map into device-only, non-synchronizing Keychain storage. The plist
  parses as XML and a source contract protects the declaration while the
  migration remains in source.
- Current post-patch Flutter results on this Windows host:
  - The final native/configuration follow-up passed **22/22** Android/iOS
    release-boundary, optional-hardware, health-scope, and privacy contracts;
    the Android final-manifest verifier's positive/negative self-test also
    passed.
  - **130/130** tester-note regression tests passed across Quick Add, barcode,
    Sleep, AI Coach access/tools/history, profile photo entry points, nutrition
    goals/schedules, admin reset, Android back navigation, and phone/tablet
    Dashboard layout. This set includes the exact Quick Add dismissal and fixed
    visual-handle/independent-drag-target regression contracts.
  - **38/38** focused native Health and community-push contracts passed. They
    cover Android's 20-signal canonical parity, present-only nutrition mapping,
    history-permission fallback, provenance/echo filtering, native provider
    fail-closed behavior, and bounded cold/warm notification deep-link routing.
  - The focused iOS notification-navigation suite passed **5/5**, and the
    combined Android/iOS notification-navigation pass passed **14/14**. These
    verify delegate/bridge dispatch, explicit Dart acknowledgement, and retained
    cold-start payload source behavior, not live APNs/FCM delivery.
  - The iOS SwiftPM/permission contract passed **6/6**, and the offline
    `flutter pub get` completed with Swift Package Manager explicitly enabled.
  - **20/20** recipe-image, globally unique workout-video, and Connected Health
    contract tests passed; the separate Connected Health widget set passed
    **5/5**, the complete cloud-platform group passed **85/85**, and the
    reset-token migration contract passed **4/4**.
  - The Epic 15 store screenshot suite passed **8/8** after reviewing and
    updating the four platform-specific Connected Health baselines. A real
    double-local-translation defect for Arabic sodium, potassium, and magnesium
    was then corrected; the final rerun passed without those warnings. The
    Daily Log source-contract suite also passed **7/7**, including a new guard
    that prevents already-localized nutrient labels from being translated a
    second time.
  - All Supabase Edge Function Deno checks passed **90/90** after the final
    backend changes, including AI Coach, admin/reset, barcode/GTIN, food search,
    commerce verification, health sync, and shared contracts.
- The final full-tree Flutter run completed with **4,110 visible tests passed**.
  Its JSON runner log recorded **5,023 successful events** in total: 4,110
  visible results plus 913 hidden load events. It recorded **0 failures, 0 error
  events, and 0 skipped tests**. Evidence is retained at
  `.dart_tool/bil_full_test_20260905_final3.json`.
- Full `flutter analyze --no-fatal-infos` reported **No issues found** (zero
  errors, warnings, or infos), including a fresh rerun after the native privacy
  correction. Final `git diff --check` passed.
- The meal-voice localization contract covers all **25 supported locales × 21
  strings**. Gallery barcode picker/image failures are recoverable, and profile
  photo removal is account-isolated and covered for local/cloud/remote-only
  avatar state. The combined focused closure run containing these cases passed
  **35/35**.
- The current Terms of Service production capture was regenerated exactly and
  passed its ordinary named golden run. The baseline
  `test/visual_closure/goldens/visual_closure_terms_phone.png` is 72,722 bytes
  with SHA-256
  `8f1dea9fd244a1947105437d26555a2f95339c094392a596057cda89a55f7c84`.
  `dart run tool/visual_reference_evidence_verifier.dart` passed after metadata
  synchronization, and `visual_reference_evidence_truth_contract_test.dart`
  passed **2/2**. This is visual-source evidence, not App Store device proof.
- The final local backend hardening follow-up passed **47/47** focused Flutter
  source/widget contracts and **23/23** Deno tests, plus Deno type-checks for
  the administrator function and both push dispatcher entry points. A linked
  read-only dry-run lists exactly the three unpublished migrations above and
  no seed/role change. No migration or function was deployed.
- A no-PII production read-only preflight returned: one unique target account,
  one active administrator row, one active unexpired closed-test grant, one
  Premium AI Coach subscription, and one currently active subscription; the
  count verified within the prior 72-hour client window was zero. This confirms
  the old client gate could lock a valid active subscription. The source fix
  keeps administrator authority separate and trusts the server-owned
  lifecycle/expiry for real paid customers while still rejecting a missing or
  implausibly future `verified_at`.
- `assets/catalogs/recipes/v1` is readable again on this checkout. Its owner has
  FullControl, the manifest/index/shard paths can be enumerated, and Git no
  longer reports the catalog as deleted. No catalog content was restored or
  rewritten during this repair.
- At the recorded September 4 backend deployment checkpoint, the linked
  production Supabase migration inventory had zero mismatches and the four
  affected functions were active at the versions recorded in
  `SUPABASE_DEPLOYMENT_2026-09-04.md`; authenticated live barcode and AI Coach
  E2E checks passed. The subsequently authored community human-moderation,
  push-delivery-idempotency, and mobile-integrity migrations are
  local-only/unpublished, so the current tree and production inventory are no
  longer identical. This does not
  replace a signed-client/device retest.
- The four Connected Health release goldens were inspected, updated to the
  platform-specific Apple Health/Health Connect UI, and passed in the final
  ordinary (non-update) golden run.
