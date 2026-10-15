#!/usr/bin/env bash
set -euo pipefail

readonly app_id='com.bilhealth.bodyintelligencelog'
readonly api_level="${BIL_ANDROID_EMULATOR_API:-}"
readonly apk='build/app/outputs/flutter-apk/app-debug.apk'
readonly evidence="artifacts/release/android_emulator_smoke/api-${BIL_ANDROID_EMULATOR_API:-unknown}"

mkdir -p "$evidence"

capture_failure_evidence() {
  local exit_status=$?
  if (( exit_status != 0 )); then
    printf 'exit_status=%s\n' "$exit_status" > "$evidence/failure.txt"
    adb logcat -d -t 1500 -s AndroidRuntime:E Flutter:E \
      > "$evidence/failure-logcat.txt" 2>&1 || true
  fi
}
trap capture_failure_evidence EXIT

if [[ ! "$api_level" =~ ^(26|29|33|34|35|36)$ ]]; then
  echo 'BIL_ANDROID_EMULATOR_API must be one of 26, 29, 33, 34, 35, or 36.' >&2
  exit 2
fi

test -s "$apk"
adb wait-for-device
network_mode='radio-state-not-forced'
if adb shell cmd connectivity airplane-mode enable >/dev/null 2>&1; then
  airplane_status=$(adb shell cmd connectivity airplane-mode | tr -d '\r')
  if [[ "$airplane_status" == 'enabled' ]]; then
    network_mode='airplane-mode'
  fi
fi
if [[ "$network_mode" == 'airplane-mode' ]]; then
  test "$(adb shell cmd connectivity airplane-mode | tr -d '\r')" = 'enabled'
fi
adb shell pm clear "$app_id" >/dev/null
adb install -r "$apk"
adb shell am start -n "$app_id/.MainActivity"
sleep 10
app_pid=$(adb shell pidof "$app_id" | tr -d '\r')
test -n "$app_pid"

adb shell getprop ro.build.version.sdk | tr -d '\r' > "$evidence/api-level.txt"
printf '%s\n' \
  "source_sha=${GITHUB_SHA:-unknown}" \
  'build_number=33' \
  "network=$network_mode;app_services_disabled=true" \
  "apk_sha256=$(sha256sum "$apk" | awk '{print $1}')" \
  'supabase=false payments=false ads=false community=false push=false' \
  > "$evidence/test-scope.txt"
adb exec-out screencap -p > "$evidence/startup.png"
sha256sum "$evidence/startup.png" > "$evidence/startup.sha256"

if adb logcat -d -t 2000 --pid="$app_pid" | grep -Eq 'FATAL EXCEPTION|Fatal signal [0-9]+'; then
  echo 'Android reported a fatal app crash during offline startup.' >&2
  exit 1
fi
