#!/usr/bin/env bash
set -euo pipefail

# The device-specific Flutter build-settings query failed on the previous
# Intel runner. Build each real test entrypoint for the generic simulator,
# then drive that exact bundle on both devices without another Xcode build.
OUT=artifacts/qa/text18/ios37-simulators
mkdir -p "$OUT"
BOUND=.github/scripts/bil_native_bounded_command.py
SOURCE_HEAD="$(git rev-parse HEAD)"
SOURCE_TREE="$(git rev-parse 'HEAD^{tree}')"
export BIL_QA_SOURCE_HEAD="$SOURCE_HEAD" BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE"

stage() {
  local label="$1" seconds="$2" log="$3"
  shift 3
  python3 "$BOUND" --label "$label" --log "$log" \
    --receipt "$OUT/$label-result.json" --timeout-seconds "$seconds" -- "$@"
}
collect_app_files() {
  local label="$1" device="$2" container
  if stage "$label-app-container" 30 "$OUT/$label-app-container.log" \
      xcrun simctl get_app_container "$device" com.bilhealth.bodyintelligencelog data; then
    container="$(tr -d '\r\n' < "$OUT/$label-app-container.log")"
    # Only synthetic QA screenshots/metadata; do not archive the app database,
    # account preferences or the Simulator's Keychain / Health data.
    for directory in feature-splashes-native platform-polish; do
      if [ -d "$container/Documents/$directory" ]; then
        stage "$label-copy-$directory" 60 "$OUT/$label-copy-$directory.log" \
          cp -R "$container/Documents/$directory" "$OUT/$label-device-$directory"
      fi
    done
  fi
}
IPHONE_UDID=''
IPAD_UDID=''
ACTIVE_DEVICE=''
BOOTED_DEVICE=''
cleanup() {
  local original_status=$? label device
  trap - EXIT
  set +e
  for pair in "iphone:$IPHONE_UDID" "ipad:$IPAD_UDID"; do
    device="${pair#*:}"
    label="${pair%%:*}"
    [ -n "$device" ] || continue
    if [ "$original_status" -ne 0 ] && [ "$device" = "$BOOTED_DEVICE" ]; then
      if [ "$device" = "$ACTIVE_DEVICE" ]; then
        # These are fresh synthetic QA simulators. Capture launch/signature
        # diagnostics before deletion so a SpringBoard denial is actionable.
        stage "$label-launch-diagnostics" 45 "$OUT/$label-launch-diagnostics.log" \
          xcrun simctl spawn "$device" log show --last 3m --style compact \
          --predicate 'process == "Runner" OR (process == "SpringBoard" AND (eventMessage CONTAINS "com.bilhealth.bodyintelligencelog"))'
        stage "$label-bundle-signature-verification" 30 "$OUT/$label-bundle-signature-verification.log" \
          codesign --verify --deep --strict --verbose=4 "$GITHUB_WORKSPACE/build/ios/iphonesimulator/Runner.app"
      fi
      stage "$label-failure-screen" 30 "$OUT/$label-failure-screen.log" \
        xcrun simctl io "$device" screenshot "$OUT/$label-failure.png"
      collect_app_files "$label" "$device"
    fi
    if [ "$device" = "$BOOTED_DEVICE" ]; then
      stage "$label-shutdown" 30 "$OUT/$label-shutdown.log" xcrun simctl shutdown "$device"
    fi
    stage "$label-delete" 30 "$OUT/$label-delete.log" xcrun simctl delete "$device"
  done
  exit "$original_status"
}
trap cleanup EXIT

stage xcode-version 120 "$OUT/xcode-version.txt" xcodebuild -version
stage list-runtimes 120 "$OUT/runtimes.json" xcrun simctl list runtimes available -j
stage list-device-types 120 "$OUT/device-types.json" xcrun simctl list devicetypes -j
read -r RUNTIME IPHONE_TYPE IPAD_TYPE < <(python3 - "$OUT" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
runtimes = json.loads((root / 'runtimes.json').read_text())['runtimes']
ios = [item for item in runtimes if item.get('isAvailable') and
       item['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
if not ios:
    raise SystemExit('No available iOS Simulator runtime')
runtime = max(ios, key=lambda item: tuple(map(int, re.findall(r'\d+', item['version']))))
types = json.loads((root / 'device-types.json').read_text())['devicetypes']
def select(prefix, preferred):
    items = [item for item in types if item['name'].startswith(prefix)]
    if not items:
        raise SystemExit('Both iPhone and iPad device types are required')
    return next((item for name in preferred for item in items if item['name'] == name), items[-1])
iphone = select('iPhone', ['iPhone 16 Pro', 'iPhone 16', 'iPhone 15 Pro'])
ipad = select('iPad', ['iPad Pro 13-inch (M4)', 'iPad Pro (13-inch) (M4)',
                       'iPad Pro (12.9-inch) (6th generation)'])
print(runtime['identifier'], iphone['identifier'], ipad['identifier'])
PY
)
stage create-iphone 120 "$OUT/create-iphone.log" xcrun simctl create \
  "BIL-iPhone37-${GITHUB_RUN_ID}" "$IPHONE_TYPE" "$RUNTIME"
IPHONE_UDID="$(tr -d '\r\n' < "$OUT/create-iphone.log")"
[[ "$IPHONE_UDID" =~ ^[0-9A-Fa-f-]{36}$ ]]
stage create-ipad 120 "$OUT/create-ipad.log" xcrun simctl create \
  "BIL-iPad37-${GITHUB_RUN_ID}" "$IPAD_TYPE" "$RUNTIME"
IPAD_UDID="$(tr -d '\r\n' < "$OUT/create-ipad.log")"
[[ "$IPAD_UDID" =~ ^[0-9A-Fa-f-]{36}$ ]]

# Reuse Flutter's pinned integration driver; pass this project's package map.
CRYPTO_DRIVER="$OUT/crypto-driver.dart"
cp "$FLUTTER_ROOT/packages/integration_test/example/test_driver/integration_test.dart" "$CRYPTO_DRIVER"
DEFINES=(
  --dart-define=BIL_ENVIRONMENT=testing
  --dart-define=BIL_USE_SUPABASE=false
  --dart-define=BIL_PAYMENTS_ENABLED=false
  --dart-define=BIL_ADS_ENABLED=false
  --dart-define=BIL_QA_IOS_SIMULATOR=true
  --dart-define=BIL_QA_DEVICE_NAME=github-ios37-native-simulator
  --dart-define=BIL_QA_SOURCE_HEAD="$SOURCE_HEAD"
  --dart-define=BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE"
)
case "${BIL_NATIVE_TARGET:-all}" in
  all) KINDS=(system-crypto native-settings feature-splashes) ;;
  system-crypto) KINDS=(system-crypto) ;;
  feature-splashes) KINDS=(feature-splashes) ;;
  *) echo 'Unsupported native entrypoint scope' >&2; exit 2 ;;
esac
# Warm the Swift package graph in the fresh native job before Flutter's fixed
# settings-query deadline. This is preparation, never native-test evidence.
python3 .github/scripts/bil_ios_native_preflight.py \
  --workspace "$GITHUB_WORKSPACE" --output "$GITHUB_WORKSPACE/$OUT"
# Exercise the existing native XCTest target, separately from Flutter drivers.
# Its in-memory App Attest key-store tests are not hardware-attestation proof.
ACTIVE_DEVICE="$IPHONE_UDID"
stage runner-tests-boot 120 "$OUT/runner-tests-boot.log" xcrun simctl boot "$IPHONE_UDID"
BOOTED_DEVICE="$IPHONE_UDID"
stage runner-tests-bootstatus 180 "$OUT/runner-tests-bootstatus.log" \
  xcrun simctl bootstatus "$IPHONE_UDID" -b
python3 .github/scripts/bil_ios_runner_tests.py \
  --workspace "$GITHUB_WORKSPACE" --output "$GITHUB_WORKSPACE/$OUT/runner-tests" \
  --device "$IPHONE_UDID" "${DEFINES[@]}"
stage runner-tests-shutdown 30 "$OUT/runner-tests-shutdown.log" xcrun simctl shutdown "$IPHONE_UDID"
ACTIVE_DEVICE=''
BOOTED_DEVICE=''
for KIND in "${KINDS[@]}"; do
  case "$KIND" in
    system-crypto)
      TARGET=integration_test/system_crypto_bridge_integration_test.dart
      DRIVER="$CRYPTO_DRIVER" ;;
    native-settings)
      TARGET=integration_test/native_settings_polish_test.dart
      DRIVER=test_driver/native_settings_capture_driver.dart ;;
    feature-splashes)
      TARGET=integration_test/native_feature_splashes_test.dart
      DRIVER=test_driver/native_feature_splashes_driver.dart ;;
  esac
  stage "$KIND-generic-build" 1800 "$OUT/$KIND-generic-build.log" \
    flutter --verbose build ios --simulator --debug --no-codesign --no-pub \
    --build-number 37 --target "$TARGET" "${DEFINES[@]}"
  APP="$GITHUB_WORKSPACE/build/ios/iphonesimulator/Runner.app"
  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")" = '37'
  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")" = 'com.bilhealth.bodyintelligencelog'
  # Local pseudo-identity '-' only: no certificate, provisioning or store signing.
  # The real Keychain integration test below still decides native correctness.
  stage "$KIND-simulator-adhoc-sign" 240 "$OUT/$KIND-simulator-adhoc-sign.log" \
    python3 .github/scripts/bil_ios_simulator_adhoc_sign.py \
    --qa-simulator-only --workspace "$GITHUB_WORKSPACE" --app "$APP" \
    --output "$GITHUB_WORKSPACE/$OUT/$KIND-simulator-signature.json" \
    --target "$TARGET" --source-head "$SOURCE_HEAD" --source-tree "$SOURCE_TREE"
  shasum -a 256 "$APP/Runner" > "$OUT/$KIND-binary.sha256"
  # Export only compiled SDK declarations/versions; no app data or secrets.
  # This reuses the existing generic QA bundle, not another build or signing.
  python3 - "$APP" "$OUT/$KIND-privacy-inventory.json" "$SOURCE_HEAD" <<'BIL_PRIVACY_PY'
import hashlib
import json
from pathlib import Path
import plistlib
import re
import sys

bundle, output, source_head = Path(sys.argv[1]).resolve(), Path(sys.argv[2]), sys.argv[3]
if bundle.suffix != '.app' or not bundle.is_dir():
    raise ValueError('Expected the existing QA simulator app bundle')
def inside(path):
    path.resolve().relative_to(bundle)
    return path
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
manifests = []
fields = ('NSPrivacyTracking', 'NSPrivacyTrackingDomains',
          'NSPrivacyCollectedDataTypes', 'NSPrivacyAccessedAPITypes')
for path in sorted(bundle.rglob('*.xcprivacy')):
    data = plistlib.loads(inside(path).read_bytes())
    if not isinstance(data, dict):
        raise ValueError('Privacy manifest must be a dictionary')
    if 'NSPrivacyTracking' in data and not isinstance(data['NSPrivacyTracking'], bool):
        raise ValueError('Privacy tracking must be a Boolean when declared')
    manifests.append({'path': path.relative_to(bundle).as_posix(),
                      'sha256': digest(path), 'declarations': {key: data.get(key) for key in fields}})
frameworks = []
for path in sorted(bundle.glob('Frameworks/*.framework/Info.plist')):
    data = plistlib.loads(inside(path).read_bytes())
    frameworks.append({'path': path.relative_to(bundle).as_posix(), 'sha256': digest(path),
                       'identifier': data.get('CFBundleIdentifier'), 'version': data.get('CFBundleShortVersionString'),
                       'build': data.get('CFBundleVersion')})
pod = Path('ios/Podfile.lock')
pods, in_pods = [], False
if pod.is_file():
    for line in pod.read_text().splitlines():
        if line == 'PODS:': in_pods = True
        elif line and not line.startswith(' '): in_pods = False
        if in_pods and line.startswith('  - '): pods.append(line[4:].split(':', 1)[0])
workspace = Path.cwd().resolve()
lock_paths = set(workspace.glob('ios/*.xcworkspace/xcshareddata/swiftpm/Package.resolved'))
lock_paths.update(workspace.glob('ios/*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'))
source_packages = workspace / 'build/ios/SourcePackages'
if source_packages.is_dir():
    lock_paths.update(source_packages.rglob('Package.resolved'))
swift_packages = []
def public_field(value, pattern):
    return value if isinstance(value, str) and re.fullmatch(pattern, value) else None
for lock in sorted(lock_paths):
    relative = lock.resolve().relative_to(workspace).as_posix()
    document = json.loads(lock.read_bytes())
    pins = document.get('pins', document.get('object', {}).get('pins'))
    rows = []
    if pins is not None and not isinstance(pins, list):
        raise ValueError('SwiftPM pins must be an array when available')
    for pin in pins or []:
        if not isinstance(pin, dict) or not isinstance(pin.get('state', {}), dict):
            raise ValueError('Malformed SwiftPM pin')
        state = pin.get('state', {})
        rows.append({'identity': public_field(pin.get('identity', pin.get('package')), r'[A-Za-z0-9_.-]{1,160}'),
                     'version': public_field(state.get('version'), r'[A-Za-z0-9.+_-]{1,128}'),
                     'revision': public_field(state.get('revision'), r'[0-9A-Fa-f]{7,64}')})
    swift_packages.append({'path': relative, 'sha256': digest(lock), 'pins': rows,
        'status': 'READ' if pins is not None else 'UNKNOWN_SCHEMA',
        'scope': 'checkout lock; not final app resolution' if '/checkouts/' in relative else 'workspace or SourcePackages resolution; not compiled-use proof'})
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps({'scope': 'Compiled simulator declarations only; not actual data use, tracking, SDK signatures or signed-release certification',
    'source_head': source_head, 'privacy_manifests': manifests, 'frameworks': frameworks,
    'pod_lock_sha256': digest(pod) if pod.is_file() else None, 'resolved_pods': pods,
    'swiftpm_lock_status': 'FOUND' if swift_packages else 'UNKNOWN_NO_RESOLVED_LOCK_FOUND',
    'swiftpm_resolved_locks': swift_packages,
    'signed_release': False, 'sdk_signatures_verified': False, 'network_collection_verified': False}, indent=2) + '\n')
BIL_PRIVACY_PY
  for PAIR in "iphone:$IPHONE_UDID" "ipad:$IPAD_UDID"; do
    DEVICE="${PAIR#*:}"
    LABEL="${PAIR%%:*}"
    ACTIVE_DEVICE="$DEVICE"
    stage "$LABEL-$KIND-boot" 120 "$OUT/$LABEL-$KIND-boot.log" xcrun simctl boot "$DEVICE"
    BOOTED_DEVICE="$DEVICE"
    stage "$LABEL-$KIND-bootstatus" 180 "$OUT/$LABEL-$KIND-bootstatus.log" \
      xcrun simctl bootstatus "$DEVICE" -b
    stage "$LABEL-$KIND-appearance" 120 "$OUT/$LABEL-$KIND-appearance.log" \
      xcrun simctl ui "$DEVICE" appearance light
    BIL_NATIVE_CAPTURE_DEVICE_ID="$DEVICE" \
    BIL_NATIVE_SETTINGS_OUTPUT="$GITHUB_WORKSPACE/$OUT/$LABEL-native-settings" \
    BIL_FEATURE_NATIVE_OUTPUT="$GITHUB_WORKSPACE/$OUT/$LABEL-feature-splashes" \
      python3 "$BOUND" --label "$LABEL-$KIND-drive" \
        --log "$OUT/$LABEL-$KIND.log" --receipt "$OUT/$LABEL-$KIND-drive-result.json" \
        --timeout-seconds 1800 --running-timeout-seconds 1200 \
        --summary-grace-seconds 60 -- \
        flutter drive --no-pub --device-id "$DEVICE" --timeout 1200 \
        --use-application-binary "$APP" --target "$TARGET" --driver "$DRIVER" \
        --test-arguments="--packages=$GITHUB_WORKSPACE/.dart_tool/package_config.json"
    collect_app_files "$LABEL-$KIND" "$DEVICE"
    stage "$LABEL-$KIND-shutdown" 30 "$OUT/$LABEL-$KIND-shutdown.log" \
      xcrun simctl shutdown "$DEVICE"
    ACTIVE_DEVICE=''
    BOOTED_DEVICE=''
  done
done
