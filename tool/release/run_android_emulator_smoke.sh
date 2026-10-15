#!/usr/bin/env bash
set -euo pipefail

readonly app_id='com.bilhealth.bodyintelligencelog'
readonly api_level="${BIL_ANDROID_EMULATOR_API:-}"
readonly apk='build/app/outputs/flutter-apk/app-debug.apk'
readonly evidence="artifacts/release/android_emulator_smoke/api-${BIL_ANDROID_EMULATOR_API:-unknown}"

if [[ ! "$api_level" =~ ^(26|33|36)$ ]]; then
  echo 'BIL_ANDROID_EMULATOR_API must be one of 26, 33, or 36.' >&2
  exit 2
fi

test -s "$apk"
adb wait-for-device
adb shell settings put global airplane_mode_on 1
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null
adb shell svc wifi disable || true
adb shell svc data disable || true
test "$(adb shell settings get global airplane_mode_on | tr -d '\r')" = '1'
adb shell pm clear "$app_id" >/dev/null
adb install -r "$apk"
adb shell am start -n "$app_id/.MainActivity"
sleep 10
app_pid=$(adb shell pidof "$app_id" | tr -d '\r')
test -n "$app_pid"

mkdir -p "$evidence"
adb shell getprop ro.build.version.sdk | tr -d '\r' > "$evidence/api-level.txt"
printf '%s\n' \
  "source_sha=${GITHUB_SHA:-unknown}" \
  'build_number=33' \
  'network=airplane-mode-enabled' \
  'supabase=false payments=false ads=false community=false push=false' \
  > "$evidence/test-scope.txt"
adb exec-out screencap -p > "$evidence/startup.png"

if adb logcat -d -t 2000 --pid="$app_pid" | grep -Eq 'FATAL EXCEPTION|Fatal signal [0-9]+'; then
  echo 'Android reported a fatal app crash during offline startup.' >&2
  exit 1
fi
