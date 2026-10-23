# BIL iOS38 — owner-authorized internal TestFlight construction only

`SOURCE_ACCEPTANCE_SCOPE: INTERNAL_TESTFLIGHT_CONSTRUCTION_ONLY`

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 38`

`STORE_SUBMISSION_APPROVED: NO`

`PRODUCTION_RELEASE_APPROVED: NO`

These markers attest the frozen, reviewed build configuration for the owner's explicitly approved internal experiment. Zero unresolved reviews here concerns this limited configuration, not the full release certification. The ordinary candidate record remains unaccepted and its default all-CI signing path is unchanged.

On 23 October2026 the owner explicitly approved using previous byte-identical app evidence for internal iOS38 signing/TestFlight without repeating the full exact-SHA lanes. The guard independently requires application/native-test parity with1b23d4d4bb73d467f9c3cf1425b2eb2d8cc78c2d and both real successful full-analysis/root and supplemental jobs in run39992878548. Runtime differences reject reuse. Reviewed native/build helpers must remain byte-identical to6a0ef55bdb11885937093332b0c455cc42f5d6c4.

CI runs40012542464 and40012589309 failed in QA tooling and remain disclosed, unaccepted results. The full release unresolved count is not reset by this internal record. Their repairs have not been incorporated into this source. Current native cryptography, production configuration, entitlements, profile, codesign, final artifact/icon checks and Apple validation remain required. Build38 is a production-configured signed binary for internal testing, not an approved public release.

Update on 24 October 2026: the owner explicitly instructed immediate fast signing and TestFlight upload without repeating simulator cryptography or application tests. This supersedes the fresh simulator requirement above for this opt-in internal route only. Runtime and native assertion bytes remain identical; the skipped test is recorded as NOT_RERUN_OWNER_APPROVED_INTERNAL_PRIOR_EVIDENCE, never PASS. Actual profile, codesign, artifact identity, production configuration and Apple validation remain required. The owner intends this binary as the store candidate after device testing; public release certification and App Review submission are not implied by signing or prior evidence reuse.

Upload exactly the verified original IPA once; verify Apple processing and existing internal-group availability. Physical-device startup/sync/purchase behavior remains unverified until tested. No public App Review submission, release, Android upload, protected-branch movement, entitlement changes, data reset or key rotation is authorized by this record.
