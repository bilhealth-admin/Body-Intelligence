# BIL — Body Intelligence Log

BIL is an offline-first Flutter Android application for recording body weight,
meals, hydration, and daily context. It calculates nutrition totals and
deterministic, explainable insights locally. Arabic is the default language and
English is supported.

## Run and verify

```text
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build apk --debug
```

From WSL in this workspace, use the Windows SDK at
`C:\develop\flutter\bin\flutter.bat`. The debug APK is produced at
`build/app/outputs/flutter-apk/app-debug.apk`.

## Local data

Drift/SQLite is the source of truth. Profile, goals, weights, daily notes,
foods, favorites, recents, meals, meal items, water, and preferences persist in
the application-support directory. Nutrition is derived from meal items; old
daily nutrition columns remain read-only solely for migration compatibility.

Cloud authentication and synchronization are deliberately disabled when no
Supabase URL and anonymous key are configured. The app remains fully usable in
Local Mode. Never place a Supabase service-role key in this client.

## Health scope

BIL offers general tracking information and cautious hypotheses. It does not
diagnose disease or replace advice from a qualified healthcare professional.
