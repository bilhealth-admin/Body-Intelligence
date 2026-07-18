# Platform support

BIL keeps data locally on Android, Windows, Web, and iOS. All targets use one
Drift schema. Body values are stored in canonical metric units and converted
only at input and display boundaries.

## Android

```sh
flutter pub get
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

The artifact is `build/app/outputs/flutter-apk/app-debug.apk`.
Release artifacts must be signed with credentials supplied outside Git. Record
the minimum/target Android versions from the generated Gradle configuration at
release time and test install/upgrade on a physical supported device.

The current development Gradle file deliberately signs release-mode artifacts
with the debug key and still uses `com.example.body_intelligence_log`. The
successfully generated APK/AAB prove release compilation only; they are not
store-upload candidates. Before distribution, choose an owned application ID,
configure an upload key through ignored/environment-provided properties,
remove debug signing from the release build type, and repeat release and
physical-device verification.

## Windows

Install Visual Studio with the Desktop development with C++ workload, then:

```sh
flutter config --enable-windows-desktop
flutter build windows --debug
flutter build windows --release
flutter run -d windows
```

The database is in the application-support directory. Resizing switches the
main shell between bottom navigation and a navigation rail.
Distribute the complete release folder or a signed installer; the executable
alone is insufficient. Support targets Windows 10/11 x64. Windows 7 is not
claimed; offer the Web build on unsupported desktop systems.

## Web

The Web database uses Drift's WebAssembly executor. `web/sqlite3.wasm` matches
the pinned sqlite3 package and `web/drift_worker.dart.js` is generated from
`tool/drift_worker.dart`.

```sh
dart compile js -O4 tool/drift_worker.dart -o web/drift_worker.dart.js
flutter build web
flutter run -d chrome
```

Drift chooses OPFS when supported and otherwise falls back to IndexedDB.
Browser storage can be cleared by the user or browser policy, so export local
JSON before clearing site data.

Deploy the complete `build/web` directory to an HTTPS static host with SPA
fallback to `index.html`. Serve `.wasm` as `application/wasm`, do not cache
`index.html` indefinitely, and use versioned immutable caching for hashed
assets. Test a fresh load, refresh on a nested route, offline/local persistence,
an upgrade, export, and storage clearing in current Chrome plus another browser.

## iOS readiness

The project and local database path are iOS-compatible. This MVP requests no
camera, photo, location, HealthKit, or tracking permissions. Compilation and
signing require macOS with Xcode:

```sh
flutter pub get
flutter build ios --simulator
flutter run -d ios
```

Before distribution, replace the example bundle identifier in
`ios/Runner.xcworkspace`, select a development team, configure signing, confirm
the deployment target supported by the installed Flutter release, and provide
App Store privacy disclosures. Validate language switching, RTL, themes,
restart persistence, migration, and reset on a simulator and physical device.

## Local-mode limitations

Supabase sync stays disabled unless configured. Data is not shared between
devices, automatic backups are not provided, and uninstalling the app or
clearing browser site storage can remove data. Export copies a JSON snapshot
to the system clipboard for saving in a destination controlled by the user.
