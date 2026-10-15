# BIL maximum test coverage register — 15 October 2026

## Current correction after reviewing text-7 through text-18

The authoritative continuation is [the reconciliation report](BIL_TEXT7_18_RECONCILIATION_20261015_AR.md), started at `7a797819d882674b6b7ed83a546c23ff3922c312`. The tables and counts below are retained historical evidence from the earlier audit, not a claim that all 53 coverage entries ran on the newer source.

- Preserve the 9,843/9,843 full Flutter result on `ef4b9f19...`; it was not rerun.
- Ref-specific Code Scanning now has **25 fixed instances and 26 open** on JavaScript/actions analysis `699abff3`. ReDoS alert 5 is fixed. The remaining 26 were individually inventoried; high alert 48 in generated Dart runtime metadata remains open pending a reachability decision. No finding was manually dismissed. See `evidence/text7-18-reconciliation-20261015/codeql-triage.json`.
- SQL AI-report failure was reproduced with native PostgreSQL 17.6 and fixed in the test's singleton state; the exact SQL suite then passed. The product migration was unchanged. The SQL workflow now uses `psql` for its RAISE/DO assertions instead of incorrectly expecting pgTAP output.
- Android run `38713591000` passed build, CodeQL and 97 purchase-fake tests; native tests did not start because a protected airplane-mode broadcast was rejected. The setup command was corrected and syntax-checked; emulator confirmation is pending. Its iPhone/iPad job is still running separately.
- Three updated moderator/admin Flutter tests passed locally. Actual product RPC coverage was added for isolated Auth/PostgREST AI-report and encrypted two-device Restore V2. Full Supabase API execution is pending; native PostgreSQL is not relabeled as that test.
- Semgrep and full Flutter analyze are being verified locally; only completed results enter the reconciliation report. Signed artifacts, store/reviewer phone sessions, HealthKit authorization, and Production deployment are still separate unproven gates.

## Historical audit snapshot (tables below)

## Direct result

The completed Flutter suite remains **9,843 passed, 0 failed, 0 errors, 0 skipped across 1,356 test files**, with full `flutter analyze --no-pub` reporting `No issues found!`. That evidence is tied to application-source commit `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67` and input fingerprint `80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e`. It was not rerun because this audit did not change `lib/`, `test/`, migrations, or Flutter dependencies.

Audit commit `234b75d1e8b449d17701663695afeffdfca1f991` was pushed by fast-forward to `integration/bil-qa-media-policy-20261011`. It changes CI workflows, the Cloudflare workout-runtime dependency lock, and release-preparation records only. It does not change app code, Flutter tests, prices, Trial, production data, store metadata, or build numbers. The GitHub Actions run on the audit commit is tracked separately below; prior app test evidence is not relabeled as having run on this newer repository SHA.

Neither Android 33 nor iOS 36 is release-ready. There is no signed AAB/IPA, store upload, clean-install reviewer test, or current physical-device session. The Android release manifest retains five unresolved Google review cases. No appeal was sent and no App Store Connect fields were changed.

## Repository and retained evidence

| Item | Value |
|---|---|
| Repository / branch | `bilhealth-admin/Body-Intelligence` / `integration/bil-qa-media-policy-20261011` |
| Parent before this audit | `eb7d095aeb09c76770a3a2173cee2771d06153ff` (matched `origin` before push) |
| Pushed audit commit | `234b75d1e8b449d17701663695afeffdfca1f991` |
| Application code and full Flutter test source | `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67` |
| Flutter input fingerprint | `80087ad7b2ef76192e9f22c5be0af34edc53dfc2139eb1b63ad81eaf7416614e` |
| Existing full test report | `BIL_20261014_FULL_SUITE_REPAIRS_AND_FINAL_RESULT_AR.md` |
| Preserved diagnostic files | 44 generated `test/**/failures/*.png` files remain unstaged and uncommitted |
| Store version records | Android `1.0.0 (33)` and iOS `1.0.0 (36)`; both manifests remain incomplete; `pubspec.yaml` remains `1.0.0+8` |

No `lib/`, `test/`, or `supabase/migrations/` file was included in the audit commit. The prior 9,843-case result therefore remains valid for the unchanged Flutter test inputs, but it is cited under its actual source SHA and fingerprint.

## Executed evidence

| Area | Result | Source, count, and limitation |
|---|---|---|
| Flutter full suite and full analyze | **PASS — prior exact app-source evidence** | SHA `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67`; 9,843/9,843, 1,356 files, 0 fail/error/skip; `flutter analyze --no-pub`: no issues. Not rerun for CI/Cloudflare-only changes. |
| GitHub focused integration QA | **PASS — prior exact app-source evidence** | [Run 38653187976](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38653187976), SHA `ef4b9f19f491426ba8663ba1a9d76f9af6fe0c67`; not a phone/store run. |
| Instant Experience QA | **PASS** | [Run 38659886270](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38659886270), audit SHA `234b75d1e8b449d17701663695afeffdfca1f991`; exact run logs/artifact retained by GitHub. |
| CodeQL security-extended | PASS WITH FINDING | Run 38675377540 completed successfully on aca3afbd in all five configured languages. Code Scanning reports 47 open alerts on this ref (1 high/error, 45 warnings, 1 note); alert 5 is an unresolved ReDoS in the generated web worker, traced to stack_trace 1.12.1. The current upstream package source still has the pattern. |
| HealthKit iOS cloud simulator | **PARTIAL** | [Run 38662883181](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/38662883181), `macos-26`; code gate passed and navigation evidence captured, but no native HealthKit authorization sheet appeared. This does not prove permission behavior on iPhone. |
| GitHub Actions syntax | **PASS** | `actionlint` 1.7.12; all 60 `.github/workflows/*.yml` files; exit 0. |
| Workflow security lint | **PASS WITH NON-FATAL PARSER WARNING** | `zizmor` 1.30.1; 0 reported workflow/config findings after scoping writer permissions, pinning actions, and removing npm-installed Deno. Exit 0; one non-fatal warning could not parse one iOS workflow. `actionlint` parsed all 60 workflow files. |
| Dependabot YAML | **PASS** | PyYAML syntax and semantic check: 6 ecosystems; 7-day ordinary version cooldown; `open-pull-requests-limit: 0` for routine version PRs. Security update PRs remain enabled separately and are not delayed by the cooldown. |
| Cloudflare dependency checks | **PASS** | `npm run check`: Wrangler type generation, TypeScript typecheck, and 5 staging-isolation tests passed. `npm test`: 5 files and 49 tests passed. `npm ci --no-audit --no-fund` passed. |
| OSV / Grype / Trivy | **PASS WITH LICENSE NOTICE** | Current OSV post-fix lock scan: 0 findings; Grype CycloneDX scan: 0 matches; Trivy: 0 vulnerabilities, 0 misconfigurations, 0 secrets, and one LOW MIT license notice for `jose`. The MIT notice is a license attribution obligation, not a vulnerability. |
| SBOM | **PASS — inventory only** | Syft recorded 540 artifacts; CycloneDX 656 components; SPDX 541 packages. CycloneDX SHA-256: `8F530E3C6B61287744BE94DAA539EDE3D8E7262B875B6CB41954A7510AE00A2C`. This is a source inventory, not a signed release SBOM or attestation. |
| Gitleaks staged-change scan | **PASS** | `gitleaks protect --staged`: 0 new matches. Run log scan and downloaded QA artifact scan: 0 matches each. |
| Gitleaks broad checkout scan | **REVIEW REQUIRED — historical heuristic matches** | 17,254 matches across the broad checkout scan, mostly generic-key fingerprints and test/build material; 8 matches in changed workflow paths were each on lines outside the added/modified hunks. No matched value is reproduced here. GitHub separately reports one open, publicly leaked `google_api_key` alert in `android/app/google-services.json`; validity is unknown and provider restrictions require owner verification. The staged diff itself is clean. |
| Semgrep | **BLOCKED — local scanner runtime** | Semgrep 1.181.0 installed in an isolated temporary directory, but Windows `semgrep-core` failed rule validation and produced no usable scan. This is not a pass. CodeQL runs remotely on the supported languages. |
| GitHub security settings | **PASS WITH OWNER ACTION** | Public repository; secret scanning, push protection, and Dependabot security updates enabled; Dependabot alerts count 0. Validity checks and non-provider secret patterns are disabled. One key alert remains open. |
| SBOM provenance / attestations | **BLOCKED** | No release artifact exists to attest. GitHub artifact attestations were not created. |
| Branch rules | **NOT CONFIGURED** | No repository ruleset and the integration branch API returned “Branch not protected.” No branch protection was changed by this audit. |

## Coverage register by family

Status values are **PASS**, **PASS WITH FINDING**, **IN PROGRESS**, **BLOCKED**, **NOT RUN**, and **NOT AVAILABLE**. A blocked or unavailable row is not a pass.

| IDs | Final classification | Evidence and remaining boundary |
|---|---|---|
| GH-01 CodeQL language support | PASS | Five supported languages are in the CodeQL matrix; Dart/Flutter remains outside CodeQL. |
| GH-02 CodeQL standard/security-extended | PASS WITH FINDING | Run 38675377540 on aca3afbd completed all five jobs and uploaded results. 47 Code Scanning alerts remain open; see alert 5 and current-source evidence above. |
| GH-03 GitHub Code Quality/AI review | NOT AVAILABLE | No Code Quality service result is enabled for this repository/account; Flutter analyzer and source checks are separate. |
| GH-04/GH-05 secret scanning and push protection | PASS WITH FINDING | Both enabled; one open public Google API key alert remains unverified. |
| GH-06 custom secret patterns | NOT AVAILABLE | GitHub non-provider patterns are disabled; no custom patterns were added. |
| GH-07 secret validity | BLOCKED | GitHub validity checks disabled; Google Cloud owner must inspect/restrict the key and rotate only if its scope/validity requires it. |
| GH-08 history/worktree secret scan | PASS WITH FINDING | Staged diff 0; broad scan contains historical/test heuristics and the separately reported open key alert. |
| GH-09/GH-10 logs and artifacts | PASS | Run 38653187976 log and its 40-file/12.36 MB QA artifact were scanned; 0 Gitleaks matches. |
| GH-11 dependency graph | PASS — public package inventory | Local Syft SBOM and GitHub dependency features were checked; no release artifact graph exists. |
| GH-12 Dependabot alerts | PASS | Current alert count: 0. |
| GH-13 Dependabot security updates | PASS | Enabled; ordinary version PRs disabled through limit 0; seven-day cooldown is explicit. |
| GH-14 Dependency Review | NOT RUN | No pull request diff exists on this audit; no PR-only dependency review was claimed. |
| GH-15 dependency submission | NOT AVAILABLE | No Flutter dependency submission was generated during this audit. |
| GH-16 SBOM | PASS — source only | Syft CycloneDX/SPDX inventory and checksums above. |
| GH-17 artifact attestation | BLOCKED | No signed release artifact to attest. |
| GH-18 license review | PASS WITH FINDING | Trivy reported the low MIT notice for `jose`; preserve attribution. |
| GHA-01 workflow syntax | PASS | `actionlint` validated all 60 workflow YAML files; latest change added only a shell/Python harness. |
| GHA-02 workflow security lint | PASS | `zizmor` reported 0 findings; see the parser caveat above. |
| GHA-03/GHA-04 permissions and action integrity | PASS — static audit | 25 existing workflows were reviewed/updated; third-party actions are SHA-pinned and credentials disabled on read-only checkouts. The scoped writer retains job-only `contents: write`. |
| GHA-05 cache/artifact controls | PASS — static audit only | No new runtime cache-poisoning experiment was performed; workflow linter and manual trigger/artifact review are not a runtime exploit test. |
| GHA-06 release gates | PASS — fail-closed source check | Android/iOS manifests remain incomplete and signed workflows require explicit manual dispatch. |
| GHA-07 Node/runner compatibility | PASS — static/CI scope | Deno setup uses Node 24; HealthKit moved to macOS 26; full behavior awaits the named runs. |
| GHA-08 branch protection | NOT CONFIGURED | No branch protection/ruleset; do not infer required-check enforcement. |
| GHA-09 workflow inventory | PASS | 58 existing workflows were individually inventoried in `BIL_20261014_GITHUB_COMPLETE_RELEASE_CERTIFICATION_AR.md`; CodeQL and isolated Android smoke bring the current count to 60. 25 existing workflow files were updated in the audit commit. |
| PLAT-01/PLAT-02 Git and LFS integrity | PASS | `git fsck --full --no-reflogs` and `git lfs fsck` passed before/after; the post-commit LFS hook was manually completed after Git Bash process creation failed. |
| PLAT-03/PLAT-05 Flutter resolve and Windows source tests | PASS — prior source SHA | Full suite/analyze on app-source SHA `ef4b9f19...`; no Flutter inputs changed afterward. |
| PLAT-04 Linux | PASS — focused only | GitHub focused run 38653187976 passed on `ef4...`; no full Linux Flutter suite claimed. |
| PLAT-06 macOS/iOS | PARTIAL | HealthKit simulator run 38662883181 completed as EVIDENCE_ONLY; no native permission sheet or physical device result. CodeQL Swift source analysis passed in run 38675377540; this is not a device test. |
| PLAT-07 Intel/Linux ARM | BLOCKED | No dedicated compatible runner/matrix run. |
| PLAT-08/PLAT-10 release builds, symbols, ABI and signing | BLOCKED | No release signing/build workflow was dispatched; no AAB/IPA or Android/iOS SDK artifact inspection. |
| PLAT-09 assets/localization/source compilation | PASS — source tests only | Existing Flutter suite; not a signed/bundled artifact check. |
| AND-00 prior Android smoke evidence quality | PASS WITH FINDING | The earlier false-green artifacts were rejected; the gate was tightened in aca3afbd and run 38675377553 passed 6/6 startup checks. |
| AND-01–AND-06 Android API/emulator, lifecycle, accessibility, resilience, 16 KB | PARTIAL | Run 38675377553 passed startup/content checks on API 26/29/33/34/35/36; the six final artifacts show Welcome and an enabled clickable control, with no BIL crash/ANR. Full lifecycle, accessibility session, resilience, 16 KB alignment, signed AAB, and physical device remain untested. |
| IOS-01–IOS-03 iOS simulator, UI, lifecycle/HealthKit | PARTIAL | HealthKit simulator run 38662883181 remains evidence-only; CodeQL Swift passed in 38675377540. No full iPhone/iPad UI matrix. |
| IOS-04 VoiceOver/Dynamic Type/device accessibility | BLOCKED | No physical iOS device or native accessibility session. |
| IOS-05 IPA/signing/privacy manifest/App Store | BLOCKED | No signed IPA or App Store Connect validation. |
| APP-01 navigation and app interaction | PASS — source only | Full Flutter source suite and focused GitHub run; no full device journey. |
| APP-02 authentication, OAuth, sessions and account isolation | BLOCKED for live E2E | Existing contracts/mocks do not prove real Auth on a release artifact; no real user account was used here. |
| APP-03 SQL/RLS/RPC/Edge/Storage/Realtimes | PARTIAL | Prior local PostgreSQL/PGlite and cloud-contract evidence remains in `BIL_20261014_LOCAL_CONTINUATION_HANDOFF_AR.md`; no full local Supabase stack or Production write. |
| APP-04 DAST/rate-limit/abuse | BLOCKED | No isolated authorized live endpoint configured. |
| APP-05 crypto/key rotation/recovery | PARTIAL | Source/contract checks exist; no handset Keystore/Keychain or real key-rotation E2E. |
| APP-06 purchase/restore/refund/boost | BLOCKED for store E2E | Source contracts only; no StoreKit/Play sandbox purchase, real receipt, refund, or renewal. |
| APP-07 AI Coach/Vision/live provider | BLOCKED for live provider E2E | Source suite only; no provider credentials or budgeted live session used in this audit. |
| APP-08 community moderation/messaging/admin | PARTIAL | Source tests and earlier isolated local SQL evidence; no live four-account release-artifact E2E. |
| APP-09 nutrition/goals/sync/history | PASS — source/contracts only | Existing full suite and local cloud contract; no phone-to-hosted-cloud run on this candidate. |
| APP-10 performance/fault injection | BLOCKED | No device profiler or production-like isolated backend load target. |
| APP-11 coverage/fuzz/mutation | NOT RUN | No coverage baseline, fuzz campaign, or mutation score. |
| APP-12 localization/RTL/accessibility/overflow | PASS — source only | Existing localized/visual source tests; native screen-reader behavior not verified. |
| APP-13 actual Coach screenshots/device visuals | BLOCKED | No physical device capture for this candidate. |
| REL-01/REL-02 Android 33 package, signing, Integrity | BLOCKED | No AAB; release manifest incomplete and 5 review issues remain. |
| REL-03 iOS 36 IPA/signing/StoreKit | BLOCKED | No IPA; release manifest incomplete. |
| REL-04 SBOM/provenance | PARTIAL | Source SBOM exists; no artifact SBOM, attestation, or signing chain. |
| REL-05 freeze/store submission | BLOCKED | Both `STAGING_MANIFEST_COMPLETE` and `CANDIDATE_FROZEN_OR_ACCEPTED` are `NO`; no submission. |

The 53 high-level coverage entries currently classify as: 20 PASS, 5 PASS WITH FINDING, 7 PARTIAL, 0 FAIL, 15 BLOCKED, 0 IN PROGRESS, 3 NOT AVAILABLE, 2 NOT RUN, and 1 NOT CONFIGURED. NOT APPLICABLE: 0. The Android false-green was detected, corrected, and rerun; Android remains partial because only startup UI was proven. CodeQL completed but remains a security finding because open alerts persist. These are coverage-entry counts, not executed test counts; Android 33 and iOS 36 remain not release-ready.

## GitHub security and release actions

- The package override moves `miniflare.sharp` from `0.35.4` to `0.35.5`; the regenerated lockfile also resolves the affected transitive packages. OSV reports 0 post-fix findings, and the Cloudflare tests pass. No routine package-update PRs are enabled; security updates remain active.
- `verify.yml` no longer interpolates the pull-request base branch directly into shell source; it validates the environment-provided ref and checks fetch/resolve exits. The Vision writer workflow scopes `contents: write` to its single integration job and supplies a job-token only to the push step. Read-only checkouts no longer persist credentials.
- The Play alert in `google-services.json` is an unresolved provider-key review item. Firebase documents that Firebase API keys identify a project and should be restricted to the APIs used by the app; the key value is omitted from this report. Owner action: check Google Cloud API restrictions and Generative Language API access, then rotate if needed. Source-level detection does not establish that the key is exploitable.
- The 7-day Dependabot cooldown applies to ordinary version updates only; GitHub’s security-update PR path remains immediate. See [Dependabot cooldowns](https://docs.github.com/en/code-security/how-tos/secure-your-dependencies/optimizing-pr-creation-version-updates) and [security-update customization](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/manage-your-dependency-security/customizing-dependabot-security-prs).

## Workflows and automatic effects

Before the audit commit push, the integration branch had no active Actions run; that push triggered only Instant Experience and CodeQL. The inventory then had 59 workflows after adding CodeQL. The later Android startup-smoke workflow raised the current total to 60. Neither workflow deploys, signs, uploads to a store, writes production source, or runs a production migration. Readiness workflows requiring store signing or production credentials were not dispatched.

No main-branch change, force push, price/Trial change, live migration, Play upload, TestFlight upload, appeal, production write, user-session creation, account grant, or balance mutation occurred.

## Required owner and device gates

1. Review the open Google API-key alert and apply API restrictions in Google Cloud; do not paste or commit the key.
2. Complete the five outstanding Google case reviews and confirm whether the one permitted appeal has already been used. Do not send the prepared appeal until a signed build 33 and reviewer clean-install/access test exist.
3. Build and validate Android 33 with the isolated production-safe release process after owner approval; inspect merged manifest, 16 KB alignment, upload certificate, Play products, clean install and reviewer access.
4. Build and validate iOS 36 without TestFlight upload; inspect the IPA, privacy manifests/SDK inventory, entitlements and Apple reviewer access. Confirm App Store Connect metadata using the approved account.
5. Run signed artifacts on real Android and Apple hardware, including actual store sandbox purchase/restore, Health Connect/HealthKit and accessibility. Simulator/source runs cannot replace this.

\n