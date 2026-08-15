# iOS readiness and release checklist

The tracked iOS project is prepared for controlled verification on macOS and
Xcode. Windows verification can lock repository contracts, but it cannot prove
an iOS compile, device launch, archive, validation, TestFlight upload, or App
Store acceptance.

## Accepted repository state

- Bundle identifier: `com.bilhealth.bodyintelligencelog`
- Minimum iOS deployment target: 15.0
- Version and build number are sourced from Flutter build metadata.
- HealthKit and Bluetooth bridges are registered in the production runner.
- HealthKit capability is declared in `Runner.entitlements`.
- Health, Bluetooth, camera, photo-library, microphone, and speech-recognition
  usage descriptions are tracked for all 25 supported locales.
- `PrivacyInfo.xcprivacy` is included in Runner resources, tracking is disabled,
  and no tracking domains are declared.
- HealthKit read access covers the supported health timeline.
- HealthKit write access is limited to explicitly reviewed weight records.
  The broader activity, sleep, vital, hydration, and nutrition scope is read-only.

The app-owned privacy manifest describes the current app-owned runtime only.
Every embedded SDK manifest and the final Xcode Privacy Report must still be
reviewed on the release Mac. App Store privacy answers are a separate external
declaration and must match the final production behavior.

## Required Mac verification

Install the release Xcode and Flutter toolchain, accept Xcode licenses, open a
terminal at the repository root, and run:

```sh
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build ios --release --no-codesign
```

Then open `ios/Runner.xcworkspace` in Xcode and verify:

1. Register `com.bilhealth.bodyintelligencelog` with the Apple Developer team.
2. HealthKit capability and provisioning are active for that identifier.
3. Consent descriptions render correctly in representative LTR and RTL
   locales on a device, with a release check covering all 25 tracked locales.
4. HealthKit read permission is requested only when its feature is used.
5. HealthKit writes remain limited to explicitly selected weight records after
   separate write consent.
6. Bluetooth discovery occurs only after an explicit user action.
7. A fresh install and an upgrade preserve local data correctly.

## Signing, archive, and TestFlight

1. Select the authorized Apple Developer team in Runner signing settings.
2. Keep certificates, provisioning profiles, App Store Connect keys, and Apple
   credentials outside Git.
3. Set the approved release version and monotonically increasing build number.
4. Archive for Any iOS Device, run Validate App, and inspect the generated
   privacy report before upload.
5. Complete App Privacy, export-compliance, review, and health-data declarations
   from verified production behavior.
6. Upload to an internal TestFlight group and complete physical-device
   regression before any external rollout.

These steps remain external release gates. Repository readiness does not claim
Apple signing, archive validation, TestFlight acceptance, or App Store approval.
