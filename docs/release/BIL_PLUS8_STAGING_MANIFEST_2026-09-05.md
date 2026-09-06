# BIL +8 staging manifest — 2026-09-05

## Decision and scope

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: NO`

`UNRESOLVED_REVIEW_COUNT: 172`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 8`

This document classifies the dirty release tree for a future clean `1.0.0+8`
candidate. It is a staging plan, not authorization to stage, commit, build,
upload, publish, submit, or reuse build `+7`.

No credential value, signing material, local account data, `.codex`/`.agents`
probe, emulator failure artifact, build output, or log is approved for staging.
No `git add`, `git reset`, `git clean`, commit, push, build, upload, or store
mutation was performed while producing this manifest.

## Snapshot accounting

At the manifest boundary:

- `git status --short --untracked-files=normal` exposed **1,694 status
  entries**. Untracked directories are intentionally collapsed in that view.
- `git status --short --untracked-files=all` expanded the same tree to
  **1,925 leaf paths**.
- The exhaustive CSV contains **1,927 unique rows**: the 1,925 leaf paths plus
  the two manifest outputs themselves.
- CSV decision totals are **552 INCLUDE**, **1,203 EXCLUDE**, and **172
  REVIEW**; they sum to 1,927.
- CSV: `artifacts/release/BIL_PLUS8_STAGING_MANIFEST_2026-09-05.csv`.
- CSV SHA-256 at creation:
  `73A3DF5EEAF663BBADBE8A00FC69BFFF0B577C0ED7EFD392CEE8F42FEEFE146A`.

The CSV lives under the repository's `artifacts/*` ignore rule. It is retained
as local audit evidence and must not be assumed staged merely because this
Markdown report references it. Regenerate both counts and the digest after all
agents stop changing the tree and before creating the clean candidate.

### Post-snapshot working delta (not a freeze)

A later read-only comparison, after the Apple market correction, active-tool
market-policy repair, FIFO repairs, release-validator hardening and the stable
iOS QA source-contract handoff, observed **1,724 normal status entries** and
**1,969 expanded dirty leaf paths**. Relative to the 1,927-row CSV universe, 43
new leaf paths appeared; the
only base row absent from `git status` is the still-present staging CSV itself,
because `artifacts/*` is ignored. Including that evidence file makes the
provisional universe **1,970 paths**. Under the existing rules all 43 additions
are provisional INCLUDE, which would yield **595 INCLUDE / 1,203 EXCLUDE / 172
REVIEW**. These are not authoritative replacement totals and the historical
CSV/hash above must not be edited by hand.

Apple reconciliation additions:

- `docs/release/BIL_APPLE_MARKET_POLICY_CORRECTION_2026-09-05.md`
- `supabase/migrations/20260905170000_owner_store_market_policy_nigeria_alignment.sql`
- `tool/apple_store_connect/asc_subscription_market_sync.mjs`
- `tool/apple_store_connect/asc_subscription_market_sync.test.mjs`
- `tool/apple_store_connect/canonical_store_pricing_2026-09-05.json`

These five Apple additions now have an independently reviewed fail-closed
tooling verdict: 15/15 Node tests and targeted `git diff --check` pass; the
second authenticated post-apply inspection returned exact final sets for all
four subscriptions. They remain provisional INCLUDE until the regenerated
freeze CSV records them.

Active Apple market-tool corrections:

- `tool/apple_store_connect/package_app_review_goldens.dart`
- `tool/apple_store_connect/asc_selected_prices_inspect.mjs`
- `store_assets/review/apple/v1.0/manifest.json`

All three active surfaces now use EGY/NGA/PAK/TUR for ordinary Premium and
reject the superseded India sequence through
`test/features/commerce/final_store_market_policy_alignment_test.dart`. The
focused file passes 6/6, the Node inspector parses, and the targeted diff check
passes. Historical transition fixtures and deployed migrations were not
rewritten.

iOS dual-account QA tooling additions:

- `tool/release/ios_plus8_dual_account_canary.mjs`
- `tool/release/ios_plus8_canary_runtime_test.mjs`
- `tool/release/ios_plus8_dual_simulator_ui.sh`
- `tool/release/ios_plus8_idb_requirements.lock`
- `tool/release/ios_plus8_reinstate_watchdog.sh`
- `tool/release/ios_plus8_secret_scope_test.sh`
- `tool/release/ios_plus8_canary/cleanup_evidence.mjs`
- `tool/release/ios_plus8_canary/cleanup_readback.mjs`
- `tool/release/ios_plus8_canary/community.mjs`
- `tool/release/ios_plus8_canary/disposable_account.mjs`
- `tool/release/ios_plus8_canary/evidence_io.mjs`
- `tool/release/ios_plus8_canary/owner_admin.mjs`
- `tool/release/ios_plus8_canary/run_identity.mjs`
- `tool/release/ios_plus8_canary/runtime.mjs`
- `tool/release/ios_plus8_canary/service_runtime.mjs`
- `tool/release/ios_plus8_canary/setup.mjs`
- `tool/release/ios_plus8_canary/watchdog_cleanup.mjs`
- `tool/release/ios_plus8_simulator_ui/accessibility.sh`
- `tool/release/ios_plus8_simulator_ui/community_flow.sh`
- `tool/release/ios_plus8_simulator_ui/owner_admin_flow.sh`
- `tool/release/ios_plus8_simulator_ui/private_review_account.sh`
- `tool/release/ios_plus8_simulator_ui/secret_scope.sh`

Frozen-candidate validator additions:

- `lib/app/environment/release_configuration_validator.dart`
- `lib/app/environment/release_manifest_metadata.dart`
- `tool/release/validate_release_configuration.dart`
- `test/fixtures/release/accepted_plus8_manifest.md`
- `test/launch_readiness/release_configuration_workflow_gate_test.dart`
- `test/launch_readiness/release_manifest_metadata_test.dart`
- `test/platform_readiness/platform_readiness_contract_test.dart`
- `test/app_foundation_services_test.dart`

FIFO/build-contract additions:

- `lib/app/analytics/bil_incoming_link_controller.dart`
- `test/bil_incoming_uri_order_test.dart`
- `android/gradle.properties`

Android/tablet responsive additions observed after the iOS handoff:

- `lib/features/connected_health/widgets/health_hub_empty_state.dart`
- `test/features/connected_health/health_hub_empty_state_responsive_test.dart`

`INCLUDE` here means “belongs in candidate review,” not “accepted.” The iOS QA
source contract has passed an independent fail-closed cleanup, secret-scope,
transition, dependency-pin and line-cap audit: the exact workflow suite passed
180/180, its workflow contract passed 12/12, 13 JavaScript files passed syntax
checks plus both injected runtime probes, and eight shell files passed syntax
checks plus the executed secret-scope probe. Unsupported `idb ui rotate` is
absent; the contract claims only iPad portrait simulator runtime and a separate
landscape widget-test boundary. That result approves the files for candidate
review only: the remote simulator job was not executed, and no simulator result
can replace the signed iPhone/iPad gates.

## Classification contract

### INCLUDE — 552 leaf paths

Meaning: candidate source, configuration, deterministic tests, migrations,
release tooling, or release documentation that belongs in the review set.
`INCLUDE` does not mean automatically safe to commit: every included diff must
still receive secret scanning, ownership review, and a clean-candidate test.

Top-level distribution:

| Prefix | Count | Contract |
|---|---:|---|
| `test/` | 197 | Product and release-contract tests, excluding emulator QA and temporary visual failures. |
| `lib/` | 190 | Flutter product source. |
| `ios/` | 40 | iOS source, entitlements, plist/project, privacy and lifecycle configuration. |
| `supabase/` | 35 | Forward migrations and Edge Functions/tests; deployed history must remain immutable. |
| `docs/` | 32 | Current release, store, integrity, auth, and closure evidence. |
| `tool/` | 27 | Deterministic release/store/verifier tooling, excluding preview/vendor review items. |
| `android/` | 13 | Android source, manifest, Gradle, bridges and lifecycle configuration. |
| `cloudflare/` | 7 | Workout/recipe runtime source and tests. |
| `.github/` | 3 | Exact `+8` signed workflows and simulator QA workflow. |
| `public_site/` | 3 | Public association/policy site sources. |
| Remaining roots | 5 | `pubspec.yaml`, `pubspec.lock`, one bundled branding asset, `wrangler.site.jsonc`, and this staging evidence family. |

Critical INCLUDE paths that must be deliberately reviewed rather than staged by
a broad glob:

- `.github/workflows/bil_android_release_candidate.yml`
- `.github/workflows/bil_ios_signed_release.yml`
- `.github/workflows/bil_ios_plus8_dual_simulator_qa.yml`
- `pubspec.yaml` and `pubspec.lock`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt`
- `android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFacebookOAuthBridge.kt`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner/Info.plist`
- `ios/Runner/Runner.entitlements`
- `ios/Runner/BILAppAttestBridge.swift`
- `tool/apple_store_connect/canonical_store_pricing_2026-09-05.json`
- `tool/apple_store_connect/apple_catalog_policy.json`
- `test/features/commerce/final_store_market_policy_alignment_test.dart`
- `supabase/migrations/20260830180011_canonical_store_market_pricing_policy.sql`
- `supabase/migrations/20260905170000_owner_store_market_policy_nigeria_alignment.sql`
- `supabase/functions/app-attest/index.ts`
- `supabase/functions/play-integrity/index.ts`
- `supabase/functions/apple-sign-in-notifications/index.ts`
- `supabase/functions/ai-coach-global-reset/index.ts`
- `docs/release/BIL_PREPRODUCTION_CONTRACT_AUDIT_2026-09-05.md`
- `docs/release/BIL_APPLE_PLUS8_STORE_GATE_AUDIT_2026-09-05.md`
- `docs/release/GOOGLE_PLAY_LIVE_RELEASE_AUDIT_2026-09-05.md`
- `docs/release/META_BUSINESS_VERIFICATION_EVIDENCE_2026-09-05.md`

The Apple ordinary-Premium correction completed after this timestamped manifest
snapshot. Authenticated App Store Connect read-back, the September 5 canonical
JSON/catalog policy/test, and the live forward migration now agree on
`EG/NG/PK/TR`; the older EG/IN policy remains immutable history. The new JSON
and migration are later dirty-tree deltas and must be added to INCLUDE when the
counts/CSV are regenerated; do not alter the historical totals by hand. Never
edit deployed migration history or infer a storefront price.

### EXCLUDE — 1,203 leaf paths

Meaning: never stage these paths into the release candidate. The exclusion is
content-based and applies even if a path later moves under a different folder.

| Pattern/content class | Count | Reason |
|---|---:|---|
| `.agents/**` | 29 | Agent instructions/probe state; not product source. |
| `.codex_supabase_fetch_probe_20260901_2320/**` | 91 | Local Codex/Supabase probe state and potential environment evidence. |
| `assets/images/**` external recipe-source images | 883 | Not bundled or release-approved; provenance/licensing not accepted. |
| `test/emulator_qa/**` | 124 | Temporary emulator evidence, not deterministic product tests. |
| temporary failure/golden-diff paths under `test/**` | 76 | Failure screenshots/diffs/diagnostic output, not accepted baselines. |

Always EXCLUDE, even when absent from this snapshot:

- credential files and values: `.env*`, private keys, keystores, provisioning
  payloads, certificates, API tokens, service-account JSON, auth cookies and
  reviewer/owner passwords or PII;
- `.codex/**`, `.agents/**`, local probes, editor/session state and terminal
  captures;
- `build/**`, `.dart_tool/**`, Gradle/Xcode/Pods caches, derived data, coverage,
  logs, crash dumps, temporary archives, generated APK/AAB/IPA and signing
  outputs;
- `test/emulator_qa/**`, `failures/**`, `failure/**`, `*_diff.png`,
  `*_actual.png`, `*_expected.png` when they are temporary comparison outputs;
  and
- downloaded media or recipe images without provenance, license, runtime need,
  deduplication and an explicit asset-manifest entry.

### REVIEW — 172 leaf paths

Meaning: quarantine from automatic staging. A named owner must approve or
exclude each path before freeze; unresolved REVIEW is a release blocker.

| Prefix/content class | Count | Required review |
|---|---:|---|
| `test/**` visual baselines | 93 | Accept individually only after iPhone/iPad/Android phone/tablet visual comparison; do not confuse a baseline with runtime proof. |
| `videos/**` | 67 | Runtime need, duplicate/hash audit, codec/size, copyright/license and source-vs-output decision. |
| `tool/**` preview/vendor media | 6 | Five local audio previews plus one vendored tooling change; prove runtime need or exclude. |
| `artifacts/**` | 2 | Generated evidence; retain externally unless a release auditor explicitly requires it in-repo. |
| repository-wide controls | 3 | `.gitignore`, `.gitattributes`, `skills-lock.json`; inspect for hidden release files or scope expansion. |
| `macos/**` generated desktop file | 1 | Out of iOS/Android release scope unless intentionally regenerated and reviewed. |

Critical REVIEW families:

- every `videos/**` source, snapshot and render output;
- visual/golden updates and reference screenshots under `test/**`;
- `artifacts/release/visual_closure/**` and the staging CSV itself;
- `tool/bil_*_preview.wav` and vendored tool content;
- `.gitignore`, especially rules capable of hiding release/signing evidence;
  and
- `macos/Flutter/GeneratedPluginRegistrant.swift`.

## Clean-candidate execution gate

The staging manifest becomes executable only after all of the following are
true:

1. All active agents stop writing and the normal/leaf counts are regenerated.
2. Every REVIEW row has an explicit INCLUDE or EXCLUDE resolution.
3. Secret and PII scans pass without printing sensitive values.
4. The same-day Apple ordinary-Premium reconciliation remains exact on live
   read-back and in the new forward/canonical contract.
5. The reviewed INCLUDE set is transferred to a separate clean candidate; this
   dirty evidence tree is preserved.
6. The clean candidate records exact commit, tag, `1.0.0+8`, allowlist digest,
   dependency locks and clean `git status`.
7. Only then may platform workflows build exact `+8`; build `+7` is never
   promoted or repackaged.
8. Android phone/tablet and iPhone/iPad reports remain separate downstream
   gates. Emulator/simulator results never substitute for signed-device/store
   evidence.

Until those conditions pass: `STAGE/COMMIT/BUILD/UPLOAD/PUBLISH = BLOCKED`.
