# BIL Apple Release Boundary

## Accepted parent

- Branch: `phase-3-product-excellence`
- Parent HEAD: `71426e6fd60f3e517c3866c8acd22c1470c8d53d`
- Package: `BIL-V1-LAUNCH-003`

## Repository-controlled boundary

- The owner-approved release candidate bundle identifier is `com.bilhealth.bodyintelligencelog`.
- The deployment target is iOS 15.0.
- HealthKit capability is declared without embedding a team, certificate,
  provisioning profile, or credential.
- Native HealthKit, Bluetooth, camera, photo-library, microphone, and speech
  consent text is tracked for all 25 supported locales.
- The app-owned privacy manifest is embedded in Runner resources, declares no
  tracking, and contains no tracking domains.
- The production bridge limits HealthKit writes to body weight. Activity,
  sleep, vital, hydration, and nutrition types are read-only.
- Apple preparation documentation reflects the current production project and
  no longer reports the obsolete example identifier or absence of HealthKit.

## External gates

The Apple Developer team, identifier ownership, HealthKit capability approval,
signing assets, macOS/Xcode compilation, physical-device permission behavior,
archive validation, Xcode Privacy Report, App Store Connect declarations,
TestFlight processing, Apple review, and rollout remain external. None is
created, executed, or claimed by this repository package.
