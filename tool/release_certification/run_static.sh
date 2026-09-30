#!/usr/bin/env bash
set -euo pipefail
out="${1:?output dir required}"; mkdir -p "$out"
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub --concurrency 1 --timeout 90s test/performance_budget_test.dart test/database_migration_test.dart test/database_migration_preservation_test.dart test/database_v17_migration_test.dart test/database_v20_body_measurement_migration_test.dart test/features/cloud_platform test/auth_boundary_test.dart test/app_router_invalid_route_test.dart test/app_router_plan_navigation_guard_test.dart test/epic_003_route_contract_test.dart test/accessibility/release_accessibility_regression_test.dart test/epic11_localization_accessibility_test.dart test/epic12_security_privacy_contract_test.dart test/launch_readiness/apple_account_deletion_contract_test.dart 2>&1 | tee "$out/focused.log"
for f in tool/epic11_localization_audit.dart tool/epic12_security_audit.dart tool/epic13_commerce_audit.dart tool/epic14_release_audit.dart tool/epic16_release_audit.dart; do dart run "$f" 2>&1 | tee -a "$out/release-audits.log"; done
python3 tool/prebuild/audit_repository.py | tee "$out/repository-audit.log"
python3 - <<'PY'
import json,pathlib
p=pathlib.Path('build/diagnostics/prebuild_code_audit_20260910/repository_inventory.json')
d=json.loads(p.read_text())
assert not d.get('secret_candidates'), d.get('secret_candidates')
assert not d.get('conflict_candidates'), d.get('conflict_candidates')
assert not d.get('syntax_errors'), d.get('syntax_errors')
PY
cp build/diagnostics/prebuild_code_audit_20260910/repository_inventory.json "$out/"
dart pub deps --json > "$out/pub-deps.json"
node tool/prebuild/audit_pub_advisories.mjs "$out/pub-deps.json" | tee "$out/pub-osv.json"
node tool/prebuild/audit_locked_advisories.mjs npm supabase/functions/deno.lock | tee "$out/deno-npm-osv.json"
npm ci --prefix cloudflare/workout-runtime
npm --prefix cloudflare/workout-runtime test
npm --prefix cloudflare/workout-runtime audit --audit-level=low | tee "$out/cloudflare-npm-audit.log"
node tool/release/bilhealth_site_worker.test.mjs 2>&1 | tee "$out/public-site-worker.log"
npm ci --prefix supabase/tests
npm --prefix supabase/tests test 2>&1 | tee "$out/supabase-contracts.log"
npm --prefix supabase/tests audit --audit-level=low | tee "$out/supabase-npm-audit.log"
(cd android && ./gradlew app:dependencies --configuration releaseRuntimeClasspath) > "$out/android-release-dependencies.txt"
node tool/prebuild/audit_locked_advisories.mjs Maven "$out/android-release-dependencies.txt" | tee "$out/android-maven-osv.json"
git diff --exit-code
test -z "$(git status --porcelain=v1 --untracked-files=no)"
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
