#!/usr/bin/env bash
set -euo pipefail

readonly app_id='com.bilhealth.bodyintelligencelog'
readonly api_level="${BIL_ANDROID_EMULATOR_API:-}"
readonly apk='build/app/outputs/flutter-apk/app-debug.apk'
readonly evidence="artifacts/release/android_emulator_smoke/api-${BIL_ANDROID_EMULATOR_API:-unknown}"
stage='initialize'

mkdir -p "$evidence"

capture_failure_evidence() {
  local exit_status=$?
  if (( exit_status != 0 )); then
    printf 'exit_status=%s\nstage=%s\n' "$exit_status" "$stage" \
      > "$evidence/failure.txt"
    adb devices -l >> "$evidence/failure.txt" 2>&1 || true
    adb logcat -d -t 1500 \
      > "$evidence/failure-logcat.txt" 2>&1 || true
    if [[ ! -f "$evidence/startup.png" ]]; then
      adb exec-out screencap -p > "$evidence/failure-screen.png" 2>&1 || true
    fi
    adb shell dumpsys activity activities \
      > "$evidence/failure-activity-state.txt" 2>&1 || true
    adb shell dumpsys window windows \
      > "$evidence/failure-window-state.txt" 2>&1 || true
  fi
}
trap capture_failure_evidence EXIT

if [[ ! "$api_level" =~ ^(26|29|33|34|35|36)$ ]]; then
  echo 'BIL_ANDROID_EMULATOR_API must be one of 26, 29, 33, 34, 35, or 36.' >&2
  exit 2
fi

stage='verify-debug-apk'
test -s "$apk"
stage='wait-for-emulator-transport'
adb wait-for-device
device_ready=false
for attempt in {1..60}; do
  device_state=$(adb get-state 2>/dev/null || true)
  boot_completed=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
  if [[ "$device_state" == 'device' && "$boot_completed" == '1' ]]; then
    device_ready=true
    break
  fi
  sleep 2
done
if [[ "$device_ready" != true ]]; then
  stage='emulator-boot-timeout'
  echo 'Android emulator did not remain online after boot.' >&2
  exit 3
fi

stage='validate-emulator-api-level'
actual_api_level=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
if [[ "$actual_api_level" != "$api_level" ]]; then
  printf 'Expected API %s but emulator reported API %s.\n' \
    "$api_level" "$actual_api_level" >&2
  exit 4
fi

network_mode='radio-state-not-forced'
stage='install-debug-apk'
adb install "$apk"
stage='clear-app-data'
adb shell pm clear "$app_id" >/dev/null
stage='launch-main-activity'
adb shell am start -n "$app_id/.MainActivity"
stage='wait-for-app-foreground'
app_pid=''
foreground_window=''
for attempt in {1..15}; do
  app_pid=$(adb shell pidof "$app_id" | tr -d '\r' || true)
  foreground_window=$(adb shell dumpsys window windows 2>/dev/null \
    | grep -E 'mCurrentFocus|mFocusedApp' | tail -n 1 | tr -d '\r' || true)
  if [[ -n "$app_pid" && "$foreground_window" == *"$app_id"* ]]; then
    break
  fi
  sleep 2
done
if [[ -z "$app_pid" || "$foreground_window" != *"$app_id"* ]]; then
  echo "BIL did not become the foreground Android window: $foreground_window" >&2
  exit 1
fi
sleep 5

stage='capture-launch-evidence'
printf '%s\n' "$actual_api_level" > "$evidence/api-level.txt"
printf '%s\n' \
  "source_sha=${GITHUB_SHA:-unknown}" \
  'build_number=33' \
  "network=$network_mode;app_services_disabled=true" \
  "apk_sha256=$(sha256sum "$apk" | awk '{print $1}')" \
  'supabase=false payments=false ads=false community=false push=false' \
  > "$evidence/test-scope.txt"
adb exec-out screencap -p > "$evidence/startup.png"
sha256sum "$evidence/startup.png" > "$evidence/startup.sha256"
adb logcat -d -t 5000 > "$evidence/startup-logcat.txt" 2>&1 || true
adb shell dumpsys activity activities > "$evidence/activity-state.txt" 2>&1 || true
adb shell dumpsys window windows > "$evidence/window-state.txt" 2>&1 || true
adb shell uiautomator dump /sdcard/bil-startup-window.xml \
  > "$evidence/uiautomator.txt" 2>&1 || true
adb pull /sdcard/bil-startup-window.xml "$evidence/startup-window.xml" \
  >/dev/null 2>&1 || true

stage='verify-first-frame-content'
if grep -Eqi \
  "ANR in |Application Not Responding|isn't responding|is not responding|لا يستجيب" \
  "$evidence/startup-logcat.txt" "$evidence/uiautomator.txt" \
  "$evidence/startup-window.xml"; then
  echo 'Android reported an ANR dialog or unresponsive process during startup.' >&2
  exit 1
fi
python3 tool/release/verify_android_startup_frame.py \
  "$evidence/startup.png" | tee "$evidence/startup-frame.txt"

stage='check-app-crash-log'
if adb logcat -d -t 2000 --pid="$app_pid" | grep -Eq 'FATAL EXCEPTION|Fatal signal [0-9]+'; then
  echo 'Android reported a fatal app crash during offline startup.' >&2
  exit 1
fi
