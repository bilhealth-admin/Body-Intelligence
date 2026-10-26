# BIL39 Crystal completion audit — still partial

Worker source reviewed and tested: `4253c3abf653d958535b25b5d14d36b5edd14702` (PR18). No worker branch was overwritten.

The actual repository scan examined 3,458 source files and found **639 candidate rows**, including **486 `lib/` rows in 207 files**. Earlier smaller counts are not a complete current inventory. The full occurrence register is `BIL39_CRYSTAL_OCCURRENCE_REGISTER_20261025.csv`.

Every row retains file/line/source excerpt and explicit pending route, direction, state, before/after and interaction fields. Regex candidates are not accepted UI instances. The legacy glyph mapping and test-source definitions are annotated as such; their mounted production call sites still need review. The scanner also does not establish completeness for generated Material/Cupertino controls.

## Proven local scope

Flutter 3.44.6: **84 tests passed, none skipped**, running `bil_crystal_arrow_test`, `bil_crystal_calendar_video_test`, `bil_crystal_purchase_cta_isolation_test`, `bil_navigation_press_style_test` and `secondary_page_navigation_test` against the worker SHA above. These cover persistent decoration, geometry, pointer/semantics/keyboard, RTL/LTR, high contrast, synthetic calendar/video controls, real secondary back and real protected purchase control actions/captures. The calendar/video fixture is explicitly synthetic; it is not a native route proof.

Both protected blobs remain byte-identical to iOS38:

- `bil_dynamic_store_components.dart`: `26303dce18ddc3f4f4ddceb859081283c0aebfe7`.
- `bil_glass_press_feedback.dart`: `653d424ddb6cca8adeb0d394f5c8f8866da3792d`.

The fixture captures alone are not a before/after baseline byte comparison. That gate remains pending, as do the per-occurrence visual and native interaction checks.

## Not complete

Only the shared secondary back/helper currently uses the new persistent crystal broadly. Many list disclosures, dropdowns, expansion/calendar/video controls and other arrows remain unmigrated or unverified. The worker's broad golden jobs also fail on changed secondary-page header pixels; the reference images have not been blanket-updated to suppress those failures.

Status remains **BLOCKED/PARTIAL**. This source audit must not be interpreted as all-arrow compliance or permission to build/upload BIL39.
