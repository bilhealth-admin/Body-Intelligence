# Community 30/33 source verification and freeze evidence

## Provenance

Base application: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1` (Android 29 / iOS 32).
Candidate branch: `fix/community-3033-ready`.
Verified runtime/test source: `d6319d1333c4ffba2df02581f1bb09fa8c24eecd`.
Green exact-commit QA: https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36600429394
All six jobs completed successfully. The source evidence verifies ancestry and
contains the complete patch against the stable base. This freeze changes only
this evidence record and the two source manifests, then reruns exact-commit QA.
Its result must be read from that new run, not assumed from the parent.

## Actual results at d6319d1

- Formatting: all 44 changed Dart files pass the pinned Dart formatter.
- `flutter analyze --no-pub`: no issues found.
- Portable code-only shard 0: 1,302 cases, 249 files, zero failed commands.
- Portable code-only shard 1: 1,397 cases, 248 files, zero failed commands.
- Portable code-only shard 2: 1,129 cases, 248 files, zero failed commands.
- Portable code-only shard 3: 1,383 cases, 248 files, zero failed commands.
- Existing performance budget, run separately: 2 cases passed. Observed database
  startup 91 ms and median 1,000-food search 1 ms; these are runner measurements,
  not a mobile-device performance guarantee. No budget was relaxed.
- Portable total including performance: 5,213 Flutter cases across 994 files.
- Additional Community visual matrix: 8 cases passed, producing 40 PNG captures.
- Total Flutter cases across these jobs: 5,221.
- Disposable PostgreSQL 17, synthetic identities only: 22 assertions passed.
- Deno provider/dispatch tests: 12 cases passed, zero failed, mocked transports.

The discovery plan contains 1,028 test files. The code-only policy excludes 34
files from that selection and preserves its seven existing mixed-file name
filters. The new visual file is one of those 34 and is explicitly executed in
the separate visual job. No claim is made that every repository test, device
integration test, asset/native test or excluded case was executed.
The four plan.json/results.json artifacts prove an exact, non-overlapping
partition of the 993 remaining selected files after the performance prerequisite.

## Evidence artifacts for d6319d1

| Artifact | ID | Archive SHA-256 |
| --- | --- | --- |
| Source and performance | 11048408455 | d04b455fa741e79c9b06753dfca9654611c728895a734b511119f588c01db989 |
| Shard 0 | 11049986197 | 7bb8ff725996891d9397572928e5935f968508193d63647a3f066a43dcbfb449 |
| Shard 1 | 11048784353 | fba33e2fd4dd93a805a260e8dc4edbc6dcfaa7b0207c29d7df8bba4385abcd49 |
| Shard 2 | 11050530955 | 2fff9afb548144839ccb5e0084c9311f2c45fb549f537596a86166e5b2b99fb5 |
| Shard 3 | 11048689476 | 7eaf5dc39341f5ad89b8222d999a8bd5288c994515473a54d26dfddfacd2010a |
| Visual and cloud boundaries | 11049885122 | 22c9ea9487bbd01cce786a63c1a516d595fe74173a1dc18b72b6e892a2d37706 |

## Visual inspection boundary

The 40 captures cover feed, actions, inbox, connections and chat, in English and
Arabic, light/dark and text scale 1/2. They match the previously inspected
candidate captures byte-for-byte. All five scene matrices were visually reviewed.
They are headless test renders with substitute evidence fonts, not iOS pixel
identity, VoiceOver/TalkBack certification, emoji-font completeness or real-user
data. Native fonts and large-text behavior still need device acceptance.
No font files are included in the exported evidence.

## Live cloud status verified on 2026-09-29

The working QR migration `20260929050616` remains unchanged.
Attention/read-receipt migration `20260929074359` is deployed. Counts are
own-account authenticated RPCs; caller-supplied owners are not accepted.
The internal arbitrary-owner push badge RPC is executable only by service_role.
`push-provider-gateway` v29 and `community-push-dispatch` v56 include backward-
compatible optional badge payloads. Shared-secret authentication and privacy-safe
previews remain intact. No notification was sent manually and no live messages
were marked read by this verification. Message/friendship Realtime publication,
RLS and the original QR/profile privacy boundaries were verified.

## Release and device boundaries

The paired source manifests are frozen for signed-artifact QA, not public release.
Both audited source variables must refer to the same final freeze commit and each
manifest variable must match that committed file's SHA-256. Repository-variable
writes were not performed by this verification. Existing 29/32 bindings are not
reused. No automatic merge into main or store upload is configured here.
No signed Android 30 AAB or iOS 33 IPA has been built by this source QA.
Real-device token registration, permission acceptance, push/badge presentation,
terminated-app taps and repeated Facebook login must be verified on new binaries.
Android launcher numeric badges depend on launcher support; in-app counters do not.
A QR card remains limited public identity, never full-profile or health-data access.
