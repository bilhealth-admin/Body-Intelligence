# BIL Android 1.0.0 build 12 — release source manifest

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 12`

## Release identity and scope

This source-only candidate preserves the complete code audit in
`3e1ab6b12dbab099a1424bf0e47ffb5b7229bd40`, including administrative Premium
grants, purchase isolation, Health synchronization, user-initiated food search,
and non-accumulating token-reset source. The preparation commit only updates
release configuration, its tests, and the explicit code-only CI selection.
The dormant manual QA workflow also resolves runner-local paths inside steps
instead of using an unavailable job-level expression context; it is not run.
The shared Flutter version remains `1.0.0+8`; the signed workflow passes
`--build-number 12`, producing Android `versionCode 12`.

The binding is not self-referential: after the preparation commit is pushed,
`BIL_ANDROID_V12_AUDITED_SOURCE_SHA` must equal that exact commit and
`BIL_ANDROID_V12_STAGING_MANIFEST_SHA256` must equal this file's committed-byte
SHA-256. Source, manifest, and expected build number are independently checked.
Older V11 bindings and release artifacts remain unchanged.

## Verification boundaries

The code audit is recorded in `../qa/FINAL_PREBUILD_CODE_AUDIT_2026-09-10.md`.
Signed CI runs analyzer, code-only portable tests, configuration checks,
signing validation, final manifest checks, and 16 KB/ELF packaging checks.
Visual/image tests and emulator checks are NOT RUN in this owner-requested
phase; excluded tests are not passes. AdMob remains deferred.

This manifest does not claim an AAB exists, a Play upload occurred, or a device
test passed. This build does not deploy pending Supabase/Worker changes: the
reset top-up migration and other unpublished server fixes need their separate
deployment verification. No paid receipts or account balances are rewritten.
