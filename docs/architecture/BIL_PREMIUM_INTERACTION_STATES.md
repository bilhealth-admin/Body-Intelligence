# BIL Premium Interaction States

## Parent baseline

`ca9dccc60544356e67642df594cc9d3bb5fd49ab`

## Decision

Interactive `PremiumSurface` instances support pointer, touch, Enter, Space,
and visible keyboard focus through one shared primitive. Non-interactive
surfaces remain outside the focus order. Existing `onTap`, hover, pressed,
reduced-motion, and hierarchy behavior is preserved.

This package does not change application commands, navigation targets, data,
copy, trusted truth, or persistence.
