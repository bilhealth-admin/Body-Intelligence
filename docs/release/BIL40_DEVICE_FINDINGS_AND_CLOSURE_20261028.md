# BIL40: physical39 findings and closure register

Snapshot started 28 October 2026; physical follow-up continued 29 October local
time. This is a source-change and evidence register, not a
release approval. Physical39 and source40 results are deliberately separate.

Latest assembled-source checkpoint: HEAD
`0515b294c2836a7922258a94cf90b9b3c4a95062` plus uncommitted follow-up repairs.
The later sections below add D39-019 through D39-022, requested blue selections,
the recovered exact0515 CI receipts and the separate phone-recovery window.
They supersede earlier incomplete checkpoints only for their stated cases.
There is still no final committed40 SHA, all-green final CI, signed40 artifact,
physical40 acceptance or completed TestFlight40 upload in this register.

- Physical39 foundation: `69ebb89279f11a8da5ee8e631016a88f3d24333d`, version
  `1.0.0 (39)`, the correctly identified BIL app on the connected iPhone.
- Candidate40 branch: `codex/bil40-device-fixes-20261028`, based on that foundation.
  At this snapshot the candidate is an uncommitted working tree. No final40 SHA,
  exact-SHA CI success, signed40 IPA or physical40 acceptance is recorded here.
- The owner requires completing the remaining physical39 discovery before
  building40. USB was reconnected and the follow-up resumed; interruptions by
  other applications and phone calls are recorded separately from BIL outcomes.
  Unobserved outcomes remain incomplete. There is no claim of exhaustive
  app, network, accessibility or policy coverage.
- No main, protected38/39 ref, price, subscription right, protected purchase
  arrow or Production cloud runtime was changed for these repairs. No App Store
  submission is authorized by this register.

## Evidence boundaries

Evidence identifiers below are local filenames relative to the private physical
QA directory or the local source-QA evidence directory. Raw screenshots, logs,
health data, account identifiers and authentication material are intentionally
excluded from the repository. A local test demonstrates the stated behavior
under its actual fixtures; it does not establish a repaired installed40 result.

Local evidence checked for this snapshot:

| Evidence | Actual result | Limit |
| --- | --- | --- |
| `bil40-source-focused-03.txt` | 134 focused Flutter outcomes passed | Includes the core fixes and related regressions; overlaps other focused runs, so totals must not be added together. |
| `community-regressions-clean.txt` | 105 community outcomes passed | Supersedes an earlier failed diagnostic run; actual direction assertion was repaired in source, not removed. |
| `restore-neutral-ui-localization-test.txt` | 11 UI/localization outcomes passed | Actual Plans page interaction with controlled service outcomes; separate from Apple's physical authentication sheet. |
| Service-investigator result for `store_transaction_queue_test.dart` | 57 focused outcomes passed; one subsequent active-access/ownership case separately passed | Final full-suite result still required after the last service refinement. |
| `qa-tools-local-final.txt` | 338 QA-tool tests passed | Includes receipt, split-native orchestration and extracted real TestFlight-readiness program tests with isolated external API fixtures. Not live TestFlight availability. |
| `analyze-local.txt` | No issues in the completed analyzer run | This run preceded the last restore-service refinement; final analyzer validation is still required. |
| Full local Flutter event log | Completed with 11,204 visible successes, 3 failures, 1 error and 1 skip across 1,477 files | The failed run is preserved. Architecture, Light-contract and Sharing/Privacy Golden findings require their separate dispositions. Focused repairs do not convert this run into a full-suite pass. |
| `community-architecture-extraction-test.txt` | 82 actual Community/auth/delivery and architecture-guard outcomes passed | Includes the real messaging owner/retry/receipt behavior after extraction. Not a native-device result or final full-suite approval. |
| `conflict-consent-reason-aware-test.txt` | 11 actual conflict-control widget outcomes passed | Initial reason-aware checkpoint, superseded by the 12-outcome run and reviewed Golden disposition recorded below. Includes English/Arabic reasons, stale-scope denial, loading and failed-read behavior. |
| `independent-qa-stale-consent-after.txt` | 12 conflict-control widget outcomes passed | Adds the independently reproduced retained-grant refresh/error regression. Includes the preceding cases; do not add the 11-outcome run to this total. |
| `independent-qa-export-range-after-03.txt` | 9 export outcomes passed across the actual range page, production export gateway and command suites | Includes real SDK account-change events, delayed A → B → A, same-owner token refresh, and locked date scope during prepare/share. Local fixtures, not physical40 sharing. |
| `affected-after-independent-qa-events.jsonl` and `affected-after-independent-qa-exit.txt` | Final affected run completed with `done.success=true`, exit0 and 404 visible non-skipped successful test outcomes | This affected selection uses the independent fixes and newly resolved StoreKit package. It is not a new full-suite result or native StoreKit execution; analyzer status is recorded separately when completed. |
| `sharing-privacy-reviewed-baseline-update.txt` and `sharing-privacy-reviewed-compare.txt` | Reviewed single-baseline generation passed; a separate normal Golden comparison then passed 1/1 | Intentional unavailable-server subtitle correction, independently inspected against old/current images. No comparison tolerance or production-capture fixture was weakened. |
| `analyze-after-independent-qa.txt` | Completed full analyzer found 8 `use_build_context_synchronously` infos in export feedback after asynchronous operations | Preserved failed checkpoint: the visit helper already checked mounted at runtime, but the analyzer requires explicit local mounted guards. It is not recorded as a clean final analyzer run. |
| `independent-export-mounted-analyze.txt` and `independent-export-mounted-tests.txt` | Targeted `dart analyze lib/features/settings/local_export_range_page.dart`: no issues; the same 3 export suites passed 9/9 again | Explicit mounted checks now precede context use while preserving the owner/visit epoch checks. No lint suppression or test relaxation; a subsequent whole-project analyzer result remains separate. |
| `analyze-after-mounted-guard.txt` and `analyze-after-mounted-guard-exit.txt` | Subsequent whole-project analyzer: no issues, 32.6 seconds, exit0 | Supersedes the failed 8-info analyzer checkpoint above without deleting its evidence. Native execution and physical40 acceptance remain separate. |
| `format-after-independent-qa.txt` and `format-after-independent-qa-exit.txt` | 3,320 Dart files formatted, zero changes, 12.91 seconds, exit0 | Final formatting readback; not a substitute for behavioral tests or final-SHA CI. |
| `read-only-routing-before-03.txt` | Four actual routing/model-action assertions failed against the pre-fix implementation; the positive command control passed | Exact physical39 request was misclassified as revision, its local plan route was permitted, and a controlled unsolicited model write survived. Two earlier constructor-fixture compile errors are preserved separately and are not behavioral proof. |
| `read-only-routing-importers-final.txt` and `read-only-routing-final-exit.json` | 492/492 outcomes passed across 23 affected suites, including the unchanged architecture guard; test exit0 and targeted analyzer exit0 | Includes all direct importers of the changed intent/parser/API/plan boundary, actual Smart Plan page journeys, health/parser/date/quantity controls, and the new seven-outcome read-only corpus. This is source40 verification, not a repaired physical40 result or full final-SHA CI. |
| `read-only-routing-analyze.txt` and `read-only-routing-format.txt` | Six affected Dart files: no analyzer issues; six files formatted with zero changes | Latest scoped validation after D39-018. The earlier full clean analyzer preceded this repair and must not be represented as a full analysis of later files. |
| `analyze-final-readonly-routing.txt` and `analyze-final-readonly-routing-exit.txt` | Subsequent whole-project analyzer after D39-018: no issues, 118.7 seconds, exit0 | This supersedes the earlier pre-D39-018 analysis checkpoint; it is not native execution or final-SHA CI. |
| `format-final-readonly-routing.txt` and `format-final-readonly-routing-exit.txt` | Final formatter inspected 3,321 Dart files, zero changes, 13.53 seconds, exit0 | No formatting baseline or acceptance threshold was relaxed. |

## Finding matrix

“Source fix verified locally” below means the physical39 defect remains part of
the historical installed39 result, while the candidate40 behavior has the named
regression proof. It never converts a failed39 phone case into a passed40 case.

| ID / severity | Physical39 observation and evidence | Candidate40 behavior and responsible component | Behavioral verification | Disposition / remaining limit |
| --- | --- | --- | --- | --- |
| D39-001 / low | Verified Premium/restore remained accompanied by “Your access is updating.” Evidence: `02-apple-transaction-result.png` and activation/restore readbacks. | `lib/features/commerce/presentation/bil_store_copy.dart`: settled verification copy no longer promises a pending access update. Explicit localized settled copy covers all 25 supported locales. | `test/features/commerce/store_recovery_copy_test.dart`; actual Plans restore tests separately distinguish settled, pending, inactive, empty and unconfirmed outcomes. | Source fix verified locally. Installed40 visual confirmation pending. No entitlement or receipt-verification semantics changed. |
| D39-002 / environment dependent | Native Apple Sandbox sheet displayed generic artwork. | No speculative store or app-icon change. Signed-artifact icon validation remains in the signing workflow. | Existing artifact inventory plus observed native sheet; no causal experiment establishes the native placeholder's owner. | Unresolved environment/metadata observation, not a confirmed app-code defect. Native artwork still needs an actual Apple-sheet check. |
| D39-003 / initially unreproduced | Initial Profile → Go Premium attempts had no visible transition; transport versus routing was ambiguous. Follow-up `361-followup39-profile-entry.png` → `362-followup39-profile-premium-tap.png` opens Plans on the Free account. | No speculative navigation patch for this observation. | Actual follow-up on physical39 reproduced a successful route. | Initial failure not confirmed. One successful route does not prove every timing condition. |
| D39-004 / log only | One UIKit `SystemGestureGate` timeout during commerce scrolling. Evidence: bounded PID-scoped commerce log. | No guessed gesture-system rewrite or suppression of logs. | OS message triage; no corresponding repeatable app crash or dead route established. | Not a confirmed app defect. Retain the original diagnostic observation. |
| D39-005 / low | Review backup conflicts produced a generic failure when Nutrition and Goal backup scopes were absent; the same review worked after consent. Evidence: screenshots 91–95 and 104 plus scoped cloud readback. | `lib/features/cloud_platform/presentation/cloud_restore_conflict_controls.dart`: review is disabled with an explanation until actual optional restore scopes are available. Server consent enforcement stays intact. | `test/features/cloud_platform/cloud_restore_conflict_consent_ui_test.dart` tests actual consent combinations and taps. Existing `cloud_restore_v2_engine_test.dart` awaits resolved consent before real conflict actions. | Source fix verified locally. No consent bypass and no data reset. Physical40 optional-scope UI check pending. |
| D39-006 / low | Dark Home retained black status-bar icons, also after Steps → Home. Evidence: screenshots 122–124. | `lib/app/router/responsive_app_shell.dart`: system status/navigation icon brightness follows actual theme brightness. | `test/responsive_shell_test.dart` checks actual overlay style for light/dark shell behavior. | Source fix verified locally. Native40 status-bar appearance still needs a phone check. |
| D39-007 / low | Ordinary “Measured” and “Last 30 days” copy stayed English on Arabic Steps history. Evidence: screenshot 123. | `lib/app/localization/app_localizations_arabic_runtime.dart`: Arabic labels added; Apple Health remains its proper source name. | `test/features/connected_health/steps_history_navigation_test.dart`: actual Arabic measured-history rendering, alongside real Back/fallback navigation cases. | Source fix verified locally. Physical40 Arabic rendering pending. |
| D39-008 / unclassified | Seven native accessibility audit types ran; three flags identify a bottom 428×11 region and two broad container regions. | No audit disablement, ignored failure rule, or invented button fix. The small rectangle is consistent with the system home-indicator region; the others are Flutter-container sized, which remains an inference. | Original `privacy-accessibility-audit.txt` and manual coordinate attribution reviewed; no named actionable app element was identified by those records. | Needs element-level attribution. Neither a proven app-control defect nor an accessibility pass. |
| D39-009 / low | English post title and resumed English draft had incorrect punctuation/number direction inside Arabic UI. Evidence: screenshots 126, 129, 133. | Community post-reference widgets and composer page/rendering/reference sections now derive direction from the actual title/body content without changing surrounding RTL UI. | `community_reference_composer_v1_test.dart`: English title with leading number stays LTR in Arabic feed; resumed English title and body stay LTR in Drafts. | Source fix verified in the 105-outcome community run. Physical40 Arabic community check pending. |
| D39-010 / medium | Publishing a resumed draft created one server post but Back returned to the original editor with already-published text. Evidence: screenshots 131–136 and publication readback. | `community_post_composer_page.dart`, reference actions, and `community_member_profile_drafts.dart`: publication reconciliation reaches only the matching original editor, retaining owner/generation guards and unrelated text. | `community_reference_composer_v1_test.dart`: both same-draft and different-draft nested publication paths reconcile only the matching editor. | Source fix verified locally. No duplicate post was actually created in the original phone test. Full physical40 publication/Back path pending. |
| D39-011 / high | Installed workout library, video entry and real plan session failed. An old iOS data-container path remained in the registry although exact approved pack bytes existed in the current container. Evidence: screenshots 155–161, 253–254 and copied-metadata reproduction. | `lib/features/wellness/services/wellness_content_pack_manager.dart`: new registry entries store a portable basename. Strictly recognized legacy iOS-container entries resolve only the identity-derived file inside the current protected pack directory. Link, payload, version and release approval checks remain. | `workout_library_discovery_merge_test.dart`: relocated registry returns 302 cards using current bytes, supports the portable entry in Arabic, does not rewrite/reset the registry on read, and rejects arbitrary outside paths and traversal. Existing exact-version checks remain. | Root cause fixed and locally reproduced through the real manager. Installed39 remains blocked; repaired physical40 video playback/source/warm-up/session/completion remain mandatory acceptance checks. No phone-container rewrite was used as a workaround. |
| D39-012 / low | A non-friend recipient was selectable; actual send/retry received the correct server authorization refusal but a generic message. No message committed. | Community repository messaging mixin maps only SQLSTATE42501 plus exact `community_message_recipient_unavailable` to a typed eligibility error. New-message and chat pages explain the friendship requirement and preserve the draft. | `community_relationship_delivery_cases.dart` preserves unrelated permission errors; `community_message_retry_cases.dart` verifies eligibility feedback and retained text. | Source fix verified in community regression run. RLS, recipient authorization and friendship requirements unchanged. Positive accepted-friend physical chat remains separate coverage. |
| D39-013 / high | Default three-dataset export failed twice; Progress + Nutrition countercheck succeeded. Production exporter returns `BIL-exercise.csv`, but the command expected another name and force-unwrapped a missing entry. | `lib/features/intelligence_center/settings_commands/coach_export_command.dart`: use the producer's actual filename and raise an explicit missing-dataset error before sharing. | `coach_export_production_gateway_test.dart` uses actual `LocalDataLifecycleService` with isolated database: all three CSVs equal the real producer output; missing dataset fails before Share. `test/parallel/bil03/export_command_test.dart` uses the canonical producer name. | Source fix verified locally. Preparing exports remains separate from explicit sharing. Installed40 all-dataset export pending. |
| D39-014 / medium | Fresh Next best focus claimed no activity although Review my day had just read verified activity under the same selections. Evidence: screenshots 216, 220, 224. | `lib/features/intelligence_center/services/coach_cloud_privacy_boundary.dart`: narrowly recognize the explicit selected-BIL-context Overview starter so the outbound projection retains available selected context. Provider category consent remains authoritative. | `coach_next_focus_projection_test.dart`: English/Arabic selected-context starter retains verified activity; withheld sleep is absent; ordinary general question still receives no activity context. | Projection cause fixed and locally verified. No prompt/model/server changes. A repaired40 real Gemini response is not yet demonstrated. |
| D39-015 / high | With Sleep/habits unchecked, fresh Explain sleep used historical connected-health sleep. Actual provider reproduction showed whole activity-history rows included when Training OR Habits was selected. | `coach_context_assembly.dart` adds explicit per-field historical scoping; `coach_context_provider.dart` applies it before context leaves the provider. Training fields and sleep fields follow independent choices; unknown future fields and empty date-only rows are omitted; history remains bounded. | `coach_activity_history_privacy_provider_test.dart`: actual serialized production snapshot for training only, habits only, both, and neither. `coach_activity_history_privacy_test.dart`: manual/connected history, no mutation and unknown-field exclusion. | Source fix verified locally. Extra personal-context phone queries were paused after discovering the leak. Physical40 disclosure/serialized request and answer checks remain pending. |
| D39-016 / approved component | Segmented waiting glyph initially looked like an older loader. | Existing `BilFeatureWelcomeStatus` is the approved feature-Splash waiting component, documented in `docs/qa_next/BIL39_PURCHASE_WAITING_UI_20261026.md`. | Reviewed the approved component and purchase-waiting document; protected checkout source blobs remain unchanged. | Closed as already approved, not an app defect. No unauthorized replacement of the protected purchase CTA. |
| D39-017 / medium | Restore → native Apple password sheet → Cancel twice returned “No restorable purchases were found for this account.” Evidence: screenshots 365–368. Retry opened authentication again, so no permanently disabled restore button was established. | `verified_store_purchase_restore.dart` and `verified_store_purchase_processing.dart`: recognized cancellation becomes `restore_cancelled`; iOS void sync with no receipt callback becomes `restore_unconfirmed`, because absence of callbacks cannot prove empty history. Pending receipts stay unknown. Plans page and 25-locale store copy expose neutral outcomes. Existing canonical paid access and prior verification/ownership/finish blockers remain authoritative. | `store_transaction_queue_test.dart`: real adapter/service silent iOS restore, exact native cancellation, stream cancellation, pending receipt, prior-blocker combinations, and active-access/ownership regression. `plans_restore_neutral_outcomes_test.dart`: actual Restore tap, neutral footer/snackbar, enabled retry, no purchase/benefit invocation, late result cannot clear ownership conflict. Copy tests distinguish all 25 locales and terminal states. | Source fix verified locally; final full-suite and analyzer result after the last refinement still required. Physical40 native Cancel/retry/empty-history distinction pending. |
| D39-018 / high | Exact read-only Markdown request opened plan revision on physical39 before Gemini; no provider request for that turn. The later write occurred only after explicit test confirmation. Screenshots 433–434 and 446, plus read-only usage readback. | Explicit restriction boundary in intent classification, legacy Smart Plan fallback, deterministic parser, local-model action admission and query orchestration. Scoped positive contrasts and literal note bodies are preserved. See detailed disposition below. | Four pre-fix actual assertions failed; final 492/492 affected outcomes and targeted analyzer passed, including seven direct boundary tests and the unchanged architecture guard. | Source40 repair verified locally. Repaired physical40 behavior and exact-SHA CI remain pending; no backend deployment or confirmation bypass. |
| D39-019 / medium | Same-process bounded idle windows measured approximately 40.47493% of one CPU core for a focused unsent Coach draft, versus 0.28636% unfocused and 0.02514% on Overview. This is a real physical39 performance finding, with a keyboard-geometry caveat. | Existing Coach composer sets `cursorOpacityAnimates: false`; caret, focus, selection, draft, status messages and request behavior remain. Removes a locally demonstrated continuous opacity ticker; does not claim to diagnose Metal backpressure. | `coach_page_caret_idle_cases.dart`: EN/AR each fail before at 124/125 pending-frame slots and pass after at 0/125, while retaining visible caret phases and zero model calls. 99/99 related page/native-presentation cases passed; later combined owner/caret validation passed 263/263. | Source mitigation verified locally. Physical39 finding stays FAILED; signed40 CPU/keyboard comparison remains pending. Frame-slot counts are not native CPU or FPS measurements. |
| D39-020 / high | Frames543–555 showed repeated account-changed redaction in the test conversation while other account UI remained available. The general message-visit guard is the matching rendering path. Exact event-time cause of543 is unknown. | `intelligence_repository_visit.dart`, page and router retire old callbacks and create a fresh verified visit for legitimate same-owner database replacement, reload the same SQLite history and preserve draft/Overview selection. Foreign/null/error auth transitions remain latched closed, including A → B → A. | Actual same-owner SQLite reopen reproduction failed before. Seven adversarial owner cases, a strengthened same-file history/pending-turn control, scoped analysis and the 263/263 combined run pass. | Reproduced source defect repaired; this is not proof that DB replacement caused frame543. Physical39 redaction stays FAILED; repaired installed40 verification pending. No old action witness is revived. |
| D39-021 / medium | Physical39 frame594 said report sent, but bounded server readback found only the pre-existing open report and no new QA note. The live duplicate guard returns no inserted row for an already-open report. | `CommunityRepository.report` requires the inserted ID receipt. Empty receipt becomes a typed duplicate acknowledgement; seven existing report entry points explain that the earlier report is pending and the new note was not added. Created feedback requires a real receipt; permission, transport and malformed-receipt errors still fail. | Real Supabase SDK HTTP fixtures and actual EN/AR report UI: five receipt regressions and two duplicate-feedback regressions failed before; final 144/144 affected outcomes and 14-file analysis passed. Existing owner/visit guards and live read-own RLS were retained. | Source40 feedback fix verified locally; historical39 success toast is not evidence that the note was stored. Physical40 submit/duplicate/readback pending. No existing report, RLS or cloud policy was changed. |
| D39-022 / medium | Owner reported the Overview Premium badge disappearing/reappearing. Separate recovery frames show the badge at a point in time, not a continuous flicker trace. Two actual-provider/UI regressions reproduced quota-loading removal and subscription-error relabeling. | `coach_overview_paid_label_provider.dart` retains only an already verified, same-owner, unexpired tier for header presentation. Exact expiry, verified downgrade, sign-out and owner retirement clear it. Credit/data/action providers and real Personal plan gates are unchanged. | Both regressions failed before; final 13/13 provider/UI cases passed, including error, expiry, zero quota, downgrade, sign-out, delayed and no-render A → B → A, and no hidden polling. Four EN/AR Light/Dark header comparisons are pixel-identical during refresh; scoped analysis clean. | Source40 presentation fix verified locally. Timeout/error continuity can last only for the residual verified lease; it is not fresh online verification or a grant of paid access. Physical40 confirmation pending. |

### D39-018: a read-only answer request incorrectly opened plan revision

Physical39 screenshots `433-final39-markdown-submit.png` and
`434-final39-markdown-result.png` show the local plan screen opening after the
explicit request: “Do not change or log anything. Show a short Arabic reply with
heading, bullets and a two-row table with English exercise names and kg, plus a
WHO health link.” The owner-scoped usage readback had no provider request for
that turn, consistent with interception before Gemini. The discovered defect is
high severity routing: bare `change` inside the negation plus `exercise` later
in the request selected `revisePlan`. It is not evidence of an unconfirmed write.
The subsequent physical schedule change was saved only after the tester
explicitly used the reviewed Confirm control; that receipt is separate evidence.

Candidate40 applies an explicit global read-only/answer-only boundary in
`coach_request_intent.dart`, `bil_smart_plan_coach.dart`,
`local_coach_command_parser.dart`, `local_coach_api.dart`, and
`intelligence_query_flow.dart`. The local plan fallback cannot override that
boundary, local logging interceptors are skipped for the restricted turn, and
unsolicited model actions are excluded while its answer/Markdown remains
available. Existing action admission, pending-action confirmation, sensitive
payload validation, successful receipts, privacy categories and cloud prompts
are unchanged.

Scoped negations remove only the forbidden imperative before deterministic
matching, preserving contrasting positive requests such as “Do not log my
weight; update my goal to 60 kg” with confirmation still required. The original
conversation/model request remains intact. Existing note, life-context and
health-search commands retain literal bodies after their colon: those bodies
cannot select a plan route or overwrite the command header. A newly reproduced
interim note-body regression (`read-only-note-literal-before.txt`) was repaired
before closure; capitalization, newlines, a second colon and the explicit
yesterday date are asserted through the actual command parser.

`coach_explicit_read_only_routing_test.dart` verifies the exact physical prompt,
typed/voice normalized routes, English/Arabic restrictions, plan-sequence reset,
actual model-gateway invocation with unchanged Markdown answer and zero admitted
unsolicited writes, positive revision/logging controls, scoped contrasts and
literal note payloads. Seven new test outcomes pass within the final 492/492
affected run; intermediate failures remain preserved. Repaired installed40
behavior and exact-SHA CI remain pending. No Production deployment was required.

## Independent code-quality findings

These findings were reproduced locally or verified in the actual locked native
dependency. They are additional candidate-source findings, not newly observed
physical39 failures. The complete sanitized audit is
`G:\BIL_Project\release_preparation\bil40-20261028\independent-code-quality-qa.md`.

| ID / severity | Reproduction / evidence | Candidate40 repair | Actual verification / remaining limit |
| --- | --- | --- | --- |
| IQ-01 / high | On the actual `LocalExportRangePage`, prepare A's export and deliver a real GoTrue SDK auth event for B. A's Share control survived. A delayed prepare could also return after A → B → A. `independent-qa-export-owner-before-02.txt` preserves the failing owner-boundary assertion. | `local_export_range_page.dart` listens to the existing authoritative profile identity provider, retires only its prepared UI snapshot on identity/visit changes, and discards stale prepare/share callbacks using a captured visit epoch. Same-owner token refresh preserves an explicitly prepared export. Date-picker completion also checks mounted. No stored data or database is deleted. | Actual-page regressions in `local_export_owner_visit_test.dart` prove account change, delayed A → B → A, and same-owner refresh plus explicit share. Included in final 9/9 export outcomes. Uses actual SDK auth events with local `.invalid` fixtures, not live account disclosure. Physical40 acceptance remains pending. |
| IQ-02 / medium | Riverpod retains the previous granted consent value while refreshing or reporting an error. The actual conflict-review ListTile remained enabled; `independent-qa-stale-consent-before.txt` failed with a non-null review callback. | `cloud_restore_conflict_controls.dart` additionally requires non-loading, non-error consent and preserves reason-specific checking/unavailable copy. The service's separate consent check remains authoritative. | `cloud_restore_conflict_consent_ui_test.dart`: 12/12 PASS, including retained-data refresh/error and zero service reads from the disabled control. This proves fail-closed UI behavior; no RLS bypass or live disclosure was established. |
| IQ-03 / medium | All dates stayed enabled during pending prepare/share while date pickers and dataset checkboxes were disabled. It could change the displayed range before the old range's export returned. `independent-qa-export-range-before.txt` preserves the enabled-callback failure. | `local_export_range_page.dart` locks All dates during prepare/share, following the existing control policy. | Actual-page test checks both pending phases, gateway dates, unchanged displayed range and re-enabling afterward. Included in `independent-qa-export-range-after-03.txt`, 9/9 PASS. No callback bypass or relaxed expectation. |
| IQ-04 / high | Actual locked StoreKit 0.4.11 native `finish(id:completion:)` calls completion only when a transaction is found. A previously finished consumable absent from `Transaction.all` can leave its Dart Future unresolved on finish replay. The official upstream patch and native replay regression corroborate the source defect. | Exact official Pub resolution to `in_app_purchase_storekit: 0.4.13+1` in `pubspec.yaml` and `pubspec.lock`; exactly one package record changed, unrelated locks/SDK constraints preserved. Official archive SHA256 `8e4c0523b5bbac99e87a2d4cd9ece58958166e3ef5fa5b2ed96b2de936d89c71` matches the resolved artifact. No package cache or Pods checksum was hand-patched. | Newly downloaded Swift source confirms completion after the optional lookup; affected local Flutter selection passed after resolution. Official package requirements fit Flutter 3.44.6, Dart 3.12.2 and iOS 15. Native macOS build and actual replay/refund/purchase validation remain pending. This does not establish the cause of every observed Sandbox delay. |

StoreKit primary evidence: [official changelog](https://pub.dev/packages/in_app_purchase_storekit/changelog)
and [official native 0.4.13+1 patch](https://chromium.googlesource.com/external/github.com/flutter/packages/+/refs/tags/in_app_purchase_storekit-v0.4.13%2B1%5E%21/).
Local dependency evidence: `storekit-official-version-metadata.json`,
`storekit-minimal-pub-upgrade.txt`,
`storekit-minimal-upgrade-verification.json`, and
`dependency-toolchain-readonly-qa.md`. Native execution must not be inferred
from downloaded-source validation or mocked commerce tests.

Analyzer follow-up for IQ-01: the full post-integration analyzer produced eight
context-after-await infos because its flow analysis cannot infer mounted from
`_isCurrentVisit`. The page now explicitly checks `mounted` before using context
after prepare/share, while retaining `_isCurrentVisit` in every guard. Runtime
owner/visit protection was not weakened. The targeted file analyzer reports no
issues and the three export suites passed 9/9 again. The earlier analyzer log
remains a failed checkpoint. The subsequent whole-project analyzer then completed
cleanly in 32.6 seconds with exit0; all 3,320 formatted Dart files needed zero
changes. These final readbacks are listed separately above.

### Final read-only source review

The final workflow/orchestration and critical data-safety diff was reviewed after
the mounted-guard fix. No additional confirmed source blocker or unrelated
application change was identified in this bounded review. This is source-review
disposition, not a claim that the pending native40 execution has already passed.

- StoreKit remains pinned exactly to 0.4.13+1 in source and lockfile. Its actual
  package requirements (Dart >=3.11, Flutter >=3.41, Swift tools5.9, iOS13)
  are compatible with the pinned Flutter3.44.6/Dart3.12.2, Xcode26 and app iOS15
  configuration. The independent iPhone/iPad jobs check out the event's exact
  source and compile the resolved plugin; their historical39 labels/build
  metadata describe simulator QA, not a change to the signed39 release ref.
- All ten configured CI workflows include the40 candidate branch. The signing
  gate requires successful, complete, same-SHA push runs on that branch, every
  required job, a clean checkout, both protected purchase/glass source blobs,
  unchanged protected38 SHA and the exact-SHA cloud-readback marker. That marker
  still requires the owner's fresh published-source verification; equality of a
  repository variable alone is not evidence of new live provider inference.
- The signing branch builds the exact tested SHA with build40, verifies original
  IPA bytes, bundle/version/team/profile and native permission inventory, and
  preserves the exact signing receipt. No App Store review submission path was
  introduced. Local Git diff contains no iOS or Supabase runtime modification;
  the candidate remains separate from main and protected38/39 refs.
- Apple preflight rejects an existing build40 and requires verified prior
  internal groups. Post-upload readiness requires processing VALID, all expected
  group associations read back and an available internal beta state. Pending or
  failed Apple state is not success; retries must not re-upload the binary.
- Only the reviewed Sharing/Privacy PNG changed in the tracked image diff.
  Original/current blob identities and its separate normal comparison remain
  recorded below. Historical source/test failures remain preserved.
- Consent, Coach history field scoping, restore receipt/ownership precedence,
  export owner-visit retirement, Community draft/message fencing, and current-
  directory-only wellness pack recovery retain the safety boundaries described
  in the finding matrix. Focused local proof does not replace the final native
  or physical40 cases.

### SDK advisory disposition: Android remains separate

Direct local toolchain readback is Flutter 3.44.6 at
`ee80f08bbf97172ec030b8751ceab557177a34a6` and Dart 3.12.2 windows_x64.
The [official GHSA-frr6-h895-5pxp advisory](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp)
published 23 October 2026 identifies outbound `dart:io` TLS risk on Android,
Windows and some Linux environments before Flutter 3.47.8 / Dart 3.13.7.
It explicitly excludes iOS, macOS and web. It is therefore not an iOS40 blocker
under that advisory's scope. Before a new Android production binary ships,
the SDK must be patched and the binary rebuilt/revalidated. No broad SDK upgrade,
exploit attempt, or claim of Android closure was made during this iOS repair.

## Follow-up coverage that must remain explicit

### QA40-001: source architecture guard

The full local run genuinely failed `architecture_source_file_size_guard_test`
with store copy at 745 lines and the connections/messaging mixin at 753 lines.
The guard and its existing ceilings were retained. Community pure message
envelope/receipt validation, request-ID creation and associated exception types
were extracted without semantic changes into the 65-line
`lib/features/community/data/community_message_delivery_validation.dart` part of
the same repository library. The mixin is now 692 lines, below the ordinary
700-line ceiling. Its RPC execution, owner checks, retry behavior and delivery
identity sequencing remain together. Actual Community/auth/delivery tests and
the unchanged architecture guard then passed together: 82 outcomes. Store copy
has a separate cohesive catalog split. The original failed full run remains a
failure; final full-suite evidence must describe the final sources.

### D39-005 visual follow-up: reason-specific disabled state

The full-run `sharing_privacy_phone production capture` Golden error was a
0.93% / 3,071-pixel text difference, not overflow or a timer failure. Manual
inspection of the master, actual and isolated-difference images showed the
conflict-review subtitle was the sole changed region. That exposed a genuine
truthfulness refinement: the unavailable-server state must not instruct the
member to enable switches that are currently disabled. The control now reuses
the existing localized checking, unavailable, sign-in and Progress-consent
reasons. The optional Nutrition/Goal enable instruction appears only when the
server confirms availability but neither optional scope is granted. Existing
enabled wording and actual consent gates remain unchanged. The initial 11 widget
outcomes passed, including each disabled availability in English and Arabic,
stale-scope denial, loading-to-available transition and failed-read denial.
The independent retained-value regression IQ-02 then brought this suite to
12/12 PASS. The final pre-update normal comparison still failed at 0.93% /
3,054 pixels (`sharing-privacy-final-visual-review.txt`); the original full-run
diagnostic was 3,071 pixels. Both failed results are preserved.

The original and final images were then actually inspected. The sole altered
region is the Review backup conflicts subtitle, which now truthfully reads
“This server cannot currently confirm support. These records stay on this
device.” in the unavailable-server state, instead of offering an actionable
version decision. The final intended capture was accepted as a reviewed visual
change, not as an unexplained baseline refresh. Exactly one Golden baseline,
`test/visual_closure/goldens/visual_closure_sharing_privacy_phone.png`, was updated:

- Original Git blob at parent HEAD:
  `aed7df58109330a2398d0b341ef2063a9b87b11c`.
- Current reviewed Git blob:
  `aba39d4ca8e90b40165b74f570690f267bc08ad4`.
- Reviewed generation evidence:
  `G:\BIL_Project\release_preparation\bil40-20261028\sharing-privacy-reviewed-baseline-update.txt`,
  1/1 PASS.
- Separate normal comparison after generation:
  `G:\BIL_Project\release_preparation\bil40-20261028\sharing-privacy-reviewed-compare.txt`,
  1/1 PASS.

No Golden tolerance, test assertion, or production-capture fixture was weakened.
The normal comparison establishes agreement with this reviewed intended state;
it does not erase the historical failed full run or establish native40 behavior.

- Physical39 purchase cancellation and retry were observed through the native
  sheet. Exact-owner readback preserved credit quantities and the prior annual
  product/expiry; subscription verification revision itself advanced. Do not claim
  all subscription metadata was unchanged.
- The rapid double-tap experiment reached a visible opening-purchase state. Its
  later capture was black, then USB discovery returned no device. This does not
  prove a duplicate transaction or successful duplicate prevention. Keep that
  physical outcome incomplete; the read-only final balance is not a substitute
  for observing the complete native flow.
- Actual39 offline Community showed an explicit safe retry state, and after
  restoring network access the retry loaded posts. Offline queued writes and
  cross-device restore were not established by that read-only/reconnect exercise.
- The original Steps Back and Meal Planner → Review and log blank-screen paths
  have physical39 positive evidence. That does not prove all routes from all
  screens are free of navigation defects.
- Workout completion/no-duplicate recording is blocked on installed39 by D39-011.
  Never create a false completed exercise to make that case pass. Video source,
  warm-up, next/previous and final-session recording must run on repaired40.
- The earlier checkpoint lacked weight-target, generated bilingual Markdown and
  plan-revision observations. The later physical follow-up below supersedes that
  checkpoint only within its explicitly observed scope; source tests and earlier
  CI are never relabeled as phone evidence.
- No logout-confirmation cancellation was observed. The inspected settings
  sign-out action calls the local sign-out path directly. Preserve the current
  authenticated fixture instead of asserting a nonexistent confirmation test.
- Advertising/privacy source and signed39 inventory were audited; the explicit
  boundary uses non-personalized requests without app health/account targeting
  payload. TLS byte counters do not prove the absence of health-to-ad traffic in
  the native provider SDK. Case39 stays partial, never a network/privacy pass.
- The three native accessibility flags remain in the original evidence. No
  unconditional claim of full Accessibility, Dynamic Type, policy compliance,
  crash freedom or zero remaining bugs is made.

## Installed39 checkpoint before the reopened follow-up

The original 56-case register now contains 19 scoped PASS, 30 PARTIAL,
5 FAILED, 1 NOT_APPLICABLE and 1 BLOCKED. None remains wholly NOT_TESTED
within that original case list; this does not mean all subcases passed.
The additional confirmed D39-018 failure is retained separately and must not
be hidden by the partial Markdown-render outcome. Raw evidence remains private.

- The actual target-weight request produced a goal proposal requiring explicit
  confirmation, not a measured-weight entry. No approval was sent. The next
  actual response still read the unchanged saved current and target values.
- A real Arabic response rendered RTL heading/bullets and a two-row table with
  English labels and units. Source navigation and return to the retained chat
  worked. A directly clickable inline WHO URL was not established; case50 is
  partial, and the earlier negated request remains D39-018.
- Local schedule review was cancelled once without changing the session, then
  explicitly confirmed. The saved receipt, changed day, revision3 history and
  read-only before/after comparison were observed. No workout completion or
  meal intake was fabricated, and no cloud-plan revision or cross-device
  conflict acceptance is claimed by this local case55 result.
- The later renewal showed Apple's success and BIL's actual activation dialog.
  Purchase confirmation was performed by the owner. No entitlement/credit
  grant or pricing change was made to obtain test access.
- A Personal plan purchase gate appeared during an automation session that
  reactivated BIL before every input. Later Progress/history navigation worked
  after that helper behavior was removed, while a timestamped server read
  showed an active subscription. Premium includes this feature. The transient
  client cause is unresolved; neither a permanent access bug nor an expired
  subscription is inferred from that confounded observation.
- An unrelated notification/permission interruption prevented final context
  cleanup. Training remains temporarily OFF; the original Sleep/habits OFF,
  Nutrition/Analytics ON and photo OFF choices remain. Restoring Training ON
  was not completed and must not be reported as done. No unrelated permission
  response or foreign-application data change was made to bypass the overlay.
- At this earlier checkpoint all owned phone control was stopped. The bounded15-second process-log
  capture and crash inventory completed. Deliberately stopping the collector
  is not an application crash, and these limited logs do not prove crash-free
  operation, full Accessibility acceptance or absence of encrypted SDK traffic.

The owner subsequently requested an additional Personal plan check and phone
control resumed. The later timestamped section below supersedes the stopped
state only for its explicitly observed outcomes; it does not clear the remaining
context-restoration or performance checks by implication.

Private follow-up register and Arabic matrix/report retain these boundaries.
The earlier `physical39-20261028/evidence-sha256.json` is a historical checkpoint;
its final refresh waits until the reopened phone follow-up has actually ended.
Candidate40 local fixes remain separate from exact-SHA CI, signing and physical40.

## Build40 acceptance sequence

1. Finish physically reachable39 cases, attribute new findings, and retain
   genuine blocked/unavailable cases with their cause. The owner explicitly
   requires this before starting the build.
2. Finish local analysis, formatting, complete Flutter execution and scoped
   regression verification against the final working files; preserve failures.
3. Commit the validated candidate on the independent40 source branch. Require
   every configured final CI job on that exact SHA; old39 receipts cannot satisfy
   the40 source gate. Keep iPhone and iPad runs independent.
4. Freshly compare unchanged published cloud runtime source against committed
   sources before recording cloud-source continuity. This is not new provider
   inference proof or authorization to deploy an unrelated cloud change.
5. Build/sign40 only after the prerequisite gates pass. Verify original IPA
   identity and bytes, then upload that exact artifact once to internal TestFlight.
6. TestFlight readiness requires Apple processing `VALID`, every expected
   internal group read back, and an available internal beta state. Pending
   processing/group propagation is explicit pending evidence, not success and
   not a reason to upload a duplicate binary.
7. Install40 and close the repaired-device acceptance cases separately. No
   App Store review submission or public-release approval follows from this file.

See `BIL_IOS40_INTERNAL_CONFIGURATION_20261028.md` for branch, build, signing and
protected-source configuration. Raw evidence remains outside the repository.

## Additional Personal plan authority investigation

The historical physical39 Personal plan paywall in frame460 is preserved as an
unresolved observation, not a confirmed permanent access defect. Later frame465
shows actual Smart Plan Progress opening, and frame476 separately shows the
actual Overview Plan entry opening Targets and plan. These observations do not
establish the earlier frame's cause; the precise client authority snapshot and
provider generation at that earlier instant were not captured.

Both `/plan` and `/smart-plan` use the same
`PremiumRouteGlassGate(personalPlan)` and the same
`verifiedSubscriptionAccessProvider` used by the Overview Premium badge. There
is no additional Plus/country requirement for an existing verified member.
Pending checks produce Checking, unreadable/unverified checks produce Retry,
and a Plans offer requires a completed server-verified Free/expired decision.

The additional
`personal_plan_verified_annual_boundary_test.dart` passes1/1 using the actual
SDK, owner-fenced HTTP transport and production entitlement repository with
synthetic `.invalid` responses. An active Apple annual row is decoded through
the real access provider and real Personal plan gate at test routes named
`/plan` and `/smart-plan`; children are sentinel widgets rather than complete
plan/database pages. Actual resume triggers reload; pending same-owner refresh
does not upsell; an authority error shows Retry without Plans; successful retry
restores access; and a real SDK owner transition discards the old member's paid
state. Evidence: `personal-plan-annual-boundary-final-clean.txt`, exit0. This proves
the exercised contract, not the historical paywall's cause. No runtime source,
entitlement, expiry, price, cloud state or purchase protection was changed.

The private bounded analysis is
`G:\BIL_Project\release_preparation\bil40-20261028\personal-plan-authority-triage.md`.

### Timestamped renewal and resumed route follow-up

The reopened follow-up distinguishes actual Sandbox expiry from the earlier
unattributed gate. At 20:31:47 UTC a read-only subscription observation showed
the test membership expired at 20:23:39 UTC. Frames485-487 then showing an offer
are consistent with that measured expiry; they do not explain frame460.

After one explicit Sandbox purchase, Apple's native success sheet appeared in
frame489 and BIL's active-membership confirmation in frame492. Frame496 shows
Premium Active. A later read-only observation at 21:24:58 UTC shows an active
annual period, revision161, expiring at 21:48:43 UTC. These are actual store/server
observations; no manual entitlement, credit or expiry adjustment was made.

After a genuine phone-call interruption and explicit activation of the same
BIL process4961, frame504 shows the existing Coach Overview. A guarded Plan tap
was sent at 21:31:38 UTC; frame505 shows the actual Targets and plan page, not a
Plans offer or a sentinel test widget. My Plan and a separately controlled
background/resume case remain distinct acceptance checks. Later call-induced
guard refusals sent no input and are not BIL routing failures.

## Additional native resource-log finding / open P2

`Runner.cpu_resource-2026-10-28-192538.ips` is attributed to the installed BIL39
bundle, process4961 and exact engine UUID. It records about90 CPU seconds in a
129-second interval, approximately70 percent of one core. Its action is `none`;
this is a resource warning, not evidence that iOS crashed or terminated BIL.

The exact official engine DWARF was recovered and its UUID independently
matched. Actual native frames resolve to the Flutter raster/Impeller Metal
drawable acquisition path, including `FlutterMetalLayer.nextTexture`. That
implementation can repeatedly request a texture until its bounded deadline.
The sample does not establish what caused texture backpressure: app redraw,
keyboard/platform presentation, the OS compositor or diagnostic screen capture
remain unseparated possibilities. No speculative rendering flag, engine patch
or SDK upgrade was applied as a claimed fix.

A separate15-second actual Targets and plan idle measurement reported1.28-4.55
percent of one core and about496-498 MB physical footprint. This is a bounded
control, not an all-screen performance pass; a Coach draft comparison remains
separate. Source audit finds sending/listening indicators conditionally mounted
and reply reveal bounded, which alone does not reproduce the resource event.

The similarly named `Runner.diskwrites_resource-2026-10-28-165848.ips` belongs
to a different installed application, not BIL. Its disk-write totals must not be
reported as a BIL defect. Private evidence: `resource-ips-triage.md`, the matching
official-symbol proof and symbolicated JSONL, and
`personal-plan-idle-pid4961.jsonl`. Performance closure on the new40 binary is
not claimed by this register.

## Requested Overview conversation-entry simplification

The owner explicitly requested removal of the separate Open Coach conversation
link. In `coach_reference_workspace.dart`, the existing Coach tab and its robot
now call the existing `onChat` callback instead of a no-op. The duplicate link
and its extra spacer were removed. The parent page's conversation/Overview
state machine, Back behavior, composer, status messages, dock and cloud logic
were not changed.

The real-page test in `coach_reference_workspace_capture_test.dart` exercises
English and Arabic: it finds the labeled robot button, verifies absence of both
duplicate link translations, opens the actual conversation, enters an unsent
draft, uses header Back, verifies Overview rather than Dashboard, reopens via
Coach and verifies the draft, unchanged SQLite transcript and existing dock.
Both cases failed against the old UI and passed after this change. Existing
fixtures that used the removed control now target the real Coach button; their
original behavioral assertions remain intact.

Focused local evidence, all exit0:
- `overview-coach-entry-focused.txt`: 80/80 across the six affected suites.
- `overview-coach-entry-visuals.txt`: 8/8 English/Arabic, Light/Dark, 100%/200%
  text cases; sixteen actual Overview/timeline rasters preserved. All eight
  Overview rasters were visually inspected.
- `overview-coach-entry-conversation-golden.txt`: 1/1 actual conversation Golden
  comparison passed against its unchanged reference; no baseline was updated.
- `overview-coach-entry-contracts.txt`: 21/21, including actual Smart Plan and
  Overview finish parity, source-size architecture guard and composer contracts.
- `overview-coach-entry-analyze.txt`: all eight changed Dart files, no issues.
- `overview-coach-entry-format.txt`: eight files, no formatting changes.

Private evidence is under `G:\BIL_Project\release_preparation\bil40-20261028`.
`overview-coach-entry-source.json` records the base HEAD and scoped source hashes;
`overview-coach-entry-diff.patch` records this exact incremental scope. These are
local results on the assembled working candidate, not final committed-SHA CI or
physical40 acceptance. No commit, push, build, cloud deployment or phone action
was performed by this subtask.

## Reopened physical follow-up checkpoint

Frames513-514 show the Personal plan offer at the actual Sandbox expiry
boundary. The 21:50:07 UTC read-only server observation reports expired,
revision162, expiry21:48:43 UTC. The interrupted request516-517 is not counted as
a completed transaction. After a foreground retry, frame522 shows Current plan;
the 22:00:40 UTC server observation reports an active annual period, revision166,
verified21:58:22 UTC, expiring22:34:17 UTC. Frame523 shows the real Targets and
plan page immediately after closing the offer. No Apple-success sheet or
biometric action was captured for this latter renewal, so neither is claimed.

My Plan background/resume is now physically observed: frame530 shows the actual
saved one-week plan and today's scheduled session; the operator sent Home,
captured the real home screen531-532, and tapped BIL's visible TestFlight icon.
Frame533 shows the same My Plan, saved schedule and today's session without an
offer. No workout-completion control was pressed. The 22:26:06 UTC server
observation confirms the active period during this check. This closes this
bounded resumed-plan scenario without reconstructing the historical460 cause.

The later actual BIL process is PID6667, identified by its exact application
container in the CoreDevice process list. Do not combine its counters with the
earlier PID4961. A new15-second Overview idle capture contains16 samples,
22:28:08.826826-22:28:23.814310 UTC: interval CPU0.00376725 seconds over14.987484
seconds, approximately0.02514 percent of one core. Instantaneous maximum is
0.19123 percent; physical footprint decreases393,216 bytes. Frames534-535
confirm Overview before/after without HID actions during monitoring. This
limited low-load control does not close the historical resource warning.

USB disappeared before the chat-draft comparison; the failed input returned
DeviceNotFoundError and usbmux returned an empty list. After reconnection,
another attempted input was refused because a native phone-call keypad had
replaced BIL (frame538). No input was sent to that keypad. Focused/unfocused
chat-draft measurements and restoration of the original Training ON selection
remain incomplete at this checkpoint. Signing/build40 remains held pending the
owner-required reachable phone follow-up; final source CI remains independent.

## Later physical39 and locally repaired40 checkpoint

The earlier incomplete idle/Training paragraph is a historical checkpoint.
The later bounded measurements in
`coach-three-idle-windows-pid6667-summary.json` completed the comparison and
found D39-019; this was not a performance PASS. Training was restored ON in
frame554 and remained ON after leaving/returning in557; Sleep/habits stayed
OFF. The unsent test draft was cleared without sending in550. Original
captures and consent distinctions remain private.

Source repair evidence under the local `bil40-20261028` evidence directory:

| Scope | Files / proof | Actual result and limit |
| --- | --- | --- |
| D39-019 focused draft workload | `coach-caret-focus-mitigation-review.md`, `coach-caret-focused-before-stable.txt`, `coach-caret-focused-after.txt`, `coach-caret-affected-page-and-native.txt`; production `intelligence_reference_chat_body.dart`, test part `coach_page_caret_idle_cases.dart` | 2 actual frame-budget failures before; 2 passes after; 99 related passes. The iOS caret changes from opacity fading to timed on/off blinking. No SDK or engine upgrade. Physical40 performance remains unmeasured. |
| D39-020 same-owner visit recovery | `coach-owner-redaction-screen543-source-audit.md`, `owner-visit-recovery-isolated-proof.json`, `owner-visit-recovery-final-adversarial.txt`, `owner-visit-recovery-history-control.txt`; production `intelligence_repository_visit.dart`, `intelligence_center_page.dart`, `app_router.dart` | Real database/repository replacement reproduced redaction while mounted. Old scopes retire; a fresh same-owner visit restores real saved history and the pending user turn, retaining draft and rejecting the old late answer. Event-time543 cause remains unknown. |
| Combined earlier owner/caret/tool integration | `merged-owner-ci-validation-proof.json`, `merged-owner-caret-native-affected.txt`, `merged-ci-tools-independent-review.json` | 263/263 affected Flutter outcomes; 341/341 Python QA plus 39 Android launch/startup/diagnostic outcomes; scoped analysis, format, YAML/Bash and diff checks passed. This checkpoint precedes later report/Premium/blue additions. Counts overlap isolated runs and must not be added as unique coverage. |
| D39-021 real report receipt | `community-report-receipt-isolated-review.md`, `community-report-receipt-final-affected.txt`, `community-report-receipt-scoped-analyze-final.txt`; `community_report_receipt_repository_test.dart`, `community_report_receipt_ui_test.dart` | 144/144 affected outcomes, clean 14-file analysis, no baseline change. Duplicate acknowledgement covers all 25 locales and seven existing base-report callers. Local HTTP fixtures are separate from live RLS/readback evidence and physical40 feedback. |
| D39-022 stable tier label | `premium-overview-flicker-isolated-proof.json`, `premium-overview-postfreeze-readonly-review.json`, `premium-overview-final13.txt`, `premium-overview-scoped-analyze-clean.txt`; `coach_overview_plan_label_refresh_test.dart` | 13/13 final outcomes; 4-file analysis clean; four actual rendered header before/refresh comparisons match exactly. All four readable locale/theme combinations inspected. Related existing commerce/workspace cases contributed 49 passes in a combined run whose new hide/reopen test initially had a localization fixture error; that fixture was corrected and all 13 new cases rerun successfully. The failed checkpoint is preserved, not renamed all-green. |

The Premium label cache does not observe quota/subscription while Overview is
hidden. Its live presentation cancels its expiry timer on disposal; a hidden
31-second test adds no quota or subscription loader calls. The auth observer
retires a previous accepted source future across owner boundaries. An error or
timeout can retain a previously verified label until its exact residual paid
period ends, while access checks continue independently. No subscription,
credits, prices, receipt ownership or permissions were granted by this fix.

## Owner-requested blue actions and selected tabs

This is an explicitly requested visual change, not a newly claimed physical39
functional failure. `CommunitySapphire` supplies the existing Explore action
blue and its existing dark-mode counterpart. All six Coach actions, including
the robot, use those tokens. The profile Friend/Follow controls share them;
Add Friend has a transparent surface. Community profile Posts/Replies/Media/
Likes and Moments/Reviews use a translucent blue selection with an underline
instead of the silver selection. Actual selected-button semantics remain
merged and enabled; callbacks and relationship/report ownership checks remain.

The final nine-file isolated UI proof is `blue-ui-isolated-proof.json`, patch
`blue-ui-isolated.patch`; `BLUE_UI_ISOLATED_REVIEW_20261029.md` records the
scope. Four new selection cases failed before the repair. The related run
passed 175 outcomes, followed by 8 final-source focused cases and clean nine-file
analysis after mechanical lint cleanup. Real English/Arabic Light/Dark
captures were inspected; no Golden baseline was weakened or replaced. The
separate old seven-file blue patch is superseded. Root applied the later
nine-file UI change alongside independent Premium/header and receipt hunks;
final integrated validation is separate and pending at this documentation
checkpoint. Installed40 visuals are not yet claimed.

## Exact0515 CI: recovered host-suite proof and six failed gates

The completed push runs belong to
`0515b294c2836a7922258a94cf90b9b3c4a95062` on
`codex/bil40-device-fixes-20261028`. They do not include later uncommitted
repairs. `ci-0515-recovered-full-coverage.json` is a real recovered receipt:
eight exact-run artifacts from run40783274576 were downloaded and digest
verified, then checked against the unchanged0515 test inventory. All 1,480
host Flutter files are represented exactly once: 11,232 successes, 0 failures,
0 errors, 1 reviewed live-range skip, 0 missing/duplicate files. These counts
were recovered without rerunning Flutter. This proves that host-suite result;
it does not convert the failed verify workflow into a success or certify the
later source.

`ci-0515b294-final-failure-triage.md` preserves the six real gate failures:

| Workflow / run | Proven failed boundary | Repair / remaining evidence |
| --- | --- | --- |
| verify /40783274576 | Final whole-file artifact collector accepts only the old BIL39 branch, despite successful constituent tests. | Collector now requires one explicitly allowlisted branch and retains exact run/SHA/event/workflow/digest/ZIP controls. Real eight-shard recovery passed; final workflow execution on the new SHA is still required. |
| CodeQL extended /40783274512 | Android API33 native fixture seeks the deleted separate Open Chat row. | Two shared native fixture locators now target the existing Coach robot action; assertions, readiness and consent remain. Native final-SHA execution pending. |
| iPhone native /40783274557 | Same obsolete fixture locator; actual native compilation and execution occurred. | Same locator repair. The historical native test failure is not a signing/compiler failure and is not relabeled passed. |
| iPad native /40783274659 | Same obsolete fixture locator. | Independent iPad workflow remains required; no combined iPhone/iPad rerun or borrowed result. |
| Android startup /40783274553 | API36 System UI ANR before BIL install/launch. APIs26/29/33/34/35 succeeded. | API36 alone uses the current software-renderer option; five bounded read-only ANR diagnostics added. No retry, dismissed dialog, relaxed blank/ANR guard, SDK upgrade or asserted causal cure. Actual API36 final-SHA check pending. |
| Video delivery /40783274517 | Release-pinned public HEAD returned HTTP500 before range GET. | Later bounded read-only requests returned HEAD200 and GET206/32 bytes; this does not erase the500. Historical provider exception is unproven. The separate Worker async-boundary fix has local regression proof but no deployment or final live-delivery acceptance here. |

The other four workflows succeeded within their scopes: isolated Coach cloud
source, supplementary security fixtures, native Coach presentation and Crystal
focused. Neither they nor the 11,232 host passes establish live Gemini service
health, native purchase/HealthKit success or final40 approval.

`ci-tools-isolated-proof.json` records the eleven-file tool repair and
`merged-owner-ci-validation-proof.json` records its earlier combined local
validation. Branch strictness is preserved; API36 diagnostic queries are
bounded to 8 seconds each and 512 KiB saved per stream, with truncation recorded.
`worker-async-rejection-isolated-proof.json` and its review record 77/77
isolated Worker outcomes, clean TypeScript and existing checks. Awaiting
delegated responses puts asynchronous storage/cancel errors inside the real
error boundary; it neither identifies nor fixes the underlying historical
public HEAD500 cause. This Worker change is prepared locally, not deployed.

## Separate Windows/iPhone recovery window and signing source audit

The recovery subset `resume-20261029-c-recovery-608-612` is distinct from the
earlier G-drive operator window. Its helper identifies SDK11.43.1 and the
copied bytecode is Python3.15; original G metadata identifies SDK11.44.0 and
the prior Python3.14 window. Eight recovery files were copied without
overwriting the originals, with all source-before/destination/source-after
SHA256 values equal. `copy-proof.json`, `ledger-checkpoint.md` and
`reviewed-event-chain-v2-raw-iso.json` preserve that chain. No credentials or
raw account data belong in this repository.

Frame609 shows Coach entry waiting,610 settled Overview,611 the revealed My
Plan tab and612 the actual saved active one-week plan. Spacing between these
captures is not app response time; the earlier runtime reset and unavailable
G drive break continuity. These images prove this bounded recovered route,
not a new purchase, a fresh entitlement server read, absence of transient
badge flicker, or completion of later meal/device tests. Those remain owned
by the ongoing physical follow-up rather than this source audit.

The read-only signing audit inspected `bil40_internal_testflight.yml`,
`bil40_internal_build_ci.py`, `bil40_internal_signing_manifest.py`, release
configuration validation and final artifact identity handling. No new
hardcoded39-only source gate, wrong40 output path or inconsistent build number
was identified in this bounded review. Older39 filenames/job labels describe
reused exact-source simulator QA. The40 signing workflow intentionally runs
on `codex/bil40-internal-testflight-20261028` at the same immutable SHA whose
completed push runs must pass on `codex/bil40-device-fixes-20261028`; they are
different branch roles, not permission to use a different SHA.

Build40, bundle/version, original IPA digest, signing/permission inventory,
generated exact-source acceptance receipt, Apple processing and expected
internal groups remain required. The cloud-source SHA variable needs fresh
operator evidence of deployed-source comparison at the final committed SHA;
the variable alone cannot prove runtime health. This review did not execute
signing, inspect current secret availability, set that variable, dispatch CI,
publish cloud code, upload to TestFlight or submit App Store review.

## Latest merged local verification checkpoint

The assembled working candidate at HEAD
`0515b294c2836a7922258a94cf90b9b3c4a95062` plus the documented source repairs
completed one combined targeted command: **421/421 passed across 16 distinct
test files**, exit 0. This covers the blue UI, report receipts, Premium label,
Coach lifecycle/owner/caret and native-chat presentation paths with overlapping
test files deduplicated. All 34 changed Dart files passed `analyze --fatal-infos`
with no issues; formatting reported 34 files and zero changes; diff checks passed.

The 45 source hashes match before/after that run. Earlier non-blue repairs remain
preserved, including all prior lines in the two overlapping Premium files.
All 20 focused blue UI renders match the already reviewed images by SHA256;
no Golden baseline was replaced. Evidence identifiers:
`blue-shared-merge-snapshot/merged-blue-report-premium-validation-proof.json`,
`combined-targeted-tests.txt`, and `all-changed-dart-analyze.txt`.

This supersedes the earlier pending integrated-local checkpoint only for those
stated checks. Final committed-SHA CI, signed40, physical40 acceptance and
TestFlight40 upload are still separate and are not claimed by this result.
