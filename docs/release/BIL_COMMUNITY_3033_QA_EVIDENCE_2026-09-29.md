# Community 30/33 source verification

## Provenance
Base application: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1` (Android 29 / iOS 32).
Application source was prepared on an isolated branch. The preparation scripts are not part of this candidate.
Green preparation QA: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36549495389
QA source: `fe87fd09609a6aa5f8206c1e78952f46a01a65f3`.
Evidence artifact: `11023549291`; archive SHA-256: `5542e4c29ee0618c1562460d10ef99bd37a06866ed6a1525c5d0f60b6d405113`.
The artifact's `candidate.json` lists SHA-256 checksums for all 53 tested changed paths.

## Actual results in that run
- `flutter analyze --no-pub`: no issues found.
- Affected Community, notification, authentication and release contracts: 439 Flutter cases passed.
- Shared navigation, responsive shell/accessibility and settings: 193 Flutter cases passed.
- Disposable PostgreSQL 17, synthetic identities only: 22 assertions passed.
- Deno push transport/authentication/payload tests: 12 cases passed with mocked providers.
- Visual matrix: 40 PNG captures across English/Arabic, light/dark, text scale 1/2 and five Community scenes. These are headless test renders with substitute evidence fonts, not iOS pixel-equivalence, screen-reader certification or real-user data. Linux emoji glyph availability can differ from devices.

These 632 Flutter cases are not a claim that every repository test was run. The committed-candidate workflow separately runs the existing complete portable code-only suite and the new visual test. Its outcome must be read from that run, not inherited from this record. The visual test is explicitly classified outside the no-image code-only runner and still executed in its own job step.

## Live cloud status
The working QR migration `20260929050616` remains unchanged.
Attention/read-receipt migration `20260929074359` is deployed. Counts are own-account authenticated RPCs; caller-supplied owners are not accepted. The internal provider count requires service_role.
On 2026-09-29 the backward-compatible optional badge payload was deployed to `push-provider-gateway` v29 and `community-push-dispatch` v56. Existing shared-secret authentication and privacy-safe previews were preserved. No notification was sent manually and no live messages were marked read for testing.
Verified: message/friendship Realtime publication membership, RLS enabled, private profile/member guard definitions and QR resolver unchanged.

## Not claimed
No signed Android 30 AAB or iOS 33 IPA has been built or uploaded by this QA.
No real-device push delivery, badge presentation, notification permission acceptance, terminated-app deep-link opening or repeated Facebook sign-in was performed on this new source.
Android launcher numeric badges depend on launcher support; the in-app counters do not.
The full profile/health-data access policy is not relaxed. A QR card is not full-profile access.

## Release control
The 30/33 source manifests remain draft until final code-only verification and explicit freeze bindings. Never reuse the 29/32 source variables or change an existing review. No automatic merge into main or store upload is configured here.
