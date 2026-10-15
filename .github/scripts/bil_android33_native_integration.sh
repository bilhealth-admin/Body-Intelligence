#!/usr/bin/env bash
set -euo pipefail

OUT=artifacts/qa/text18/android-api33
mkdir -p "$OUT"
SOURCE_HEAD="$(git rev-parse HEAD)"
SOURCE_TREE="$(git rev-parse 'HEAD^{tree}')"
# The emulator action has installed its SDK binary before calling this script.
"${ANDROID_HOME:?}/emulator/emulator" -accel-check
case "${BIL_NATIVE_TARGET:-all}" in
  all|system-crypto) ;;
  *) echo 'Unsupported native entrypoint scope' >&2; exit 2 ;;
esac

# ConnectivityService provides the shell command used by Android CTS. Sending
# AIRPLANE_MODE broadcasts directly is forbidden to shell on the API 33 image.
adb shell cmd connectivity airplane-mode enable
test "$(adb shell cmd connectivity airplane-mode | tr -d '\r')" = 'enabled'

flutter test integration_test/system_crypto_bridge_integration_test.dart \
  --no-pub --device-id emulator-5554 --reporter expanded \
  --dart-define=BIL_ENVIRONMENT=testing \
  --dart-define=BIL_USE_SUPABASE=false \
  --dart-define=BIL_PAYMENTS_ENABLED=false \
  --dart-define=BIL_ADS_ENABLED=false \
  2>&1 | tee "$OUT/system-crypto.log"

if [ "${BIL_NATIVE_TARGET:-all}" = system-crypto ]; then
  exit 0
fi

BIL_NATIVE_SETTINGS_OUTPUT="$GITHUB_WORKSPACE/$OUT/native-settings" \
  flutter drive --device-id emulator-5554 \
    --driver=test_driver/native_settings_capture_driver.dart \
    --target=integration_test/native_settings_polish_test.dart \
    --dart-define=BIL_ENVIRONMENT=testing \
    --dart-define=BIL_USE_SUPABASE=false \
    --dart-define=BIL_QA_SOURCE_HEAD="$SOURCE_HEAD" \
    --dart-define=BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE" \
    2>&1 | tee "$OUT/native-settings.log"

BIL_FEATURE_NATIVE_OUTPUT="$GITHUB_WORKSPACE/$OUT/feature-splashes" \
  flutter drive --device-id emulator-5554 \
    --driver=test_driver/native_feature_splashes_driver.dart \
    --target=integration_test/native_feature_splashes_test.dart \
    --dart-define=BIL_ENVIRONMENT=testing \
    --dart-define=BIL_USE_SUPABASE=false \
    --dart-define=BIL_QA_ANDROID_EMULATOR=true \
    --dart-define=BIL_QA_DEVICE_NAME=github-api33-pixel6 \
    --dart-define=BIL_QA_SOURCE_HEAD="$SOURCE_HEAD" \
    --dart-define=BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE" \
    2>&1 | tee "$OUT/native-feature-splashes.log"
