Gemini photo estimates V2 — staged, disabled, not published

Root status, 2026-11-19: analyze-meal107 and the supplemental-consent migration
20261119054650 are deployed and their complete source/ACL readbacks match.
The global V2 flag remains absent (effective OFF). Local Dart/Deno/PostgreSQL
gates and ordinary-user admission rejection checks passed; actual Gemini V2
output and signed48/40 native acceptance remain separate required gates.
This is an internal release candidate, not approval for public activation.

V1 remains the exact installed47/39 analysis contract: selected photo, locale
and technical image/request metadata identify visible food and portions. V2 is
opted into only by a new binary with BIL_GEMINI_PHOTO_ESTIMATES_V2=true and a
server with BIL_MEAL_VISION_ESTIMATES_V2_ENABLED=true. Both default off. There is
no fallback from a denied/unavailable V2 request to a second paid V1 analysis.

V2 adds a separately revocable meal_vision_nutrition_ai policy1 receipt on top
of the existing meal_vision_ai policy1 receipt. It expands the described Gemini
output to the pictured portion and sparse supported nutrition estimates. It
does not add health/profile context to the image request. Base withdrawal still
blocks both versions. V1 receipts are neither replaced nor silently upgraded.

The Review identifies Google Gemini as its source and labels values estimates.
Unknown is null, explicit zero is retained, and only supplied nutrients are
displayed/persisted. Canonical unit conversion occurs on the server; the
reviewed portion scales that source basis exactly once in the atomic diary
transaction. No catalog, USDA, verified-food status or medical accuracy is
claimed. Direct net carbohydrate is optional evidence, not a client calculation
to fill a missing model value. Every supplied supported micronutrient survives
in the immutable envelope; compatibility columns do not turn missing values
into measured zero.

Analysis and opening Review write no diary rows. Daily Log and Food Log show
Save and its meal/day destination; their one explicit confirmation commits.
Coach shows Use this estimate, then the existing-style visible meal/day Save
confirmation. No action auto-logs just because Gemini returned a response.
All stages retain the captured authenticated owner visit across await, picker,
consent, image preprocessing, transport, dialog and SQL. Old owner ABA work is
retired. No account/consent/entitlement change is inferred from model output.

The existing usage reservation, settlement and refund contract remains one
successful image analysis charge. Review edits and confirmation add no Gemini
requests. Plans feature listings name existing Personal plan and BIL Vision
using AI tokens; no PersonalPlan engine/template/generation or pricing/right
change is included.

Activation checklist for Root, after review/tests:
1. Verify source-bound consent migration preconditions and deploy the reviewed
   migration/functions under the existing separately approved cloud workflow.
2. Run V1 regression, V2 schema/security/quota/consent RLS, owner and persistence
   tests. Root keeps their command receipts and source bindings separately;
   local success does not establish hosted provider or signed-device success.
3. Review public privacy/store disclosures for the same expanded output and
   recipient before activation; the application includes a feature-specific
   dated legal addendum, not a claim that hosted policy has already changed.
4. Review mixed-version cloud compatibility: new V2 envelopes require the new
   reader. Installed47/39 fails closed on new evidence rather than mislabel it.
   Do not enable mixed-version cloud writing without an accepted compatibility
   policy. No server/client flag is enabled by this external proposal.
5. Run a new signed48/40 real Gemini image review/explicit-save journey, inspect
   actual nullable nutrients/basis/provenance and owner/durable roundtrip.
   Local mocks do not establish hosted Gemini quality or native acceptance.
