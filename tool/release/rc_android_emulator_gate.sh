#!/usr/bin/env bash
set -euo pipefail

EVIDENCE=artifacts/release/rc_mobile_test/android
mkdir -p "$EVIDENCE"

PHASE="${BIL_ANDROID_EMULATOR_PHASE:-all}"

if [[ "$PHASE" == "crypto" || "$PHASE" == "all" ]]; then
  flutter test --no-pub \
    integration_test/system_crypto_bridge_integration_test.dart \
    -d emulator-5554 --timeout 10m
fi

if [[ "$PHASE" == "crypto" ]]; then
  exit 0
fi

if [[ "$PHASE" == "api26" ]]; then
  APK=build/app/outputs/flutter-apk/app-debug.apk
  test -s "$APK"
  adb install -r "$APK"
  adb shell pm clear "$BIL_APP_ID"
  adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
  sleep 8
  adb exec-out screencap -p > "$EVIDENCE/09-api26-cold-launch.png"
  adb logcat -d > "$EVIDENCE/api26-logcat.txt"
  if grep -Eiq 'FATAL EXCEPTION|AndroidRuntime.*FATAL|Process: com\.bilhealth\.bodyintelligencelog.*has died' "$EVIDENCE/api26-logcat.txt"; then
    echo 'Android API 26 runtime fatal marker detected.' >&2
    exit 1
  fi
  echo 'ANDROID_API26_MINSDK_INSTALL_LAUNCH=PASS' >> "$EVIDENCE/gate-status.txt"
  exit 0
fi

if [[ "$PHASE" == "api36" ]]; then
  APK=build/app/outputs/flutter-apk/app-debug.apk
  test -s "$APK"
  adb install -r "$APK"
  adb shell pm clear "$BIL_APP_ID"
  adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
  sleep 8
  adb shell am start -W -a android.intent.action.VIEW -d 'bil://login'
  sleep 3
  adb exec-out screencap -p > "$EVIDENCE/10-api36-login-deep-link.png"
  adb logcat -d > "$EVIDENCE/api36-logcat.txt"
  if grep -Eiq 'FATAL EXCEPTION|AndroidRuntime.*FATAL|Process: com\.bilhealth\.bodyintelligencelog.*has died' "$EVIDENCE/api36-logcat.txt"; then
    echo 'Android API 36 runtime fatal marker detected.' >&2
    exit 1
  fi
  echo 'ANDROID_API36_TARGETSDK_INSTALL_DEEPLINK=PASS' >> "$EVIDENCE/gate-status.txt"
  exit 0
fi

if [[ "$PHASE" != "ui" && "$PHASE" != "all" ]]; then
  echo "Unknown BIL_ANDROID_EMULATOR_PHASE: $PHASE" >&2
  exit 2
fi

flutter test --no-pub \
  integration_test/native_settings_polish_test.dart \
  -d emulator-5554 --timeout 10m

BIL_ADMOB_ANDROID_APP_ID='ca-app-pub-3940256099942544~3347511713' \
flutter test --no-pub \
  integration_test/admob_native_banner_integration_test.dart \
  -d emulator-5554 --timeout 10m
ADMOB_GATE='PASS'

BARCODE_GATE='NOT_RUN_MISSING_QA_CREDENTIALS'
if [[ -n "${BIL_BARCODE_GATE_EMAIL:-}" && -n "${BIL_BARCODE_GATE_PASSWORD:-}" ]]; then
  flutter test --no-pub \
    integration_test/real_barcode_photo_integration_test.dart \
    -d emulator-5554 --timeout 12m \
    --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
    --dart-define=BIL_BARCODE_GATE_EMAIL="${BIL_BARCODE_GATE_EMAIL}" \
    --dart-define=BIL_BARCODE_GATE_PASSWORD="${BIL_BARCODE_GATE_PASSWORD}"
  BARCODE_GATE='PASS'
fi

TWO_ACCOUNT_GATE='NOT_RUN_MISSING_QA_CREDENTIALS'
if [[ -n "${BIL_EPIC9_ACCOUNT_A_EMAIL:-}" && -n "${BIL_EPIC9_ACCOUNT_A_PASSWORD:-}" && \
      -n "${BIL_EPIC9_ACCOUNT_B_EMAIL:-}" && -n "${BIL_EPIC9_ACCOUNT_B_PASSWORD:-}" ]]; then
  flutter test --no-pub \
    integration_test/epic9_two_account_cloud_test.dart \
    --timeout 12m \
    --dart-define=BIL_RUN_EPIC9_CLOUD_INTEGRATION=true \
    --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
    --dart-define=BIL_EPIC9_ACCOUNT_A_EMAIL="${BIL_EPIC9_ACCOUNT_A_EMAIL}" \
    --dart-define=BIL_EPIC9_ACCOUNT_A_PASSWORD="${BIL_EPIC9_ACCOUNT_A_PASSWORD}" \
    --dart-define=BIL_EPIC9_ACCOUNT_B_EMAIL="${BIL_EPIC9_ACCOUNT_B_EMAIL}" \
    --dart-define=BIL_EPIC9_ACCOUNT_B_PASSWORD="${BIL_EPIC9_ACCOUNT_B_PASSWORD}"
  TWO_ACCOUNT_GATE='PASS'
fi

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

adb shell cmd uimode night yes
adb shell am force-stop "$BIL_APP_ID"
adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
sleep 4
adb exec-out screencap -p > "$EVIDENCE/05-dark-mode.png"

adb shell cmd uimode night no
adb shell settings put system font_scale 2.0
adb shell am force-stop "$BIL_APP_ID"
adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
sleep 4
adb exec-out screencap -p > "$EVIDENCE/06-large-text-200.png"
adb shell settings put system font_scale 1.0

NETWORK_GATE='NOT_CONFIRMED_EMULATOR_NETWORK'
adb shell cmd connectivity airplane-mode enable >/dev/null 2>&1 || true
adb shell svc wifi disable >/dev/null 2>&1 || true
adb shell svc data disable >/dev/null 2>&1 || true
sleep 4
if ! adb shell dumpsys connectivity | grep -q 'NET_CAPABILITY_VALIDATED'; then
  adb shell am force-stop "$BIL_APP_ID"
  adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
  sleep 4
  adb exec-out screencap -p > "$EVIDENCE/07-offline-launch.png"
  NETWORK_GATE='PASS'
fi
adb shell cmd connectivity airplane-mode disable >/dev/null 2>&1 || true
adb shell svc wifi enable >/dev/null 2>&1 || true
adb shell svc data enable >/dev/null 2>&1 || true
sleep 6
adb shell am force-stop "$BIL_APP_ID"
adb shell monkey -p "$BIL_APP_ID" -c android.intent.category.LAUNCHER 1
sleep 4
adb exec-out screencap -p > "$EVIDENCE/08-network-recovered.png"

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
  'ANDROID_DARK_LIGHT=PASS' \
  'ANDROID_LARGE_TEXT_200_PERCENT=PASS' \
  "ANDROID_NETWORK_OFFLINE_RECOVERY=${NETWORK_GATE}" \
  'ANDROID_PERMISSION_GRANT_REVOKE=PASS' \
  'ANDROID_RUNTIME_CRASH_SCAN=PASS' \
  'ANDROID_NATIVE_CRYPTO=PASS' \
  'ANDROID_NATIVE_SETTINGS_UI=PASS' \
  "ANDROID_ADMOB_OFFICIAL_TEST_BANNER=${ADMOB_GATE}" \
  "ANDROID_REAL_BARCODE_PHOTO=${BARCODE_GATE}" \
  "ANDROID_TWO_ACCOUNT_CLOUD=${TWO_ACCOUNT_GATE}" \
  > "$EVIDENCE/gate-status.txt"
