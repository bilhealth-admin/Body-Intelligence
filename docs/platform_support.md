# Platform support

BIL keeps data locally on Android, Windows, Web, and iOS. All targets use one
Drift schema. Body values are stored in canonical metric units and converted
only at input and display boundaries.

## Android

```sh
flutter pub get
flutter build apk --debug
```

The artifact is `build/app/outputs/flutter-apk/app-debug.apk`.

## Windows

Install Visual Studio with the Desktop development with C++ workload, then:

```sh
flutter config --enable-windows-desktop
flutter build windows --debug
flutter run -d windows
```

The database is in the application-support directory. Resizing switches the
main shell between bottom navigation and a navigation rail.

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
