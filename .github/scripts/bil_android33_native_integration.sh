#!/usr/bin/env bash
set -euo pipefail

OUT=artifacts/qa/text18/android-api33
mkdir -p "$OUT"
BOUND=.github/scripts/bil_native_bounded_command.py
DEVICE="${BIL_NATIVE_CAPTURE_DEVICE_ID:-${ANDROID_SERIAL:-emulator-5554}}"
[[ "$DEVICE" =~ ^emulator-[0-9]+$ ]] || { echo 'Expected a QA emulator serial' >&2; exit 2; }
export BIL_NATIVE_CAPTURE_DEVICE_ID="$DEVICE"
SOURCE_HEAD="$(git rev-parse HEAD)"
SOURCE_TREE="$(git rev-parse 'HEAD^{tree}')"

# Native QA and the eventual release consume the same pinned SDK repairs.
python3 tool/release/prepare_android_policy_plugin_overrides.py > "$OUT/android-plugin-overlays.json"
dart run tool/release/sanitize_flutter_release_plugins.dart --platform=android --preserve-dev-native-plugins > "$OUT/android-plugin-discovery.json"

native_command() {
  local label="$1"
  shift
  # The first real native counter starts a separate test budget after build /
  # install. Terminal summaries get 60s to deliver the real driver result.
  python3 "$BOUND" --label "$label" \
    --log "$OUT/$label.log" --receipt "$OUT/$label-result.json" \
    --timeout-seconds 1800 --running-timeout-seconds 1200 \
    --summary-grace-seconds 60 -- "$@"
}
collect_command() {
  local label="$1"
  shift
  python3 "$BOUND" --label "$label" \
    --log "$OUT/$label.log" --receipt "$OUT/$label-result.json" \
    --timeout-seconds 30 -- "$@"
}
collect_before_exit() {
  local original_status=$?
  trap - EXIT
  set +e
  # The app writes these synthetic QA PNG/metadata files independently of the
  # potentially oversized integration-driver response. Never copy app databases.
  if [ "${BIL_NATIVE_TARGET:-all}" != system-crypto ]; then
    collect_command device-feature-evidence adb -s "$DEVICE" pull \
      /sdcard/Android/data/com.bilhealth.bodyintelligencelog/files/feature-splashes-native \
      "$OUT/device-feature-splashes"
  fi
  if [ "${BIL_NATIVE_TARGET:-all}" = all ]; then
    collect_command device-settings-evidence adb -s "$DEVICE" pull \
      /sdcard/Android/data/com.bilhealth.bodyintelligencelog/files/platform-polish \
      "$OUT/device-platform-polish"
  fi
  if [ "$original_status" -ne 0 ]; then
    collect_command failure-logcat adb -s "$DEVICE" logcat -d -t 1000
    collect_command failure-memory adb -s "$DEVICE" shell dumpsys meminfo \
      com.bilhealth.bodyintelligencelog
    if collect_command failure-screen-device adb -s "$DEVICE" shell screencap \
      -p /sdcard/bil-native-qa-failure.png; then
      collect_command failure-screen-copy adb -s "$DEVICE" pull \
        /sdcard/bil-native-qa-failure.png "$OUT/failure-screen.png"
    fi
  fi
  collect_command restore-connectivity adb -s "$DEVICE" shell cmd \
    connectivity airplane-mode disable
  exit "$original_status"
}
trap collect_before_exit EXIT
# The emulator action has installed its SDK binary before calling this script.
collect_command acceleration-check "${ANDROID_HOME:?}/emulator/emulator" -accel-check
case "${BIL_NATIVE_TARGET:-all}" in
  all|system-crypto|feature-splashes) ;;
  *) echo 'Unsupported native entrypoint scope' >&2; exit 2 ;;
esac

# ConnectivityService provides the shell command used by Android CTS. Sending
# AIRPLANE_MODE broadcasts directly is forbidden to shell on the API 33 image.
collect_command airplane-enable adb -s "$DEVICE" shell cmd connectivity airplane-mode enable
collect_command airplane-status adb -s "$DEVICE" shell cmd connectivity airplane-mode
test "$(tr -d '\r\n' < "$OUT/airplane-status.log")" = 'enabled'

if [ "${BIL_NATIVE_TARGET:-all}" != feature-splashes ]; then
  native_command system-crypto flutter test integration_test/system_crypto_bridge_integration_test.dart \
    --no-pub --device-id "$DEVICE" --reporter expanded \
    --dart-define=BIL_ENVIRONMENT=testing \
    --dart-define=BIL_USE_SUPABASE=false \
    --dart-define=BIL_PAYMENTS_ENABLED=false \
    --dart-define=BIL_ADS_ENABLED=false

  if [ "${BIL_NATIVE_TARGET:-all}" = system-crypto ]; then
    exit 0
  fi

  BIL_NATIVE_SETTINGS_OUTPUT="$GITHUB_WORKSPACE/$OUT/native-settings" \
    native_command native-settings flutter drive --timeout 1200 --device-id "$DEVICE" \
      --driver=test_driver/native_settings_capture_driver.dart \
      --target=integration_test/native_settings_polish_test.dart \
      --dart-define=BIL_ENVIRONMENT=testing \
      --dart-define=BIL_USE_SUPABASE=false \
      --dart-define=BIL_QA_SOURCE_HEAD="$SOURCE_HEAD" \
      --dart-define=BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE"
fi

BIL_FEATURE_NATIVE_OUTPUT="$GITHUB_WORKSPACE/$OUT/feature-splashes" \
  native_command native-feature-splashes flutter drive --timeout 1200 --device-id "$DEVICE" \
    --driver=test_driver/native_feature_splashes_driver.dart \
    --target=integration_test/native_feature_splashes_test.dart \
    --dart-define=BIL_ENVIRONMENT=testing \
    --dart-define=BIL_USE_SUPABASE=false \
    --dart-define=BIL_QA_ANDROID_EMULATOR=true \
    --dart-define=BIL_QA_DEVICE_NAME=github-api33-pixel6 \
    --dart-define=BIL_QA_SOURCE_HEAD="$SOURCE_HEAD" \
    --dart-define=BIL_QA_SOURCE_FINGERPRINT="$SOURCE_TREE"
