#!/usr/bin/env bash
set -euo pipefail
out="${1:?output dir required}"; mkdir -p "$out"
trap 'code=$?; echo "LIVE_BACKEND_CORE=$([[ $code -eq 0 ]] && echo PASS || echo FAIL)" > "$out/status.txt"; exit $code' EXIT
npx --yes supabase@2.117.0 --version | tee "$out/cli.txt"
npx --yes supabase@2.117.0 link --project-ref tgmanzhqulksykhslrzb --password "$SUPABASE_DB_PASSWORD"
npx --yes supabase@2.117.0 migration list --linked | tee "$out/migrations.txt"
npx --yes supabase@2.117.0 functions list --project-ref tgmanzhqulksykhslrzb | tee "$out/functions.txt"
pwsh -NoProfile -File tool/ai_coach/run_live_text_e2e.ps1 -ProjectRef tgmanzhqulksykhslrzb 2>&1 | tee "$out/coach.log"
pwsh -NoProfile -File tool/ai_coach/run_live_voice_metering_db.ps1 -ProjectRef tgmanzhqulksykhslrzb 2>&1 | tee "$out/voice.log"
pwsh -NoProfile -File tool/meal_vision_benchmark/run_live_supabase_e2e.ps1 -ProjectRef tgmanzhqulksykhslrzb 2>&1 | tee "$out/vision.log"
pwsh -NoProfile -File tool/nutrition/run_live_barcode_gate_e2e.ps1 -ProjectRef tgmanzhqulksykhslrzb 2>&1 | tee "$out/barcode.log"
pwsh -NoProfile -File tool/account_deletion/run_live_disposable_e2e.ps1 -ProjectRef tgmanzhqulksykhslrzb -OwnerEmail release-certification@bilhealth.invalid 2>&1 | tee "$out/deletion.log"
flutter pub get
flutter test --no-pub --dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true test/features/wellness/wellness_video_stream_live_test.dart 2>&1 | tee "$out/workout.log"
curl -fsSL https://www.bilhealth.com/.well-known/apple-app-site-association -o "$out/aasa.json"
curl -fsSL https://www.bilhealth.com/.well-known/assetlinks.json -o "$out/assetlinks.json"
curl -fsSL https://www.bilhealth.com/app-ads.txt -o "$out/app-ads.txt"
curl -fsSL https://workouts.bilhealth.com/v2/manifest/wellness-workouts-v2-af6082ff28856f9154216067f16fe6a7147548c9a29f8e205b43bb81bc34efe8.json -o "$out/workout-manifest.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$out/aasa.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$out/assetlinks.json"
node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$out/workout-manifest.json"
test -s "$out/app-ads.txt"
