# BIL39 Crystal Arrow Audit — preliminary inventory

Source baseline: branch work/ios38-safe-fixes-20261025 at commit
155b079696430919f8272df934371f033fb11be2.

## Implemented in this draft

| File | Change | Proof status |
| --- | --- | --- |
| lib/shared/widgets/bil_crystal_arrow.dart | New decoration-only widget; 48 px crystal is present at rest, during press, after release, and for disabled controls. Bubble excludes semantics and ignores pointer events. High-contrast/accessibility mode removes blur and strengthens the border. | Widget tests added; not executed in this environment. |
| lib/app/theme/bil_navigation_press_style.dart | Adds a transparent chrome style for a button whose child draws its own static crystal; routes the existing backIcon helper through the new widget. Existing neutralBubble and BilGlassPressFeedback behavior are not changed. | Source diff review only. |
| lib/shared/widgets/secondary_page_app_bar.dart | Uses BilCrystalArrow for the canonical secondary-page back control while retaining the existing callback/pop/fallback logic and a 48 px button target. | Existing navigation tests plus new widget test added; not executed here. |
| test/bil_crystal_arrow_test.dart | Covers resting/tap/release persistence, geometry, disabled state, secondary-page callback, high-contrast border, semantics, keyboard activation, light/dark, RTL/LTR. | Added, not run: no Flutter/Dart executable is available in this runner. |
| tool/audit_bil_crystal_arrows.py | Read-only candidate scanner for Dart and common native source files; flags candidates for manual review and marks the protected commerce file. | Added; not run against the full repository in this environment. |

## Protected payment control

No change was made to
lib/features/commerce/presentation/bil_dynamic_store_components.dart.
The source blob SHA at baseline was
26303dce18ddc3f4f4ddceb859081283c0aebfe7. The legacy
lib/shared/widgets/bil_glass_press_feedback.dart is also unchanged
(blob SHA 653d424ddb6cca8adeb0d394f5c8f8866da3792d), so the
store-purchase-cta keeps its previous press-only behavior and does not inherit
the new permanent crystal by a shared-widget side effect.

## Known source evidence

- lib/shared/widgets/bil_glass_press_feedback.dart:152-205 — legacy feedback
  draws its bubble only while pressed. Deliberately not changed because the
  protected store-purchase-cta uses this widget.
- test/bil_navigation_press_style_test.dart:48-86 — legacy test explicitly
  expects no bubble before and after release. Deliberately retained as a
  contract for the legacy widget; the new component has separate tests.
- lib/app/theme/bil_navigation_press_style.dart:5-33 — existing neutralBubble
  styling is preserved; a separate crystalButton style is added.
- lib/shared/widgets/secondary_page_app_bar.dart:51-59 — canonical back control
  now uses the new persistent crystal component.

## Coverage status: BLOCKED / PARTIAL — do not call all-arrow compliance

The full occurrence inventory is not complete in this draft. The source
repository could be read through selected GitHub file endpoints, but a local
checkout and Flutter/Dart SDK were unavailable to run a whole-repository scan,
widget/golden tests, native builds, and before/after device captures. The
scanner is included for the next repository-backed run. Its CSV is a candidate
list, not proof that every arrow was found or audited.

Not yet verified:
- all Dart occurrences across lib/, including Material-generated arrows,
  DropdownButton/ExpansionTile/calendar internals, image assets, and custom
  painters;
- native iOS Swift/Objective-C and Android Kotlin/Java/XML arrow surfaces;
- every route and every disabled/loading/error/dialog state;
- all RTL/LTR screenshots and visual golden comparisons;
- the store-purchase-cta before/after pixel/geometry and interaction golden.
  Its source and shared legacy press widget were intentionally left untouched,
  but unchanged source hashes alone do not prove a runtime visual invariant.

## Run when a full checkout and SDK are available

1. Run python3 tool/audit_bil_crystal_arrows.py --root . --output build/bil39_crystal_arrow_candidates.csv.
2. Review every candidate and all automatic/platform-rendered arrows manually; add route, direction, resting/pressed/released state, interaction proof, and final decision to the project QA inventory.
3. Run flutter test test/bil_crystal_arrow_test.dart test/bil_navigation_press_style_test.dart test/secondary_page_navigation_test.dart.
4. Generate and review visual goldens for light/dark and RTL/LTR. Compare the protected purchase CTA before and after using the same viewport, theme, offer data, and interaction sequence.
5. Keep this PR draft until full inventory, tests, and the protected CTA visual/behavior invariant are evidenced. Do not ship Build 39 from this partial audit.
