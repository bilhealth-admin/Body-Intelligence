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

## CI evidence from first compact commit
- Initial `023fb907`: complete Flutter Analyze **PASS**; strict Dart Format **FAIL** on only one whitespace layout at `final showIcon`; Android Debug [run #37966571242](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37966571242) **PASS**. Focused Goldens and 8 shards were correctly not executed because source-checks were red.
- Follow-up: apply precisely the Dart SDK formatter diff and make the `Challenges` Diary destination text-first, as required by existing real widget contract. Add four **strict** targeted More widget/source tests to `source-checks` *after* Format+Analyze, while preserving the five existing focused groups, eight full shards and aggregate, without new test skip rules or Golden updates.
- All results on the follow-up commit require new exact-SHA CI evidence; no native-device certification is implied.


## Follow-up: actual compact screenshot review and scroll coverage

- [Verify 37967927535](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37967927535) on `75e494490c6e89d5179a166a4e88a1dc63ab4da1`: **Dart Format + full Flutter Analyze PASS**, **17 More targeted widget/source tests PASS**, Splash PASS, Transaction Queue PASS. Strict focused Store **23 pass/21 Golden fail**, Data **36 pass/25 fail**, Production **38 pass/88 Golden fail**. Eight complete Flutter shards skipped, required aggregate red. [Android Debug 37967927449](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37967927449) **SUCCESS**.
- CI actual images: artifact `11634681223`, `visual_closure_more_phone_testImage.png` and `visual_closure_more_lower_phone_testImage.png`, viewed at 390 × 844 beside owner references `IMG_9672.PNG` and `IMG_9673.PNG` resized to equal width. New BIL design removes pale-blue background, dark card emphasis, saturated icons and oversized section spacing. It keeps BIL-specific group hierarchy rather than cloning reference. **No native device signoff.**
- A **nonpixel** Data Golden failure is `settings production phone capture page 4`: the old test dragged a fixed `-700` three times, but the now shorter More page reaches its bottom after the second movement. Follow-up uses `position.maxScrollExtent / 3` to produce three distinct forward movements and still captures **all four** viewports with strict pixel comparisons and no test suppression.
- Do not update visual Goldens automatically. CI on the follow-up fixture commit must be checked separately.
