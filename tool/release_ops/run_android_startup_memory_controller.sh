#!/usr/bin/env bash
set -euo pipefail

readonly frozen_source='5775d082a1b4c7a29e4ed4d6e01693b31923dc31'
readonly controller_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly app_root="${BIL_FROZEN_APP_ROOT:?BIL_FROZEN_APP_ROOT is required}"
readonly api="${BIL_ANDROID_EMULATOR_API:?API is required}"
readonly evidence="$app_root/artifacts/release/android_emulator_smoke/api-$api"
readonly sdk_root="${ANDROID_HOME:?ANDROID_HOME is required}"
readonly sdk_adb="$sdk_root/platform-tools/adb"
[[ -x "$sdk_adb" ]] || { echo 'The exact Android SDK ADB executable is missing' >&2; exit 127; }
export PATH="$sdk_root/platform-tools:$PATH"
[[ "$api" == 34 || "$api" == 35 ]]
mkdir -p "$evidence"

case "${1:-}" in
  stream)
    printf '%s\n' "$BASHPID" > "$evidence/boot-logcat-collector-started.pid"
    "$sdk_adb" wait-for-device
    printf '%s\n' "$BASHPID" > "$evidence/boot-logcat-device-connected.pid"
    exec "$sdk_adb" logcat -b all -v threadtime
    ;;
  telemetry)
    printf '%s\n' "$BASHPID" > "$evidence/resource-collector-started.pid"
    "$sdk_adb" wait-for-device
    printf '%s\n' "$BASHPID" > "$evidence/resource-device-connected.pid"
    while "$sdk_adb" get-state >/dev/null 2>&1; do
      date -u +'%Y-%m-%dT%H:%M:%SZ'
      cat /proc/loadavg
      awk '/MemTotal:|MemAvailable:|SwapTotal:|SwapFree:/' /proc/meminfo
      timeout 10s "$sdk_adb" shell cat /proc/meminfo /proc/pressure/memory /proc/pressure/cpu || true
      sleep 5
    done
    exit 0
    ;;
esac

check_collectors() {
  local phase="$1" role pid process_state
  [[ "$phase" == waiting || "$phase" == connected ]] || return 1
  for role in boot-logcat resource; do
    [[ -s "$evidence/$role-collector.pid" && -s "$evidence/$role-collector-started.pid" ]] || { echo "COLLECTOR_RECEIPT_MISSING:$role" >&2; return 1; }
    read -r pid < "$evidence/$role-collector.pid" || return 1
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
    [[ "$(cat "$evidence/$role-collector-started.pid")" == "$pid" ]] || { echo "COLLECTOR_STARTUP_PID_MISMATCH:$role" >&2; return 1; }
    kill -0 "$pid" 2>/dev/null || { echo "COLLECTOR_PROCESS_NOT_RUNNING:$role" >&2; return 1; }
    process_state="$(ps -p "$pid" -o stat=)" || return 1
    [[ "$process_state" =~ [^[:space:]] && ! "$process_state" =~ ^[[:space:]]*Z ]] || { echo "COLLECTOR_PROCESS_NOT_RUNNING:$role" >&2; return 1; }
    if [[ "$phase" == connected ]]; then
      [[ "$(cat "$evidence/$role-device-connected.pid")" == "$pid" ]] || { echo "COLLECTOR_DEVICE_NOT_CONNECTED:$role" >&2; return 1; }
    fi
  done
  if [[ "$phase" == connected ]]; then
    [[ -s "$evidence/full-boot-logcat.txt" ]] || { echo 'FULL_BOOT_LOG_STREAM_EMPTY' >&2; return 1; }
  fi
}

assert_source() {
  PYTHONPATH="$controller_dir" python3 - <<'PY'
import os
from pathlib import Path
from android_startup_focus_controller import assert_frozen_checkout
assert_frozen_checkout(Path(os.environ['BIL_FROZEN_APP_ROOT']))
PY
  git -C "$app_root" diff --exit-code -- android lib pubspec.yaml pubspec.lock
}

capture_state() {
  local prefix="$1"
  free -m > "$evidence/$prefix-host-memory.txt" 2>&1 || true
  cat /proc/loadavg > "$evidence/$prefix-host-load.txt" 2>&1 || true
  timeout 15s "$sdk_adb" shell cat /proc/meminfo > "$evidence/$prefix-guest-memory.txt" 2>&1 || true
  timeout 15s "$sdk_adb" shell dumpsys cpuinfo > "$evidence/$prefix-guest-cpu.txt" 2>&1 || true
  timeout 15s "$sdk_adb" shell dumpsys meminfo > "$evidence/$prefix-guest-meminfo.txt" 2>&1 || true
  timeout 15s "$sdk_adb" shell dumpsys window > "$evidence/$prefix-full-window.txt" 2>&1 || true
  timeout 15s "$sdk_adb" shell dumpsys activity lastanr > "$evidence/$prefix-last-anr.txt" 2>&1 || true
  timeout 15s "$sdk_adb" logcat -b crash -d > "$evidence/$prefix-crash-buffer.txt" 2>&1 || true
}

if [[ "${1:-}" == prelaunch ]]; then
  assert_source
  free -m > "$evidence/before-boot-host-memory.txt"
  lscpu > "$evidence/before-boot-host-cpu.txt"
  cat /proc/loadavg > "$evidence/before-boot-host-load.txt"
  ps -eo pid,comm,rss,pcpu --sort=-rss > "$evidence/before-boot-host-processes.txt"
  python3 - <<'PY'
from pathlib import Path
import os
memory = dict(line.split(':',1) for line in Path('/proc/meminfo').read_text().splitlines())
available_kib = int(memory['MemAvailable'].split()[0])
if available_kib < 6 * 1024 * 1024:
    raise SystemExit('Host memory is insufficient for the controlled4096MiB guest plus host margin')
if (os.cpu_count() or 0) < 2:
    raise SystemExit('The original2-core emulator cannot be supported by this host')
PY
  "$sdk_adb" version > "$evidence/adb-version.txt" 2>&1
  "$sdk_root/emulator/emulator" -no-window -version > "$evidence/emulator-version.txt" 2>&1
  grep -F '37.2.12.0' "$evidence/emulator-version.txt"
  grep -F '16428233' "$evidence/emulator-version.txt"
  cp "$ANDROID_AVD_HOME/test.avd/config.ini" "$evidence/avd-config.ini"
  "$sdk_adb" kill-server || true
  "$sdk_adb" start-server
  nohup bash "$0" stream > "$evidence/full-boot-logcat.txt" 2> "$evidence/full-boot-logcat.stderr.txt" < /dev/null &
  printf '%s\n' "$!" > "$evidence/boot-logcat-collector.pid"
  nohup bash "$0" telemetry > "$evidence/boot-resource-telemetry.txt" 2> "$evidence/boot-resource-telemetry.stderr.txt" < /dev/null &
  printf '%s\n' "$!" > "$evidence/resource-collector.pid"
  # A bounded startup handshake, not another emulator boot or test attempt.
  for ((poll = 0; poll < 30; poll++)); do
    if [[ -s "$evidence/boot-logcat-collector-started.pid" && -s "$evidence/resource-collector-started.pid" ]]; then
      break
    fi
    sleep 0.1
  done
  check_collectors waiting
  printf '%s\n' 'COLLECTORS_STARTED_WAITING_FOR_FIRST_DEVICE' > "$evidence/prelaunch-collector-status.txt"
  exit 0
fi

[[ "${1:-}" == run ]]
assert_source
finish() {
  local code=$?
  trap - EXIT
  set +e
  capture_state after-smoke
  timeout 15s "$sdk_adb" logcat -b all -d > "$evidence/final-full-logcat.txt" 2>&1
  if (( code != 0 )); then
    timeout 180s "$sdk_adb" bugreport "$evidence/failure-bugreport.zip" > "$evidence/failure-bugreport-command.txt" 2>&1
  fi
  printf 'controller_exit_code=%s\nsource_sha=%s\n' "$code" "$frozen_source" > "$evidence/controller-result.txt"
  exit "$code"
}
trap finish EXIT
capture_state before-smoke
check_collectors connected
"$sdk_adb" shell getprop > "$evidence/guest-properties.txt"
readonly vbmeta="$("$sdk_adb" shell getprop ro.boot.vbmeta.digest | tr -d '\r')"
if [[ "$api" == 34 ]]; then
  [[ "$vbmeta" == 451e57ed688ff746d2c636d52169ade253e2bc5bb30a5c3ff23679ca15d3bcd3 ]]
else
  [[ "$vbmeta" == b3271ba499104f4631ae3723913d5c12574e01715fce5b82d60beed097ead264 ]]
fi
python3 - "$evidence/before-smoke-guest-memory.txt" <<'PY'
from pathlib import Path
import sys
memory = dict(line.split(':',1) for line in Path(sys.argv[1]).read_text().splitlines())
if int(memory['MemTotal'].split()[0]) < 3_500_000:
    raise SystemExit('The guest did not receive the controlled4096MiB memory configuration')
PY
export BIL_CONTROLLER_SMOKE="$RUNNER_TEMP/bil-original-smoke-api-$api.sh"
export BIL_CONTROLLER_DIR="$controller_dir"
python3 - <<'PY'
import hashlib,json,os,shlex
from pathlib import Path
root = Path(os.environ['BIL_FROZEN_APP_ROOT'])
original = root / 'tool/release/run_android_emulator_smoke.sh'
body = original.read_text()
needle = 'python3 tool/release/verify_android_startup_frame.py'
if body.count(needle) != 3:
    raise SystemExit('The frozen smoke gate call graph changed')
helper = Path(os.environ['BIL_CONTROLLER_DIR']) / 'android_startup_focus_controller.py'
controlled = body.replace(needle, 'python3 ' + shlex.quote(str(helper)))
target = Path(os.environ['BIL_CONTROLLER_SMOKE'])
target.write_text(controlled)
evidence = root / 'artifacts/release/android_emulator_smoke' / ('api-' + os.environ['BIL_ANDROID_EMULATOR_API'])
receipt = {'app_source': '5775d082a1b4c7a29e4ed4d6e01693b31923dc31',
           'app_source_tree': '7ea15defb433ad134ee5066f538d8e790c45f809',
           'controller_source': os.environ.get('BIL_CONTROLLER_SOURCE'),
           'frozen_smoke_sha256': hashlib.sha256(original.read_bytes()).hexdigest(),
           'controlled_smoke_sha256': hashlib.sha256(controlled.encode()).hexdigest(),
           'classification_only_call_replacements': 3,
           'frozen_app_files_modified': False, 'guest_ram_mib': 4096,
           'guest_cores': 2, 'emulator_build': '16428233', 'target': 'google_apis',
           'gpu': 'swiftshader_indirect', 'source_is_signed_release': False}
(evidence / 'controller-provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
PY
bash -n "$BIL_CONTROLLER_SMOKE"
cd "$app_root"
GITHUB_SHA="$frozen_source" bash "$BIL_CONTROLLER_SMOKE"
assert_source
PYTHONPATH="$controller_dir" python3 - "$evidence/full-boot-logcat.txt" <<'PY'
from pathlib import Path
import sys
from android_startup_focus_controller import fresh_boot_anr_lines
capture = Path(sys.argv[1])
if not capture.is_file() or not capture.stat().st_size:
    raise SystemExit('Full clean-boot log stream is missing; result is blocked')
events = fresh_boot_anr_lines(capture.read_text(errors='replace'))
if events:
    print('\n'.join(events), file=sys.stderr)
    raise SystemExit('Fresh clean-boot ANR recorded; no interactive startup pass is accepted')
PY
check_collectors connected
