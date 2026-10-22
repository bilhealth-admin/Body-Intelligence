# Frozen-source QA recovery — 22 October 2026

Mobile source is strictly frozen at 31554b3e078667a38bd3c53aa105f5f1d2a4dc96. Do not move integration/bil-qa-media-policy-20261011, edit product files or execute bil_ios_signed_release.yml / workflow346770575 / TestFlight. All changes here are additional QA tools and documentation on qa/bil-independent-31554-20261022.

## Live-contracts failure diagnosed

Run39701915665 / job119572911077 failed before the controlled resolved-barcode request, during cleanup of the legacy synthetic fixture. The original QA function Get-CacheRows calls direct table REST access with service_role. Read-only production inspection confirmed SELECT and DELETE are absent on bil_barcode_shared_cache; RLS is enabled and the established bil_get_cached_barcode and bil_put_cached_barcode functions grant EXECUTE to service_role. No production grant, schema change or deployment was performed. Never apply GRANT merely to satisfy this outdated fixture helper.

The new adapter verifies the original script Git blob b98bfb00f889ab5f8c1a11ddd594286a7b62b037 and frozen HEAD, writes only an untracked temporary QA copy, and moves fixture read/delete to the management SQL transport already used by the original fixture setup. Cleanup is restricted to an exact numeric GTIN plus both original synthetic name/brand markers, checks the returned deleted identity and independently rereads for residue. Real product rows are preserved. The actual bil_put_cached_barcode RPC and barcode-lookup HTTP request remain unchanged. The existing strict Supabase CLI JSON parser handles both supported result shapes. CLI stays pinned to2.121.0.

## Independent scopes

bil_qa_live_recovery_20261022.yml first parses and exercises offline fixture safety without service credentials, then independently runs five failed/unrun scopes: resolved barcode; account deletion; community translation; public endpoint/live-workout/admin boundary checks; all five original guarded rollback SQL E2E audits. The SQL programs retain their exact PRECHECK/TRANSACTION/RESIDUE and body/ACL checks. No previously passing AI text/voice-metering/meal vision/premium barcode gate or full Flutter suite is repeated by this recovery workflow.

Each receipt distinguishes frozen product SHA from QA harness SHA. These are patched-harness scoped results, not a pristine full final certification and not proof of physical devices or stores. A queued, skipped, missing, malformed or failed job is not PASS. Do not relabel original run39701915665 as green; associate replacement receipts by exact scope.

## Existing runs to retain

Main independent dispatcher39701603831, Windows launcher repair39702297238, corrected dev tool audit39702054172. The corrected dev tool audit was observed successful; original committed dependencies remain unchanged. Transactional live cloud job119572910747 succeeded; its companion guarded SQL job was skipped after the live-contracts dependency failed. Core CI child run IDs39701825576,39701840404,39701855090,39701868179,39701878731,39701889132,39701903483,39701910826,39701915665,39701919420,39701926911,39701935548,39701940019,39701944497 must be checked independently, including child jobs of still-running workflows. MobSF depends on the exact native CodeQL artifact and must not be claimed run without its receipt.

## Monitoring and retry policy

Read actual latest logs and artifacts; classify infrastructure, QA harness, dependency security, product defects and external blockers separately. Retry only the affected job after verified transient failure or a reviewed tested QA repair; never loop on deterministic permission or advisory errors. If repairing QA code, a rerun of the old commit cannot pick up that repair: use the exact new QA workflow with the original frozen product checkout. Do not dispatch the master again, redo successful full suites, weaken assertions, rebaseline Goldens, publish secrets or modify production permissions. Update this record with verified replacement run IDs/results, not hoped-for success.
