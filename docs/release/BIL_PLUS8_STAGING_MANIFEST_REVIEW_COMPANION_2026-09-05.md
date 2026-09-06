# BIL +8 Staging Manifest REVIEW Companion — 2026-09-05

## Authority and boundary

This is a companion correction for the 172 rows classified `REVIEW` in
`artifacts/release/BIL_PLUS8_STAGING_MANIFEST_2026-09-05.csv`. It does not
rewrite that historical CSV, its date, or its original counts. The CSV still
contains 1,927 rows: 552 `INCLUDE`, 1,203 `EXCLUDE`, and 172 `REVIEW`. Its
SHA-256 remains
`73a3df5eeaf663bbadbe8a00fc69bfff0b577c0ed7efd392cee8f42feefe146a`.

The decisions below are the proposed disposition for the next regenerated,
frozen release manifest. `EXCLUDE` means preserve in the shared worktree but do
not stage into the release candidate. It does not authorize deletion.

The audit and the two narrowly authorized contract corrections performed no
Git staging, commit, push, release build, signing, upload, deployment, delete,
move, or historical-manifest rewrite.

## Verdict

| Historical REVIEW group | Rows | Proposed INCLUDE | Proposed EXCLUDE | Remain REVIEW |
|---|---:|---:|---:|---:|
| Visual baselines and their Dart tests | 93 | 73 | 5 | 15 |
| Video authoring/output paths | 67 | 2 | 65 | 0 |
| Local preview WAVs | 5 | 0 | 5 | 0 |
| Repository-wide controls | 3 | 2 | 1 | 0 |
| Generated visual evidence | 2 | 2 | 0 | 0 |
| Out-of-scope macOS generated file | 1 | 0 | 1 | 0 |
| Vendored Android manifest | 1 | 1 | 0 | 0 |
| **Total** | **172** | **80** | **77** | **15** |

This closes 157 of the 172 historical `REVIEW` rows. The remaining 15 are all
visual-closure PNGs whose current reference-truth rows still report
`unmatched_until_human_or_pixel_review_passes`; a contact-sheet inspection is
useful evidence but is not a substitute for their named ordinary golden run or
an accepted equivalence row.

## Visual baseline audit

The 93 rows contain 91 PNGs and two Dart test sources. All 91 PNGs decoded,
retained the same pixel dimensions as their `HEAD` counterparts, and had no
blank/uniform-image signature. Every image was reviewed in contact sheets. The
current files were also compared by SHA-256, dimensions, and pixel-difference
metrics against `HEAD`. Sixty-five current PNGs match an existing generated
`*_testImage.png` byte-for-byte; that confirms capture provenance, but a
failure-directory image is not itself approval.

| Subgroup | Rows | INCLUDE | EXCLUDE | REVIEW | Basis |
|---|---:|---:|---:|---:|---|
| `test/features/commerce/goldens/**` | 6 | 6 | 0 | 0 | Coherent reviewed purchase surfaces; the recorded complete commerce regression passed 169/169. These remain narrow review attachments/internal baselines, not public store screenshots. |
| `test/features/onboarding/goldens/**` | 9 | 9 | 0 | 0 | Decodable, dimension-stable, visually coherent localized/large-text baselines; bundled visual sources are first-party/repository-governed. |
| `test/goldens/epic15_*` | 31 | 31 | 0 | 0 | Internal cross-platform regression baselines. The platform-parity record reports the final Epic 15 suite passed 8/8 after platform-specific baseline review. This does not promote them to public App Store/Play screenshots. |
| `test/goldens/premium_dashboard_*` | 4 | 4 | 0 | 0 | Decodable, dimension-stable phone/tablet/desktop regression inputs with coherent responsive content. |
| `test/goldens/workouts/**` | 2 | 2 | 0 | 0 | Decodable, dimension-stable LTR/RTL regression inputs with no unlicensed external media embedded. |
| `test/visual_closure/goldens/**` | 39 | 19 | 5 | 15 | Sixteen paths have only accepted truth-matrix rows; three reachable settings captures passed the new targeted capture/uniqueness contract. Five stale duplicate settings names are excluded. Fifteen unmatched paths remain open below. |
| `actual_data_pages_golden_test.dart` and `visual_defect_regression_test.dart` | 2 | 2 | 0 | 0 | Versioned deterministic test source, not media output. |

The 19 `visual_closure` PNGs proposed for `INCLUDE` are:

- `visual_closure_connected_health_compatibility_phone.png`
- `visual_closure_connected_health_offline_phone.png`
- `visual_closure_connected_health_permission_phone.png`
- `visual_closure_connected_health_unavailable_phone.png`
- `visual_closure_connected_health_update_required_phone.png`
- `visual_closure_dashboard_phone_2.png`
- `visual_closure_dashboard_phone_3.png`
- `visual_closure_dashboard_phone_4.png`
- `visual_closure_dashboard_phone_5.png`
- `visual_closure_dashboard_phone_6.png`
- `visual_closure_privacy_policy_phone.png`
- `visual_closure_settings_phone.png`
- `visual_closure_settings_phone_3.png`
- `visual_closure_settings_phone_4.png`
- `visual_closure_sharing_privacy_phone.png`
- `visual_closure_sleep_trend_phone.png`
- `visual_closure_store_plans_phone.png`
- `visual_closure_store_plans_phone_2.png`
- `visual_closure_terms_phone.png`

All are under `test/visual_closure/goldens/`.

### Settings pagination defect and correction

The audit found a real capture defect before changing it: settings pages 4
through 9 all had SHA-256
`e9280b06368215ae3372bd0b01362cd298ec8caf06bc0a085d50e5cb41d16d9e`.
The test kept dragging after the only `Scrollable` reached its terminal
viewport and then saved that same viewport under new page names.

At the audited 390×844 surface there are four reachable capture viewports: the
initial viewport plus three forward scrolls. The authorized correction:

- limits generated settings captures to the reachable `main`, `2`, `3`, and
  `4` files;
- asserts after every drag that `position.pixels` strictly increased;
- hashes all four reachable baselines and fails closed if any two are equal;
- maps the future reference-truth `export` evidence to page 4 and limits the
  generated settings candidate list to pages 1–4.

The targeted update run selected five tests and changed zero golden hashes. The
same five tests then passed without `--update-goldens`. The reachable baseline
hashes are distinct. The stale page 5–9 files were not deleted or moved; they
are proposed `EXCLUDE` rows:

- `test/visual_closure/goldens/visual_closure_settings_phone_5.png`
- `test/visual_closure/goldens/visual_closure_settings_phone_6.png`
- `test/visual_closure/goldens/visual_closure_settings_phone_7.png`
- `test/visual_closure/goldens/visual_closure_settings_phone_8.png`
- `test/visual_closure/goldens/visual_closure_settings_phone_9.png`

### Visual rows that remain REVIEW

These 15 paths retain `REVIEW` until their named ordinary golden tests pass on
the frozen tree or their truth-matrix rows gain accepted equivalence evidence:

- `test/visual_closure/goldens/quick_add_ar_dark_phone.png`
- `test/visual_closure/goldens/quick_add_en_light_phone.png`
- `test/visual_closure/goldens/visual_closure_ai_coach_conversation_phone.png`
- `test/visual_closure/goldens/visual_closure_daily_log_empty_phone.png`
- `test/visual_closure/goldens/visual_closure_dashboard_nutrient_goal_card_phone.png`
- `test/visual_closure/goldens/visual_closure_dashboard_phone.png`
- `test/visual_closure/goldens/visual_closure_diary_settings_phone.png`
- `test/visual_closure/goldens/visual_closure_diary_sharing_phone.png`
- `test/visual_closure/goldens/visual_closure_food_catalog_phone.png`
- `test/visual_closure/goldens/visual_closure_more_lower_phone.png`
- `test/visual_closure/goldens/visual_closure_profile_goals_phone.png`
- `test/visual_closure/goldens/visual_closure_profile_phone.png`
- `test/visual_closure/goldens/visual_closure_quick_nutrition_form_phone.png`
- `test/visual_closure/goldens/visual_closure_sleep_phone_2.png`
- `test/visual_closure/goldens/visual_closure_sleep_phone.png`

The Epic 15 images are still classified as internal regression inputs even
where a separate reference-equivalence row is unmatched. Source-control
inclusion of a deterministic test baseline and acceptance as store/device
proof are distinct decisions.

## Video and media audit

### Splash motion: 2 INCLUDE, 46 EXCLUDE

Only these two `videos/bil-splash-motion/**` paths are proposed `INCLUDE`:

- `videos/bil-splash-motion/index.html`
- `videos/bil-splash-motion/render-manifest.json`

The tracked `test/splash_video_contract_test.dart` consumes both. The
composition establishes the exact BIL wordmark/color/font identity, and the
manifest pins the runtime MP4 and fallback identity image. The ordinary test
passed 2/2 and verified a 1080×2400 H.264 asset, 60 frames at 30 fps, 2.0
seconds, no audio stream, fast-start atom order, 119,574 bytes, and SHA-256
`15145a4fc414df7fe59597c0adaa83a94e6f1c54c5ba33b3e61995525884646d`.

The composition contains no external audio or video reference. The brand
identity is first-party, and the retained Montserrat font has the repository
OFL file `assets/fonts/OFL-Montserrat.txt`. Visual inspection of the splash
proof frames showed a coherent blue/white BIL wordmark and intentional final
hold frames.

The remaining 46 splash paths are authoring configuration, duplicate identity
media, snapshots, raw decoded samples, contact sheets, and render proofs. They
remain useful local evidence but are not required by the Flutter runtime or the
tracked release contract, so they are proposed `EXCLUDE`.

The source-hygiene classifier now applies an exact two-path allowlist before
the broad `videos/bil-splash-motion/**` exclusion. Its contract test proves the
allowlist shape and ordering. A focused in-memory invocation of the actual
PowerShell `Classify-Path` function over all 48 historical splash rows returned
exactly 2 `INCLUDE` and 46 `EXCLUDE`.

### Product-launch project: 19 EXCLUDE

All 19 `videos/bil-product-launch/**` rows are proposed `EXCLUDE`. The project
brief/source audit still records missing approved fresh Build 5 captures and
blocked narration/music sourcing. Its capture manifest is planning evidence,
not a completed licensed store deliverable. No product-launch authoring file or
proof is consumed by the current app candidate.

### Local preview WAVs: 5 EXCLUDE

All five `tool/bil_mic_*_preview.wav` rows are local audition files and are
proposed `EXCLUDE`. They are 44.1 kHz mono signed 16-bit PCM and approximately
0.140 seconds each. The two vibration previews are redundant byte copies of
the runtime platform assets:

- open vibration SHA-256
  `d47c6c2777399a2795a219f18774eeae9ac2a3d3fabfce030db9267c10ab9c5e`
  matches both Android and iOS;
- end vibration SHA-256
  `e29f1afff253816438fdb973878a3b8d51e9b4b081bc8bb813ecd3e93518e565`
  matches both Android and iOS.

The other three previews have no runtime reference. The actual candidate
sounds remain under `android/app/src/main/res/raw/` and `ios/Runner/`.

## Controls, generated evidence, and vendor row

| Path/group | Decision | Evidence |
|---|---|---|
| `.gitignore` | INCLUDE | Adds exact ignores for the two generated public association outputs. Release tests require those files to remain generated only from real production identifiers. |
| `.gitattributes` | INCLUDE | Marks only `assets/catalogs/recipes/v1/recipe-thumbnails-v4.json -text`, preserving the byte-pinned catalog across line-ending environments. |
| `skills-lock.json` | EXCLUDE | Locks a local HyperFrames/product-launch skill and is workstation authoring metadata, not app release source. |
| `artifacts/release/visual_closure/reference/visual_reference_coverage.csv` | INCLUDE | Deterministic tracked input consumed by launch-readiness visual-reference tests and the verifier. |
| `artifacts/release/visual_closure/reference/visual_reference_manifest.json` | INCLUDE | Deterministic tracked input consumed by launch-readiness visual-reference tests and the verifier. |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | EXCLUDE | Generated macOS registration for `sign_in_with_apple`; macOS is outside the iOS/Android +8 candidate. Regenerate it when macOS is deliberately in scope. |
| `tool/vendor_app_links/android/src/main/AndroidManifest.xml` | INCLUDE | Removes the obsolete manifest `package` attribute while `android/build.gradle.kts` supplies `namespace = "com.llfbandit.app_links"`. The app uses this local path dependency; the vendored source retains its Apache-2.0 license. |

`dart run tool/visual_reference_evidence_verifier.dart` passed in check mode:
177 artifacts, 44 approved-equivalence rows, 34 external-pending rows, 35
production files, and 161 unique visual-evidence files.

## Duplicate and integrity findings

Across the 172 historical review rows, SHA-256 grouping found seven duplicate
groups covering 22 rows:

- one six-row visual group was the settings pagination defect above;
- the other 16 rows are media-workspace duplicates: repeated splash hold
  frames, three empty `.gitkeep` files, and duplicated `AGENTS.md`/`CLAUDE.md`
  authoring instructions.

Those 16 media rows all fall inside the proposed exclusions. No duplicate group
requires adding another runtime asset.

All 172 historical paths existed during the audit. No content scan disclosed a
credential or secret, and no report evidence includes sensitive local values.

## Verification record

| Check | Result |
|---|---|
| Targeted settings golden update (`main`, pages 2–4, uniqueness guard) | 5/5 passed; zero golden hash changes |
| Same targeted settings run without update mode | 5/5 passed |
| Splash video contract | 2/2 passed |
| Source-hygiene classifier contract | 3/3 passed |
| Focused actual classifier over the 48 splash rows | 2 INCLUDE / 46 EXCLUDE; exact-path contract passed |
| Visual-reference evidence verifier | Passed with the counts above |
| PowerShell parse of `create_visual_reference_truth_matrix.ps1` | Passed |
| Full source-hygiene `-NoWrite` | **Gate remains open.** It stopped fail-closed on 114 pre-existing unclassified dirty paths: 91 local Supabase-probe paths, 19 incomplete product-launch paths, plus `.gitignore`, `.gitattributes`, `macos/Flutter/GeneratedPluginRegistrant.swift`, and `wrangler.site.jsonc`. No manifest was written. |
| Historical CSV SHA-256 after corrections | Unchanged |

The shared tree continued to contain unrelated work from other tasks. A final
clean/frozen candidate must rerun the selected ordinary golden suites and the
source-hygiene dry run after its broader unclassified-path policy is reconciled.
The focused splash-classifier result is not a substitute for that full freeze
gate. That future gate does not change this companion's 80 / 77 / 15
disposition of the dated 172-row review set.
