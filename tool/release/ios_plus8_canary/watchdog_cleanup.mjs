import crypto from 'node:crypto';

import {
  mask,
  pairFilter,
  params,
  requiredEnv,
  signIn,
  uuid,
} from './runtime.mjs';
import { deleteDisposableAccount } from './disposable_account.mjs';
import { disposableRunEmail, reviewerRunMarkers } from './run_identity.mjs';
import {
  adminUsersByEmail,
  serviceRequest,
  serviceRpc,
  serviceSelect,
} from './service_runtime.mjs';

async function deleteRows(table, values) {
  await serviceRequest({
    method: 'DELETE',
    route: `/rest/v1/${table}?${params(values)}`,
    allowed: [200, 204],
    prefer: 'return=minimal',
  });
}

async function reinstateRun(owner, reason) {
  const rows = await serviceRpc(
    'bil_list_suspended_community_members_for_admin',
    { p_actor_id: owner.userId },
  );
  if (!Array.isArray(rows)) throw new Error('watchdog_suspension_list_invalid');
  const exact = rows.filter((row) => row?.reason === reason);
  if (exact.length > 1) throw new Error('watchdog_multiple_exact_suspensions');
  if (exact.length === 1) {
    const userId = String(exact[0].user_id ?? '');
    if (!uuid(userId)) throw new Error('watchdog_invalid_target');
    mask(userId);
    const restored = await serviceRpc('bil_reinstate_community_member', {
      p_actor_id: owner.userId,
      p_user_id: userId,
      p_idempotency_key: `watchdog:${crypto.randomUUID()}`,
    });
    if (restored?.reinstated !== true) throw new Error('watchdog_reinstate_failed');
  }
  const postcondition = await serviceRpc(
    'bil_list_suspended_community_members_for_admin',
    { p_actor_id: owner.userId },
  );
  if (!Array.isArray(postcondition)) {
    throw new Error('watchdog_suspension_postcondition_invalid');
  }
  if (postcondition.some((row) => row?.reason === reason)) {
    throw new Error('watchdog_reinstate_postcondition_failed');
  }
}

async function cleanReviewerOwnerRun(owner, reviewerId, disposableExists) {
  const markers = reviewerRunMarkers();
  const friendPair = pairFilter(owner.userId, reviewerId);
  const messagePair = friendPair
    .replaceAll('requester_id', 'sender_id')
    .replaceAll('addressee_id', 'recipient_id');
  const messageBodies = [markers.reviewerMessage, markers.ownerMessage];
  const markerRows = [];
  for (const body of messageBodies) {
    markerRows.push(...await serviceSelect('bil_messages', {
      select: 'id', body: `eq.${body}`, or: messagePair,
    }));
  }
  const postRows = await serviceSelect('bil_community_posts', {
    select: 'id', author_id: `eq.${reviewerId}`,
    body: `eq.${markers.rejectedPost}`,
  });
  const runAttributed = disposableExists || markerRows.length > 0 || postRows.length > 0;
  for (const body of messageBodies) {
    await deleteRows('bil_messages', { body: `eq.${body}`, or: messagePair });
  }
  await deleteRows('bil_community_posts', {
    author_id: `eq.${reviewerId}`,
    body: `eq.${markers.rejectedPost}`,
  });
  const blockPair = friendPair
    .replaceAll('requester_id', 'blocker_id')
    .replaceAll('addressee_id', 'blocked_id');
  const [friendRows, blockRows] = await Promise.all([
    serviceSelect('bil_friendships', { select: 'id', or: friendPair }),
    serviceSelect('bil_blocks', {
      select: 'blocker_id,blocked_id', or: blockPair,
    }),
  ]);
  if (runAttributed) {
    await deleteRows('bil_friendships', { or: friendPair });
    await deleteRows('bil_blocks', { or: blockPair });
  } else if (friendRows.length !== 0 || blockRows.length !== 0) {
    throw new Error('watchdog_unattributed_pair_state_not_mutated');
  }

  for (const body of messageBodies) {
    if ((await serviceSelect('bil_messages', {
      select: 'id', body: `eq.${body}`, or: messagePair,
    })).length !== 0) throw new Error('watchdog_message_residue');
  }
  if ((await serviceSelect('bil_community_posts', {
    select: 'id', author_id: `eq.${reviewerId}`,
    body: `eq.${markers.rejectedPost}`,
  })).length !== 0) throw new Error('watchdog_reviewer_post_residue');
  if ((await serviceSelect('bil_friendships', {
    select: 'id', or: friendPair,
  })).length !== 0) throw new Error('watchdog_friend_pair_residue');
  if ((await serviceSelect('bil_blocks', {
    select: 'blocker_id,blocked_id', or: blockPair,
  })).length !== 0) throw new Error('watchdog_block_pair_residue');
}

export async function watchdog() {
  const ownerEmail = requiredEnv('OWNER_EMAIL');
  const ownerPassword = requiredEnv('OWNER_PASSWORD');
  const reviewerEmail = requiredEnv('REVIEWER_EMAIL');
  const reason = requiredEnv('BIL_QA_SUSPEND_REASON');
  mask(ownerEmail, ownerPassword, reviewerEmail);
  const owner = await signIn(ownerEmail, ownerPassword);
  mask(owner.userId, owner.accessToken, owner.refreshToken);
  await reinstateRun(owner, reason);

  const disposableMatches = await adminUsersByEmail(disposableRunEmail());
  if (disposableMatches.length > 1) {
    throw new Error('watchdog_multiple_disposable_accounts');
  }
  const reviewerMatches = await adminUsersByEmail(reviewerEmail);
  if (reviewerMatches.length !== 1 || !uuid(reviewerMatches[0]?.id)) {
    throw new Error('watchdog_reviewer_identity_not_exact');
  }
  const reviewerId = String(reviewerMatches[0].id);
  mask(reviewerId);
  await cleanReviewerOwnerRun(owner, reviewerId, disposableMatches.length === 1);
  await deleteDisposableAccount();
  process.stdout.write('INDEPENDENT_REINSTATE_WATCHDOG=PASS\n');
  process.stdout.write('INDEPENDENT_REVIEWER_OWNER_RESIDUE_WATCHDOG=PASS\n');
  process.stdout.write('INDEPENDENT_DISPOSABLE_ACCOUNT_DELETE=PASS\n');
}
