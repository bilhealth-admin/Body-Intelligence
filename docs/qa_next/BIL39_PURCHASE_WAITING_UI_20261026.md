# Purchase waiting and Restore evidence — 26October2026

Scope: dirty `bil39/integration-20261025`, base155b079696430919f8272df934371f033fb11be2. This is local integration evidence, not final committed-SHA CI or signed39 device acceptance.

The four prior commerce fixes and their11-file manifest remain independently recorded in the private `commerce-focused-20261026` handoff. Parent reviewed the actual seven production-file diffs and verified all11 hashes before extending this work. No purchase owner, credit, subscription price, store metadata, native verification contract or Production data was changed.

## Newly reproduced defect

The Plans page declared Restore timed out after20seconds while its shared service continued awaiting native sync under the existing90second policy. A receipt could be verified in that interval, causing contradictory success, timeout and busy messages. Initial native Restore also used checkout's generic opening message.

Two new behavioral widget cases reproduced the timeout RED, including a receipt verified before native Restore completed. The first fixture run additionally exposed a missing ProviderScope; that fixture was corrected and the second RED retained before product changes. No assertion was weakened.

The service now declares `restore_pending` and exposes its read-only `isRestoring` state. After the20second observation deadline, the page awaits the **same** still-running service operation. It does not retry, make another purchase, increase the service's pending deadline or treat receipt verification as completion of native sync. Its status remains Restore-specific until settlement. An unknown final result offers continued verification rather than claiming failure or an empty history. Existing ownership rejection and inactive-receipt behavior remain authoritative.

The four affected service/UI suites finished successfully:103 behavior cases plus4 hidden suite-loading entries. Evidence: private `central-register/commerce-restore-ui-deadline-green.jsonl` (terminal success=true). The new cases cover early verification, pending beyond the UI observation window, unknown settlement, one restore call and zero purchase requests.

## User-approved loading presentation exception

The user explicitly requested the existing Splash activity indicator, then clarified: **no indicator inside the purchase button; one indicator above it is sufficient**. This supersedes the old whole-file freeze only for the reviewed waiting presentation. Button shape, price, arrow, halo, interaction and commercial policy remain protected.

- Reuses `BilFeatureWelcomeStatus`, including the same segmented glyph, radius12, theme colors and native/Flutter reduced-motion handling.
- A single indicator appears beside the existing status above checkout. The purchase button keeps its label and localized price while disabled.
- Restore uses its static restore icon and existing checking text; it does not add a second spinner.
- Coach waiting reuses the same component beside its original labels. Preparing/Working/Thanks texts, phase timing and composer/navigation contracts are unchanged.
- The shared indicator's optional default colors exactly match the existing feature Splash palette. Existing explicit-color callers retain their supplied colors.

Focused tests:53 behavior cases PASS in `commerce-single-splash-indicator-tests.jsonl`, comprising16 loading variants,5 Coach status cases,28 Plans/Boost UI cases and4 protected CTA cases. Tests assert no indicator descendant inside checkout, exactly one actual Splash component, retained price, no purchase requests while busy, AR/EN, Light/Dark,1x/2x and reduced motion. The widget-test PNGs initially used Ahem placeholders, so they are **layout evidence only, not native typography approval**. Native captures are a separate gate.

The zero-tolerance comparator passed all12 original checkout surfaces (rest/pressed/cancelled × Light/Dark × LTR/RTL), including the full button, halo and geometry. Only the separately reviewed nonpayment feature-chevron decoration may differ. Evidence: private `cta-single-indicator-exact-comparison.json`.

Original component blob:26303dce18ddc3f4f4ddceb859081283c0aebfe7. Current approved waiting component blob:fdd24dbfa5b16f78aad65a821a2f5cf1215f90d5. The exact-source build guards now pin the current reviewed blob; they do not bypass hash validation. Shared legacy glass remains653d424ddb6cca8adeb0d394f5c8f8866da3792d.

## Remaining release gates

Native compositor review, final integrated local QA, final committed-SHA GitHub gates, and signed39 Apple purchase/Restore checks remain separate requirements. Existing38 observations, HTTP200 responses and local test success do not satisfy them. No final integration commit, release upload or App Review submission is asserted by this record.
