#!/usr/bin/env bash
set -euo pipefail

source tool/release/ios_plus8_simulator_ui/secret_scope.sh

export OWNER_EMAIL='owner-scope-canary'
export OWNER_PASSWORD='owner-password-scope-canary'
export REVIEWER_EMAIL='reviewer-scope-canary'
export REVIEWER_PASSWORD='reviewer-password-scope-canary'
export ASC_KEY_ID='asc-key-scope-canary'
export ASC_ISSUER_ID='asc-issuer-scope-canary'
export ASC_PRIVATE_KEY_BASE64='asc-private-scope-canary'
export BIL_SUPABASE_SERVICE_ROLE_KEY='service-role-scope-canary'

BIL_IDB_EXECUTABLE="$(command -v env)"
BIL_XCRUN_EXECUTABLE="$(command -v env)"
install_sanitized_apple_tool_wrappers

for output in "$(idb)" "$(xcrun)"; do
  for name in OWNER_EMAIL OWNER_PASSWORD REVIEWER_EMAIL REVIEWER_PASSWORD \
    ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_BASE64 \
    BIL_SUPABASE_SERVICE_ROLE_KEY; do
    if grep -Fq "$name=" <<< "$output"; then
      echo "Sensitive environment escaped into a child tool: $name" >&2
      exit 1
    fi
  done
done

printf '%s\n' 'IOS_PLUS8_APPLE_TOOL_SECRET_SCOPE=PASS'
