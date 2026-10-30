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
      > "$evidence/failure.txt" || true
    timeout 15s adb devices -l >> "$evidence/failure.txt" 2>&1 || true
    # Same bounded capture as the prelaunch guard; an existing receipt prevents
    # duplicate ADB requests. Diagnostic failure never replaces the original exit.
    timeout 45s python3 tool/release/verify_android_startup_frame.py \
      --capture-failure-diagnostics "$evidence" \
      > "$evidence/failure-diagnostics-command.txt" 2>&1 || true
    timeout 15s adb logcat -d -t 1500 \
      > "$evidence/failure-logcat.txt" 2>&1 || true
    if [[ ! -f "$evidence/startup.png" && ! -f "$evidence/failure-screen.png" ]]; then
      timeout 15s adb exec-out screencap -p \
        > "$evidence/failure-screen.png" 2>&1 || true
    fi
    timeout 15s adb shell dumpsys activity activities \
      > "$evidence/failure-activity-state.txt" 2>&1 || true
    timeout 15s adb shell dumpsys window \
      > "$evidence/failure-window-state.txt" 2>&1 || true
    # Focus can change from Launcher to its ANR dialog after the last poll.
    # Preserve the failed attempt and identify the actual dialog owner.
    timeout 15s python3 tool/release/verify_android_startup_frame.py \
      --window-health-only --require-app-focus \
      --window-state "$evidence/failure-window-state.txt" \
      > "$evidence/failure-window-check.txt" \
      2> "$evidence/failure-window-errors.txt" || true
    if [[ -f "$evidence/failure-diagnostic-last-anr.txt" ]]; then
      cp "$evidence/failure-diagnostic-last-anr.txt" "$evidence/failure-last-anr.txt" || true
    else
      timeout 15s adb shell dumpsys activity lastanr \
        > "$evidence/failure-last-anr.txt" 2>&1 || true
    fi
    timeout 15s adb logcat -b crash -d -t 1000 \
      > "$evidence/failure-crash-logcat.txt" 2>&1 || true
    timeout 15s adb shell uiautomator dump /sdcard/bil-failure-window.xml \
      > "$evidence/failure-uiautomator.txt" 2>&1 || true
    timeout 15s adb pull /sdcard/bil-failure-window.xml "$evidence/failure-window.xml" \
      >/dev/null 2>&1 || true
  fi
  return "$exit_status"
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
stage='capture-launch-scope'
printf '%s\n' "$actual_api_level" > "$evidence/api-level.txt"
printf '%s\n' \
  "source_sha=${GITHUB_SHA:-unknown}" \
  'build_number=33' \
  "network=$network_mode;app_services_disabled=true" \
  "apk_sha256=$(sha256sum "$apk" | awk '{print $1}')" \
  'supabase=false payments=false ads=false community=false push=false' \
  > "$evidence/test-scope.txt"

stage='verify-emulator-system-ui-before-launch'
python3 tool/release/verify_android_startup_frame.py \
  --verify-emulator-before-launch "$evidence"

stage='verify-emulator-display-budget'
python3 tool/release/configure_android_emulator_display.py verify-runtime \
  --api-level "$api_level" --evidence-dir "$evidence"

stage='install-debug-apk'
adb install "$apk"
stage='clear-app-data'
adb shell pm clear "$app_id" >/dev/null
stage='launch-main-activity'
adb shell am start -n "$app_id/.MainActivity"
stage='wait-for-app-foreground'
app_pid=''
foreground_ready=false
for attempt in {1..15}; do
  app_pid=$(adb shell pidof "$app_id" | tr -d '\r' || true)
  adb shell dumpsys window > "$evidence/foreground-focused-window.txt"
  window_exit=0
  python3 tool/release/verify_android_startup_frame.py \
    --window-health-only --require-app-focus \
    --window-state "$evidence/foreground-focused-window.txt" \
    > "$evidence/foreground-window-check.txt" \
    2> "$evidence/foreground-window-errors.txt" || window_exit=$?
  if (( window_exit >= 20 && window_exit <= 22 )); then
    cat "$evidence/foreground-window-check.txt" >&2
    cat "$evidence/foreground-window-errors.txt" >&2
    exit "$window_exit"
  fi
  if [[ -n "$app_pid" && "$window_exit" == 0 ]]; then
    foreground_ready=true
    break
  fi
  sleep 2
done
if [[ "$foreground_ready" != true ]]; then
  cat "$evidence/foreground-window-check.txt" >&2 || true
  echo 'BIL did not become the actual focused Android window.' >&2
  exit 1
fi

stage='wait-for-accessible-app-content-and-first-frame'
frame_ready=false
app_content_ready=false
frame_attempt=0
for attempt in {1..30}; do
  frame_attempt=$attempt
  if adb shell uiautomator dump /sdcard/bil-startup-window.xml \
      > "$evidence/startup-uiautomator-poll.txt" 2>&1 \
      && adb pull /sdcard/bil-startup-window.xml \
        "$evidence/startup-window.xml" >/dev/null 2>&1; then
    if adb exec-out screencap -p > "$evidence/startup.png" \
        2> "$evidence/screencap-errors.txt"; then
      adb shell dumpsys window > "$evidence/startup-focused-window.txt"
      frame_exit=0
      python3 tool/release/verify_android_startup_frame.py \
          "$evidence/startup.png" "$evidence/startup-window.xml" \
          --window-state "$evidence/startup-focused-window.txt" \
          > "$evidence/startup-frame.txt" \
          2> "$evidence/startup-frame-errors.txt" || frame_exit=$?
      if (( frame_exit >= 20 && frame_exit <= 22 )); then
        cat "$evidence/startup-frame.txt" >&2
        cat "$evidence/startup-frame-errors.txt" >&2
        exit "$frame_exit"
      fi
      if (( frame_exit == 0 )); then
        app_content_ready=true
        frame_ready=true
        break
      fi
    fi
  fi
  sleep 2
done
printf 'attempts=%s\napp_content_ready=%s\nframe_ready=%s\n' \
  "$frame_attempt" "$app_content_ready" "$frame_ready" \
  > "$evidence/startup-frame-wait.txt"
if [[ -f "$evidence/startup.png" ]]; then
  sha256sum "$evidence/startup.png" > "$evidence/startup.sha256"
fi
if [[ "$frame_ready" != true ]]; then
  cat "$evidence/startup-frame.txt" >&2 || true
  echo 'BIL did not expose interactive app content and a visible frame within the startup wait.' >&2
  exit 1
fi

stage='capture-launch-evidence'
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

stage='check-app-crash-log'
if adb logcat -d -t 2000 --pid="$app_pid" | grep -Eq 'FATAL EXCEPTION|Fatal signal [0-9]+'; then
  echo 'Android reported a fatal app crash during offline startup.' >&2
  exit 1
fi
