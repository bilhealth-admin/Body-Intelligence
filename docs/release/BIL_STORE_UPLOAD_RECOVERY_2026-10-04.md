# BIL store upload recovery — 2026-10-04

Application source remains `3f0085e6e6686f2e87e9cf14789e9e578ea64159`, version `1.0.0`, Android `32`, iOS `35`. These are production-configured candidates for store/native testing, not authorization for public rollout or a new review submission.

## Confirmed failures and narrowly scoped repairs

- Android run `37229040573`, job `111514615723`: signed AAB and native/SDK/16 KB/artifact gates succeeded. Only Google upload pre-validation failed with HTTP 400 requesting `changesNotSentForReview=true`. The validate API has no such parameter. Commit performs validation and supports the parameter. Only the exact observed error may proceed to the existing protected commit (`changesNotSentForReview=true`, `changesInReviewBehavior=ERROR_IF_IN_REVIEW`). Every other validation failure still aborts. No blind retries.
- Reuse only artifact `11313338798` from that run. Its archive digest is `a7cd8ec1ee310e027886359179db3134dc0b0abb4b8c6e25e4849a3eecf97603`. The sealed AAB is `183645353` bytes, SHA-256 `9819aabf66c0ed86d1fc3a88e583158b707b50282113fb2f2e38cfaa4f8aa11a`. Recovery checks original controller/source, artifact hash, build number, certificate, configuration and native gate receipts, and never recompiles it.
- iOS run `37229457859`, job `111515871889`: the actual simulator AES-GCM integration test succeeded. Step 19 then failed because an exact-line grep rejected the existing TAB indentation of `GADApplicationIdentifier` in the tested source. A semantic plist assertion now requires exactly one key and the unchanged exact build-setting binding; signed-IPA validation and native gates remain required. No IPA was created or uploaded in this failed run.

## Current verification

- Changed Google upload contract tests: 29 PASS (mocked API boundary tests, not native billing evidence).
- Changed iOS/controller tests: 34 PASS (including immutable source, indentation, missing/duplicate/wrong binding fixtures).
- Both changed workflows parse as YAML; all eight embedded Python programs compile.
- Application/native/dependency/Edge source remains byte-identical to the tested source. No previous successful application QA was rerun or claimed as new native-commerce evidence.

## Owner-requested store changes

- Apple submission `411564b4-9a26-45f6-9152-8ec10e7e87ee` was cancelled in App Store Connect. Fresh UI confirms `Removed`; version `1.0.0` is `Developer Rejected`. Previously attached build remains `32`. No new submission. Apple reviewer account was not changed.
- Google rejected production release `29` was discarded. Fresh Publishing overview has no production-release change; only updated sign-in instructions remain pending. Uploaded bundles remain recoverable in the artifact library. Historical rejection banners are not deleted policy history.
- Store privacy reconciliation is NOT certified complete: Google approximate-location collection optionality and Apple advertising/tracking answers still require evidence. Previous saved purpose/category corrections do not prove these unresolved answers. Native purchase/restore and reviewer-route acceptance remain open.

Public release readiness remains unproven. A successful signed upload must be reported separately from store processing, tester installation, native billing, review approval and public release.

Primary API contracts: [Google validate](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/validate), [Google commit](https://developers.google.com/android-publisher/api-ref/rest/v3/edits/commit), [Google edit lifecycle](https://developers.google.com/android-publisher/edits).
