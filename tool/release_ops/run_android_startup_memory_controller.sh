#!/usr/bin/env bash
set -euo pipefail

readonly frozen_source='5da21a5660b26e59e9ead7b0927d4ed7cf2c3996'
readonly controller_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly app_root="${BIL_FROZEN_APP_ROOT:?BIL_FROZEN_APP_ROOT is required}"
readonly api="${BIL_ANDROID_EMULATOR_API:?API is required}"
readonly evidence="$app_root/artifacts/release/android_emulator_smoke/api-$api"
[[ "$api" == 34 || "$api" == 35 ]]
mkdir -p "$evidence"

case "${1:-}" in
  stream)
    adb wait-for-device
    exec adb logcat -b all -v threadtime
    ;;
  telemetry)
    adb wait-for-device
    while adb get-state >/dev/null 2>&1; do
      date -u +'%Y-%m-%dT%H:%M:%SZ'
      cat /proc/loadavg
      awk '/MemTotal:|MemAvailable:|SwapTotal:|SwapFree:/' /proc/meminfo
      timeout 10s adb shell cat /proc/meminfo /proc/pressure/memory /proc/pressure/cpu || true
      sleep 5
    done
    exit 0
    ;;
esac

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
  timeout 15s adb shell cat /proc/meminfo > "$evidence/$prefix-guest-memory.txt" 2>&1 || true
  timeout 15s adb shell dumpsys cpuinfo > "$evidence/$prefix-guest-cpu.txt" 2>&1 || true
  timeout 15s adb shell dumpsys meminfo > "$evidence/$prefix-guest-meminfo.txt" 2>&1 || true
  timeout 15s adb shell dumpsys window > "$evidence/$prefix-full-window.txt" 2>&1 || true
  timeout 15s adb shell dumpsys activity lastanr > "$evidence/$prefix-last-anr.txt" 2>&1 || true
  timeout 15s adb logcat -b crash -d > "$evidence/$prefix-crash-buffer.txt" 2>&1 || true
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
  "$ANDROID_HOME/emulator/emulator" -version > "$evidence/emulator-version.txt" 2>&1
  grep -F '37.2.12.0' "$evidence/emulator-version.txt"
  grep -F '16428233' "$evidence/emulator-version.txt"
  cp "$ANDROID_AVD_HOME/test.avd/config.ini" "$evidence/avd-config.ini"
  adb kill-server || true
  adb start-server
  nohup bash "$0" stream > "$evidence/full-boot-logcat.txt" 2> "$evidence/full-boot-logcat.stderr.txt" < /dev/null &
  printf '%s\n' "$!" > "$evidence/boot-logcat-collector.pid"
  nohup bash "$0" telemetry > "$evidence/boot-resource-telemetry.txt" 2> "$evidence/boot-resource-telemetry.stderr.txt" < /dev/null &
  printf '%s\n' "$!" > "$evidence/resource-collector.pid"
  exit 0
fi

[[ "${1:-}" == run ]]
assert_source
finish() {
  local code=$?
  trap - EXIT
  set +e
  capture_state after-smoke
  timeout 15s adb logcat -b all -d > "$evidence/final-full-logcat.txt" 2>&1
  if (( code != 0 )); then
    timeout 180s adb bugreport "$evidence/failure-bugreport.zip" > "$evidence/failure-bugreport-command.txt" 2>&1
  fi
  printf 'controller_exit_code=%s\nsource_sha=%s\n' "$code" "$frozen_source" > "$evidence/controller-result.txt"
  exit "$code"
}
trap finish EXIT
capture_state before-smoke
adb shell getprop > "$evidence/guest-properties.txt"
readonly vbmeta="$(adb shell getprop ro.boot.vbmeta.digest | tr -d '\r')"
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
receipt = {'app_source': '5da21a5660b26e59e9ead7b0927d4ed7cf2c3996',
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
