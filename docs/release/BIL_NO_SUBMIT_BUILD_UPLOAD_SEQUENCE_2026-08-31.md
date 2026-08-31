# BIL locked-build and no-submit upload sequence — 2026-08-31

This is an execution handoff, not evidence that a final build or upload already
occurred. Do not run any command below until QA closes, the worktree is clean,
and one immutable release tag points to the accepted source commit.

Current store identity:

- version name: `1.0.0`;
- next common build number: `5` (or a higher unused integer if another build is
  uploaded first);
- Android package and Apple bundle ID:
  `com.bilhealth.bodyintelligencelog`;
- App Store Connect app ID: `6805349703`;
- App Store version ID: `7a132506-d5a8-4810-a51f-b2dc2bd636cf`.

## Pre-build executable gates

1. Finish QA and record one clean full-suite result against the exact commit.
2. Create an immutable release tag/branch at that commit. Both workflows must
   check out that same ref and use the same numeric build number.
3. Verify the required GitHub Actions secrets by name. Secret existence cannot
   be proved from this workstation because GitHub CLI is not installed.
4. Complete Apple DSA trader verification for the 27 EU territories, or make an
   explicit non-EU launch decision. This is an owner/UI requirement.
5. Upload the approved Apple product-page screenshots. App Store Connect
   currently has zero screenshot sets; Google Play currently has eight phone
   screenshots, one icon and one feature graphic.
6. Confirm the production billing verifier secret and Google RTDN/Pub/Sub test
   evidence described in `BIL_GOOGLE_BILLING_LIVE_CONFIGURATION.md`. Existing
   Android Publisher access does not prove the runtime Supabase secret or RTDN
   delivery is configured.
7. Do not start a public review, production rollout, or App Store version
   submission as part of build creation.

## Required workflow inputs and secrets

### Android

Workflow: `.github/workflows/bil_android_release_candidate.yml`

Input:

- `build_number`: integer `5` or higher and greater than every Play upload.

Secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_UPLOAD_CERTIFICATE_SHA256`

The workflow produces a private signed AAB artifact and signing/hash evidence.
It has no Google Play upload, track update, review, or rollout step.

### iOS

Workflow: `.github/workflows/bil_ios_signed_release.yml`

Inputs:

- `build_number`: the same integer used for Android;
- `upload_to_testflight`: `false` for build/validation only, or `true` after
  source freeze to upload that run's validated IPA to TestFlight. TestFlight
  upload does not submit App Store version 1.0.0 for review.

Secrets:

- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64`
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE_BASE64`
- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`

The workflow validates the profile, signed entitlements, app identifier,
production push, Sign in with Apple, HealthKit, `get-task-allow=false`, IPA
hash, and App Store validation. Its TestFlight upload is explicitly gated by
the boolean input.

## Exact workflow dispatch shape

GitHub CLI is not installed on this workstation, so use the Actions UI or run
the following from a trusted environment after installing/authenticating `gh`:

```bash
gh workflow run bil_android_release_candidate.yml \
  --repo bilhealth-admin/Body-Intelligence \
  --ref <immutable-release-tag> \
  -f build_number=<N>

gh workflow run bil_ios_signed_release.yml \
  --repo bilhealth-admin/Body-Intelligence \
  --ref <same-immutable-release-tag> \
  -f build_number=<N> \
  -f upload_to_testflight=true
```

Before accepting either run, download its private artifact and verify:

- `BIL-source-head.txt` equals the frozen commit;
- `BIL-build-number.txt` equals `<N>`;
- the AAB/IPA SHA-256 equals the downloaded binary;
- the signing/certificate/entitlement gates say PASS;
- the forbidden bundled-crypto scan reports zero markers;
- `PHYSICAL_DEVICE_GATE=REQUIRED` remains open until testing is actually done.

## Google Play: upload the AAB without a release or review submission

Use the exact signed AAB only after the checks above. The safe staging sequence
does **not** update any track:

1. `POST /androidpublisher/v3/applications/{packageName}/edits` to create one
   transient edit.
2. Upload the AAB bytes with content type `application/octet-stream` to:
   `POST /upload/androidpublisher/v3/applications/{packageName}/edits/{editId}/bundles?uploadType=media`.
3. Require returned `versionCode == <N>` and returned SHA-256 to equal the
   workflow AAB hash. Abort and delete the edit on any mismatch.
4. Do **not** call `edits.tracks.update` or `edits.tracks.patch` in this staging
   operation. A Play release with status `draft` is still a separate catalog
   decision; it is not needed merely to preserve the uploaded AAB.
5. Validate the edit:
   `POST /androidpublisher/v3/applications/{packageName}/edits/{editId}:validate`.
6. Commit only with both safety parameters:
   `POST /androidpublisher/v3/applications/{packageName}/edits/{editId}:commit?changesNotSentForReview=true&changesInReviewBehavior=ERROR_IF_IN_REVIEW`.
   Never use the API default, because it may cancel an existing review and
   submit changes.
7. Open a fresh GET-only edit and confirm bundle `<N>` exists while `alpha`
   still serves only the previously approved release and `production` remains
   empty.

This sequence uploads the binary but neither serves it to testers nor sends it
for review. A later, separately approved closed-test rollout must update the
intended test track and must preserve any version codes that need to remain in
the release.

## Apple: TestFlight upload and no-submit build attachment

With `upload_to_testflight=true`, the signed workflow runs:

```bash
xcrun altool --validate-app -f <exact-ipa> -t ios \
  --apiKey <key-id> --apiIssuer <issuer-id>
xcrun altool --upload-app -f <exact-ipa> -t ios \
  --apiKey <key-id> --apiIssuer <issuer-id>
```

After Apple finishes processing, identify exactly one eligible build:

```text
GET /v1/builds
  ?filter[app]=6805349703
  &filter[version]=<N>
  &filter[processingState]=VALID
  &filter[preReleaseVersion.version]=1.0.0
  &filter[preReleaseVersion.platform]=IOS
  &filter[buildAudienceType]=APP_STORE_ELIGIBLE
  &limit=10
```

Refuse attachment unless the query returns exactly one build, its version is
`<N>`, processing state is `VALID`, it is not expired, and the current version
relationship is empty:

```text
GET /v1/appStoreVersions/7a132506-d5a8-4810-a51f-b2dc2bd636cf/build
```

Attach only that build:

```http
PATCH /v1/appStoreVersions/7a132506-d5a8-4810-a51f-b2dc2bd636cf/relationships/build
Content-Type: application/json

{
  "data": {
    "type": "builds",
    "id": "<validated-build-resource-id>"
  }
}
```

Require HTTP `204`, then repeat the relationship GET and confirm the same build
ID. This relationship PATCH does not submit the version for review. Do not
create an `appStoreVersionSubmission`, a `reviewSubmission`, or invoke any
submit endpoint until screenshots, DSA, final privacy/export reconciliation,
physical-device evidence, StoreKit tests, and the owner's final release
approval are all complete.

## Remaining post-build gates

- representative real Android and iPhone smoke tests against the exact hashes;
- Health Connect/Wear OS, HealthKit/Apple Watch, and supported fitness-only BLE
  tests on physical hardware;
- licensed Play Billing and StoreKit Sandbox/TestFlight purchase, renewal,
  cancellation, refund and restore evidence;
- Google closed-test eligibility time and feedback requirements;
- final owner approval before any public review or production rollout.
