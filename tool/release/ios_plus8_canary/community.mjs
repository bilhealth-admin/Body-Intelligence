import {
  appendEvidence,
  atomicWriteState,
  creditBalance,
  digest,
  friendships,
  mask,
  messagesForMarker,
  postsForMarker,
  readState,
  request,
  select,
  uuid,
} from './runtime.mjs';

export async function verifyFriendRequest() {
  const state = readState();
  const rows = await friendships(state);
  if (
    rows.length !== 1 || rows[0].status !== 'pending' ||
    rows[0].requester_id !== state.reviewer.userId ||
    rows[0].addressee_id !== state.owner.userId || !uuid(rows[0].id)
  ) throw new Error('friend_request_server_postcondition_failed');
  state.records.friendshipId = rows[0].id;
  mask(rows[0].id);
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    'REVIEWER_IPAD_FRIEND_REQUEST_UI=PASS',
    'FRIEND_REQUEST_SERVER_STATE_PENDING=PASS',
    `FRIENDSHIP_ID_SHA256=${digest(rows[0].id)}`,
  ]);
}

export async function verifyFriendAccepted() {
  const state = readState();
  const rows = await friendships(state);
  if (
    rows.length !== 1 || rows[0].id !== state.records.friendshipId ||
    rows[0].status !== 'accepted' || !rows[0].responded_at
  ) throw new Error('friend_accept_server_postcondition_failed');
  appendEvidence('cross-account-status.txt', [
    'OWNER_IPHONE_FRIEND_ACCEPT_UI=PASS',
    'FRIENDSHIP_SERVER_STATE_ACCEPTED=PASS',
  ]);
}

export async function verifyMessage(markerKey, expectedSender, expectedRecipient) {
  const state = readState();
  const marker = state.markers[markerKey];
  if (!marker) throw new Error('unknown_message_marker');
  const rows = await messagesForMarker(state, marker);
  if (
    rows.length !== 1 || rows[0].sender_id !== state[expectedSender].userId ||
    rows[0].recipient_id !== state[expectedRecipient].userId || !uuid(rows[0].id)
  ) throw new Error(`message_server_postcondition_failed:${markerKey}`);
  if (!state.records.messageIds.includes(rows[0].id)) {
    state.records.messageIds.push(rows[0].id);
  }
  mask(rows[0].id);
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    `${markerKey === 'reviewerMessage' ? 'REVIEWER_TO_OWNER' : 'OWNER_TO_REVIEWER'}_MESSAGE_UI=PASS`,
    `${markerKey === 'reviewerMessage' ? 'REVIEWER_TO_OWNER' : 'OWNER_TO_REVIEWER'}_MESSAGE_SERVER=PASS`,
    `MESSAGE_ID_SHA256=${digest(rows[0].id)}`,
  ]);
}

function postAuthor(state, markerKey) {
  return markerKey === 'rejectedPost' ? state.reviewer : state.disposable;
}

export async function verifyPost(markerKey, expectedStatus) {
  const state = readState();
  const marker = state.markers[markerKey];
  const author = postAuthor(state, markerKey);
  if (!marker) throw new Error('unknown_post_marker');
  const rows = await postsForMarker(state, marker, author);
  if (
    rows.length !== 1 || rows[0].author_id !== author.userId ||
    rows[0].moderation_status !== expectedStatus || rows[0].deleted_at != null ||
    !uuid(rows[0].id)
  ) throw new Error(`post_server_postcondition_failed:${markerKey}:${expectedStatus}`);
  if (expectedStatus === 'pending' && rows[0].reviewed_at != null) {
    throw new Error('pending_post_has_review_timestamp');
  }
  if (expectedStatus !== 'pending' && !rows[0].reviewed_at) {
    throw new Error('moderated_post_missing_review_timestamp');
  }
  if (!state.records.postIds.includes(rows[0].id)) {
    state.records.postIds.push(rows[0].id);
  }
  mask(rows[0].id);

  const visibilityAccount = expectedStatus === 'approved'
    ? state.reviewer
    : state.owner;
  const visibleToAccount = await request({
    route: `/rest/v1/bil_community_posts?id=eq.${rows[0].id}` +
      '&select=id,moderation_status,reviewed_at',
    token: visibilityAccount.accessToken,
  });
  if (!Array.isArray(visibleToAccount.data)) {
    throw new Error('post_visibility_query_invalid');
  }
  if (expectedStatus === 'approved') {
    if (
      visibleToAccount.data.length !== 1 ||
      visibleToAccount.data[0].moderation_status !== 'approved'
    ) throw new Error('approved_disposable_post_not_visible_to_reviewer');
    const balance = await creditBalance(
      state.disposable.accessToken,
      state.disposable.userId,
    );
    const original = state.records.disposable.initialCredits;
    const rewardDelta = balance.granted - original.granted;
    if (rewardDelta !== 5) {
      throw new Error('approval_reward_delta_not_exactly_five');
    }
    if (balance.used !== original.used || balance.reserved !== original.reserved) {
      throw new Error('approval_changed_unrelated_disposable_credit_state');
    }
    if (
      state.records.rewardDelta != null &&
      state.records.rewardDelta !== rewardDelta
    ) throw new Error('approval_reward_delta_changed');
    state.records.rewardDelta = rewardDelta;
    appendEvidence('cross-account-status.txt', [
      `APPROVAL_REWARD_DELTA_TOKENS=${rewardDelta}`,
      'APPROVAL_REWARD_BALANCE_POSTCONDITION=PASS',
    ]);
  } else if (visibleToAccount.data.length !== 0) {
    throw new Error('nonapproved_post_visible_to_owner');
  }
  atomicWriteState(state);
  const outcomeEvidence = {
    'approvedPost:pending': [
      'DISPOSABLE_PENDING_POST_AUTHENTICATED_SERVER=PASS',
      'NONAPPROVED_DISPOSABLE_POST_OWNER_DENIAL=PASS',
    ],
    'approvedPost:approved': [
      'OWNER_IPHONE_DISPOSABLE_POST_APPROVAL_UI_AND_SERVER=PASS',
      'APPROVED_DISPOSABLE_POST_REVIEWER_VISIBILITY=PASS',
    ],
    'rejectedPost:pending': [
      'REVIEWER_IPAD_POST_CREATE_UI_AND_SERVER_PENDING=PASS',
      'NONAPPROVED_REVIEWER_POST_OWNER_DENIAL=PASS',
    ],
    'rejectedPost:rejected': [
      'OWNER_IPHONE_REVIEWER_POST_REJECTION_UI_AND_SERVER=PASS',
      'REJECTED_REVIEWER_POST_OWNER_DENIAL=PASS',
    ],
    'restoredPost:pending': [
      'REINSTATED_DISPOSABLE_AUTHENTICATED_SERVER_WRITE=PASS',
      'RESTORED_PENDING_POST_OWNER_DENIAL=PASS',
    ],
  }[`${markerKey}:${expectedStatus}`];
  if (!outcomeEvidence) throw new Error('unknown_post_evidence_contract');
  appendEvidence('cross-account-status.txt', [
    ...outcomeEvidence,
    `POST_ID_SHA256=${digest(rows[0].id)}`,
  ]);
}

export async function verifyBlock() {
  const state = readState();
  const [blockRows, friendRows] = await Promise.all([
    select(state.owner.accessToken, 'bil_blocks', {
      select: 'blocker_id,blocked_id,created_at',
      blocker_id: `eq.${state.owner.userId}`,
      blocked_id: `eq.${state.disposable.userId}`,
    }),
    select(state.owner.accessToken, 'bil_friendships', {
      select: 'id,status',
      or: `(and(requester_id.eq.${state.owner.userId},addressee_id.eq.${state.disposable.userId}),and(requester_id.eq.${state.disposable.userId},addressee_id.eq.${state.owner.userId}))`,
    }),
  ]);
  if (
    blockRows.length !== 1 || blockRows[0].blocker_id !== state.owner.userId ||
    blockRows[0].blocked_id !== state.disposable.userId || friendRows.length !== 0
  ) throw new Error('owner_block_server_postcondition_failed');
  state.records.blockCreated = true;
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    'OWNER_IPHONE_BLOCK_UI=PASS',
    'BLOCK_SERVER_ROW=PASS',
    'BLOCK_ATOMIC_FRIENDSHIP_REMOVAL=PASS',
    `BLOCK_PAIR_SHA256=${digest(`${state.owner.userId}:${state.disposable.userId}`)}`,
  ]);
}

export async function verifyWriteDenied(markerKey, kind) {
  const state = readState();
  const marker = state.markers[markerKey];
  if (!marker) throw new Error('unknown_denial_marker');
  const table = kind === 'message' ? 'bil_messages' : 'bil_community_posts';
  const body = kind === 'message'
    ? {
        sender_id: state.disposable.userId,
        recipient_id: state.owner.userId,
        body: marker,
      }
    : {
        author_id: state.disposable.userId,
        body: marker,
        visibility: 'community',
        moderation_status: 'pending',
      };
  const result = await request({
    method: 'POST',
    route: `/rest/v1/${table}`,
    token: state.disposable.accessToken,
    body,
    allowed: [400, 401, 403, 409],
    prefer: 'return=representation',
  });
  if (result.status >= 200 && result.status < 300) {
    throw new Error('denied_write_unexpectedly_succeeded');
  }
  const rows = kind === 'message'
    ? await select(state.disposable.accessToken, 'bil_messages', {
        select: 'id', body: `eq.${marker}`,
      })
    : await postsForMarker(state, marker, state.disposable);
  if (rows.length !== 0) throw new Error('denied_write_left_server_row');
  appendEvidence('cross-account-status.txt', [
    `${markerKey.toUpperCase()}_AUTHENTICATED_SERVER_REQUEST_DENIAL=PASS`,
    `${markerKey.toUpperCase()}_NO_ROW_CREATED=PASS`,
  ]);
}

export async function createRestoredPost() {
  const state = readState();
  const marker = state.markers.restoredPost;
  const result = await request({
    method: 'POST',
    route: '/rest/v1/bil_community_posts',
    token: state.disposable.accessToken,
    body: {
      author_id: state.disposable.userId,
      body: marker,
      visibility: 'community',
      moderation_status: 'pending',
    },
    allowed: [201],
    prefer: 'return=representation',
  });
  if (!Array.isArray(result.data) || result.data.length !== 1) {
    throw new Error('restored_disposable_post_create_failed');
  }
  await verifyPost('restoredPost', 'pending');
}
