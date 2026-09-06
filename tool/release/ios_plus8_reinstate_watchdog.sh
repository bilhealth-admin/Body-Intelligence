#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${OWNER_EMAIL:?}"
: "${OWNER_PASSWORD:?}"
: "${ASC_KEY_ID:?}"
: "${ASC_ISSUER_ID:?}"
: "${ASC_PRIVATE_KEY_BASE64:?}"
: "${BIL_SUPABASE_SERVICE_ROLE_KEY:?}"
: "${RUNNER_TEMP:?}"

owner_email_secret="$OWNER_EMAIL"
owner_password_secret="$OWNER_PASSWORD"
asc_key_id_secret="$ASC_KEY_ID"
asc_issuer_id_secret="$ASC_ISSUER_ID"
asc_private_key_secret="$ASC_PRIVATE_KEY_BASE64"
service_role_secret="$BIL_SUPABASE_SERVICE_ROLE_KEY"
unset OWNER_EMAIL OWNER_PASSWORD ASC_KEY_ID ASC_ISSUER_ID
unset ASC_PRIVATE_KEY_BASE64 BIL_SUPABASE_SERVICE_ROLE_KEY

REVIEW_CREDENTIALS="$RUNNER_TEMP/bil-watchdog-review-credentials.json"
ASC_KEY_PATH="$RUNNER_TEMP/AuthKey_${asc_key_id_secret}.p8"
remove_watchdog_private_material() {
  rm -f "$REVIEW_CREDENTIALS" "$ASC_KEY_PATH"
}
trap remove_watchdog_private_material EXIT

source tool/release/ios_plus8_simulator_ui/private_review_account.sh
load_private_review_account \
  "$asc_key_id_secret" "$asc_issuer_id_secret" "$asc_private_key_secret"
reviewer_email_secret="$(node -e \
  "const x=require(process.argv[1]);process.stdout.write(x.email)" \
  "$REVIEW_CREDENTIALS")"
rm -f "$REVIEW_CREDENTIALS" "$ASC_KEY_PATH"
asc_key_id_secret=''
asc_issuer_id_secret=''
asc_private_key_secret=''

env OWNER_EMAIL="$owner_email_secret" OWNER_PASSWORD="$owner_password_secret" \
  REVIEWER_EMAIL="$reviewer_email_secret" \
  BIL_SUPABASE_SERVICE_ROLE_KEY="$service_role_secret" \
  node tool/release/ios_plus8_dual_account_canary.mjs watchdog
