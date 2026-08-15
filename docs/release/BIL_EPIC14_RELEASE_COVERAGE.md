# BIL v1 — Epic 14 release coverage

This file records the release boundary implemented in source. It does not claim
store upload, Apple signing, TestFlight, Play closed testing, or physical-device
verification without their external evidence.

## Frozen identity and version

- Android application/namespace: `com.kadem.bil`.
- Apple bundle identifier: `com.kadem.bil`.
- Store name: `BIL - Body Intelligence Log` on Android and `BIL` on Apple.
- Release version: `1.0.0+1`. Future uploads increment the build number; semantic
  marketing versions change only for an intended product release.
- Android: min API 26, compile/target API 36, Java 17, AGP 9.2.1, Gradle 9.4.1.
- Apple: iOS 15 minimum. The final Xcode/SDK version is proven only by the macOS
  workflow artifact.

## Android production boundary

- The production bundle targets `arm64-v8a` and `x86_64`; every packaged native
  library is checked by the Epic 14 gate for 16 KB ELF LOAD alignment. The
  optional legacy `armeabi-v7a` ABI is excluded because the scanner dependency's
  32-bit binary remains 4 KB aligned. BIL therefore does not advertise support
  for 32-bit-only Android devices; scanning remains available on supported
  64-bit devices. The release gate enforces this at Flutter's bundle command
  with `--target-platform android-arm64,android-x64`, because Flutter's bundle
  task controls the final ABI set in the AAB.
- Release builds never fall back to the debug signing key.
- `artifacts/release/epic14/prepare_android_upload_key.ps1` creates a real private
  upload identity locally, outside Git, and writes a separate ignored recovery
  record. The owner must make an offline backup before Play enrollment.
- R8 optimization and resource shrinking are enabled with narrow platform-channel
  keep rules.
- Cleartext traffic and Android backup are disabled.
- Runtime permissions are limited to notifications, selected camera/microphone
  actions, BLE, and the Health Connect records actually supported by BIL.
- Legacy BLE location permissions end at API 30; modern BLE scan declares
  `neverForLocation`.
- Health Connect, billing, notifications, app links, voice, camera, barcode and
  BLE remain permission/feature gated by their existing truthful UI boundaries.
- The final gate produces a signed release AAB, verifies its JAR signature,
  records SHA-256 and size, and audits packaged native ELF alignment for 16 KB
  page compatibility when native libraries are present.
- Eleven superseded V8/V9/V10 image declarations with no production or test
  references were removed from the Flutter asset bundle; source originals remain
  untouched for provenance and do not inflate the AAB.

## Apple production boundary

- HealthKit and production APNs hooks are declared. Push remains hidden unless
  its audited server configuration and user opt-in are present.
- Debug signing uses a separate HealthKit-only entitlement file; the production
  APNs entitlement is confined to Profile/Release distribution builds.
- Camera, photo selection, microphone, speech, BLE, HealthKit and notification
  background usage have purpose-specific descriptions or entitlements.
- The app privacy manifest explicitly declares no tracking. App-level required
  reason entries remain empty because BIL production code does not directly call
  a covered required-reason API; dependency manifests are merged at build time.
- Universal Links/Associated Domains are not declared until the verified owner
  domain is supplied and its `apple-app-site-association` file is live.
- The unsigned macOS workflow proves compilation without claiming distribution.
  The signed workflow fails closed until the Apple membership, team, certificate
  and provisioning profile secrets are supplied.

## External gates and owner input

| Status | Required evidence |
|---|---|
| `OWNER_INPUT_REQUIRED` | Verified official domain and live support/privacy/terms/account-deletion URLs. |
| `OWNER_INPUT_REQUIRED` | Google Play product IDs and closed-track purchase/restore evidence. |
| `OWNER_INPUT_REQUIRED` | Android upload-key offline backup confirmation and Play App Signing enrollment. |
| `OWNER_INPUT_REQUIRED` | Apple Developer membership acceptance, Team ID, distribution certificate and provisioning profile. |
| `OWNER_INPUT_REQUIRED` | App Store Connect product IDs, subscription group and sandbox purchase/restore evidence. |
| `OWNER_INPUT_REQUIRED` | APNs/FCM production credentials and live deep-link association files. |
| `EXTERNAL_REQUIRED_NOT_CLAIMED` | Physical Android/iPhone, Health Connect/HealthKit and BIL BLE hardware validation. |

No placeholder URL, product ID, credential, certificate, keystore, or successful
external verification is embedded in the application or claimed here.
