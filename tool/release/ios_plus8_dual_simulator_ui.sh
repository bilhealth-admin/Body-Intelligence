#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${IPHONE_UDID:?}"
: "${IPAD_UDID:?}"
: "${OWNER_EMAIL:?}"
: "${OWNER_PASSWORD:?}"
: "${ASC_KEY_ID:?}"
: "${ASC_ISSUER_ID:?}"
: "${ASC_PRIVATE_KEY_BASE64:?}"
: "${BIL_SUPABASE_SERVICE_ROLE_KEY:?}"
: "${BIL_QA_STATE_PATH:?}"
: "${BIL_QA_SUSPEND_REASON:?}"
: "${BIL_EVIDENCE_DIR:?}"
: "${RUNNER_TEMP:?}"

owner_email_secret="$OWNER_EMAIL"
owner_password_secret="$OWNER_PASSWORD"
asc_key_id_secret="$ASC_KEY_ID"
asc_issuer_id_secret="$ASC_ISSUER_ID"
asc_private_key_secret="$ASC_PRIVATE_KEY_BASE64"
service_role_secret="$BIL_SUPABASE_SERVICE_ROLE_KEY"
unset OWNER_EMAIL OWNER_PASSWORD ASC_KEY_ID ASC_ISSUER_ID
unset ASC_PRIVATE_KEY_BASE64 BIL_SUPABASE_SERVICE_ROLE_KEY

PRIVATE_UI_DIR="$RUNNER_TEMP/bil-private-ui"
REVIEW_CREDENTIALS="$RUNNER_TEMP/bil-review-credentials.json"
ASC_KEY_PATH="$RUNNER_TEMP/AuthKey_${asc_key_id_secret}.p8"
mkdir -p "$PRIVATE_UI_DIR"
chmod 700 "$PRIVATE_UI_DIR"

remove_private_material() {
  rm -f "$REVIEW_CREDENTIALS" "$ASC_KEY_PATH"
  rm -rf "$PRIVATE_UI_DIR"
}
trap remove_private_material EXIT

backend_canary() {
  env BIL_SUPABASE_SERVICE_ROLE_KEY="$service_role_secret" \
    node tool/release/ios_plus8_dual_account_canary.mjs "$@"
}

source tool/release/ios_plus8_simulator_ui/secret_scope.sh
source tool/release/ios_plus8_simulator_ui/accessibility.sh
source tool/release/ios_plus8_simulator_ui/private_review_account.sh
source tool/release/ios_plus8_simulator_ui/community_flow.sh
source tool/release/ios_plus8_simulator_ui/owner_admin_flow.sh
install_sanitized_apple_tool_wrappers

load_private_review_account \
  "$asc_key_id_secret" "$asc_issuer_id_secret" "$asc_private_key_secret"
reviewer_email_secret="$(node -e \
  "const x=require(process.argv[1]);process.stdout.write(x.email)" \
  "$REVIEW_CREDENTIALS")"
reviewer_password_secret="$(node -e \
  "const x=require(process.argv[1]);process.stdout.write(x.password)" \
  "$REVIEW_CREDENTIALS")"
rm -f "$ASC_KEY_PATH"
asc_key_id_secret=''
asc_issuer_id_secret=''
asc_private_key_secret=''

env OWNER_EMAIL="$owner_email_secret" OWNER_PASSWORD="$owner_password_secret" \
  BIL_REVIEW_CREDENTIALS_PATH="$REVIEW_CREDENTIALS" \
  BIL_SUPABASE_SERVICE_ROLE_KEY="$service_role_secret" \
  node tool/release/ios_plus8_dual_account_canary.mjs bootstrap
rm -f "$REVIEW_CREDENTIALS"

OWNER_ID="$(backend_canary get owner_id)"
REVIEWER_ID="$(backend_canary get reviewer_id)"
OWNER_NAME="$(backend_canary get owner_name)"
REVIEWER_NAME="$(backend_canary get reviewer_name)"
DISPOSABLE_NAME="$(backend_canary get disposable_name)"
DISPOSABLE_EMAIL="$(backend_canary get disposable_email)"
REVIEWER_MESSAGE="$(backend_canary get reviewer_message)"
OWNER_MESSAGE="$(backend_canary get owner_message)"
APPROVED_POST="$(backend_canary get approved_post)"
REJECTED_POST="$(backend_canary get rejected_post)"
INDIVIDUAL_REASON="$(backend_canary get individual_reason)"
INDIVIDUAL_MESSAGE="$(backend_canary get individual_message)"
TARGET_NOTIFICATION="$(backend_canary get target_notification)"

login "$IPHONE_UDID" "$owner_email_secret" "$owner_password_secret"
login "$IPAD_UDID" "$reviewer_email_secret" "$reviewer_password_secret"

# Authenticated screenshots/accessibility dumps remain runner-private.
xcrun simctl io "$IPHONE_UDID" screenshot "$PRIVATE_UI_DIR/owner-dashboard.png"
xcrun simctl io "$IPAD_UDID" screenshot "$PRIVATE_UI_DIR/reviewer-dashboard.png"

run_cross_account_community_flow
run_owner_admin_flow

printf '%s\n' \
  'OWNER_IPHONE_LOGIN=PASS' \
  'APPLE_REVIEWER_IPAD_LOGIN=PASS' \
  'REVIEWER_AI_COACH_NO_PAYWALL_UI=PASS' \
  'APPLE_REVIEWER_IPAD_REJECTED_POST_VISIBLE_UI=PASS' \
  'REVIEWER_MODERATION_UI_DENIAL=PASS' \
  'REVIEWER_APPROVAL_REWARD_TOKENS=0' \
  'CROSS_ACCOUNT_UI_SEQUENCE=PASS' \
  'OWNER_ADMIN_DISPOSABLE_ACCOUNT_SEQUENCE=PASS' \
  'AUTHENTICATED_RAW_SCREENSHOTS_UPLOADED=false' \
  > "$BIL_EVIDENCE_DIR/authenticated-ui-status.txt"
