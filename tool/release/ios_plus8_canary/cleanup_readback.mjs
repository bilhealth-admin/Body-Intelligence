import { serviceSelect } from './service_runtime.mjs';

export async function verifyCleanupZeroReadback(state, disposableId) {
  // RLS can deliberately hide tombstoned or rejected rows. A cleanup PASS is
  // therefore based on exact service-role read-back, never on UI visibility.
  for (const messageId of state.records.messageIds) {
    if ((await serviceSelect('bil_messages', {
      select: 'id', id: `eq.${messageId}`,
    })).length !== 0) throw new Error('cleanup_message_id_residue');
  }
  for (const postId of state.records.postIds) {
    if ((await serviceSelect('bil_community_posts', {
      select: 'id', id: `eq.${postId}`,
    })).length !== 0) throw new Error('cleanup_post_id_residue');
  }
  for (const marker of Object.values(state.markers)) {
    if ((await serviceSelect('bil_messages', {
      select: 'id', body: `eq.${marker}`,
    })).length !== 0) throw new Error('cleanup_message_marker_residue');
    if ((await serviceSelect('bil_community_posts', {
      select: 'id', body: `eq.${marker}`,
    })).length !== 0) throw new Error('cleanup_post_marker_residue');
  }
  if (state.records.friendshipId && (await serviceSelect('bil_friendships', {
    select: 'id', id: `eq.${state.records.friendshipId}`,
  })).length !== 0) throw new Error('cleanup_friendship_id_residue');
  const exactFriendRows = await serviceSelect('bil_friendships', {
    select: 'id,requester_id,addressee_id,status',
    or: `(
      and(requester_id.eq.${state.owner.userId},addressee_id.eq.${state.reviewer.userId}),
      and(requester_id.eq.${state.reviewer.userId},addressee_id.eq.${state.owner.userId})
    )`.replaceAll(/\s/g, ''),
  });
  if (exactFriendRows.length !== 0) {
    throw new Error('cleanup_exact_friend_pair_residue');
  }
  const blockFilters = [
    `and(blocker_id.eq.${state.owner.userId},blocked_id.eq.${state.reviewer.userId})`,
    `and(blocker_id.eq.${state.reviewer.userId},blocked_id.eq.${state.owner.userId})`,
  ];
  if (disposableId) blockFilters.push(
    `and(blocker_id.eq.${state.owner.userId},blocked_id.eq.${disposableId})`,
    `and(blocker_id.eq.${disposableId},blocked_id.eq.${state.owner.userId})`,
  );
  const exactBlockRows = await serviceSelect('bil_blocks', {
    select: 'blocker_id,blocked_id',
    or: `(${blockFilters.join(',')})`,
  });
  if (exactBlockRows.length !== 0) throw new Error('cleanup_exact_block_residue');
}
