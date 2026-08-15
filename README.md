# BIL — Body Intelligence Log

BIL is an offline-first Flutter body-intelligence application. It records body
weight, meals, hydration, and life context, then produces deterministic,
explainable insights locally. It also supports personal experiments,
behavior-first private challenges, adaptive meal suggestions, and privacy-safe
progress cards. Fresh installs start in English; Arabic is available from the
first onboarding screen with immediate RTL/LTR switching.

## Run and verify

```text
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
flutter build web
```

From WSL in this workspace, use the Windows SDK at
`C:\develop\flutter\bin\flutter.bat`. The debug APK is produced at
`build/app/outputs/flutter-apk/app-debug.apk`.

See [`docs/platform_support.md`](docs/platform_support.md) for Web persistence
assets, Windows prerequisites, Android output, and the iOS signing checklist.

## Local data

Drift/SQLite schema v13 is the source of truth. Profile, goals, plan overrides,
weights, daily notes, foods, favorites, recents, meals, meal items, water,
context, decision memory, experiments, challenges, and preferences persist in
the application-support directory. Nutrition is derived from meal items; old
daily nutrition columns remain read-only solely for migration compatibility.

Cloud authentication and synchronization are deliberately disabled when no
Supabase URL and anonymous key are configured. The app remains fully usable in
Local Mode. Never place a Supabase service-role key in this client.

Other external capabilities—including AI, commerce, community, coach access,
remote updates, and shared challenges—remain visibly unavailable until their
authenticated server-side adapters, consent rules, and verification paths are
configured. No unavailable action reports success.

## Release documentation

- [Final v1 release constitution](docs/BIL_V1_FINAL_RELEASE_CONSTITUTION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Database and migrations](docs/DATABASE.md)
- [Scientific and health-safety rules](docs/SCIENTIFIC_RULES.md)
- [Platform builds and deployment](docs/platform_support.md)
- [Performance budgets and measurement](docs/PERFORMANCE.md)
- [iOS readiness checklist](docs/IOS_READINESS.md)
- [Commercial boundary](docs/COMMERCIAL_BOUNDARY.md)
- [Current roadmap and external blockers](docs/ROADMAP.md)

## Health scope

BIL offers general tracking information and cautious hypotheses. It does not
diagnose disease or replace advice from a qualified healthcare professional.
