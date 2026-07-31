# BIL Premium Accessibility and Localization

## Decision

Premium surfaces must preserve their information hierarchy when accessibility
or localization settings change. The shared `PremiumSurface` is the authority
for these adaptations.

## Contract

- High-contrast mode removes translucent blur and doubles the dashboard-card
  border width so the boundary does not depend on subtle glass effects.
- Surface gradients use directional alignment and therefore mirror with RTL
  layout without maintaining a second visual implementation.
- Large text scale and Arabic direction remain supported without replacing the
  accepted dashboard composition.
- Default LTR rendering remains unchanged; existing goldens stay authoritative.

## Scope

This package changes only the shared Premium UI foundation and its accessibility
contract. It does not alter dashboard data, decision authority, navigation, or
feature behavior.
