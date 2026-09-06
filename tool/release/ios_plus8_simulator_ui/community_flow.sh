#!/usr/bin/env bash

run_cross_account_community_flow() {
  open_link "$IPAD_UDID" 'bil://intelligence-center'
  wait_marker "$IPAD_UDID" 'Your BIL Coach'
  if has_marker "$IPAD_UDID" 'Buy verified Boost' || \
     has_marker "$IPAD_UDID" 'Choose your plan'; then
    echo 'Reviewer account was incorrectly stopped by a purchase wall.' >&2
    return 1
  fi

  open_link "$IPAD_UDID" 'bil://community/moderation'
  wait_marker "$IPAD_UDID" 'Moderator access is required.'

  # Apple reviewer on iPad requests; owner on iPhone accepts.
  open_link "$IPAD_UDID" 'bil://community/people'
  wait_marker "$IPAD_UDID" 'Display name'
  tap_marker "$IPAD_UDID" 'Display name'
  idb ui text --udid "$IPAD_UDID" "$OWNER_NAME"
  sleep 5
  scroll_until_marker "$IPAD_UDID" "$OWNER_NAME" 8
  tap_near_marker "$IPAD_UDID" "$OWNER_NAME" 'Send request'
  sleep 4
  backend_canary verify-friend-request

  open_link "$IPHONE_UDID" 'bil://community/connections'
  wait_marker "$IPHONE_UDID" 'Requests'
  tap_marker "$IPHONE_UDID" 'Requests'
  sleep 4
  scroll_until_marker "$IPHONE_UDID" "$REVIEWER_NAME" 8
  tap_near_marker "$IPHONE_UDID" "$REVIEWER_NAME" 'Accept'
  sleep 4
  backend_canary verify-friend-accepted

  # Exact nonce-bearing messages travel in both directions.
  open_link "$IPAD_UDID" "bil://community/chat/$OWNER_ID"
  wait_marker "$IPAD_UDID" 'Message'
  tap_marker "$IPAD_UDID" 'Message'
  idb ui text --udid "$IPAD_UDID" "$REVIEWER_MESSAGE"
  tap_marker "$IPAD_UDID" 'Send message'
  sleep 4
  wait_marker "$IPAD_UDID" "$REVIEWER_MESSAGE"
  backend_canary verify-reviewer-message

  open_link "$IPHONE_UDID" "bil://community/chat/$REVIEWER_ID"
  wait_marker "$IPHONE_UDID" "$REVIEWER_MESSAGE"
  tap_marker "$IPHONE_UDID" 'Message'
  idb ui text --udid "$IPHONE_UDID" "$OWNER_MESSAGE"
  tap_marker "$IPHONE_UDID" 'Send message'
  sleep 4
  wait_marker "$IPHONE_UDID" "$OWNER_MESSAGE"
  backend_canary verify-owner-message
  open_link "$IPAD_UDID" "bil://community/chat/$OWNER_ID"
  wait_marker "$IPAD_UDID" "$OWNER_MESSAGE"

  # Reviewer creates only the reject canary, so the review account can never
  # receive the immutable five-token approval reward.
  open_link "$IPAD_UDID" 'bil://community'
  wait_marker "$IPAD_UDID" 'Share an experience or win'
  tap_marker "$IPAD_UDID" 'Share an experience or win'
  idb ui text --udid "$IPAD_UDID" "$REJECTED_POST"
  tap_marker "$IPAD_UDID" 'Publish'
  sleep 5
  wait_marker "$IPAD_UDID" "$REJECTED_POST"
  backend_canary verify-rejected-pending

  # The approved post belongs to the disposable account. Its reward vanishes
  # with that account, while reviewer balance remains byte-for-byte unchanged.
  backend_canary verify-approved-pending
  open_link "$IPHONE_UDID" 'bil://community/moderation'
  scroll_until_marker "$IPHONE_UDID" "$APPROVED_POST" 20
  tap_near_marker "$IPHONE_UDID" "$APPROVED_POST" 'Approve'
  wait_marker "$IPHONE_UDID" 'Approve this post?'
  tap_near_marker "$IPHONE_UDID" 'Approve this post?' 'Approve'
  sleep 5
  backend_canary verify-approved

  scroll_until_marker "$IPHONE_UDID" "$REJECTED_POST" 20
  tap_near_marker "$IPHONE_UDID" "$REJECTED_POST" 'Reject'
  wait_marker "$IPHONE_UDID" 'Reject this post?'
  tap_near_marker "$IPHONE_UDID" 'Reject this post?' 'Reject'
  sleep 5
  backend_canary verify-rejected

  open_link "$IPAD_UDID" 'bil://community'
  scroll_until_marker "$IPAD_UDID" "$APPROVED_POST" 18
  scroll_until_marker "$IPAD_UDID" "$REJECTED_POST" 18
  has_markers "$IPAD_UDID" "$REJECTED_POST" 'Rejected' || {
    echo 'Reviewer iPad did not show the exact post with rejected status.' >&2
    return 1
  }

  # Block only the disposable account from its pre-seeded accepted connection.
  open_link "$IPHONE_UDID" 'bil://community/connections'
  scroll_until_marker "$IPHONE_UDID" "$DISPOSABLE_NAME" 12
  tap_near_marker "$IPHONE_UDID" "$DISPOSABLE_NAME" 'Manage connection'
  wait_marker "$IPHONE_UDID" 'Block member'
  tap_marker "$IPHONE_UDID" 'Block member'
  sleep 4
  backend_canary verify-block
  backend_canary verify-blocked-message-denied
}
