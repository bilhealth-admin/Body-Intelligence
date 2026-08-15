# BIL v1 Epic 3 — Unified product design system

## Status

Complete; awaiting the selective closure commit. This document is the visual implementation contract for Epic 3. The
comparison screenshots are used to study information hierarchy and interaction
discipline; BIL does not copy third-party names, marks, imagery, or assets.

## Product principles

- Mobile first: iPhone and Android are the primary review targets.
- Native typography: San Francisco on iOS, the platform sans family on Android,
  and Segoe UI on Windows. BIL does not bundle a heavy display font for phone UI.
- The supported weights are 400, 600, and 700. Body text stays at 400, controls
  and compact headings use 600, and major page or hero headings use 700.
- Page titles are centered and navigation remains stable and predictable.
- Light mode uses a quiet neutral canvas, white surfaces, restrained borders,
  and minimal elevation. Blue haze and decorative gradients are reserved for
  branded hero moments rather than routine content.
- The standard geometry is 10/14/18 pixels. Routine cards and fields use the
  middle radius; sheets and dialogs may use the large radius.
- Inputs, buttons, icon buttons, rows, menus, chips, dialogs, sheets, tabs, and
  navigation inherit from `BilFlagshipTheme` instead of defining local systems.
- Interactive targets remain at least 48 logical pixels and tolerate text
  scaling, keyboard insets, RTL, LTR, and device safe areas.

## BIL identity that must remain

- Body Twin, evidence, confidence, privacy, and decision intelligence.
- The BIL medical device and watch experiences.
- BIL dark mode and the metallic wordmark.
- Honest states: no invented health readings, community activity, purchases,
  recipes, workouts, or connected-device data.

## Route coverage

The contract applies to splash, onboarding, account entry, authentication,
dashboard, diary and all food capture modes, water, weight, exercise, progress,
analytics, reports, plans, recipes, wellness, community, connected health,
profile, settings, privacy, help, commerce, paywalls, and their loading, empty,
error, disabled, and offline states.

## Review matrix

Every primary flow is reviewed on compact and large phones in Arabic and
English, light and dark themes, with keyboard and safe areas present. Critical
screens also require text-scaling and RTL checks. Golden references supplement
widget and semantic contracts; they never replace behavior verification.

## Closure evidence

- Original-scope audit: PASS on 2026-08-03.
- Route registry: all 43 active routes classified with executable or explicit
  source evidence.
- State coverage: loading, empty, error/retry, disabled, and offline verified.
- Visual matrix: 8/8 goldens verified across 390x844 and 430x932, English and
  Arabic, Light and Dark, LTR and RTL.
- Accessibility/responsiveness: 200% text scale, keyboard inset, safe areas,
  minimum action height, and primary-action reachability verified.
- Final full gate: format clean across 1,001 files, full analysis clean with
  zero issues, 955 tests passed, and 18 tests explicitly skipped.
