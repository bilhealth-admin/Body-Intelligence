#!/usr/bin/env bash
set -euo pipefail

DEVICE="${ANDROID_SERIAL:-emulator-5554}"
[[ "$DEVICE" =~ ^emulator-[0-9]+$ ]] || { echo 'Disposable emulator required' >&2; exit 2; }
QEMU="$(adb -s "$DEVICE" shell getprop ro.kernel.qemu | tr -d '\r')"
if [[ "$QEMU" != 1 ]]; then
  QEMU="$(adb -s "$DEVICE" shell getprop ro.boot.qemu | tr -d '\r')"
fi
test "$QEMU" = 1
API="$(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')"
test "$API" -ge 33
APP=com.bilhealth.bodyintelligencelog
TARGET=integration_test/android_notification_permission_integration_test.dart
OUT="$PWD/artifacts/qa/notification-sdk-api$API"
mkdir -p "$OUT"
HEAD="$(git rev-parse HEAD)"
TREE="$(git rev-parse 'HEAD^{tree}')"
DRIVER="$PWD/build/qa/notification-sdk-driver.dart"
mkdir -p "$(dirname "$DRIVER")"
cat > "$DRIVER" <<'DART'
import 'package:integration_test/integration_test_driver.dart';
Future<void> main() => integrationDriver();
DART

python3 tool/release/prepare_android_policy_plugin_overrides.py > "$OUT/plugin-overrides.json"
dart run tool/release/sanitize_flutter_release_plugins.dart --platform=android --preserve-dev-native-plugins > "$OUT/plugin-discovery.json"
for permission in denied granted; do
  flutter build apk --debug --no-pub --target "$TARGET" \
    --dart-define=BIL_ENVIRONMENT=testing \
    --dart-define=BIL_QA_ANDROID_EMULATOR=true \
    --dart-define=BIL_USE_SUPABASE=false \
    --dart-define=BIL_PAYMENTS_ENABLED=false \
    --dart-define=BIL_PUSH_ENABLED=false \
    --dart-define=BIL_ADS_ENABLED=false \
    --dart-define=BIL_QA_NOTIFICATION_PERMISSION_EXPECTED="$permission" \
    --dart-define=BIL_QA_SOURCE_HEAD="$HEAD" \
    --dart-define=BIL_QA_SOURCE_FINGERPRINT="$TREE" \
    > "$OUT/build-$permission.log" 2>&1
  APK="$PWD/build/app/outputs/flutter-apk/app-debug.apk"
  test -s "$APK"
  adb -s "$DEVICE" install -r "$APK"
  adb -s "$DEVICE" shell am force-stop "$APP"
  adb -s "$DEVICE" shell pm clear-permission-flags "$APP" android.permission.POST_NOTIFICATIONS user-set
  adb -s "$DEVICE" shell pm clear-permission-flags "$APP" android.permission.POST_NOTIFICATIONS user-fixed
  if [[ "$permission" == granted ]]; then
    adb -s "$DEVICE" shell pm grant "$APP" android.permission.POST_NOTIFICATIONS
  else
    adb -s "$DEVICE" shell pm revoke "$APP" android.permission.POST_NOTIFICATIONS
  fi
  python3 .github/scripts/bil_native_bounded_command.py \
    --label "notification-sdk-$permission-api$API" \
    --log "$OUT/test-$permission.log" \
    --receipt "$OUT/result-$permission.json" \
    --timeout-seconds 1200 --running-timeout-seconds 600 --summary-grace-seconds 60 \
    -- flutter drive --no-pub --device-id "$DEVICE" --timeout 600 \
      --target "$TARGET" --driver "$DRIVER" --use-application-binary "$APK"
  python3 - "$OUT/test-$permission.log" "$permission" "$HEAD" "$TREE" <<'PY'
import json, pathlib, sys
log, permission, head, tree = sys.argv[1:]
rows = []
for line in pathlib.Path(log).read_text(encoding='utf-8', errors='replace').splitlines():
    if 'BIL_NOTIFICATION_SDK_QA ' in line:
        rows.append(json.loads(line.split('BIL_NOTIFICATION_SDK_QA ', 1)[1]))
assert len(rows) == 2, 'Both plain and tagged native outcomes are required'
assert {row['variant'] for row in rows} == {'plain', 'tagged'}
for row in rows:
    assert row['status'] == 'PASS' and row['owned_notification_cleanup'] == 'PASS'
    assert row['expected_permission'] == permission
    assert row['source_head'] == head and row['source_fingerprint'] == tree
    assert row['dart_http_attempts'] == 0
    assert row['matching_active_count'] == (1 if permission == 'granted' else 0)
print(json.dumps({'permission': permission, 'native_cases': len(rows), 'source': head, 'status': 'PASS'}))
PY
done
git diff --exit-code
