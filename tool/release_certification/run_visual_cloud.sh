#!/usr/bin/env bash
set -euo pipefail
out="${1:?output dir required}"; mkdir -p "$out"
flutter pub get
flutter test --no-pub --reporter expanded test/features/community/community_polish_visual_test.dart test/dashboard_polish/dashboard_current_preview_test.dart test/epic15_store_screenshot_golden_test.dart 2>&1 | tee "$out/visual.log"
psql -h 127.0.0.1 -U postgres -d community_qa -f tool/release/test_community_attention_isolated.sql 2>&1 | tee "$out/postgres.log"
npm install --prefix "$RUNNER_TEMP/bil-deno" deno@2.5.1
"$RUNNER_TEMP/bil-deno/node_modules/.bin/deno" test --allow-env --allow-read --allow-net supabase/functions/push-provider-gateway supabase/functions/community-push-dispatch 2>&1 | tee "$out/deno.log"
git diff --exit-code
