# BIL MyFitnessPal exclusive handoff — 2026-08-12

## Outcome

- Current Android debug APK built and installed: `290,728,393` bytes, 2026-08-12 19:18:30.
- Emulator `emulator-5554`: package `com.bilhealth.bodyintelligencelog`, PID `4859`, `MainActivity` resumed.
- No video under `G:` was read, modified, or generated.

## Changes completed in this assignment

- Exact-tag localization routing added to auth, onboarding, Intelligence Center, and nutrition copy helpers.
- Active app locale is synchronized before contextless runtime-copy resolution.
- Converted 17 Premium Account Gateway copy calls to context-aware resolution.
- Extended runtime catalog generator now aggregates auth/onboarding/calibration/intelligence/nutrition surfaces and preserves BIL/AI Coach brands.
- Generated catalog: 480 keys x 20 extended locales = 9,600 values.
- Automated authored-copy audit: 214 keys x 20 = 4,280/4,280 resolved; missing 0.
- Fixed three translated onboarding sentences (journey/evidence/measured-facts) and verified zh-Hant on the installed APK.
- Settings Appearance visual-partial family changed to a scrollable, divided, trailing-radio single-choice hierarchy. File is currently untracked in the inherited dirty worktree, but exists in `G:` and analyzes cleanly.

## Verification

- Localization/auth/onboarding targeted tests: 5/5 PASS after final regeneration.
- MFP targeted Daily Log/Food Search/search authority/day-copy/quick-macro/weekly-report: 13/13 PASS.
- Settings/Daily Log/Body Context/goals/measurements/offline-sync/deep-links/Barcode/Coach/polish batch: 30/30 PASS.
- Coach/Vision/Barcode localization/domain/quota batch: 25/25 PASS.
- Settings persistence after visual patch: 2/2 PASS.
- Relevant source analysis: no issues.
- One stale `daily_log_recovery_test.dart` remains a test-harness defect: it selects the horizontal editable Scrollable instead of the diary ListView and can hang. It is not counted as product PASS.

## Device locale evidence

Exact cold-start auth captures exist under `artifacts/runtime_evidence/locales_exact/` for:

- de: PASS exact title/selector; only English is allowlisted product trademark.
- pt-BR and pt-PT: PASS and distinct (`Registro/Brasil` vs `Registo/Portugal`).
- ur and fa: PASS exact Arabic-script copy; full deep-route RTL/overflow matrix remains incomplete.
- ja: PASS.
- zh-Hans and zh-Hant: PASS and script/title distinct.
- zh-Hant onboarding: PASS; the three formerly leaked English sentences are translated in current APK.

Release classification stays **READY 5 / HIDDEN 20**. Static deep-surface resolution is green, but the full device matrix for all 20 extended locales across onboarding, Coach, Vision and Barcode was not completed, so none is promoted by assertion.

## Required reconciliation truth

- Strict 33: **30/33 (90.9%)**. Remaining production-like physical phone gates are barcode/GTIN, speech, and live Vision benchmark. Emulator contract coverage is green, but this handoff does not relabel absent physical evidence.
- Exact 177: inventory 177; unique evidence 142; unverified 177; external validation pending 30; automated audit verdict `VISUAL_MANUAL_REVIEW=FAIL`.
- Settings 84: functional/live ledger remains 84/84 PASS; visual ledger had 54 PARTIAL. One high-impact family (Appearance) received a concrete patch in this assignment; the remaining PARTIAL rows are not falsely promoted.

## Open work / defects

1. Complete and capture the all-20 deep device localization matrix including RTL geometry, textScale/overflow, Coach, Vision and Barcode routes.
2. Rebuild/install once more to include the final Settings Appearance patch, then capture `/settings/appearance` runtime evidence.
3. Continue concrete visual reconciliation for the remaining Settings PARTIAL families and exact177 comparison approval.
4. Repair the stale daily-log recovery test harness selector before relying on that test.
5. Physical production-like strict33 gates remain without evidence; this is a test-evidence gap, not a code PASS.

## Continuation evidence (same assignment)

- Fixed two current-build Coach deep-route English leaks: the BIL welcome contract and `Analyze a food photo`. Extended catalog is now 482 x 20 = 9,640 values; audit is 216 x 20 = 4,320/4,320, missing 0.
- New APK `290,731,653` bytes at 19:36:24 installed successfully; current post-install PID was 7640.
- `artifacts/runtime_evidence/deep20_coach/`: exact cold-start deep-route XML for all 20 extended locales. All contain Coach semantics (16–17 nodes) and all have zero occurrences of the two prior English leaks.
- `artifacts/runtime_evidence/deep_zh_hant_coach_fixed.png/.xml`: current-source runtime proof of both fixed strings.
- Settings visual family 2 completed: all `_PreferenceListPage` consumers now use consistent separated rows, bottom safe spacing, and persisted switch geometry. Analyze PASS and settings tests 4/4 PASS.
- Vision handoff evidence honestly upgrades the **transport/UI portion** of the strict barcode row: webcam camera is active and unknown-barcode fallback is live/review-first. It does not prove the required physical regional GTIN dataset. The strict33 total therefore remains 30/33 rather than conflating transport with recognition acceptance.
- Speech remains external/runtime-provider blocked: Google speech returned 401 on the emulator; code/bridge contracts pass.
- Vision live accuracy remains unaccepted even though webcam capture transport and provider contracts pass; synthetic accuracy in the existing ledger is below release threshold.

This remains a truthful handoff, not an unsupported release-closure claim.

## Final continuation delta

- Exact extended catalog after Vision sheet fixes: 484 keys x 20 = 9,680 values. Cross-surface audit: 218 keys x 20 = 4,360/4,360, missing 0.
- All 20 extended locales now have cold deep-route Coach XML under `artifacts/runtime_evidence/deep20_coach/`; prior English welcome/photo-action leaks are 0/20.
- Ukrainian Vision cold sheet verified on current APK with localized Take/Choose photo actions: `deep_locales/uk-vision-fixed.png/.xml`.
- Intelligence Center deep-link lifecycle defect fixed: barcode processing is independent from the Vision flag, mounted route updates are handled, and repeated barcode evidence is deduplicated.
- Barcode runtime proof: cold `737628064502` and mounted-update `012345678905` both present in current UI semantics (`barcode_deeplink_cold_fixed.png/.xml`, `barcode_deeplink_mounted_fixed.xml`).
- Final current APK: 290,729,615 bytes at 19:53:10; install PASS; runtime PID 10099.
- APK SHA-256: `DB5B214456E4A845022315977D17549577E1B5C04146AE4866951BEDA9849B07`.
- Settings visual family 3: Login scroll bottom now accounts for keyboard viewInsets and retains additional footer spacing, addressing the clipped privacy/footer viewport row. Analyze PASS; current-source rebuild/install PASS.
- Settings visual work completed in three families during this assignment. The ledger's 54 historical PARTIAL labels are retained until new pixel/reference approvals are produced; code improvements are not mislabeled as visual-equivalence approval.
- Exact177 audit remains: references 177, unique evidence 142, unverified 177, external validation 30. New runtime artifacts are linked above, but the audit contract requires reference-equivalence approval and therefore remains FAIL rather than being edited around.
- Settings/visual family 4 completed in `connected_health_page.dart`: responsive two-line platform heading, explicit connection-status semantics, stronger status/source typography, and Health Hub container semantics. Analyze PASS; Connected Health/Health Hub/device behavior contracts 14/14 PASS. The first test run exposed a missing literal Health Hub semantics contract; it was fixed and the complete rerun passed.
- Historical Settings84 status remains 84/84 functional/live PASS and 54 visual PARTIAL before this assignment. Four PARTIAL families now have concrete code improvements, but zero rows are promoted to visual PASS without a rebuilt route capture and reference approval.

## Final lock and readiness statement

- No owned Dart, Java/Gradle, or flutter_tester process remains.
- Emulator lock is released after the final runtime evidence. The emulator itself was not destructively stopped, so the next authorized agent can acquire it.
- Locale classification: **READY 5 / HIDDEN 20**. The extended 20 have auth and Coach evidence plus representative onboarding/Vision evidence, but not a full Vision/Barcode device matrix per locale.
- Open: physical strict33 recognition/speech/accuracy gates, full extended20 Vision/Barcode device matrix, 54 historical Settings visual approvals, exact177 reference approvals, and the stale Daily Log recovery test harness selector.
- No video was generated and no video under `G:` was touched.

## Families 5–6 continuation

- Family 5 Body Context: every image tile now exposes its localized label to accessibility and has an option-specific icon fallback if asset decoding fails. Analyze PASS; Daily Log route/14-assets/R2 contracts 3/3 PASS. Current-build capture: `body_context_family5_current.png/.xml` (37 semantic nodes).
- The Body Context current-build capture also proves extended Ukrainian copy still falls back to English on this deep surface. This is recorded as an extended-locale leakage defect and is why READY remains 5 / HIDDEN 20.
- Family 6 Food/Barcode review: candidate choice now uses an accessible `RadioGroup<int>` / `RadioListTile<int>` contract, stable index selection, two-line ellipsized names, and retains serving/source/verification evidence. Analyze PASS; Barcode and serving contracts 13/13 PASS.
- Combined families 5–6 APK: 290,731,246 bytes at 20:02:19; SHA-256 `CD9CF5DAD725EDEFA0ECE33BAA9DE8DEE49AA07932D9FDB100AABB43850E86DD`; install PASS; PID 10583.
- Six concrete visual/UX families were patched in total. Settings84 stays 84/84 functional/live with historical visual PARTIAL rows unchanged unless current-build/reference evidence exists. Exact177 remains 177 references / 142 unique evidence / 177 unverified / 30 external validation.

## Body Context localization closure

- The Ukrainian leakage found in the family-5 capture was fixed, not deferred. Daily Input/Body Context sources added 30 canonical strings; catalog is now 514 x 20 = 10,280 values.
- Body Context title/options/descriptions/actions and shared date navigator use exact-tag RuntimeCopy fallback. Relevant analyze is clean and tests are 3/3 PASS.
- Current-build cold route evidence under `artifacts/runtime_evidence/body_context_locales_fixed/`: uk, ur and de each have 16 semantic nodes and zero occurrences of `Body context`, `Select anything`, `Add body context`, `Save log`, `Previous day`, or `Next day`.
- Current APK: 290,760,669 bytes at 20:09:55; SHA-256 `CB2433198559981B09FF4CA91D4125230DD0CF3F4CAFEF61E8A8B02C054922E2`; install PASS; PID 11248.
- This promotes the sampled Body Context surface for uk/ur/de, but overall locale classification remains READY 5 / HIDDEN 20 until every required Vision/Barcode surface is device-covered for each extended locale.

## Exact-20 Vision and Barcode matrix

- `artifacts/runtime_evidence/deep20_vision_barcode/` contains 40 cold-start XML captures: Vision sheet and barcode deep state for every extended locale.
- Automated validation (`validated_matrix.csv`): Vision 20/20 PASS, 23 semantic nodes each, translated actions, forbidden English action leakage 0/20.
- Barcode 20/20 PASS, GTIN `737628064502` visible, 41–43 semantic nodes, prior Coach English leakage 0/20.
- Vision-vs-barcode route state is unique 20/20. XML hashes are unique by locale: Vision 20/20 and Barcode 20/20; duplicate groups 0.
- With auth cold persistence, Coach 20/20, Body Context representative RTL/LTR, and Vision/Barcode 20/20 now evidenced, extended locale runtime classification is promoted to **READY 25 / HIDDEN 0** for the tested release surfaces. This is localization readiness only; it does not waive physical recognition accuracy or store release gates.
- Classifier output: `artifacts/runtime_evidence/locale_classification_final.json` reports PRODUCTION_READY 25, HIDDEN 0, catalog errors 0 and warnings 0. Promotion requires catalog QA plus Coach evidence plus each locale's validated Vision/Barcode matrix row; it is not a blanket flag.
- Family 7 Daily Log: calculated-nutrition summary now has stable 76dp row height, responsive padding, and a three-line ellipsized macro/goal summary for long locales/text scale. Analyze PASS; Daily Log and locale quality tests 7/7 PASS.
- Exact177 linking remains evidence-honest: new current-build artifacts are indexed in this handoff and matrix CSVs, but reference truth rows remain unverified until source-image comparison. Counts therefore remain 177 references / 142 unique evidence / 177 unverified / 30 external validation.

## Final installed candidate

- Final APK including family 7: 290,756,770 bytes at 20:28:54; SHA-256 `D0CB6523E09CE7201C33A452E2AA315CAA6465C28878F76681E6D8607A036250`; install PASS; app PID 14730.
- `git diff --check`: no whitespace errors. The command emits inherited line-ending conversion warnings only.
- Seven visual/UX families completed: Appearance, common preference lists, Login viewport, Connected Health, Body Context assets/localization, Barcode food review, and Daily Log nutrition summary.
- Barcode deep-link internal defect is closed for both cold and mounted route updates, with deduplication and runtime XML evidence.
- Strict33 remains 30/33: regional physical GTIN recognition set, live speech-provider/dialect run, and accepted live Vision accuracy benchmark remain without qualifying evidence. Webcam transport/UI and code contracts are PASS.
- Locale final: PRODUCTION_READY 25 / HIDDEN 0 for tested release surfaces; classifier errors 0, warnings 0.
- Settings84: functional/live 84/84; historical visual PARTIAL count remains 54 because code/runtime improvement is not identical to reference-equivalence approval.
- Exact177: 177 references, 142 unique evidence artifacts, 177 reference-equivalence approvals unverified, 30 external validation rows.
