# iOS readiness and release checklist

iOS has been audited for source compatibility but cannot be compiled or run on
this Windows host. The shared application no longer imports Android-only APIs.
Drift uses its native executor on iOS and stores the SQLite file in the
application-support directory. Shared preferences stores locale/theme settings.
Clipboard export uses Flutter's cross-platform services API.

The current Xcode project still uses the development identifier
`com.example.bodyIntelligenceLog`. Replace it with an identifier owned by the
Apple Developer account before signing or distribution. The MVP does not use
camera, photos, microphone, location, contacts, HealthKit, tracking, or push
notifications, so no usage-description keys are currently required in
`Info.plist`. Re-audit this when adding any such feature.

## Required Mac verification

Install the current stable Xcode and Flutter toolchain, accept Xcode licenses,
open a terminal at the repository root, and run exactly:

```sh
flutter doctor -v
flutter pub get
dart format .
flutter analyze
flutter test
flutter devices
flutter build ios --simulator
flutter run -d <ios-simulator-id>
```

Verify a genuinely fresh install and an upgrade containing existing data.
Exercise English/Arabic switching and immediate RTL/LTR, system/light/dark
themes, onboarding in metric and imperial units, wheel and typed input, profile
editing, weights, meals, water, dashboard, analytics, JSON clipboard export,
reset confirmation, app termination/relaunch, and database persistence.

## Signing, archive, and TestFlight

1. Join or select the appropriate Apple Developer Program team.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. In Runner > Signing & Capabilities, set the owned bundle identifier, select
   the Team, and use automatic signing or the team's managed provisioning.
4. Confirm the deployment target against the installed Flutter stable release
   and supported device policy. Do not lower it below plugin requirements.
5. Set release version/build numbers and create the App Store Connect record.
6. Complete App Privacy answers for on-device profile, health/fitness-style,
   nutrition, and diagnostics data accurately. Local-only processing does not
   remove the obligation to describe collected app data correctly.
7. Test a Release build on a physical device, including clipboard export and
   persistence after termination.
8. In Xcode select Any iOS Device (arm64), then Product > Archive. Run Validate
   App before Distribute App > App Store Connect > Upload.
9. Add the uploaded build to an internal TestFlight group, complete export
   compliance and review information, and perform the same regression suite.

Never commit signing certificates, provisioning profiles, App Store Connect
API keys, or Apple credentials. A successful iOS build, launch, archive, and
TestFlight upload remain Mac-only blockers.
