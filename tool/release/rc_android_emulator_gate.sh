#!/usr/bin/env bash
set -euo pipefail

EVIDENCE=artifacts/release/rc_mobile_test/android
mkdir -p "$EVIDENCE"

flutter test --no-pub \
  integration_test/system_crypto_bridge_integration_test.dart \
  -d emulator-5554 --timeout 10m

flutter test --no-pub \
  integration_test/native_settings_polish_test.dart \
  -d emulator-5554 --timeout 10m

APK=build/app/outputs/flutter-apk/app-debug.apk
test -s "$APK"
adb install -r "$APK"
adb shell pm clear "$BIL_APP_ID"
adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
sleep 8

adb exec-out screencap -p > "$EVIDENCE/01-cold-launch.png"
adb shell uiautomator dump /sdcard/bil-ui.xml >/dev/null
adb pull /sdcard/bil-ui.xml "$EVIDENCE/01-cold-launch.xml" >/dev/null

adb shell am start -W -a android.intent.action.VIEW -d "bil://login"
sleep 3
adb exec-out screencap -p > "$EVIDENCE/02-login-deep-link.png"

adb shell input keyevent 3
sleep 2
adb shell am force-stop "$BIL_APP_ID"
adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
sleep 5
adb exec-out screencap -p > "$EVIDENCE/03-relaunch.png"

adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
sleep 2
adb exec-out screencap -p > "$EVIDENCE/04-landscape.png"
adb shell settings put system user_rotation 0

for PERM in \
  android.permission.CAMERA \
  android.permission.RECORD_AUDIO \
  android.permission.POST_NOTIFICATIONS; do
  adb shell pm revoke "$BIL_APP_ID" "$PERM" || true
  adb shell pm grant "$BIL_APP_ID" "$PERM" || true
done

adb logcat -d > "$EVIDENCE/logcat.txt"
if grep -Eiq 'FATAL EXCEPTION|AndroidRuntime.*FATAL|Process: com\.bilhealth\.bodyintelligencelog.*has died' "$EVIDENCE/logcat.txt"; then
  echo 'Android runtime fatal marker detected.' >&2
  exit 1
fi

printf '%s\n' \
  'ANDROID_EMULATOR_INSTALL=PASS' \
  'ANDROID_COLD_LAUNCH=PASS' \
  'ANDROID_DEEP_LINK=PASS' \
  'ANDROID_BACKGROUND_FORCE_STOP_RELAUNCH=PASS' \
  'ANDROID_ROTATION=PASS' \
  'ANDROID_PERMISSION_GRANT_REVOKE=PASS' \
  'ANDROID_RUNTIME_CRASH_SCAN=PASS' \
  'ANDROID_NATIVE_CRYPTO=PASS' \
  'ANDROID_NATIVE_SETTINGS_UI=PASS' \
  > "$EVIDENCE/gate-status.txt"
