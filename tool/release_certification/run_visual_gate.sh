#!/usr/bin/env bash
set -euo pipefail
PASS="${1:?pass number required}"
OUT="${RUNNER_TEMP:-/tmp}/bil-cert-visual-${PASS}"
mkdir -p "$OUT"
test "$(git rev-parse HEAD)" = "${GITHUB_SHA:?GITHUB_SHA required}"
flutter pub get
printf '%s\n' \
  'EPIC15_STRICT_GOLDENS=WINDOWS_FULL_SHARDS_PASS_1_AND_PASS_2' \
  'UBUNTU_VISUAL_GATE=COMMUNITY_DASHBOARD_PLUS_ISOLATED_CLOUD_ONLY' \
  > "$OUT/visual-host-policy.txt"
flutter test --no-pub --reporter expanded   test/features/community/community_polish_visual_test.dart   test/dashboard_polish/dashboard_current_preview_test.dart   2>&1 | tee "$OUT/visual.log"
: "${PGPASSWORD:?PGPASSWORD required}"
psql -h 127.0.0.1 -U postgres -d community_qa   -f tool/release/test_community_attention_isolated.sql   2>&1 | tee "$OUT/postgres.log"
npm install --prefix "$RUNNER_TEMP/bil-deno-${PASS}" deno@2.5.1
"$RUNNER_TEMP/bil-deno-${PASS}/node_modules/.bin/deno" test   --allow-env --allow-read --allow-net   supabase/functions/push-provider-gateway   supabase/functions/community-push-dispatch   2>&1 | tee "$OUT/deno.log"
git diff --exit-code
test -z "$(git status --porcelain=v1 --untracked-files=no)"
printf 'VISUAL_CLOUD_PASS_%s=PASS\n' "$PASS" | tee "$OUT/status.txt"
