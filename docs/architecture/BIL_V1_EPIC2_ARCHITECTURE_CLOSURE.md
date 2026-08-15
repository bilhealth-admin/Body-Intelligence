# BIL v1 — Epic 2 Architecture Closure

Epic 2 closes the maintainability baseline by separating large presentation
libraries into responsibility-focused Dart parts while preserving their public
library boundaries, state ownership, localization, semantics, and routing.

## Completed responsibility splits

- Analytics: page coordination and reusable analytics primitives.
- Dashboard benchmark: orchestration, command center, and evidence surfaces.
- Dashboard daily summary: summary composition and metric grid.
- Dashboard header: header shell, guide orb, and signal orb.
- History: page coordination and history visualization components.
- Nutrition catalog: overview, food tiles, and custom-food dialog.
- Wellness tools: sleep, workout, fasting, and shared tool components.
- Responsive shell: removed the obsolete duplicate quick-add implementation;
  the routed quick-add sheet remains the single implementation.

All splits use `part`/`part of` deliberately. This keeps private widget and state
boundaries private while making file ownership explicit. No business logic was
moved into presentation-only abstractions and no second design system was added.

## Enforced ceiling

`test/architecture_source_file_size_guard_test.dart` prevents hand-maintained
sources from growing beyond 700 lines without an explicit reviewed exception.
Generated files are excluded. The localization catalog and the two repository
query boundaries are documented exceptions because splitting them would obscure
their generated/catalog or transactional query ownership rather than clarify it.

The ceiling is a regression guard, not a target. New code should normally remain
well below it and be split when a file gains a second independent responsibility.
