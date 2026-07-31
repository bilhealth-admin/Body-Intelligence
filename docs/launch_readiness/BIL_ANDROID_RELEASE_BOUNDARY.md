# BIL Android Release Boundary

## Accepted parent

- Branch: `phase-3-product-excellence`
- Parent HEAD: `b29700e5ee5640503c714800124698f9cbe7b5b4`
- Package: `BIL-V1-LAUNCH-002`

## Production identity

- Namespace: `com.kadem.bil`
- Application ID: `com.kadem.bil`
- Minimum Android API: 26
- Target and compile API: 36
- Java and Kotlin target: 17
- Version name and code remain sourced from Flutter's version metadata.

Changing the application ID after store onboarding creates a different app and
therefore requires an explicit Product Owner decision. This package freezes the
current identity as the release candidate identity; it does not register it in
Google Play.

## Signing boundary

- Release signing is enabled only when a private `android/key.properties` file
  exists and contains every required value.
- Missing signing values fail configuration instead of silently producing a
  partially configured signed build.
- Release builds never fall back to the debug signing key.
- `key.properties`, `*.jks`, and `*.keystore` are ignored by Git.
- `key.properties.example` contains placeholders only and is not a credential.

An unsigned release artifact proves repository build readiness only. It is not
uploadable production evidence until the Product Owner supplies and controls a
real upload key outside Git.

## Permission boundary

- Android 12+ BLE uses `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`.
- Pre-Android-12 BLE compatibility permissions are capped at API 30.
- BLE hardware remains optional so installation is not blocked on devices
  without BLE.
- Health Connect permissions correspond to the record types supported by the
  production bridge.
- Write access is limited to weight and hydration, the only record types the
  bridge currently writes.
- Health permissions have an in-app localized rationale and permission-usage
  activity.
- Cleartext network traffic and Android application backup remain disabled.

## External gates

Google Play developer identity, Play App Signing enrollment, upload-key
creation, private `key.properties`, store declarations, public privacy-policy
URL, device testing, Play review, and production rollout remain external. No
credential or approval is created or claimed by this repository package.
