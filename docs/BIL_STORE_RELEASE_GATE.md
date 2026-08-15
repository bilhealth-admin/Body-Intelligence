# BIL Google Play and App Store release gate

No build is release-ready until every applicable item is green.

## Code and product

- Analyzer and full test suite pass on the release commit.
- Arabic and English are complete. French, Spanish and Turkish receive native
  review wherever advertised as supported.
- Account, local-only, verification, reset, export, deletion and permission
  denial are tested on physical devices.
- Search, barcode, voice and image analysis fail honestly offline.
- Tobacco, medicine/supplement, cosmetic/cleaner, food and unknown states never
  invent nutrition or permit a non-food product into a meal.
- Only licensed, verified recipe/workout packs are visible; no demo content.
- Guide, Body Twin, evidence, watch and medical-device states remain truthful.

## External activation

- Apple Developer and Play Console agreements and signing identities are live.
- Free, Plus and Pro product IDs, prices, trials and server entitlements match.
- Supabase migrations, RLS, edge functions, SMTP, secrets and redirects deploy.
- Vision/catalog/wellness endpoints use HTTPS, integrity and monitoring.
- Media licenses and food-data provenance are documented.
- Reporting, blocking, moderation and abuse response exist before community.

## Native review

- Android AAB, current target API, Health Connect/BLE declarations and Play
  pre-launch report pass.
- iOS archive is built on macOS; privacy, HealthKit, BLE and TestFlight pass.
- Small/large text, RTL, light/dark, reduced motion, screen reader and denied
  permissions pass on phones.
- Screenshots, medical disclaimer, privacy, terms, support and review account
  are complete.

## Final commands

```powershell
flutter analyze
flutter test --timeout 30s
flutter build appbundle --release
```

The repository also provides the manual GitHub workflow
`BIL Android signed release candidate`. It refuses to build without all four
Android signing secrets, verifies the resulting AAB signature, records its
SHA-256 and uploads it only as a private workflow artifact. It never submits
to Google Play automatically.

Required GitHub Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

On a configured macOS runner:

```bash
flutter build ipa --release
```

The existing `BIL iOS unsigned release validation` workflow proves that the
iOS source compiles on macOS. App Store submission remains blocked until the
Apple team, distribution certificate, provisioning profile, privacy answers
and signed archive are supplied and reviewed.
