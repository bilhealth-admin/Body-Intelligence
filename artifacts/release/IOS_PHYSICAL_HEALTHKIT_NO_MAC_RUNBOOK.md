# BIL physical HealthKit validation without a Mac

The production Apple bundle identifier is
`com.bilhealth.bodyintelligencelog`. The obsolete `com.kadem.bil`
identifier must never be used for signing, provisioning, upload, or runtime
evidence.

## Why a physical iPhone is required

The cloud iOS Simulator build and `/connected-health` route are verified, but
the simulator reports `HKHealthStore.isHealthDataAvailable() == false` and
therefore cannot display the real Apple Health authorization sheet. References
4988–4991 require a signed build on an iPhone where HealthKit is available.

## Owner prerequisites

1. Active Apple Developer Program membership.
2. An App Store Connect app record for `com.bilhealth.bodyintelligencelog`.
3. The App ID has HealthKit enabled.
4. An App Store distribution certificate and an App Store provisioning profile
   that authorizes the same bundle ID and HealthKit entitlement.
5. A Team App Store Connect API key with permission to validate/upload builds.

Never paste private keys, certificate passwords, or provisioning profiles into
chat, source control, logs, issues, or build arguments.

## GitHub Actions secrets

Add these under repository **Settings → Secrets and variables → Actions**:

- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64`: base64 of the `.p12` file.
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`: password of that `.p12`.
- `APPLE_PROVISIONING_PROFILE_BASE64`: base64 of the `.mobileprovision` file.
- `APPLE_TEAM_ID`: the Apple Developer Team ID.
- `APP_STORE_CONNECT_KEY_ID`: Team API key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: Team API issuer ID.
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`: base64 of `AuthKey_*.p8`.

## Cloud build and TestFlight

Run **BIL iOS signed release candidate** from GitHub Actions. Set
`upload_to_testflight=true` only when an upload is intended. The workflow fails
closed unless the profile and signed app both prove:

- production bundle identifier;
- HealthKit entitlement;
- valid App Store Connect candidate;
- a nonempty signed IPA.

Install the processed build from TestFlight on the owner's iPhone. A Mac is not
required.

## Physical evidence for references 4988–4991

1. Cold-open BIL and navigate to **Connected Health**.
2. Tap the Health access action once.
3. Capture the top, two distinct middle scroll positions, and bottom of the
   native Apple Health authorization sheet.
4. At the bottom, record one explicit permission outcome (deny is acceptable
   for privacy-safe QA).
5. Capture BIL after dismissal and verify the sheet is gone, the route is still
   Connected Health, and the state does not claim access was granted without
   records.
6. Do not include real health measurements, Apple ID, email, device serial,
   notification contents, or other personal data in the evidence.

Independent QA must review the four native images and the post-dismissal state
before references 4988–4991 can be approved. Simulator evidence alone is not a
substitute.
