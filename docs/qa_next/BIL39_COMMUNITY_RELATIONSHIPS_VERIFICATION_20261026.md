# BIL39 Community relationships: implemented flows and live verification

Verified on 26 October 2026 in `G:\BIL_Project\worktrees\bil39-integration-20261025`, branch `bil39/integration-20261025`, base HEAD `155b079696430919f8272df934371f033fb11be2`.

The integration tree is dirty. File SHA256 receipts identify the tested implementation; this document is not exact-commit CI, signed-build, physical-device, or TestFlight certification.

## What was incomplete

- Follow changed to an ambiguous Following label instead of exposing Unfollow.
- Pending friendship lacked direct cancellation. Incoming requests did not open a focused acceptance/rejection action. Accepted friendship management could disappear when a friend count was shown.
- Connections rows did not open the other person's profile, and closing a profile connection list could leave stale counters.
- Optional creator metadata could suppress a verified follow result or keep Unfollow disabled indefinitely after the core mutation and overview had succeeded.

## Implemented user flow

| Entry / state | Behavior |
| --- | --- |
| Feed author name/avatar, People search, profile connection list | Opens that person's profile. |
| Main Connections member row | Opens the correct other profile; refreshes Connections on return. Existing chat actions remain available. |
| Other profile, not following | Follow performs the deployed RPC, then reads the profile projection back. The same button becomes Unfollow. |
| Other profile, following | Unfollow performs its RPC and verified readback; the same button returns to Follow where new follows are permitted. |
| Other profile, no friendship | Add Friend sends a real request; verified outgoing state exposes pending status and Cancel request. |
| Incoming friendship | Review request opens Accept / Decline / Cancel. |
| Accepted friendship | Friends opens explicit Remove friend / Cancel. |
| Own profile | No Follow or Add Friend against oneself. |

Followers and accepted friends are separate relationships. Accepting a friend does not create a follow or inflate follower counts.

Production UI files are `community_member_profile_header.dart`, `community_member_profile_actions.dart`, `community_member_profile_connections.dart`, `community_connections_page.dart`, and the one follow-metadata generation field in `community_member_profile_page.dart`, all under `lib/features/community/presentation/`.

Mutations retain visit/owner/target validation. ID-based friend actions resolve exactly one matching requester/addressee relationship before acting. Failed or ambiguous readback does not invent successful relationship state. Optional creator refresh occurs after the verified result releases the action lock; visit, generation and overview identity checks reject stale results.

## Local behavior proof

- `test/features/community/community_profile_relationship_flow_test.dart`: **23/23 PASS** after the final metadata fix, and **23/23 PASS again after test-only lint cleanup** (`community-relationships-final-after-lint.jsonl`). Covers actual widget taps and repository calls, follow/unfollow counts, request cancellation, acceptance/rejection/removal, double taps, offline/retry, privacy flags, self exclusion, incorrect relationship IDs, account changes, profile entry, list readback, Arabic dark mode and 2x text.
- Two held-creator cases failed before the final fix because Unfollow remained disabled. Both passed afterwards; a third case verifies containment of a delayed optional-metadata error. No expectation was weakened to hide these failures.
- Existing Community parity/profile-owner suites passed **42/42 again after the final metadata fix**, with a successful terminal result. Together with the unchanged-hash 23-case relationship fixture, this gives **65 distinct local behavior cases** on the final relationship implementation across two commands. Evidence: `central-register/community-relationships-auth-parity-after-held-metadata.jsonl`.
- The integrated parity/profile-owner/Coach lifecycle command passed **106/106** before that last metadata fix, including four new pending-reply navigation cases. This older integrated result is not represented as final certification of all current files.

Private local evidence: `central-register/community-relationships-audit-20261026.md`, `community-held-metadata-red.log`, `community-held-metadata-green.log`, `community-held-metadata-after-hashes.json`.

Static analysis of six affected source/test files finished **No issues found!** after correcting three missing-brace style notices in test cleanup code. Current hashes and actual successful test terminals are recorded in `central-register/community-relationships-current-local-receipt-20261026.json`. Product source hashes remained unchanged after the live run; the only subsequent change among its ten hashed files was those test cleanup braces.

## Actual live cloud proof

Project: `tgmanzhqulksykhslrzb`. Run: `bil39-rel-4d9a0df4787c4c8a9f3e2dcbacfdaefc`, from `2026-10-26T00:53:27.359389+00:00` to `2026-10-26T00:53:56.379488+00:00`.

**34/34 checks passed through 116 actual HTTPS requests**, including Auth setup/cleanup. Three disposable accounts used actual password-authenticated sessions. Relationship, profile and consent requests used their own JWTs and the deployed application contracts. Admin credentials were used only for temporary Auth identity setup/cleanup; no credentials were printed or saved in the evidence.

The live checks established:

- Follow persisted; both profile projections reflected the correct follower/following count. Duplicate concurrent follows did not increase counts beyond one. The underlying follow table remained inaccessible directly.
- Unfollow removed the relation and counts even after the target disabled new follows. New follows while disabled were rejected without inventing a relation.
- Friend requests were visible as pending/incoming to their respective parties, with the same relationship identity and correct other-person identity. Repeated requests did not create duplicates.
- Cancellation, decline, acceptance and removal persisted and were read back from both participants. Acceptance did not create a follow. A completed acceptance could not be applied twice.
- The reverse request direction worked. Simultaneous reciprocal requests produced one pending row, not two.
- Anonymous/self-follow and forged follower identity were rejected. A third party could not read, accept or delete someone else's friendship. These write attacks deliberately omitted the client's extra ownership filters so that server authorization, rather than a nonmatching client predicate, was tested. Requesters could not accept their own requests. Friendship party identity could not be reassigned.
- Disabling friend requests prevented creation. Hidden counters returned unavailable values; a private profile could not be read by a nonfriend.

Every accepted behavior was checked by a subsequent authenticated read; HTTP success alone was not treated as proof of a write. No schema, RLS, grants, Edge Function, price, subscription, entitlement, main branch or protected build-38 change was deployed for these checks. Existing users and their relationships were not test targets.

## Cleanup and evidence integrity

All disposable sessions were globally revoked, users deleted, and their Auth absence read back. Independent read-only SQL then found zero residual rows for all seven fixture identities, including the two aborted fixture runs, across **146 foreign-key columns in 123 tables** referencing Auth users or public profiles. A separate core inventory also verified zero Auth users, sessions, profiles, friendships, follows, policy acceptances, rate buckets and push-outbox recipients.

Two earlier probe setup attempts remain recorded as failures: an incorrect consent conflict target in the probe (the server correctly requires the composite primary key), and an attempted direct follow-table read (correctly denied by deployed grants). The probe was corrected to match the application RPC/readback contract. No server protection was changed and those attempts are not counted as successful full runs.

Private evidence, under `G:\BIL_Project\release_preparation\bil39-intake-20261025\central-register\`:

- `community-relationships-live-20261026.json`: checks, request statuses/timing, cleanup and ten source/test hashes at the live run. SHA256 `554602fe5d8e26439cb1e200abc8f8dcbd33a4f2ae3c6b0106e09d4cb88ea98b`.
- `community-relationships-live-independent-residue-20261026.json`: exact read-only SQL and original returned results.
- `community_relationships_live_probe.py`: credential-free test program; secrets remain in process memory.
- `community-relationships-live-fixture-conflict-20261026.json` and `community-relationships-live-direct-read-guard-20261026.json`: retained aborted attempts, not relabeled PASS.

The live result proves the deployed relationship backend behavior through actual user sessions. Native build-39 visual/device checks and final integration CI remain separate release gates.
