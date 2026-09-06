import fs from 'node:fs';
import path from 'node:path';

import {
  evidence,
  evidenceDir,
  readState,
  startedPath,
  statePath,
} from './runtime.mjs';

export function getValue(argument) {
  const state = readState();
  const allowed = {
    owner_id: state.owner.userId,
    reviewer_id: state.reviewer.userId,
    owner_name: state.owner.displayName,
    reviewer_name: state.reviewer.displayName,
    reviewer_message: state.markers.reviewerMessage,
    owner_message: state.markers.ownerMessage,
    approved_post: state.markers.approvedPost,
    rejected_post: state.markers.rejectedPost,
    blocked_message: state.markers.blockedMessage,
    suspended_post: state.markers.suspendedPost,
    restored_post: state.markers.restoredPost,
    disposable_name: state.disposable.displayName,
    disposable_email: state.disposable.email,
    individual_reason: state.markers.individualReason,
    individual_message: state.markers.individualMessage,
    target_notification: state.markers.targetNotification,
  };
  if (!(argument in allowed)) throw new Error('private_state_key_not_allowed');
  process.stdout.write(String(allowed[argument]));
}

function sensitiveValues(state) {
  if (state == null) return [];
  return [
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
    ...Object.values(state.markers),
    ...state.records.messageIds,
    ...state.records.postIds,
    state.records.friendshipId,
    state.records.disposable?.seededFriendshipId,
    state.records.disposable?.approvedPostId,
    state.records.disposable?.resetId,
    state.records.disposable?.notificationId,
  ].filter((value) => typeof value === 'string' && value.length > 1);
}

function evidenceFiles() {
  const files = [];
  const walk = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) walk(target);
      else if (entry.isFile()) files.push(target);
    }
  };
  walk(evidenceDir);
  return files;
}

export function scanEvidence() {
  const canaryStarted = fs.existsSync(startedPath);
  if (canaryStarted && !fs.existsSync(statePath)) {
    throw new Error('private_state_missing_after_canary_start');
  }
  const state = fs.existsSync(statePath) ? readState() : null;
  const exactSensitive = sensitiveValues(state);
  for (const file of evidenceFiles()) {
    const bytes = fs.readFileSync(file);
    for (const secret of exactSensitive) {
      if (bytes.includes(Buffer.from(secret, 'utf8'))) {
        throw new Error(
          `artifact_exact_private_value_detected:${path.basename(file)}`,
        );
      }
    }
    const extension = path.extname(file).toLowerCase();
    if (['.txt', '.json', '.log', '.xml', '.plist'].includes(extension)) {
      const text = bytes.toString('utf8');
      if (
        /eyJ[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/.test(text)
      ) throw new Error(`artifact_jwt_detected:${path.basename(file)}`);
    }
  }
  evidence('artifact-scan-status.txt', [
    `EXACT_PRIVATE_VALUE_SCAN=${state == null ? 'NOT_APPLICABLE_CANARY_NOT_STARTED' : 'PASS'}`,
    'TEXT_JWT_SCAN=PASS',
    'AUTHENTICATED_RAW_UI_AND_LOGS_EXCLUDED=true',
    'ARTIFACT_PRIVACY_SCAN=PASS',
  ]);
}
