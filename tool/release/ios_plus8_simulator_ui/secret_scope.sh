#!/usr/bin/env bash

install_sanitized_apple_tool_wrappers() {
  IDB_EXECUTABLE="${BIL_IDB_EXECUTABLE:-$(command -v idb)}"
  XCRUN_EXECUTABLE="${BIL_XCRUN_EXECUTABLE:-$(command -v xcrun)}"

  idb() {
    env -u OWNER_EMAIL -u OWNER_PASSWORD \
      -u REVIEWER_EMAIL -u REVIEWER_PASSWORD \
      -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_PRIVATE_KEY_BASE64 \
      -u BIL_SUPABASE_SERVICE_ROLE_KEY "$IDB_EXECUTABLE" "$@"
  }

  xcrun() {
    env -u OWNER_EMAIL -u OWNER_PASSWORD \
      -u REVIEWER_EMAIL -u REVIEWER_PASSWORD \
      -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_PRIVATE_KEY_BASE64 \
      -u BIL_SUPABASE_SERVICE_ROLE_KEY "$XCRUN_EXECUTABLE" "$@"
  }
}
