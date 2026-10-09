# BIL PR11 — More typography aligned with reference hierarchy (2026-10-09)

## Owner correction
The preceding PR11 More screenshot was correctly rendered at **390 × 844** logical test pixels; the review image showing two captures side by side was **840 × 949** due to composition and captions, not a zoomed app screenshot. Original user reference images are **1284 × 2778** device pixels. Compare screens after normalizing them to equal display width; do not infer font parity from pixel width alone.

BIL's theme **already leaves fontFamily unset**, using San Francisco on iOS and native system sans on Android. The mismatch was actual typography weight and hierarchy, **not an absent third-party font**. Verified old More source used 22sp/W900 navigation title, 21sp/W900 section headings, and 16sp/W700 navigation rows. Reference `IMG_9672.PNG`, `IMG_9673.PNG`, `IMG_9764.PNG` has comparatively regular, neutral, compact navigation typography.

## Scoped changes (More only)
- App bar `More`: 19sp / W600 native system font.
- Section labels: 14sp / W600 in theme onSurfaceVariant; **retain BIL section architecture**, do not clone a competitor.
- Navigation/Review Setup/Cloud Sync row labels: 15.5sp / W400; retain tappable tile heights and icon action semantics.
- Profile name: 18sp / W600; metric values W600.
- Premium link title: 15sp / W600; supporting verified-state copy: 12sp / W400. Existing verified entitlement gating, retry/loading and `/plans` action unchanged.
- No global `ThemeData`, font package, image assets, Home/Dashboard, Log Food, billing/prices/Trial, or Production changed.

A strict source contract covers typography weights and row navigation. No Golden PNG baselines or tolerances are modified; expect focused image tests to remain red until reviewed visual signoff per case. This commit is **not** a 146-reference completion or physical-device certification.

Previous CI `52bcaacf`: Format/Analyze and Splash/Transaction PASS; 21 Store, 23 Data, 88 Production Golden failures; 8 full shards correctly skipped, Android Debug succeeded. New exact-SHA results required independently.
