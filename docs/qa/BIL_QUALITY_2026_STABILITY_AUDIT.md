# BIL-QUALITY 2026 — Stability, Flicker and Source-Label Audit

**Scope:** isolated Flutter source changes on `qa/bil-stability-flicker-data-20261008`. This is a technical audit with a patch set, not a statement that a shipped binary is fixed.

**Integration base at branch creation:** `a5af21e56d509eaa7fcba52f7ce85a4cc458bc33` (`qa/coach-community-next-20261005`).

**Previously uploaded app source provided by product owner:** `3f0085e6e6686f2e87e9cf14789e9e578ea64159` (iOS 1.0.0 build 35, Android 1.0.0 versionCode 32). Android 32 store rejection on 2026-10-08 was for paywall-gated reviewer content and is **outside** this branch; BIL-00 separately owns store policy and release correctness.

**Do not merge or publish before review.** No changes to `main`, `qa/coach-community-next-20261005`, `qa/bil-premium-visual-2026`, Supabase Production, entitlement/payment/trial logic, or store binaries.

## Evidence vocabulary

- **Source-confirmed:** code path observed directly; a real device symptom is *not* implied.
- **Widget regression added:** a host-side test expresses the proposed behavior; result must be taken from CI, not asserted from its existence.
- **Device unverified:** profile-mode physical iOS/Android frame capture unavailable.
- **Risk / investigation:** a potential defect requiring instrumentation or user reproduction. Do not describe as already fixed.
- **Already present in base:** logic pre-dates this branch; not a BIL-QUALITY improvement.

## Submitted binaries vs integration source

Git tree analysis compared 6,371 tracked entries in uploaded source with 7,397 entries in integration base; integration was 160 commits ahead, 0 behind. The following table is based on exact blob SHA comparison, not screenshots or assumed version equivalence.

| Area / file | Submitted build 35/32 source vs integration base | Implication |
| --- | --- | --- |
| `coach_message_text.dart` | Changed | Both contained per-rune 40 ms reveal; later adjustments do not retroactively change 35/32 |
| `coach_anchored_history.dart` | Identical | Anchored scrolling was already present; its presence does not prove zero device flicker |
| `intelligence_center_message_widgets.dart` | Changed | Reaction/Report/Sources rendering changed in development, so UI must be tested separately in each binary |
| `intelligence_reference_chat_body.dart` | Absent in submitted source | This newer file cannot be used to infer behavior of submitted binaries |
| `ai_coach_settings_page.dart` | Identical | Refresh/fallback risks were present in both source revisions |
| `community_post_composer_toolbar.dart` | Changed | Current Publish button was not the same source as submitted Build 35/32 |
| `community_post_composer_page.dart` | Changed | Publication flow has evolved; validate idempotency and owner boundaries against current code |
| `dashboard_preferences_page.dart` | Changed | New editor presentation differs from submitted UI |
| `dashboard_preferences_actions.dart` | Identical | The global save guard/atomic preferences write existed before the quality branch |
| `dashboard_preferences_body.dart` | Absent in submitted source | The newer Customize Today body cannot be used to claim shipped UI behavior |
| `connected_health_model.dart` | Identical | Fallback to raw source string was in both revisions |
| `sleep_tracker_experience.dart` | Identical | Sleep source UI called the raw-source display function in both revisions |
| `app_localizations_base_catalog.dart` | Identical | Legacy Home destination label used Dashboard/لوحة القيادة in both |

**Important:** These conclusions describe repository *source*, not an inspected, cryptographically matched IPA/AAB/APK. Whether a bug manifests on the uploaded binaries needs the actual installed builds, environment and data fixtures. Google Play's paywall rejection cannot be addressed in this QA branch.

## Defect inventory and patch map

| ID | Surface / symptom | Code path and source-confirmed cause | Intervention in this branch | Evidence and remaining gate |
| --- | --- | --- | --- | --- |
| Q01 P0 | Coach Like/Dislike/Report/Sources appears to move/flash during typing | `coach_message_text.dart` built successively taller selectable text; `intelligence_center_message_widgets.dart` places actions after this text in the same Column | Reserve full text typography with an invisible non-semantic layout anchor and overlay only the visible selectable text; bound cosmetic reveal to 2.4 s for very long replies | Widget tests measure stable text size and adjacent feedback Y across frames, mixed scripts and long text. Real iOS/Android profile capture pending |
| Q02 P1 | Joined emoji split during text reveal | Iteration by Unicode runes can stop in the middle of an emoji grapheme cluster | `characters` 1.4.1 iterates full grapheme clusters; package declared directly, lock retained | Widget test checks each sampled intermediate frame ends at a full grapheme boundary. Different font/text scaling still needs device coverage |
| Q03 P1 | Reveal repeats after sliver recycle | Stable key registry was **already present** in base; `coach_anchored_history.dart` uses stable keys and center anchor | Keep existing behavior; do not replace with blunt scroll lock | Existing recycle regression retained; true app lifecycle/back navigation not certified |
| Q04 P1 | Customize Today cards flash back to old values | Stream/provider can still emit old committed value while `setMany` is pending; `dashboard_preferences_body.dart` normally follows `state.value` | Render pending section/preset values until authoritative stream agrees; rollback on failure; keep icon geometry stable | New widget tests simulate deliberately stale streams and failed write. Full manual fast-tap/RTL/reduced-motion matrix pending |
| Q05 P1 | Done Editing visually changes/disables during individual section edits | Global `_saving` guard and secondary spinner overlay; Done could look enabled but have no effect | Defer Done tap until successful individual section write, keep card badge static; **preserve existing disabled/cannot-pop contract for batch saves** | Existing batch lock test and new pending section test; Android system back and error timing still needs host/device test |
| Q06 P1 | Publish button height/label/surface changes during network request | `community_post_composer_toolbar.dart` toggled gradient, label, icon and inserted image progress bar | Single fixed-size subdued surface and persistent Publish text; 20 px icon slot for spinner; progress slot reserves height | New host test checks geometry and single pending repository call; permission, network and backend rewards still need end-to-end verification |
| Q07 P1 | AI Settings refresh shows empty/error UI after transient failure | `ai_coach_settings_page.dart` displayed `_errorState` and did not explicitly retain a verified owner-scoped fallback | Cache last verified usage per authenticated owner, show inline failed-refresh notice, preserve body, reject owner-stale async responses | Existing SDK-backed credit test remains; add network failure/owner-change adversarial widget test if CI allows; live consent readback must be verified |
| Q08 P1 | AI Coach context switches revert while save/refresh pending | Context override was reset at refresh initiation; persisted selection rendered only after `set` future | Optimistic selection, save then reconcile on successful local/remote refresh, rollback on failure | No direct host failure test yet; pending |
| Q09 P1 | Sleep/health detail displays raw JSON/device identifiers | `connectedHealthDisplaySource` fell through to `signal.source.trim()`; recognized device names from implicit `Map.toString()` concatenation | Bounded JSON and double-encoding decoding; explicit human name fields; unknown => localized generic source; do **not** alter source provenance | Tests for Apple Watch evidence, Wear OS non-misidentification, unknown maps, malformed/double-encoded values, source immutability; real HealthKit/Health Connect metadata still needs sampling |
| Q10 P2 | Dashboard label inconsistent with desired Home identity | Core `dashboard` localized lookup mapped to Dashboard/لوحة القيادة | User-facing core copy is Home/الرئيسية (fr Accueil, es Inicio, tr Ana sayfa); invalid-link return-to-home wording updated | Search additional runtime strings and accessibility labels before merge; route path `/dashboard` intentionally unchanged |
| Q11 P2 | Other screens blank during refresh despite cached value | Risk: `ConnectedHealthSignalDetailPage` uses `health.isLoading` for whole body, regardless of available prior snapshot | No patch yet. Do not mark fixed; verify with AsyncValue refresh fixture | Targeted follow-up |
| Q12 P2 | Stale response or source avatar re-fetch | General risk across asynchronous `ref.invalidate`, `FutureBuilder`, `StreamBuilder`, animations, focus and media | No app-wide certification. Current scoped fixes avoid changing BIL-UX visual identity and BIL-00 backend behavior | Route inventory + real device profiling pending |

## Tests / reproducible scenarios

### Coach

- Short reply, long multi-paragraph reply; with/without references; AR, EN, mixed scripts, joined emoji.
- Remain at tail while revealing; scroll up during reveal; read history while new reply arrives; return to tail.
- Reaction icons (thumbs, report, Sources) must stay at a stable Y for the same message during reveal.
- Like ↔ Dislike selection intentionally animates exactly once; selection must not reset due to another message build.
- Keyboard open/close, navigate away/back, foreground/background, retry and failure state.
- Exact messages should be keyed by stable ID; existing `CoachAnchoredHistory` tests cover some anchor behavior, **not** real-device timing.

### Customize Today

- Inject previously committed `Stream.value(true)` while user chooses false and repository write is deliberately deferred: displayed switch must remain false, Done unchanged, no overlay spinner.
- Resolve write and emit false: persistent UI must remain false.
- Reject pending write: rollback to true and show saved-view error.
- Batch preset write still blocks PopScope/system Back and Done during transaction (existing contract); defaults restore must remain atomic.

### Community

- Valid text, blocked empty body/photo-only caption, slow publication, simulated double tap; at most one repository call.
- Capture button size before, during and after pending.
- Failed publication retains draft and images; verify with existing draft-owner suites and backend replay.
- Do not infer rewards/AI Tokens from UI callback before persisted publication has been confirmed.

### Health provenance

- Known Apple Watch via explicit HealthKit source metadata; Watch model product code; ordinary Apple Health phone source.
- Health Connect/Wear OS **must not** be relabeled Apple Watch.
- Nested structured source without recognized name, broken JSON and `Instance of` must render a localized generic source, never source JSON.
- Double-encoded JSON with recognized `sourceName` can present it without changing the original canonical source.

### Display/accessibility and devices — required before merge

- Light/dark; all 25 configured locales; AR RTL/EN LTR; font scale 1.0/1.3/2.0; 320 px narrow/large phone/tablet.
- Real iOS/Android profile builds from *reviewed QA source* using Flutter DevTools frame timeline and frame-by-frame recording; no release/store builds or app publication.
- Scroll offset and focus continuity, screen reader announcements, keyboard IME, lifecycle resume, poor/no network, auth owner switch.
- Compare captured frame deltas and jank to accepted base; do not treat host `testWidgets` as performance proof.

## Engineering references / rationale

- Flutter 3.44.6 and Dart SDK minimum ^3.12.2 from repo CI/pubspec; `flutter_riverpod ^3.3.2`.
- Flutter official performance guidance: localize widget rebuild work, maintain stable layout, avoid unnecessary intrinsic passes, profile physical device in profile mode: https://docs.flutter.dev/perf/best-practices and https://docs.flutter.dev/perf/ui-performance .
- Flutter scroll anchoring: https://api.flutter.dev/flutter/widgets/ScrollView/center.html .
- Flutter reduced motion: https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html . iOS Reduce Motion is a distinct platform signal; do not globally disable all animation to mask unstable state.
- Riverpod `AsyncValue` refresh/reload preservation semantics: https://pub.dev/documentation/riverpod/latest/riverpod/AsyncValue-class.html .

## PR acceptance and ownership

- Base: `qa/coach-community-next-20261005`; PR remains **Draft** until format, analysis, tests, review and profile-device evidence.
- CI `verify` is triggered automatically by pull requests. Its checks and links are authoritative; **do not mark a test passed merely because the file exists**.
- BIL-00 owns backend/CI release pipeline/paywall issue and Coach/Community core logic; BIL-UX owns broader visual polish and design. Resolve conflicts and integrate only after their independent review.
- Uploaded iOS Build 35 and Android Code 32 remain **unchanged**. No production signing, build publication, or deployment in this branch.
