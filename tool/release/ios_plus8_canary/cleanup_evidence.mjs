import crypto from 'node:crypto';
import fs from 'node:fs';

import { reinstateExactRun } from './owner_admin.mjs';
import { deleteDisposableAccount } from './disposable_account.mjs';
import { verifyCleanupZeroReadback } from './cleanup_readback.mjs';
import {
  atomicWriteState,
  blocks,
  creditBalance,
  evidence,
  evidenceDir,
  friendships,
  mask,
  messagesForMarker,
  params,
  postsForMarker,
  readState,
  refresh,
  request,
  requiredEnv,
  rpc,
  startedPath,
  statePath,
} from './runtime.mjs';
import {
  serviceRequest,
  serviceRpc,
  serviceSelect,
} from './service_runtime.mjs';

async function patchSoftDeletePost(state, postId) {
  await request({
    method: 'PATCH',
    route: `/rest/v1/bil_community_posts?${params({
      id: `eq.${postId}`,
      author_id: `eq.${state.reviewer.userId}`,
    })}`,
    token: state.reviewer.accessToken,
    body: {
      deleted_at: new Date().toISOString(),
      media_url: null,
      media_object_path: null,
      media_mime_type: null,
      media_bytes: null,
      media_width: null,
      media_height: null,
    },
    allowed: [200, 204],
    prefer: 'return=minimal',
  });
}

async function deleteRows(token, table, values) {
  await request({
    method: 'DELETE',
    route: `/rest/v1/${table}?${params(values)}`,
    token,
    allowed: [200, 204],
    prefer: 'return=minimal',
  });
}

async function serviceDeleteRows(table, values) {
  await serviceRequest({
    method: 'DELETE',
    route: `/rest/v1/${table}?${params(values)}`,
    allowed: [200, 204],
    prefer: 'return=minimal',
  });
}

export async function cleanup() {
  fs.mkdirSync(evidenceDir, { recursive: true });
  if (!fs.existsSync(statePath)) {
    if (fs.existsSync(startedPath)) {
      throw new Error('private_state_missing_after_canary_start');
    }
    evidence('cleanup-status.txt', [
      'CANARY_BACKEND_CLEANUP=NOT_STARTED_NO_MUTATIONS',
    ]);
    return;
  }
  const state = readState();
  mask(
    state.owner.email,
    state.owner.userId,
    state.owner.accessToken,
    state.owner.refreshToken,
    state.owner.displayName,
    state.reviewer.email,
    state.reviewer.userId,
    state.reviewer.accessToken,
    state.reviewer.refreshToken,
    state.reviewer.displayName,
    state.disposable?.email,
    state.disposable?.userId,
    state.disposable?.accessToken,
    state.disposable?.refreshToken,
    state.disposable?.displayName,
    state.records.friendshipId,
    state.records.messageIds,
    state.records.postIds,
  );
  await refresh(state.owner);
  await refresh(state.reviewer);
  if (state.disposable?.accessToken && state.disposable?.refreshToken) {
    await refresh(state.disposable);
  }
  atomicWriteState(state);

  // Reinstate first so privacy-preserving author cleanup cannot be blocked.
  await reinstateExactRun(state);

  for (const marker of [state.markers.reviewerMessage, state.markers.ownerMessage]) {
    const messageRows = await messagesForMarker(
      state,
      marker,
      state.reviewer.accessToken,
    );
    for (const row of messageRows) {
      await rpc(state.owner.accessToken, 'bil_delete_message', {
        p_message_id: row.id,
      });
      await rpc(state.reviewer.accessToken, 'bil_delete_message', {
        p_message_id: row.id,
      });
      await serviceDeleteRows('bil_messages', { id: `eq.${row.id}` });
    }
  }
  const reviewerPostRows = await postsForMarker(
    state,
    state.markers.rejectedPost,
    state.reviewer,
  );
  for (const row of reviewerPostRows) {
    await patchSoftDeletePost(state, row.id);
    await serviceDeleteRows('bil_community_posts', { id: `eq.${row.id}` });
  }

  await deleteRows(state.owner.accessToken, 'bil_blocks', {
    blocker_id: `eq.${state.owner.userId}`,
    blocked_id: `eq.${state.reviewer.userId}`,
  });
  await deleteRows(state.reviewer.accessToken, 'bil_blocks', {
    blocker_id: `eq.${state.reviewer.userId}`,
    blocked_id: `eq.${state.owner.userId}`,
  });
  await deleteRows(state.owner.accessToken, 'bil_friendships', {
    or: `(
      and(requester_id.eq.${state.owner.userId},addressee_id.eq.${state.reviewer.userId}),
      and(requester_id.eq.${state.reviewer.userId},addressee_id.eq.${state.owner.userId})
    )`.replaceAll(/\s/g, ''),
  });

  const [friendRows, blockRows, suspended, reviewerCredits] = await Promise.all([
    friendships(state),
    blocks(state),
    serviceRpc('bil_list_suspended_community_members_for_admin', {
      p_actor_id: state.owner.userId,
    }),
    creditBalance(state.reviewer.accessToken, state.reviewer.userId),
  ]);
  if (!Array.isArray(suspended)) {
    throw new Error('cleanup_suspension_postcondition_invalid');
  }
  if (friendRows.length !== state.original.friendshipCount) {
    throw new Error('cleanup_friendship_postcondition_failed');
  }
  if (blockRows.length !== state.original.blockCount) {
    throw new Error('cleanup_block_postcondition_failed');
  }
  const reason = requiredEnv('BIL_QA_SUSPEND_REASON');
  if (
    suspended.some(
      (row) => row?.user_id === state.reviewer.userId || row?.reason === reason,
    )
  ) throw new Error('cleanup_reinstate_postcondition_failed');
  for (const marker of Object.values(state.markers)) {
    if ((await messagesForMarker(state, marker, state.owner.accessToken)).length !== 0) {
      throw new Error('cleanup_owner_message_visibility_failed');
    }
    if (
      (await messagesForMarker(state, marker, state.reviewer.accessToken)).length !== 0
    ) throw new Error('cleanup_reviewer_message_visibility_failed');
    if ((await postsForMarker(state, marker)).length !== 0) {
      throw new Error('cleanup_post_visibility_failed');
    }
  }
  const expectedRewardDelta = state.records.rewardDelta ?? 0;
  if (
    reviewerCredits.granted !== state.original.reviewerCredits.granted ||
    reviewerCredits.used !== state.original.reviewerCredits.used ||
    reviewerCredits.reserved !== state.original.reviewerCredits.reserved
  ) throw new Error('cleanup_reviewer_credit_snapshot_postcondition_failed');

  const disposableId = state.disposable?.userId;
  if (disposableId) {
    const moderators = await serviceRpc(
      'bil_list_community_moderators_for_admin',
      { p_actor_id: state.owner.userId },
    );
    if (!Array.isArray(moderators)) {
      throw new Error('cleanup_disposable_moderator_list_invalid');
    }
    const exactModerators = moderators.filter(
      (row) => row?.user_id === disposableId,
    );
    if (exactModerators.length > 1) {
      throw new Error('cleanup_duplicate_disposable_moderator');
    }
    if (exactModerators.length === 1) {
      const removed = await serviceRpc('bil_remove_community_moderator', {
        p_actor_id: state.owner.userId,
        p_user_id: disposableId,
        p_idempotency_key: `cleanup-moderator:${crypto.randomUUID()}`,
      });
      if (removed !== true) throw new Error('cleanup_moderator_remove_failed');
    }
  }
  await deleteDisposableAccount(state);
  if (disposableId) {
    const residueQueries = [
      ['bil_public_profiles', { select: 'user_id', user_id: `eq.${disposableId}` }],
      ['bil_ai_credit_balances', { select: 'owner_id', owner_id: `eq.${disposableId}` }],
      ['bil_ai_coach_reset_notices', { select: 'owner_id', owner_id: `eq.${disposableId}` }],
      ['bil_admin_notices', { select: 'owner_id', owner_id: `eq.${disposableId}` }],
      ['bil_community_posts', { select: 'id', author_id: `eq.${disposableId}` }],
      ['bil_friendships', {
        select: 'id',
        or: `(requester_id.eq.${disposableId},addressee_id.eq.${disposableId})`,
      }],
      ['bil_blocks', {
        select: 'blocker_id',
        or: `(blocker_id.eq.${disposableId},blocked_id.eq.${disposableId})`,
      }],
    ];
    for (const [table, query] of residueQueries) {
      if ((await serviceSelect(table, query)).length !== 0) {
        throw new Error(`disposable_public_residue:${table}`);
      }
    }
  }

  await verifyCleanupZeroReadback(state, disposableId);

  evidence('cleanup-status.txt', [
    'REINSTATE_FIRST=PASS',
    'MESSAGE_TOMBSTONES_BOTH_PARTIES_THEN_HARD_DELETE=PASS',
    'FRIENDSHIP_RESTORED_TO_ORIGINAL_NONE=PASS',
    'BLOCK_ROWS_RESTORED_TO_ORIGINAL_NONE=PASS',
    'REVIEWER_POST_SOFT_DELETE_THEN_HARD_DELETE=PASS',
    'REVIEWER_NEVER_SUSPENDED=PASS',
    'REVIEWER_CREDIT_UNCHANGED=PASS',
    `DISPOSABLE_APPROVAL_REWARD_BEFORE_ACCOUNT_DELETE=${expectedRewardDelta}`,
    'DISPOSABLE_ACCOUNT_AND_PUBLIC_ROWS_DELETED=PASS',
    'SERVICE_ROLE_EXACT_IDS_AND_MARKERS_ZERO_READBACK=PASS',
    'CANARY_BACKEND_CLEANUP=PASS',
    'EXPECTED_IMMUTABLE_RESIDUALS=PII-minimized community lifecycle and administrator audit ledgers required by server policy; no reviewer credit mutation',
  ]);
}
