# BIL 33 / 30 release handoff — 2026-10-02

## Authority and scope

This document is the release handoff for **iOS build 33** and **Android build 30**.
It supersedes older staging checklists for current-release decisions but does not
rewrite historical evidence.

- Production bundle/application ID: `com.bilhealth.bodyintelligencelog`
- Last fully automated certified source: `5c8efb4c246c8473eda18177a60e8beece7d6cb7`
  - Sapphire #179: SUCCESS
  - Final Release Certification #65: SUCCESS
  - RC mobile #31: SUCCESS on retry (Android and iOS jobs both SUCCESS)
- Current code/test parent candidate:
  `f8861019d99fb8444148d8f009765b61f7d03a15`
- The post-certification delta keeps the previously certified application
  behavior and adds only the reviewed iOS HealthKit permission hardening,
  Windows-only barcode-package discovery isolation, accessibility evidence
  hardening, their regression tests, canonical formatter closure, and the
  final analyzer lint closure. Full `flutter analyze --no-pub` passed before
  that lint-only commit was created.
- This documentation-only commit intentionally triggers one unified final
  revalidation so Sapphire, Final Release Certification, Android RC and iOS RC
  all bind to one exact candidate SHA before release freeze.

Do not bind 33/30 to a final audited SHA until that unified revalidation is
green. No signed build or store upload is authorized by this handoff.

## Baseline lineage

The uploaded/known-good baseline was:

- iOS build 32 + Android build 29:
  `9f439cae97d72b784880a1b1ac4ef1d33ede30c1`

The current release lineage remains ahead of that baseline with no rollback.

## Release binding rule

Do not run the signed iOS 33 or Android 30 workflows while they still pin the
historical accepted source `45079805c98c4885558afadd8d6263f774e3a4e4`.

Before any signed build:

1. targeted iOS delta verification must be green;
2. choose one final source SHA;
3. set both repository variables to the exact same SHA:
   - `BIL_IOS_V33_AUDITED_SOURCE_SHA`
   - `BIL_ANDROID_V30_AUDITED_SOURCE_SHA`
4. regenerate/freeze both 33/30 manifests from that same source;
5. set both manifest SHA-256 repository variables;
6. update the workflow hard-coded `EXPECTED` values to that same source;
7. run artifact-only signed builds first;
8. only upload to TestFlight/Google Play after explicit owner approval.

Invariant:

```
iOS 33 source SHA == Android 30 source SHA == final certified source SHA
```

## iOS runtime-log review from RC #31

The successful iOS retry on `5c8efb4c...` was read in full. Actionable items:

- `simple_barcode_scanner` Swift Package Manager warning:
  actionable and already fixed in source after the successful run.
- HealthKit automatic startup permission behavior:
  policy/design gap and already fixed in source after the successful run.
- transient accessibility JSON decode traceback:
  QA-evidence weakness and already hardened after the successful run.

Non-actionable runner/test-build notes:

- `Building for device with codesigning disabled` is expected for the unsigned
  RC device-shaped build.
- Homebrew/pip PATH advisory is runner-local and does not affect the app.
- simulator “default LCD display” notes are informational.
- genuine App Attest, HealthKit and StoreKit sandbox remain physical-device /
  store-sandbox gates by design.

## Apple release contract

Code/source gates currently expected:

- App Privacy file: `ios/Runner/PrivacyInfo.xcprivacy`
- HealthKit entitlement
- Sign in with Apple entitlement
- production APNs entitlement
- associated domain `applinks:www.bilhealth.com`
- App Attest production entitlement
- camera, selected-photo, microphone, speech, Bluetooth, Health read and
  weight-write usage descriptions
- no ATT claim unless a future release actually tracks users
- Restore Purchases is explicit/user initiated
- account deletion is available in-app
- Sign in with Apple deletion path must revoke the associated grant where a
  revocable token is available
- HealthKit permission is user initiated from Apps & Devices, not passive
  dashboard startup

Required signed-archive evidence:

- valid distribution certificate and provisioning profile
- final codesign verification
- embedded profile matches bundle ID and Team ID
- signed entitlements exactly match required capabilities
- final `PrivacyInfo.xcprivacy` present and valid
- Xcode aggregate privacy report reviewed, including embedded third-party SDKs
- forbidden bundled crypto scan = 0
- App Store Connect validation passes before any upload

Official Apple references used for this handoff:

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/design/human-interface-guidelines/healthkit/
- https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://developer.apple.com/support/third-party-SDK-requirements/
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/app-store/subscriptions/
- https://developer.apple.com/documentation/storekit/restoring-purchased-products

## Google Play / Android release contract

Current code facts:

- `compileSdk = 36`
- `targetSdk = 36`
- `minSdk = 26`
- Health Connect release scope in the manifest is limited to:
  - `READ_STEPS`
  - `READ_DISTANCE`
  - `READ_ACTIVE_CALORIES_BURNED`
- camera, microphone and BLE are optional hardware journeys
- broad media/storage permissions are removed from the final manifest merge
- AD_ID / Privacy Sandbox advertising permissions are explicitly removed from
  the app manifest merge
- account deletion is available in-app and the public site exposes
  `https://www.bilhealth.com/account-deletion`
- privacy policy is available at
  `https://www.bilhealth.com/privacy`
- UGC has report/block/human moderation paths
- AI Coach has an unsafe/offensive answer report path

Required signed-AAB evidence:

- upload certificate fingerprint matches the owner-approved fingerprint
- final merged manifest / target SDK = 36
- 16 KB packaging and ELF alignment gate passes
- no forbidden bundled crypto markers
- final permissions inventory matches Console declarations
- Health Connect declaration exactly matches the final AAB
- Data Safety reflects the final AAB and every included SDK
- Play Integrity and Billing genuine behavior require Play-installed/device
  evidence

Official Google/Android references used for this handoff:

- https://support.google.com/googleplay/android-developer/answer/11926878
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://support.google.com/googleplay/android-developer/answer/13327111
- https://support.google.com/googleplay/android-developer/answer/16679511
- https://support.google.com/googleplay/android-developer/answer/18258653
- https://developer.android.com/guide/practices/page-sizes
- https://developer.android.com/health-and-fitness/health-connect/publish

## External / Console gates

These are not allowed to be silently promoted to PASS from source code alone:

- App Store Connect App Privacy answers
- App Store age/content rating and review metadata
- App Store subscription metadata/availability/pricing state
- Google Play Data Safety answers
- Google Play Health Apps / Health Connect declarations
- Google Play target audience/content rating/contains-ads declaration
- Google Play subscription/base-plan/offer state
- genuine StoreKit / Play Billing purchase lifecycle
- genuine App Attest / Play Integrity
- genuine HealthKit / Health Connect grants and reads
- genuine push delivery
- native Google/Facebook/Apple login on signed device builds

The current read-only store audit cannot certify Google Play until
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` is configured for the audit job.

## Public legal routes

Production source contains:

- `/privacy`
- `/terms`
- `/subscription-terms`
- `/account-deletion`
- `/data-deletion`
- `/health-disclaimer`
- `/community-guidelines`
- `/support`
- `/contact`

Public privacy and support contacts:

- `privacy@bilhealth.com`
- `support@bilhealth.com`

## Release decision states

- **GREEN / retained:** prior full automated certification on `5c8efb4c...`
- **TARGETED REVALIDATION REQUIRED:** two narrow iOS/QA commits through
  `c77721e...`
- **CONSOLE EVIDENCE REQUIRED:** App Privacy, Data Safety and store metadata
- **PHYSICAL DEVICE / STORE SANDBOX REQUIRED:** integrity, health and billing
- **SIGNED BUILD NOT AUTHORIZED BY THIS DOCUMENT:** this is preparation only
