# BIL PR11 — More Premium link and selective icons (2026-10-09)

## User direction
Flat SF-style / Material icons **when they convey something useful**, otherwise no icon. No shadows or decorative icon discs. Protected Home/Dashboard and Log Food untouched.

The More membership entry had an oversized navy gradient, border, 52px gold crown, heavy W900 title and a trial-forward headline. Selected compact **text-only treatment**, no card, custom fake glass, or emblem. Apple's current HIG recommends meaningful text in place of unnecessary icons and limits Liquid Glass to appropriate native controls; see:
- https://developer.apple.com/design/human-interface-guidelines/buttons
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/design/human-interface-guidelines/accessibility
- https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations
- https://gentlerstories.com/newsroom/20250911gentlerstreakios26

## Implementation
- More: no membership card. Transparent Material + InkWell with minimum **52dp** hit area, platform-native type, 16sp title in muted gold (`#8B6429` light, `#E2C78E` dark), simple localized small supporting status and RTL chevron. Light gold has contrast **5.31:1 against white**; color is not used as the only affordance.
- State and route preserved: verified Free displays existing localized `Explore Premium` and enters existing `/plans`; verified paid shows `Active` and also enters `/plans`; unverified/error retries subscription authority without presenting plans; loading shows disabled state and spinner. No false promise that a trial is always newly available. No prices, billing, entitlements, Trial or store operations changed.
- Help: text-only rows with directional chevrons; remove the eight decorative leading icons introduced by earlier QA, preserving actions and routes. No global icon/theme mutations.
- Strict tests revised to ensure Help leading is null, verify More label/key and guarded plan route, and forbid a card/glass/shadow in the entry subtree. **No Golden image updated or tolerance changed**. The More/Help baselines now require an individual approved visual review.
- QA source SHA prior to change: `3f235bfe186a26de41adfb9c55cbbe0f733df620`. Verify https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37958491779 had Format+Analyze, Splash and Transaction Queue passing, **125 visual focused failures unchanged**, eight full shards skipped. Android debug https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37958491784 succeeded. New SHA CI evidence must be gathered separately.

## Remaining certification
All focused Goldens must individually pass after source/fixture remediation and reviewed nonprotected baseline decisions; then the original eight full shards, final aggregate and Android Debug on a single SHA. 146 original references and native device comparisons are a separate gate. PR11 remains Draft and unmerged.
