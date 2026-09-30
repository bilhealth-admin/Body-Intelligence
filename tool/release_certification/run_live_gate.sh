#!/usr/bin/env bash
set -euo pipefail
PASS="${1:?pass number required}"
OUT="${RUNNER_TEMP:-/tmp}/bil-cert-live-${PASS}"
mkdir -p "$OUT"
status() {
  printf 'LIVE_BACKEND_CORE=%s\n' "$1" | tee "$OUT/status.txt"
}
if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" || -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  echo "Required Supabase CI credentials are unavailable." | tee "$OUT/not-run.txt"
  status "NOT RUN"
  exit 0
fi
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?GITHUB_SHA required}"
CLI=(npx --yes supabase@2.117.0)
"${CLI[@]}" --version | tee "$OUT/supabase-cli-version.txt"
"${CLI[@]}" init --force
"${CLI[@]}" link --project-ref "${BIL_SUPABASE_PROJECT_REF:?project ref required}" --password "$SUPABASE_DB_PASSWORD"
"${CLI[@]}" migration list --linked | tee "$OUT/remote-migrations.txt"
python3 - "$OUT/remote-migrations.txt" <<'PY'
import pathlib, re, sys
rows=[]
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    parts=[p.strip() for p in line.split('|')]
    if len(parts) < 2: continue
    local=re.sub(r'\D','',parts[0]); remote=re.sub(r'\D','',parts[1])
    if local or remote: rows.append((local,remote,line))
if not rows: raise SystemExit('NO_MIGRATION_ROWS_PARSED')
drift=[row for row in rows if row[0] != row[1]]
if drift: raise SystemExit('LOCAL_REMOTE_MIGRATION_DRIFT: '+repr(drift[:20]))
print(f'MIGRATION_PARITY=PASS rows={len(rows)}')
PY
"${CLI[@]}" functions list --project-ref "$BIL_SUPABASE_PROJECT_REF" | tee "$OUT/edge-functions.txt"

run_pinned_ps1() {
  local source="$1"; shift
  local tmp="$RUNNER_TEMP/$(basename "$source" .ps1)-pinned-${PASS}.ps1"
  python3 - "$source" "$tmp" <<'PY'
import pathlib, sys
source=pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig')
if 'supabase@latest' not in source:
    raise SystemExit('Expected supabase@latest marker was not found')
pathlib.Path(sys.argv[2]).write_text(source.replace('supabase@latest','supabase@2.117.0'),encoding='utf-8')
PY
  pwsh -NoProfile -File "$tmp" "$@"
}

run_pinned_ps1 tool/ai_coach/run_live_text_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/ai-coach-text.log"
run_pinned_ps1 tool/ai_coach/run_live_voice_metering_db.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/ai-voice-metering.log"
run_pinned_ps1 tool/meal_vision_benchmark/run_live_supabase_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/meal-vision.log"
run_pinned_ps1 tool/nutrition/run_live_barcode_gate_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" 2>&1 | tee "$OUT/barcode.log"
run_pinned_ps1 tool/account_deletion/run_live_disposable_e2e.ps1 -ProjectRef "$BIL_SUPABASE_PROJECT_REF" -OwnerEmail "release-certification@bilhealth.invalid" 2>&1 | tee "$OUT/account-deletion.log"

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
rm -rf supabase/.temp
rm -f supabase/config.toml
git diff --exit-code
test -z "$(git status --porcelain=v1 --untracked-files=no)"
status "PASS"
