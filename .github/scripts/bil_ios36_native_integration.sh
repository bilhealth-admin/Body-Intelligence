#!/usr/bin/env bash
set -euo pipefail

# The device-specific Flutter build-settings query failed on the previous
# Intel runner. Build each real test entrypoint for the generic simulator,
# then drive that exact bundle on both devices without another Xcode build.
OUT=artifacts/qa/text18/ios36-simulators
mkdir -p "$OUT"
SOURCE_HEAD="$(git rev-parse HEAD)"
SOURCE_TREE="$(git rev-parse 'HEAD^{tree}')"
export BIL_QA_SOURCE_HEAD="$SOURCE_HEAD" BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE"
xcodebuild -version > "$OUT/xcode-version.txt"
xcrun simctl list runtimes available -j > "$OUT/runtimes.json"
xcrun simctl list devicetypes -j > "$OUT/device-types.json"
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
IPHONE_UDID="$(xcrun simctl create "BIL-iPhone36-${GITHUB_RUN_ID}" "$IPHONE_TYPE" "$RUNTIME")"
IPAD_UDID="$(xcrun simctl create "BIL-iPad36-${GITHUB_RUN_ID}" "$IPAD_TYPE" "$RUNTIME")"
cleanup() {
  for DEVICE in "$IPHONE_UDID" "$IPAD_UDID"; do
    xcrun simctl shutdown "$DEVICE" || true
    xcrun simctl delete "$DEVICE" || true
  done
}
trap cleanup EXIT

# Reuse Flutter's pinned integration driver; pass this project's package map.
CRYPTO_DRIVER="$OUT/crypto-driver.dart"
cp "$FLUTTER_ROOT/packages/integration_test/example/test_driver/integration_test.dart" "$CRYPTO_DRIVER"
DEFINES=(
  --dart-define=BIL_ENVIRONMENT=testing
  --dart-define=BIL_USE_SUPABASE=false
  --dart-define=BIL_PAYMENTS_ENABLED=false
  --dart-define=BIL_ADS_ENABLED=false
  --dart-define=BIL_QA_IOS_SIMULATOR=true
  --dart-define=BIL_QA_DEVICE_NAME=github-ios36-native-simulator
  --dart-define=BIL_QA_SOURCE_HEAD="$SOURCE_HEAD"
  --dart-define=BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE"
)
case "${BIL_NATIVE_TARGET:-all}" in
  all) KINDS=(system-crypto native-settings feature-splashes) ;;
  system-crypto) KINDS=(system-crypto) ;;
  *) echo 'Unsupported native entrypoint scope' >&2; exit 2 ;;
esac
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
  flutter --verbose build ios --simulator --debug --no-codesign --no-pub \
    --build-number 36 --target "$TARGET" "${DEFINES[@]}" \
    2>&1 | tee "$OUT/$KIND-generic-build.log"
  APP="$GITHUB_WORKSPACE/build/ios/iphonesimulator/Runner.app"
  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")" = '36'
  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")" = 'com.bilhealth.bodyintelligencelog'
  shasum -a 256 "$APP/Runner" > "$OUT/$KIND-binary.sha256"
  for PAIR in "iphone:$IPHONE_UDID" "ipad:$IPAD_UDID"; do
    DEVICE="${PAIR#*:}"
    LABEL="${PAIR%%:*}"
    xcrun simctl boot "$DEVICE"
    xcrun simctl bootstatus "$DEVICE" -b
    xcrun simctl ui "$DEVICE" appearance light
    BIL_NATIVE_SETTINGS_OUTPUT="$GITHUB_WORKSPACE/$OUT/$LABEL-native-settings" \
    BIL_FEATURE_NATIVE_OUTPUT="$GITHUB_WORKSPACE/$OUT/$LABEL-feature-splashes" \
      flutter drive --no-pub --device-id "$DEVICE" --timeout 1200 \
        --use-application-binary "$APP" --target "$TARGET" --driver "$DRIVER" \
        --test-arguments="--packages=$GITHUB_WORKSPACE/.dart_tool/package_config.json" \
        2>&1 | tee "$OUT/$LABEL-$KIND.log"
    xcrun simctl shutdown "$DEVICE"
  done
done
