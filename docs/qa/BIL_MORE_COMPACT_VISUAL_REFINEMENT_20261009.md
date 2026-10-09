# More refined QA design: measured font, restrained icons and compact groups

**Source before change:** `51803a153b0aa51cfdbd53cc2f67910de0ddb00a`. This change applies **only to More**, preserving all existing destinations, subscription authority, navigation and data sources.

## Source-grounded visual decisions
- Original BIL More still had pale-blue page gradient, elevated 24-radius boxed sections, 44x44 bold blue/pink semantic icons, 60dp rows and a tall 34-radius account avatar. These combine to make its rows denser in decoration, yet farther apart than the user's iPhone references.
- Refine into compact, neutral sections: page's native scaffold surface, 14dp soft-border group cards **without shadows**, ~12dp section gaps and 54dp noncritical rows (>=48dp minimum hit size). Protected Community/Coach entrypoints remain 60dp with meaningful flat icons.
- Only navigation categories where icons aid recognition retain glyphs: goals/trends/nutrition, workouts/sleep, devices and relevant community. Pure account, language, location, support and administration list actions omit glyphs rather than showing redundant colored shapes. Flat icons 34dp footprint, 20dp glyph, theme onSurfaceVariant instead of saturated blue/pink. Divider indentation matches whether an icon exists.
- Profile summary remains live repository-derived. Tighten padding, avatar (34 -> 28 radius) and metric spacing without replacing goal/weight math or requiring mock content. Premium gold link is unchanged.

## Focused regression gates
- Enforce exactly the literal accessibility geometry required by `more_language_entry_test.dart` (`minTileHeight: protectedEntry ? 60 : 54`); do not loosen that test.
- `more_section_headings_test.dart` requires some text-first rows without leading icons in both Account and Diary sections, and every row remains tappable. This source change closes that actual missing contract, while leaving Community/Coach icon entries available.
- `more_premium_polish_contract_test.dart` updated to **enforce** smaller flat glyphs, no shadow/elevation, scoped radius and verified route/status preserved. No screenshot baseline updates, assertions weakened or Golden tolerances changed.
- No edits to Home/Dashboard, Log Food, app theme, routes, billing/prices/Trial or production; PR11 Draft only. Strict five focused tests must pass before original eight full Flutter shards and final aggregate; Android Debug independently required.
- Actual matched iOS/Android photos and all 146 source-reference parity still pending. CI image mismatches need individual assessment and owner visual signoff before changes to Golden PNGs.
