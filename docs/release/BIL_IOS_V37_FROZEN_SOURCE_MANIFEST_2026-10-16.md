# BIL iOS 1.0.0 build 37 — frozen candidate for signed-artifact verification

`STAGING_MANIFEST_COMPLETE: YES`

`CANDIDATE_FROZEN_OR_ACCEPTED: YES`

`UNRESOLVED_REVIEW_COUNT: 0`

`RELEASE_VERSION: 1.0.0`

`RELEASE_BUILD_NUMBER: 37`

`STORE_SUBMISSION_APPROVED: NO`

`PRODUCTION_RELEASE_APPROVED: NO`

## Scope — revised 20 October 2026

This record freezes iOS 37 for signed-artifact verification alongside Android 33. It is not a store approval or permission to publish. The owner authorized the Android 33 AAB, the iOS 37 IPA, and TestFlight upload after the required local validation gates pass. No artifact is represented as built by this manifest.

The source branch is `integration/bil-qa-media-policy-20261011`. Both platform workflows require the same full audited source commit. The commit is bound through `BIL_IOS_V37_AUDITED_SOURCE_SHA` and `BIL_ANDROID_V33_AUDITED_SOURCE_SHA`; this file does not embed its own commit SHA. The committed bytes are bound separately through `BIL_IOS_V37_STAGING_MANIFEST_SHA256`.

The existing manifest path and release identities remain unchanged. The completion and acceptance markers describe the source record prepared for candidate verification; they do not assert that automated tests, signed artifacts, device journeys, or store review have passed.

## Current repair scope

The candidate includes the existing Community moderation and privacy boundaries, notification registration ownership checks, explicit AI consent, and the current advertising disclosure that separates BIL-recorded data from Google SDK processing. The 20 October repairs also cover registration data minimization, AI settlement-result validation and bounded diagnostics, preservation of failed store-audit evidence, and the notification guard regression.

The scope includes reviewed visual references for the changed Arabic AI-consent and advertising-disclosure screens, and isolated Android startup provisioning and bounded failure diagnostics for the shared source. These source changes and references are verification inputs, not successful runtime evidence. The generated public policy pages must match the current website source before its separate deployment.

## Exact-source evidence boundary at preparation

The combined candidate's final formatting, full analysis, unsharded comprehensive tests, relevant policy/cloud checks, and native checks remain required. Historical runs on earlier source commits are not substitutes. Their results must be preserved separately against the exact frozen source and input hashes; this manifest records no successful result for the combined candidate.

No iOS 37 IPA, TestFlight processing result, iPhone/iPad journey, actual store transaction, or device-health integration is established by this update. A successful simulator or source test must retain its stated scope. The audited source variables and committed-manifest digest must be updated only after the applicable exact-source gates pass; the matching Android source variable must remain identical.

## Validation boundary

The earlier full-suite and policy evidence cited by the 14 October iOS 36 manifest belongs to its recorded source only. It is not evidence for later local changes or this candidate. The final local full analysis and unsharded test result must be recorded against the exact frozen source before starting signed builds. Passing source tests will not establish store acceptance, reviewer-account access, production purchase behavior, or a successful device journey.

The signed IPA must still pass certificate/profile, bundle/build identity, privacy-manifest, entitlement, SDK, and export checks. TestFlight upload is authorized only after those checks and the final local gates pass. App Review submission is not authorized.

## Store and backend boundary

Apple’s iOS 35 privacy objection remains unresolved officially until App Store Connect updates the case. Google’s suspension and historical enforcement status remain separate Console decisions. Neither a source freeze nor a successful build closes a store case. Do not claim that privacy declarations, reviewer access, subscriptions, or health/device integrations were validated on this IPA until the exact artifact is exercised.

Production state and migration/deployment evidence remain in [the production finalization report](../qa_next/BIL_20261016_PRODUCTION_FINALIZATION_AR.md). This manifest authorizes no additional production, account, price, subscription, or trial changes.
