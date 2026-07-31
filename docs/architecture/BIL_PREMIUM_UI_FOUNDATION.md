# BIL Premium UI Foundation

## Baseline

- Branch: `phase-3-product-excellence`
- Parent HEAD: `66172d1a452af82db5faef48fa40e953d8223a0a`

## Decision

`BilPremiumVisualFoundation` owns the semantic geometry, interaction scales,
surface borders, and dashboard shadow parameters used during the Premium UI
epic. `PremiumDesignTokens` remains a compatibility facade so the first package
does not alter accepted rendering or require a broad consumer migration.

## Non-regression boundary

This foundation does not change layout, copy, localization, application state,
navigation, dashboard authority, trusted truth, persistence, or command
behavior. Later Premium UI packages must consume the canonical foundation and
prove visual changes through focused widget and golden contracts.
