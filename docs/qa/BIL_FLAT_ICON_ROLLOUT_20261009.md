# BIL — flat semantic icon migration (QUALITY only)

**User approval:** clean SF Symbols-inspired icons throughout BIL, excluding the Home/Dashboard and Log Food screens. No realistic photo thumbnails, 3D artwork, decorative shadows, glows, shaders or gradient icon plates. Do not change the protected screen layouts, colors, copy, assets, or Goldens.

## Implementation

- The new, opt-in `BilFlatIcon` uses immediate, synchronous Cupertino icons on Apple platforms and matching Material icons elsewhere; it keeps stable footprints and existing semantic colors without a decorative tile or image load.
- The original shared `BilSemanticIconBadge` is unchanged. Its existing Home/Dashboard and Log Food consumers continue to render exactly as before. These screens and their visual code were not edited.
- The native SF-symbol Settings bridge remains intact, with an opt-in `flat` presentation for settings; other callers keep the old default.
- The first migrated surfaces are Community (Circles, navigation, context actions), More and native Settings icons, notification controls, connected health signals, AI Coach Settings, and the Wellness Library icon treatment. Form buttons, icons already drawn flat, and any remaining feature-specific wrappers are not claimed as converted.
- Circle photos or covers uploaded and verified through the existing server contract remain available. Only fallback illustrations change to neutral, icon-only visuals. Membership, joins, requests, posts and count data remain authoritative and unchanged.
- No changes to payments, subscription/trial rules, main, BIL-00, BIL-UX, Production Supabase, publishing, store builds or deployment.

## Acceptance and remaining work

1. Flutter format, analyzer, targeted widget tests and **all eight shards** of the unchanged full-suite Verify must be checked on the new commit. Android Debug must also pass. Existing unrelated red/Golden tests stay visible; do not auto-accept or regenerate screenshot baselines.
2. Confirm light/dark, English/Arabic RTL, 100–200% text scale, native iOS symbol fidelity, Android fallback, and contrast. A Windows host golden is **not** proof on a physical device.
3. Continue inventorying bespoke icon badges in remaining, nonprotected pages and migrate them incrementally after visual review. This commit is a reusable foundation and first real rollout, not evidence every icon in the app has changed.
