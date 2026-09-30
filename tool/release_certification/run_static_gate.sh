#!/usr/bin/env bash
set -euo pipefail
PASS="${1:?pass number required}"
OUT="${RUNNER_TEMP:-/tmp}/bil-cert-static-${PASS}"
mkdir -p "$OUT"
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?GITHUB_SHA required}"
test -z "$(git status --porcelain=v1 --untracked-files=all)"
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub 2>&1 | tee "$OUT/analyze.log"
flutter test --no-pub --concurrency 1 --timeout 90s --reporter expanded   test/performance_budget_test.dart   test/database_migration_test.dart   test/database_migration_preservation_test.dart   test/database_v17_migration_test.dart   test/database_v20_body_measurement_migration_test.dart   test/features/cloud_platform   test/auth_boundary_test.dart   test/app_router_invalid_route_test.dart   test/app_router_plan_navigation_guard_test.dart   test/epic_003_route_contract_test.dart   test/accessibility/release_accessibility_regression_test.dart   test/epic11_localization_accessibility_test.dart   test/epic12_security_privacy_contract_test.dart   test/launch_readiness/apple_account_deletion_contract_test.dart   2>&1 | tee "$OUT/focused.log"
for audit in   tool/epic11_localization_audit.dart   tool/epic12_security_audit.dart   tool/epic13_commerce_audit.dart   tool/epic14_release_audit.dart   tool/epic16_release_audit.dart
do
  dart run "$audit" 2>&1 | tee -a "$OUT/release-audits.log"
done
python3 tool/prebuild/audit_repository.py | tee "$OUT/repository-audit.log"
python3 - "$OUT" <<'PY'
import json, pathlib, shutil, sys
out=pathlib.Path(sys.argv[1])
src=pathlib.Path('build/diagnostics/prebuild_code_audit_20260910/repository_inventory.json')
data=json.loads(src.read_text())
for key in ('secret_candidates','conflict_candidates','syntax_errors'):
    if data.get(key):
        raise SystemExit(f'{key}={data[key]}')
shutil.copyfile(src, out/'repository_inventory.json')
PY
dart pub deps --json > "$OUT/pub-deps.json"
node tool/prebuild/audit_pub_advisories.mjs "$OUT/pub-deps.json" | tee "$OUT/pub-osv.json"
node tool/prebuild/audit_locked_advisories.mjs npm supabase/functions/deno.lock | tee "$OUT/deno-npm-osv.json"
npm ci --prefix cloudflare/workout-runtime
npm --prefix cloudflare/workout-runtime test 2>&1 | tee "$OUT/cloudflare-tests.log"
npm --prefix cloudflare/workout-runtime audit --audit-level=low | tee "$OUT/cloudflare-npm-audit.log"
node tool/release/bilhealth_site_worker.test.mjs 2>&1 | tee "$OUT/public-site-worker.log"
npm ci --prefix supabase/tests
npm --prefix supabase/tests test 2>&1 | tee "$OUT/supabase-contracts.log"
npm --prefix supabase/tests audit --audit-level=low | tee "$OUT/supabase-npm-audit.log"
(cd android && ./gradlew app:dependencies --configuration releaseRuntimeClasspath) > "$OUT/android-release-dependencies.txt"
node tool/prebuild/audit_locked_advisories.mjs Maven "$OUT/android-release-dependencies.txt" | tee "$OUT/android-maven-osv.json"
git diff --exit-code
test -z "$(git status --porcelain=v1 --untracked-files=no)"
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
printf 'STATIC_CERTIFICATION_PASS_%s=PASS\n' "$PASS" | tee "$OUT/status.txt"
