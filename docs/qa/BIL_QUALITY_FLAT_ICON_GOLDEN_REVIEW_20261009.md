# BIL QUALITY: reviewed flat-icon Golden deltas — 2026-10-09

Source evidence: [focused CI run 37910853461](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37910853461) on QA head `89353e298576ff4ad5b593d60bbe09e6107c8b42`; focus job `production-goldens` or `data-goldens` artifact includes exact expected/master and actual/test images. Pixel differences were manually inspected and bounded to the icon leading/tile area. No app layout/text moves were seen in these **eight** candidates. These represent the user's approved SF-symbol/Material flat icon design, rather than a functional regression.

**Reviewer whitelist only; evidence is not blanket permission to update baselines.** No Golden PNG was edited in this document. Recheck these exact hashes against any current on-branch render before selectively updating just these eight baselines. Keep baseline comparisons strict. Never auto-rebaseline all `goldens/` files.

| Reviewed Golden PNG (in `test/visual_closure/goldens/`) | Changed pixel count (% of 390×844) | Inclusive difference envelope (x0–x1, y0–y1) | Expected SHA-256 of approved candidate actual PNG |
|---|---:|---|---|
| `visual_closure_more_phone.png` | 3.211% | 32–76, 415–844 | `121e02c2f58ff4be2c130293ea5fd08b73529105c78cece9c929edcb82404716` |
| `visual_closure_more_lower_phone.png` | 5.163% | 32–76, 56–763 | `6638633ee207054ce6a50adda4f92868b5f46b24a2237a28a01976bf5d7e171c` |
| `visual_closure_settings_phone.png` | 3.211% | 32–76, 415–844 | `0e72b314d3a62a59e6edaea992217975e4064e1f269fdcabc79a9ec4638cbd0d` |
| `visual_closure_settings_phone_2.png` | 6.218% | 32–76, 56–844 | `fcc7e6265ccbf07b2acfc5be3a33e76ad02980f67d5b45ac9a95f643c195aafd` |
| `visual_closure_settings_phone_3.png` | 5.184% | 32–76, 56–844 | `02bab03c9e648309f6b1e22c8988f7219c5d1e38974d774b6d06f6526826ed61` |
| `visual_closure_settings_phone_4.png` | 4.803% | 32–76, 56–731 | `4cd79085013d883b7cc3feb75edb581689f9201f8e994bdef14eb53d69cbd910` |
| `visual_closure_notification_settings_phone.png` | 1.022% | 28–81, 185–417 | `580aaf65d46eb0afa2d22fdec5d8d081a89c4bd9c734e41d23f2d9dbaa1011bf` |
| `visual_closure_wellness_library_phone.png` | 0.482% | 45–88, 495–537 | `fe31b02a66a7f0e92e998dee28723932692af7a68b42d2862db98bc72c415421` |

These candidates are nonprotected and scoped to the user's approved icon-only change. This review **explicitly excludes**:
- All Home/Dashboard and Log Food production and Golden visuals, including `epic15_*_02_daily_log.png` and associated food-entry flows
- Community Hub, navigation sheet and empty Notifications references with large layout/copy differences; these need separate current-design review
- Local export date-range reference, whose actual now presents data-category checkboxes instead of a single description; functional review required
- Splash and recipe library Golden differences until deterministic setup and current source/asset fidelity pass

Follow-up must preserve the actual current design, owner-specific permissions and data, RTL/large text contrast, and all required CI checks. A passing screenshot without source inspection does not establish a device-level iOS acceptance.

## Scoped visual-review acceptance on QUALITY branch

The eight PNG snapshots above were cross-checked against original
expected/actual/isolated-diff artifacts and their SHA-256 digests in
[focused run 37914774060](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37914774060).
All eight differences are confined to the approved 44dp leading-icon
treatment in More/Settings, notification settings and the Wellness icon.
They are legitimate accepted SF-style flat-icon changes, not runtime errors.

Only the eight allowlisted Golden PNG paths from the table above may be
updated; they remain byte-for-byte identical to their reviewed candidate
testImage PNGs. Native iOS/Android device confirmation is still outstanding.
Do **not** update Home, Dashboard, Log Food, their Golden files, or any
other screenshot without separate review.

Subsequent **read-only** evidence collection has an explicit SHA-256 allowlist
for additional changed Community, AI Coach, local export, and recipe imagery.
These are **not yet approved baselines** merely because their bytes have been
exported. The complete visual and behavioral contract remains mandatory.
