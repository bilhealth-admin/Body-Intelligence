import crypto from 'node:crypto';

import {
  appendEvidence,
  atomicWriteState,
  digest,
  letters,
  ownerAdmin,
  readState,
  requiredEnv,
  suspendedMembers,
  uuid,
} from './runtime.mjs';
import { serviceRpc } from './service_runtime.mjs';

export async function verifySuspended() {
  const state = readState();
  const reason = requiredEnv('BIL_QA_SUSPEND_REASON');
  const rows = await suspendedMembers(state.owner.accessToken);
  const exact = rows.filter(
    (row) => row?.user_id === state.disposable.userId && row?.reason === reason,
  );
  if (exact.length !== 1) {
    throw new Error('disposable_suspension_server_postcondition_failed');
  }
  state.records.suspensionApplied = true;
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    'OWNER_IPHONE_SUSPEND_UI=PASS',
    'DISPOSABLE_SUSPENSION_SERVER_STATE=PASS',
    `SUSPENSION_TARGET_SHA256=${digest(state.disposable.userId)}`,
    `SUSPENSION_REASON_SHA256=${digest(reason)}`,
  ]);
}

export async function verifyReinstated() {
  const state = readState();
  const reason = requiredEnv('BIL_QA_SUSPEND_REASON');
  const rows = await suspendedMembers(state.owner.accessToken);
  if (
    rows.some(
      (row) => row?.user_id === state.disposable.userId || row?.reason === reason,
    )
  ) throw new Error('disposable_reinstate_server_postcondition_failed');
  state.records.suspensionRestored = true;
  atomicWriteState(state);
  appendEvidence('cross-account-status.txt', [
    'OWNER_IPHONE_REINSTATE_UI=PASS',
    'DISPOSABLE_REINSTATE_SERVER_STATE=PASS',
  ]);
}

export async function verifyOwnerProtection() {
  const state = readState();
  const result = await ownerAdmin(state.owner.accessToken, {
    operation: 'community_member_suspend',
    idempotency_key: `owner-protect:${crypto.randomUUID()}`,
    email: state.owner.email,
    reason: `owner protection ${letters(10)}`,
  }, [409]);
  if (result.status !== 409 || result.data?.error !== 'protected_administrator') {
    throw new Error('owner_protection_denial_failed');
  }
  appendEvidence('cross-account-status.txt', [
    'PROTECTED_OWNER_SUSPEND_SERVER_DENIAL=PASS',
  ]);
}

export async function reinstateExactRun(state) {
  const reason = requiredEnv('BIL_QA_SUSPEND_REASON');
  const rows = await serviceRpc(
    'bil_list_suspended_community_members_for_admin',
    { p_actor_id: state.owner.userId },
  );
  if (!Array.isArray(rows)) throw new Error('cleanup_suspension_list_invalid');
  const targetId = state.disposable?.userId;
  const exact = rows.filter(
    (row) => row?.reason === reason && (!uuid(targetId) || row?.user_id === targetId),
  );
  if (exact.length > 1) throw new Error('multiple_exact_suspension_rows');
  if (exact.length === 1) {
    const result = await serviceRpc('bil_reinstate_community_member', {
      p_actor_id: state.owner.userId,
      p_user_id: exact[0].user_id,
      p_idempotency_key: `cleanup-reinstate:${crypto.randomUUID()}`,
    });
    if (result?.reinstated !== true) {
      throw new Error('cleanup_reinstate_failed');
    }
  }
}
