# BIL Android 1.0.0 build 33 — frozen candidate for signed-artifact verification

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 33`

`STORE_SUBMISSION_APPROVED: NO`

`PRODUCTION_RELEASE_APPROVED: NO`

## Scope — revised 20 October 2026

This record freezes Android 33 for signed-artifact verification alongside iOS 37. It is not a store approval or permission to publish. The owner authorized the Android 33 AAB, the iOS 37 IPA, and TestFlight upload after the required local validation gates pass. No artifact is represented as built by this manifest.

The source branch is `integration/bil-qa-media-policy-20261011`. Both platform workflows require the same full audited source commit. The commit is bound through `BIL_ANDROID_V33_AUDITED_SOURCE_SHA` and `BIL_IOS_V37_AUDITED_SOURCE_SHA`; this file does not embed its own commit SHA. `BIL_ANDROID_V33_STAGING_MANIFEST_SHA256` binds this file's committed-byte SHA-256 separately.

The existing manifest path and release identities remain unchanged. The completion and acceptance markers describe the source record prepared for candidate verification; they do not assert that automated tests, signed artifacts, device journeys, or store review have passed.

## Current repair scope

The candidate includes the existing Community moderation and privacy boundaries, notification registration ownership checks, explicit AI consent, and the current advertising disclosure that separates BIL-recorded data from Google SDK processing. The 20 October repairs also cover registration data minimization, AI settlement-result validation and bounded diagnostics, preservation of failed store-audit evidence, and the notification guard regression.

The scope includes reviewed visual references for the changed Arabic AI-consent and advertising-disclosure screens. Android API 34/35 startup provisioning and bounded failure diagnostics address the observed external Pixel Launcher ANR obstruction; an actual successful startup is still required and is not inferred from these changes. The generated public policy pages must match the current website source before its separate deployment.

## Exact-source evidence boundary at preparation

The combined candidate's final formatting, full analysis, unsharded comprehensive tests, relevant policy/cloud checks, and native checks remain required. Historical runs on earlier source commits are not substitutes. Their results must be preserved separately against the exact frozen source and input hashes; this manifest records no successful result for the combined candidate.

No signed Android 33 AAB, actual Play transaction, final-device startup, or Health Connect journey is established by this update. The matching iOS 37 IPA and iPhone/iPad evidence remain separate requirements. The audited source variables and committed-manifest digest must be updated only after the applicable exact-source gates pass; the matching iOS source variable must remain identical.

## Validation boundary

The earlier full-suite and policy evidence cited by the 14 October manifest belongs to its recorded source only. It is not evidence for later local changes or this candidate. The final local full analysis and unsharded test result must be recorded against the exact frozen source before starting signed builds. Passing source tests will not establish store acceptance, reviewer-account access, production purchase behavior, Health Connect behavior on a device, or successful Play/App Store review.

The release candidate must still pass the signed AAB checks for merged permissions, SDK inventory, target SDK 36, 16 KB compatibility, signer identity, and install/runtime smoke. Google’s suspension and historical enforcement status remain separate Console decisions; no appeal or Play upload is authorized here.

Production state and migration/deployment evidence remain in [the production finalization report](../qa_next/BIL_20261016_PRODUCTION_FINALIZATION_AR.md). This manifest authorizes no additional production or account changes.

## iOS counterpart and store boundary

The matching iOS candidate is build 37, not build 36. Build 36 remains historical TestFlight evidence and is not replaced. The iOS workflow separately verifies its V37 manifest digest, signing, privacy/build configuration, and artifact before the owner-authorized TestFlight upload. App Review submission is not authorized.

Google’s prior suspension and Apple’s iOS 35 privacy objection remain unresolved officially until the stores update their case state. No claim of store acceptance, successful reviewer login, sandbox purchase, or device-health journey is made by this source-freeze record.
