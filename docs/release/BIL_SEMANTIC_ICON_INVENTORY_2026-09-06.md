# Semantic-icon inventory recheck — 2026-09-06

## Scope

This source inventory was captured at `2026-09-06T04:40:32Z` and its repair
status was rechecked at `2026-09-06T05:01:27Z` for R-093 and the visual
direction in IMG_7806. It distinguishes functional entry
icons from status, error, selection, overflow, search-field, media-control, and
brand treatments. No Flutter command or visual runtime was executed for this
recheck, so this document does **not** claim pixel parity on iPhone, iPad,
Android phone, or Android tablet.

The reference is used for its clear function-to-glyph treatment: food search,
linear barcode, voice, meal camera, water, weight, and exercise must not collapse
to the same generic symbol. Its MyFitnessPal wordmark and protected assets are
not implementation inputs and must not be copied.

## Current central contract

`lib/app/theme/bil_semantic_icons.dart` currently defines 52 functional kinds,
platform-specific Material/Cupertino glyph resolution, light/dark semantic
accent and container colors, solid-accent foreground contrast, route mapping,
and health-signal mapping. The exact post-repair app-wide source scan finds
**61 consumer files**, not the historical 19-file count still quoted in the
traceability row. The raw matcher finds 62 files; one is the central contract
definition itself and is excluded from the consumer count.

Current consumers by area:

| Area | Consumer files | Current paths |
| --- | ---: | --- |
| App shell / Quick Add | 2 | `lib/app/router/bil_quick_add_sheet.dart`; `lib/app/theme/bil_navigation_icons.dart` |
| Ads, challenges, commerce | 3 | `advertising_privacy_page.dart`; `challenges_page.dart`; `premium_logging_intro_page.dart` |
| Community | 5 | `community_connections_page.dart`; `community_hub_page.dart`; `community_notifications_page.dart`; `community_safety_page.dart`; `community_taxonomy_sheet.dart` |
| Connected health | 3 | `connected_health_components.dart`; `connected_health_page.dart`; `steps_settings_page.dart` |
| Daily check-in / Daily Log | 12 | `daily_check_in_page.dart`; `daily_log_capture_actions.dart`; `daily_log_meal_entry_components.dart`; `daily_log_meal_entry.dart`; `daily_log_meal_search.dart`; `daily_log_mutation_actions.dart`; `daily_log_navigation_actions.dart`; `daily_log_page_actions.dart`; `daily_log_page.dart`; `daily_log_input_sections.dart`; `daily_log_meals_list.dart`; `quick_macro_entry_dialog.dart` |
| Dashboard | 7 | `dashboard_page.dart`; `dashboard_preferences_catalog.dart`; `dashboard_preferences_page.dart`; `dashboard_meals_timeline.dart`; `dashboard_reference_goal_components.dart`; `dashboard_reference_phone.dart`; `dashboard_water_card.dart` |
| History / progress | 3 | `history_page.dart`; `progress_page.dart`; `progress_page_components.dart` |
| AI Coach | 5 | `ai_coach_settings_components.dart`; `ai_coach_settings_page.dart`; `intelligence_action_flow.dart`; `intelligence_center_message_widgets.dart`; `intelligence_conversation_history.dart` |
| Life context | 1 | `life_context_page.dart` |
| Notifications | 2 | `notification_settings_actions.dart`; `notification_settings_page.dart` |
| Nutrition | 5 | `nutrition_pathways_page.dart`; `food_catalog_overview.dart`; `meals_recipes_components.dart`; `meals_tab.dart`; `recipes_tab.dart` |
| Profile | 2 | `premium_profile_actions.dart`; `premium_profile_components.dart` |
| Settings / privacy / support | 7 | `help_center_page.dart`; `location_settings_page.dart`; `reference_goals_page.dart`; `reference_settings_home_page.dart`; `settings_page.dart`; `sharing_privacy_settings_page.dart`; `trust_support_page.dart` |
| Wellness | 4 | `sleep_tracker_experience.dart`; `wellness_learn_page.dart`; `wellness_library_page.dart`; `workout_entry_chooser_page.dart` |

Paths in the table are relative to their area's `lib/features/...` directory
except for the two explicitly app-level paths.

## IMG_7806 functional comparison

| Reference meaning | Current BIL contract | Source result |
| --- | --- | --- |
| Log food | `foodLog` | distinct magnifier/search glyph |
| Barcode scan | `barcode` | linear barcode viewfinder on iOS and Android; not a QR glyph |
| Voice log | `voice` | microphone glyph |
| Meal scan/photo | `mealPhoto` | camera/viewfinder glyph |
| Water | `water` | water drop glyph |
| Weight | `weight` | body-scale glyph on both platforms; iOS does not use a speedometer gauge |
| Exercise | `exercise` | fitness/flame platform glyph |

Quick Add consumes the contract directly at
`lib/app/router/bil_quick_add_sheet.dart:63-99` and resolves platform glyphs and
semantic colors at `:208-242`. Its first four visible actions correspond to BIL
food log, barcode, voice, and meal-photo behavior. The current secondary BIL
actions are exercise, notes, and food search; therefore source proves semantic
icons for the actions BIL currently exposes, but it does **not** prove literal
action-inventory parity with IMG_7806's Water/Weight/Exercise lower list.

No `myfitnesspal`, `my fitness pal`, or `mfp` reference is present under current
`lib/**` or `assets/**`. This textual scan cannot prove the visual content of
every opaque raster asset. The approved BIL identity must still be checked in
runtime screenshots rather than inferred from filenames.

## Implemented repairs awaiting final runtime confirmation

| Severity | Surface | Exact source evidence | Current state |
| --- | --- | --- | --- |
| P1 repair | Nutrition-pathway Premium badge | `lib/features/nutrition_plans/presentation/nutrition_pathways_page.dart:268-321`; rendered in the hero card and compact row | Implemented: the Premium branch now uses `BilSemanticIcons.subscription` and always renders a visible localized `Premium` / `مميز` label; Free remains a visible lock-open + localized Free label. Access gating and tap behavior are unchanged. The first root run found only an invented test fixture ID (`smart-fat-loss` versus the catalog's `cutting`), not a source defect; the test now derives keys from `smartFatLossPathway.id` and `carbCyclingPathway.id`. Its rerun is pending. |
| P1 repair | Help Center navigation rows | `lib/features/settings/help_center_page.dart:78-260` | Implemented: all seven rows render `BilSemanticIconBadge` with Support, Legal, Preferences, Account deletion, or Health semantics and platform-aware glyph resolution. Exact About, FAQ, Troubleshooting, and Service Status glyph overrides retain their distinct meanings. All original action closures remain unchanged. The focused Help mapping and central-contract tests passed in root session `74758`; the combined run reported 11 passes and one nutrition-fixture failure described above. |
| Evidence | App-wide runtime parity | `test/bil_semantic_icons_test.dart:270-311` source-checks 13 named major surfaces, while the current source inventory contains 61 consumer files | The test is a valuable regression subset, not an exhaustive screen inventory or golden proof. R-093 cannot be honestly called 100% visually closed from it. |

## Post-repair source review

- Nutrition hero placement uses `PositionedDirectional(end: ...)`, the page
  heading uses `AlignmentDirectional.centerStart`, and the badge Row inherits
  ambient text direction. The label is flexible, single-line, and ellipsized
  inside bounded widths (132 hero / 112 compact), so it cannot expand the
  trailing Row without limit. The corrected widget test exercises English and
  Arabic at 160% text scaling and explicitly reaches the compact row; its rerun
  remains pending. The badge is not a separate control: the surrounding
  `InkWell` or `ListTile` owns the full tap target.
- Help keeps `ListTile.leading` and `ListTile.trailing`, which swap placement
  under RTL. Flutter marks both `Icons.chevron_right_rounded` and
  `Icons.arrow_back_rounded` with `matchTextDirection: true`, so their glyphs
  mirror with direction. Each row retains `minTileHeight: 72`; the fixed 42 px
  decorative badge does not constrain the flexible title. The central badge
  resolves Material versus Cupertino glyphs from `ThemeData.platform` and its
  colors from brightness. Its icon is excluded from duplicate screen-reader
  output while the unchanged ListTile title remains the action label.
- Source diff comparison confirms the actions are still: About dialog; FAQ
  `/help/faq`; support email; Terms `/legal/terms`; Troubleshooting dialog;
  Delete Account `/help/delete-account`; and Service Status dialog. No access,
  routing, email, dialog, or subscription behavior changed.
- The shared subscription glyph is the existing neutral
  `BilSemanticIcons.subscription`; the central contract does not currently
  define a separate Cupertino access glyph or semantic color kind. Existing
  gold/green access treatments were retained, avoiding an unrelated entitlement
  or upsell redesign.

## Generic-looking cases that are not current production conflicts

- `reference_settings_home_page.dart:234-246` has a defensive Cupertino circle
  fallback, but every one of its nine current `_SettingsRow` routes at `:51-90`
  resolves through `kindForRoute`; the circle is not reached by present
  callsites.
- `daily_log_input_sections.dart:638-655` maps every current body-context key to
  a specific glyph. Its ellipsis is an unknown-value fallback, not the icon for
  any selectable current option.
- `fasting_timer_components.dart:16`,
  `sleep_tracker_education.dart:235`, onboarding choice circles, and dashboard
  completion circles are bullets/status/selection indicators. Converting them
  into category badges would change their meaning.
- Grid/list toggles, overflow ellipses, chevrons, Back/Close, Retry, destructive
  actions, verified/error states, search-field adornments, and video controls
  are controls or states rather than feature-entry identities and intentionally
  remain outside the badge contract.
- Emoji in `bil_notification_service.dart:686-707` and
  `bil_daily_notification_grouping.dart:101-106` is notification copy, not a
  Flutter navigation/entry icon. It should be handled as a separate copy-policy
  decision if the owner later requires emoji-free notification titles.

## Existing source-test coverage and truthful boundary

The current tests cover distinct core glyphs, per-platform fallbacks, 3:1 icon
contrast, RTL/LTR and phone/tablet layout matrices, badge semantics, Quick Add
solid-accent foregrounds, and a 13-file major-surface source guard. Focused Help
mapping coverage has passed. The corrected nutrition badge test covers English
and Arabic at 160% text scaling, both hero and compact-row badges, but its rerun
is pending. A release claim still needs current golden or simulator captures
for the 61-file consumer set, both brightness modes, both directions, and
phone/tablet layouts. Source and widget tests alone do not prove visual parity.

## Final focused verification

Root session `28608` passed **17/17 tests, exit 0** across the nutrition badge,
Help locale/platform mappings, central semantic contract, and existing
nutrition access-policy suites. The two earlier failures were fixture errors:
an invented pathway ID and scroll position retained when the same test tree
changed locale after inspecting the lower compact row. The corrected fixture
uses the real catalog IDs and a fresh keyed screen for each locale. It still
asserts both hero and compact badges at 160% text in English and Arabic.

Scoped Dart analysis of all four changed source/test files then reported
**No issues found**, exit 0 (`session 46806`). These results supersede the
pending-rerun notes above; no native-device or app-wide pixel-parity claim is
made. No access rule, route, action closure, brand asset, or store state changed.

## Current decision

`SEMANTIC_ICON_CONSUMER_FILES=61`

`HISTORICAL_19_FILE_COUNT=STALE`

`IMG_7806_CORE_FUNCTION_GLYPHS=SOURCE_CONFIRMED`

`OLD_MFP_TEXTUAL_REFERENCE_IN_LIB_OR_ASSETS=NOT_FOUND`

`CONFIRMED_OPAQUE_PREMIUM_DOT=IMPLEMENTED_TEST_PASSED`

`HELP_CENTER_CENTRAL_CONTRACT_BYPASS=IMPLEMENTED_TEST_PASSED`

`APP_WIDE_VISUAL_PARITY=NOT_YET_PROVEN`
