# HealthKit native evidence — references 4988–4991

This gate must run on macOS with an iPhone or an iOS Simulator. Android and
Flutter goldens cannot produce Apple's native Health Access sheet. When no
local Mac is available, run the manual GitHub Actions workflow
`BIL HealthKit cloud simulator evidence` (`bil_healthkit_cloud_simulator.yml`).
It builds the real iOS simulator app, opens the production authorization path,
captures four native states, and uploads hashes and toolchain metadata.
The same run also uploads `BIL-iOS-Simulator.zip`. Upload that archive to a
Sauce Labs **Mobile Virtual / iOS Simulator** Live session to show and control
the iPhone screen interactively in a browser when no local Mac is available.
The interactive stream is presentation evidence; the workflow's native-sheet
assertions remain the acceptance evidence for references 4988–4991.

## Build and launch

1. Open the repository on the Mac and run:

   ```sh
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter devices
   flutter run -d <ios-device-id>
   ```

2. If BIL has previously requested HealthKit access, remove BIL from the
   device/simulator and reinstall it so Apple presents the first-request sheet.
3. Open **Connected Health** and press **Grant health access**.

## Required native captures

Capture the genuine BIL sheet, without enabling reference-user values:

- `4988`: top of the Health Access sheet, including the BIL app identity and
  the first requested types.
- `4989`: continuation of BIL's actual requested types, if the sheet scrolls.
- `4990`: read-access portion or the next genuine native state.
- `4991`: bottom of the sheet with Apple's Allow/Don't Allow controls.

If BIL's deliberately smaller scope fits in fewer viewports, do not fabricate
extra types or duplicate screenshots. Capture the distinct states that exist
and document the four references as one limited HealthKit permission family.

## Truth checks

- The sheet must identify **BIL**, never MyFitnessPal.
- Requested read types must come from `BilHealthScope.read`: activity and
  distance, energy and workouts, sleep duration/stages, body measurements,
  heart/oxygen/respiratory/blood-pressure/glucose measurements, hydration, and
  nutrition nutrients. Missing records remain missing evidence.
- Apple write access is restricted to the reviewed Apple boundary; the BIL UI
  says **Allow weight export** on iOS and does not promise nutrition export.
- Record OS version, device/simulator model, locale, app build hash, and whether
  the user selected Allow or Don't Allow.
- After dismissal, capture Connected Health once more to prove BIL exits the
  busy state and reports the resulting permission state without a crash.

## Evidence destination

Store sanitized images under:

`artifacts/release/healthkit_native_4988_4991/`

Do not include Apple ID, personal health records, or other user identifiers.
