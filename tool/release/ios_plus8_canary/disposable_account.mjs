import crypto from 'node:crypto';

import {
  appendEvidence,
  atomicWriteState,
  creditBalance,
  digest,
  letters,
  mask,
  ownerAdmin,
  params,
  readState,
  request,
  requiredEnv,
  signIn,
  uuid,
} from './runtime.mjs';
import { disposableRunEmail } from './run_identity.mjs';
import {
  adminUsersByEmail,
  deleteAdminUser,
  serviceRequest,
  serviceSelect,
} from './service_runtime.mjs';

async function insertReturning(table, body, query = '') {
  const suffix = query ? `?${query}` : '';
  const result = await serviceRequest({
    method: 'POST',
    route: `/rest/v1/${table}${suffix}`,
    body,
    allowed: [200, 201],
    prefer: 'return=representation,resolution=merge-duplicates',
  });
  if (!Array.isArray(result.data) || result.data.length !== 1) {
    throw new Error(`disposable_insert_postcondition_failed:${table}`);
  }
  return result.data[0];
}

export function initializeDisposableState(state) {
  const email = disposableRunEmail();
  const displayName = `BIL QA ${letters(12)}`;
  mask(email, displayName);
  state.disposable = {
    email,
    displayName,
    created: false,
    userId: null,
    accessToken: null,
    refreshToken: null,
  };
  state.markers.individualReason = `reset ${letters(12)}`;
  state.markers.individualMessage = `BIL reset ${letters(18)}`;
  state.markers.targetNotification = `BIL notice ${letters(18)}`;
  state.markers.approvedPost = `BIL QA approve ${letters(18)}`;
  state.markers.blockedMessage = `BIL QA block ${letters(18)}`;
  state.markers.suspendedPost = `BIL QA suspend ${letters(18)}`;
  state.markers.restoredPost = `BIL QA restore ${letters(18)}`;
  state.records.disposable = {
    seededFriendshipId: null,
    approvedPostId: null,
    resetId: null,
    notificationId: null,
    initialCredits: { granted: 0, used: 0, reserved: 0 },
  };
}

export async function createDisposableAccount(state) {
  const email = state.disposable.email;
  const preexisting = await adminUsersByEmail(email);
  if (preexisting.length !== 0) {
    throw new Error('disposable_account_preexisted_exact_run');
  }
  const password = `${letters(24)}7a!`;
  mask(password);
  const created = await serviceRequest({
    method: 'POST',
    route: '/auth/v1/admin/users',
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: { qa_scope: 'ios-plus8-disposable' },
    },
    allowed: [200, 201],
  });
  const userId = String(created.data?.id ?? created.data?.user?.id ?? '');
  if (!uuid(userId)) throw new Error('disposable_account_create_invalid');
  mask(userId);
  state.disposable.userId = userId;
  state.disposable.created = true;
  atomicWriteState(state);

  const session = await signIn(email, password);
  mask(session.accessToken, session.refreshToken);
  state.disposable.accessToken = session.accessToken;
  state.disposable.refreshToken = session.refreshToken;
  const expiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
  const grant = await serviceRequest({
    method: 'POST',
    route: '/rest/v1/rpc/bil_set_ai_closed_test_access',
    body: {
      p_owner_id: userId,
      p_cohort: `ios-plus8-${requiredEnv('GITHUB_RUN_ID')}`,
      p_active: true,
      p_expires_at: expiresAt,
      p_reason: 'Disposable iOS +8 simulator QA account',
    },
  });
  if (
    grant.data?.owner_id !== userId || grant.data?.active !== true ||
    grant.data?.full_premium_ai_coach !== true
  ) throw new Error('disposable_premium_grant_postcondition_failed');
  await insertReturning('bil_public_profiles', {
    user_id: userId,
    display_name: state.disposable.displayName,
    locale_code: 'en',
    discoverable: true,
    allow_friend_requests: true,
    allow_messages_from: 'friends',
  }, params({ on_conflict: 'user_id' }));
  const policies = await serviceSelect('bil_content_policies', {
    select: 'version', active: 'eq.true', order: 'effective_at.desc', limit: '1',
  });
  if (policies.length === 1) {
    await insertReturning('bil_content_policy_acceptances', {
      user_id: userId,
      policy_version: policies[0].version,
    }, params({ on_conflict: 'user_id,policy_version' }));
  }
  const friendship = await insertReturning('bil_friendships', {
    requester_id: userId,
    addressee_id: state.owner.userId,
    status: 'accepted',
    responded_at: new Date().toISOString(),
  });
  const post = await request({
    method: 'POST',
    route: '/rest/v1/bil_community_posts',
    token: session.accessToken,
    body: {
      author_id: userId,
      body: state.markers.approvedPost,
      visibility: 'community',
      moderation_status: 'pending',
    },
    allowed: [201],
    prefer: 'return=representation',
  });
  if (!Array.isArray(post.data) || post.data.length !== 1 || !uuid(post.data[0]?.id)) {
    throw new Error('disposable_pending_post_seed_failed');
  }
  state.records.disposable.seededFriendshipId = friendship.id;
  state.records.disposable.approvedPostId = post.data[0].id;
  state.records.disposable.initialCredits = await creditBalance(
    session.accessToken,
    userId,
  );
  mask(friendship.id, post.data[0].id);
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    'DISPOSABLE_ACCOUNT_CREATED=PASS',
    'DISPOSABLE_EPHEMERAL_PREMIUM_GRANT=PASS',
    'DISPOSABLE_PROFILE_AND_POLICY=PASS',
    'DISPOSABLE_ACCEPTED_CONNECTION_SEEDED=PASS',
    `DISPOSABLE_ACCOUNT_SHA256=${digest(userId)}`,
    `DISPOSABLE_PENDING_POST_SHA256=${digest(post.data[0].id)}`,
  ]);
}

export async function verifyIndividualReset() {
  const state = readState();
  const target = state.disposable;
  const [credits, notices] = await Promise.all([
    creditBalance(target.accessToken, target.userId),
    serviceSelect('bil_ai_coach_reset_notices', {
      select: 'owner_id,reset_id,message',
      owner_id: `eq.${target.userId}`,
      message: `eq.${state.markers.individualMessage}`,
    }),
  ]);
  const initial = state.records.disposable.initialCredits;
  if (
    credits.granted !== initial.granted + 2500 ||
    credits.used !== initial.used || credits.reserved !== initial.reserved ||
    notices.length !== 1 || notices[0].owner_id !== target.userId ||
    !uuid(notices[0].reset_id)
  ) throw new Error('individual_reset_disposable_postcondition_failed');
  state.records.disposable.resetId = notices[0].reset_id;
  mask(notices[0].reset_id);
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    'OWNER_IPHONE_INDIVIDUAL_RESET_UI=PASS',
    'INDIVIDUAL_RESET_EXACT_MESSAGE=PASS',
    'INDIVIDUAL_RESET_PLUS_2500=PASS',
    `INDIVIDUAL_RESET_ID_SHA256=${digest(notices[0].reset_id)}`,
  ]);
}

export async function verifyTargetNotification() {
  const state = readState();
  const rows = await serviceSelect('bil_admin_notices', {
    select: 'owner_id,notification_id,notification_kind,body',
    owner_id: `eq.${state.disposable.userId}`,
    notification_kind: 'eq.custom',
    body: `eq.${state.markers.targetNotification}`,
  });
  if (
    rows.length !== 1 || rows[0].owner_id !== state.disposable.userId ||
    !uuid(rows[0].notification_id)
  ) throw new Error('target_notification_disposable_postcondition_failed');
  state.records.disposable.notificationId = rows[0].notification_id;
  mask(rows[0].notification_id);
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    'OWNER_IPHONE_TARGET_NOTIFICATION_UI=PASS',
    'TARGET_NOTIFICATION_EXACT_TEXT_AND_RECIPIENT=PASS',
    `TARGET_NOTIFICATION_ID_SHA256=${digest(rows[0].notification_id)}`,
  ]);
}

async function moderatorEntries(state) {
  const response = await ownerAdmin(state.owner.accessToken, {
    operation: 'moderator_list',
    idempotency_key: `qa-list:${crypto.randomUUID()}`,
  });
  if (!Array.isArray(response.data)) throw new Error('moderator_list_invalid');
  return response.data.filter((row) => row?.user_id === state.disposable.userId);
}

export async function verifyModerator(expected) {
  const state = readState();
  const entries = await moderatorEntries(state);
  if (entries.length !== (expected ? 1 : 0)) {
    throw new Error(`disposable_moderator_postcondition_failed:${expected}`);
  }
  appendEvidence('cross-account-status.txt', [
    `OWNER_IPHONE_MODERATOR_${expected ? 'ADD' : 'REMOVE'}_UI=PASS`,
    `DISPOSABLE_MODERATOR_SERVER_${expected ? 'PRESENT' : 'ABSENT'}=PASS`,
  ]);
}

export async function deleteDisposableAccount(state) {
  const email = state?.disposable?.email ?? disposableRunEmail();
  const matches = await adminUsersByEmail(email);
  if (matches.length > 1) throw new Error('multiple_disposable_accounts_found');
  if (matches.length === 1) await deleteAdminUser(String(matches[0].id));
  if ((await adminUsersByEmail(email)).length !== 0) {
    throw new Error('disposable_account_delete_postcondition_failed');
  }
}
