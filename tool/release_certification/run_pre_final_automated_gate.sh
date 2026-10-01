#!/usr/bin/env bash
set -euo pipefail

OUT="${RUNNER_TEMP:-/tmp}/bil-pre-final-automated"
mkdir -p "$OUT"

test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?GITHUB_SHA required}"
test -z "$(git status --porcelain=v1 --untracked-files=all)"

flutter pub get
flutter test --no-pub --concurrency 1 --timeout 180s --reporter expanded \
  test/release/pre_final_stress_test.dart \
  test/features/meal_planner/recipe_catalog_1500_contract_test.dart \
  test/features/wellness/recipe_release_repository_test.dart \
  test/features/cloud_platform/aes_gcm_cloud_payload_cipher_test.dart \
  test/features/cloud_platform/cloud_account_key_repository_test.dart \
  test/features/cloud_platform/cloud_backup_restore_system_test.dart \
  test/features/cloud_platform/cloud_conflict_resolver_regression_test.dart \
  test/features/cloud_platform/cloud_sync_account_isolation_test.dart \
  test/features/cloud_platform/durable_cloud_runtime_test.dart \
  test/features/cloud_platform/offline_first_cloud_platform_test.dart \
  test/features/commerce/store_transaction_queue_test.dart \
  test/features/commerce/verified_entitlement_continuity_store_test.dart \
  test/features/commerce/verified_entitlement_surface_contract_test.dart \
  test/features/commerce/subscription_lifecycle_test.dart \
  test/premium_dashboard_benchmark_test.dart \
  test/features/commerce/billing_release_hardening_contract_test.dart \
  test/mobile_integrity_payload_test.dart \
  test/runtime_permission_design_contract_test.dart \
  test/features/notifications/notification_settings_permission_resilience_test.dart \
  test/launch_readiness/deep_link_exhaustive_source_contract_test.dart \
  test/epic12_security_audit_regression_test.dart \
  test/features/intelligence_center/coach_cloud_payload_sanitizer_test.dart \
  2>&1 | tee "$OUT/flutter-targeted.log"

pushd supabase/functions >/dev/null
deno test -A --frozen --lock=deno.lock \
  food-search/index_test.ts \
  analyze-meal/consent_test.ts \
  analyze-meal/providers/providers_test.ts \
  app-attest/index_test.ts \
  play-integrity/index_test.ts \
  community-push-dispatch/server_test.ts \
  push-provider-gateway/server_test.ts \
  verify-store-purchase/apple_purchase_ownership_test.ts \
  verify-store-purchase/google_account_binding_test.ts \
  verify-store-purchase/apple_subscription_lifecycle_test.ts \
  verify-store-purchase/google_play_subscription_lifecycle_test.ts \
  verify-store-purchase/mobile_integrity_test.ts \
  _shared/account_deletion_storage_test.ts \
  2>&1 | tee "$OUT/deno-fault-matrix.log"
deno test -A --frozen --lock=deno.lock \
  ai-coach/server_test.ts ai-coach/mobile_integrity_test.ts \
  2>&1 | tee "$OUT/deno-ai-coach-faults.log"
popd >/dev/null

printf '%s\n' \
  'PRE_FINAL_STRESS=PASS' \
  'RECIPE_CATALOG_1500=PASS' \
  'CLOUD_OFFLINE_RETRY_IDEMPOTENCY_SIMULATED=PASS' \
  'CLOUD_CONFLICT_CORRUPT_MISSING_KEY_SIMULATED=PASS' \
  'BACKEND_FAULT_MATRIX_SIMULATED=PASS' \
  'STOREKIT_PLAY_LOCAL_LOGIC=PASS_NOT_GENUINE_STORE_SANDBOX' \
  'DYNAMIC_SECURITY_FAIL_CLOSED_SIMULATED=PASS' \
  'PERMISSIONS_RECOVERY_CONTRACTS=PASS' \
  'LOW_STORAGE_RUNTIME=NOT_RUN_UNSAFE_CI_SIMULATION' \
  'BATTERY_THERMAL=PHYSICAL_DEVICE_REQUIRED' \
  'GENUINE_APP_ATTEST=PHYSICAL_DEVICE_REQUIRED' \
  'GENUINE_PLAY_INTEGRITY=PHYSICAL_DEVICE_REQUIRED' \
  > "$OUT/status.txt"

git diff --exit-code
test -z "$(git status --porcelain=v1 --untracked-files=no)"
