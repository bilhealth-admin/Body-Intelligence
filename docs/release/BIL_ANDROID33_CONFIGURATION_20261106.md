# Android 33 configuration — paired with iOS 41

Release version: 1.0.0. Android versionCode: 33. iOS build: 41.
Both signed artifacts must originate from the same final committed source SHA.
Build numbers are explicit platform build arguments; the pubspec fallback is not
an artifact identity. The protected iOS40 source and main remain unchanged.

The owner authorized signed Android33 preparation and iOS41 internal TestFlight
upload on 6 November 2026. This is not authorization to submit either app to a
public store review or to change prices, entitlements, credits, or Production.

Bluetooth scanning, device registration, direct-channel access and restored BLE
connections are disabled on Android for this release. Android requests no BLE,
location, body-sensor, advertising-ID, or Ad Services permissions. Optional
hardware declarations marked required=false do not grant permissions. iOS BLE
behavior is preserved. Health Connect retains exactly read-only steps, distance,
and active-calorie access with explicit user authorization.

Existing billing, server verification, integrity binding, encryption, account
ownership, advertising-consent controls and privacy gates remain mandatory.
Reviewer access uses the existing Store reviewer access password route and the
verified account grant; credentials never belong in source or this document.
Google's conditional reinstatement is not final public availability.

Signing follows successful exact-source CI/security/native lanes. Its runtime
acceptance manifest is generated from their actual receipts and has a separate
internal-signing scope; this configuration document does not certify test results.
The final AAB and derived signed QA APK must pass manifest permission, certificate,
package/version, 16-KB and cryptography checks. A derived APK is not proof of Play
delivery, Play App Signing, real billing, or the complete native reviewer journey.
