#!/usr/bin/env bash

open_owner_admin() {
  open_link "$IPHONE_UDID" 'bil://settings'
  scroll_until_marker "$IPHONE_UDID" 'BIL Administration' 30
  tap_marker "$IPHONE_UDID" 'BIL Administration'
  wait_marker "$IPHONE_UDID" 'BIL Administration'
}

run_individual_reset() {
  open_owner_admin
  scroll_until_marker "$IPHONE_UDID" 'Individual AI Coach Reset' 20
  tap_near_marker "$IPHONE_UDID" 'Individual AI Coach Reset' 'Account email'
  idb ui text --udid "$IPHONE_UDID" "$DISPOSABLE_EMAIL"
  tap_near_marker "$IPHONE_UDID" 'Individual AI Coach Reset' 'Reason (optional)'
  idb ui text --udid "$IPHONE_UDID" "$INDIVIDUAL_REASON"
  tap_near_marker "$IPHONE_UDID" 'Individual AI Coach Reset' \
    'Message delivered with the 2,500-token gift'
  idb ui text --udid "$IPHONE_UDID" "$INDIVIDUAL_MESSAGE"
  tap_near_marker "$IPHONE_UDID" 'Individual AI Coach Reset' 'Reset this account'
  wait_marker "$IPHONE_UDID" 'Confirm individual reset'
  tap_near_marker "$IPHONE_UDID" 'Confirm individual reset' 'Reset this account'
  wait_marker "$IPHONE_UDID" \
    'The account’s current AI Coach usage was reset safely' 20
  backend_canary verify-individual-reset
}

run_moderator_add_remove() {
  scroll_until_marker "$IPHONE_UDID" 'Community moderators' 28
  tap_near_marker "$IPHONE_UDID" 'Community moderators' 'Account email'
  idb ui text --udid "$IPHONE_UDID" "$DISPOSABLE_EMAIL"
  tap_near_marker "$IPHONE_UDID" 'Community moderators' 'Add'
  wait_marker "$IPHONE_UDID" 'Moderator added.' 20
  sleep 3
  backend_canary verify-moderator-added
  scroll_until_marker "$IPHONE_UDID" "$DISPOSABLE_EMAIL" 20
  tap_near_marker "$IPHONE_UDID" "$DISPOSABLE_EMAIL" 'Delete'
  wait_marker "$IPHONE_UDID" 'Remove moderator?'
  tap_near_marker "$IPHONE_UDID" 'Remove moderator?' 'Delete'
  sleep 5
  backend_canary verify-moderator-removed
}

run_target_notification() {
  scroll_until_marker "$IPHONE_UDID" 'Write a custom message' 80
  tap_marker "$IPHONE_UDID" 'Write a custom message'
  wait_marker "$IPHONE_UDID" 'Notification text'
  tap_marker "$IPHONE_UDID" 'Notification text'
  idb ui text --udid "$IPHONE_UDID" "$TARGET_NOTIFICATION"
  tap_marker "$IPHONE_UDID" 'Specific email'
  wait_marker "$IPHONE_UDID" 'Account email'
  tap_marker "$IPHONE_UDID" 'Account email'
  idb ui text --udid "$IPHONE_UDID" "$DISPOSABLE_EMAIL"
  tap_marker "$IPHONE_UDID" 'Review before sending'
  wait_marker "$IPHONE_UDID" 'Confirm notification'
  tap_near_marker "$IPHONE_UDID" 'Confirm notification' 'Send now'
  wait_marker "$IPHONE_UDID" 'Notification queued safely for' 20
  backend_canary verify-target-notification
}

run_suspend_reinstate() {
  open_owner_admin
  scroll_until_marker "$IPHONE_UDID" 'Member account email' 45
  tap_marker "$IPHONE_UDID" 'Member account email'
  idb ui text --udid "$IPHONE_UDID" "$DISPOSABLE_EMAIL"
  tap_marker "$IPHONE_UDID" 'Audit reason'
  idb ui text --udid "$IPHONE_UDID" "$BIL_QA_SUSPEND_REASON"
  tap_marker "$IPHONE_UDID" 'Suspend Community access'
  wait_marker "$IPHONE_UDID" 'Suspend Community access?'
  tap_near_marker "$IPHONE_UDID" 'Suspend Community access?' 'Suspend'
  wait_marker "$IPHONE_UDID" 'Community access suspended.' 20
  backend_canary verify-suspended
  backend_canary verify-suspended-post-denied

  scroll_until_marker "$IPHONE_UDID" "$DISPOSABLE_EMAIL" 16
  tap_near_marker "$IPHONE_UDID" "$DISPOSABLE_EMAIL" 'Restore access'
  wait_marker "$IPHONE_UDID" 'Restore Community access?'
  tap_near_marker "$IPHONE_UDID" 'Restore Community access?' 'Restore'
  sleep 5
  backend_canary verify-reinstated
  backend_canary create-restored-post
}

run_owner_protection() {
  open_owner_admin
  scroll_until_marker "$IPHONE_UDID" 'Member account email' 45
  tap_marker "$IPHONE_UDID" 'Member account email'
  idb ui text --udid "$IPHONE_UDID" "$owner_email_secret"
  tap_marker "$IPHONE_UDID" 'Audit reason'
  idb ui text --udid "$IPHONE_UDID" 'owner protection check'
  tap_marker "$IPHONE_UDID" 'Suspend Community access'
  wait_marker "$IPHONE_UDID" 'Suspend Community access?'
  tap_near_marker "$IPHONE_UDID" 'Suspend Community access?' 'Suspend'
  wait_marker "$IPHONE_UDID" 'The request could not be completed.' 20
  backend_canary verify-owner-protection
}

run_owner_admin_flow() {
  run_individual_reset
  run_moderator_add_remove
  run_target_notification
  run_suspend_reinstate
  run_owner_protection
}
