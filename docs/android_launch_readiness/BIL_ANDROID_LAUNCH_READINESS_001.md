# BIL-ANDROID-LAUNCH-READINESS-001

## Purpose
Close internal Android blockers before beginning Google Play Console and signing activation.

## Changes
- Pin Android compile and target SDK to API 36 for the 2026 Google Play submission requirement.
- Add the Health Connect permission-rationale Activity and Android 14+ permission-usage alias.
- Add localized Arabic and English rationale copy.
- Add coarse-location compatibility through Android 11 for legacy BLE discovery.
- Disable cleartext HTTP traffic in the production Android application manifest.
- Verify a debug APK and a release AAB without adding credentials or enabling Play services.

## External work intentionally deferred
- Google Play Console registration.
- Upload key and Play App Signing.
- Store listing, Data Safety, privacy-policy URL and Health Connect declaration forms.
- Billing, Play Integrity and production backend activation.
