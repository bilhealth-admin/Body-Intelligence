#!/usr/bin/env bash
set -euo pipefail
PASS="${1:?pass number required}"
OUT="${RUNNER_TEMP:-/tmp}/bil-cert-live-${PASS}"
mkdir -p "$OUT"
status() {
  printf 'LIVE_BACKEND_CORE=%s\n' "$1" | tee "$OUT/status.txt"
}
if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Required Supabase CI credentials are unavailable." | tee "$OUT/not-run.txt"
  status "NOT RUN"
  exit 0
fi
pwsh -NoProfile -File tool/release/test_http_failure_body.ps1
pwsh -NoProfile -File tool/release_certification/test_auth_admin_user_create.ps1
pwsh -NoProfile -File tool/ai_coach/test_live_text_e2e_diagnostics.ps1
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?GITHUB_SHA required}"
CLI=(npx --yes supabase@2.121.0)
"${CLI[@]}" --version | tee "$OUT/supabase-cli-version.txt"
# Management API queries use the existing PAT, without a database password.
# Preserve known historical aliases and independent admin migrations; do not replay DDL.
mkdir -p supabase/.temp
printf '%s' "${BIL_SUPABASE_PROJECT_REF:?project ref required}" > supabase/.temp/project-ref
"${CLI[@]}" db query --linked --project-ref "$BIL_SUPABASE_PROJECT_REF" \
  "select version,name,md5(array_to_string(statements,E'\\n')) as statements_md5 from supabase_migrations.schema_migrations order by version" \
  --output json > "$OUT/deployed-migration-ledger.json"
python3 tool/release_certification/check_cloud_deployment_ledger.py "$OUT/deployed-migration-ledger.json" | tee "$OUT/migration-ledger-check.json"
"${CLI[@]}" functions list --project-ref "$BIL_SUPABASE_PROJECT_REF" | tee "$OUT/edge-functions.txt"

run_pinned_ps1() {
  local source="$1"; shift
  local tmp="$(dirname "$source")/.ci-$(basename "$source" .ps1)-pinned-${PASS}.ps1"
  python3 - "$source" "$tmp" <<'PY'
import pathlib, sys
source=pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig')
if 'supabase@latest' not in source:
    raise SystemExit('Expected supabase@latest marker was not found')
pathlib.Path(sys.argv[2]).write_text(source.replace('supabase@latest','supabase@2.121.0'),encoding='utf-8')
PY
  local result=0
  local capture="$OUT/$(basename "$source" .ps1)-result.json"
  pwsh -NoProfile -File "$tmp" "$@" > "$capture" || result=$?
  rm -f "$tmp"
  cat "$capture"
  if [[ "$result" == 0 ]]; then
    python3 - "$capture" <<'PY'
import json, pathlib, sys
report = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
if report.get('success', report.get('translated')) is not True:
    raise SystemExit('Live service did not return actual success')
for key in ('cleanup', 'user_deleted', 'session_revoked', 'cascade_clean'):
    if key in report and report[key] is not True:
        raise SystemExit('Disposable fixture cleanup failed: ' + key)
PY
  fi
  return "$result"
}

run_pinned_ps1 tool/ai_coach/run_live_text_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/ai-coach-text.log"
run_pinned_ps1 tool/ai_coach/run_live_voice_metering_db.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/ai-voice-metering.log"
run_pinned_ps1 tool/meal_vision_benchmark/run_live_supabase_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/meal-vision.log"
run_pinned_ps1 tool/nutrition/run_live_barcode_gate_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/barcode.log"
run_pinned_ps1 tool/account_deletion/run_live_disposable_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" -OwnerEmail "release-certification@bilhealth.invalid" 2>&1 | tee "$OUT/account-deletion.log"

run_pinned_ps1 tool/community_translation/run_live_synthetic_e2e.ps1 2>&1 | tee "$OUT/community-translation.log"

flutter pub get
flutter test --no-pub --dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true test/features/wellness/wellness_video_stream_live_test.dart 2>&1 | tee "$OUT/live-workout-range.log"
curl --fail --silent --show-error --location https://www.bilhealth.com/.well-known/apple-app-site-association --output "$OUT/apple-app-site-association.json"
curl --fail --silent --show-error --location https://www.bilhealth.com/.well-known/assetlinks.json --output "$OUT/assetlinks.json"
curl --fail --silent --show-error --location https://www.bilhealth.com/app-ads.txt --output "$OUT/app-ads.txt"
curl --fail --silent --show-error --location https://workouts.bilhealth.com/v2/manifest/wellness-workouts-v2-af6082ff28856f9154216067f16fe6a7147548c9a29f8e205b43bb81bc34efe8.json --output "$OUT/workout-manifest.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$OUT/apple-app-site-association.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$OUT/assetlinks.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$OUT/workout-manifest.json"
test -s "$OUT/app-ads.txt"
node tool/release_certification/admin_web_boundary_smoke.mjs | tee "$OUT/admin-web-boundary.json"
rm -rf supabase/.temp
git diff --exit-code
test -z "$(git status --porcelain=v1 --untracked-files=no)"
status "PASS"
