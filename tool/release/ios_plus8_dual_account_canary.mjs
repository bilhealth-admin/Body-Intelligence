#!/usr/bin/env node

/**
 * Small fail-closed orchestrator for the manual +8 iOS dual-simulator canary.
 * Private sessions live only in a mode-0600 RUNNER_TEMP state file. Uploaded
 * evidence contains fixed status vocabulary and SHA-256 identifiers only.
 */

import {
  createRestoredPost,
  verifyBlock,
  verifyFriendAccepted,
  verifyFriendRequest,
  verifyMessage,
  verifyPost,
  verifyWriteDenied,
} from './ios_plus8_canary/community.mjs';
import {
  verifyIndividualReset,
  verifyModerator,
  verifyTargetNotification,
} from './ios_plus8_canary/disposable_account.mjs';
import { cleanup } from './ios_plus8_canary/cleanup_evidence.mjs';
import {
  getValue,
  scanEvidence,
} from './ios_plus8_canary/evidence_io.mjs';
import {
  verifyOwnerProtection,
  verifyReinstated,
  verifySuspended,
} from './ios_plus8_canary/owner_admin.mjs';
import { bootstrap } from './ios_plus8_canary/setup.mjs';
import { watchdog } from './ios_plus8_canary/watchdog_cleanup.mjs';

const mode = process.argv[2] ?? '';
const argument = process.argv[3] ?? '';
const operations = {
  bootstrap,
  'verify-friend-request': verifyFriendRequest,
  'verify-friend-accepted': verifyFriendAccepted,
  'verify-reviewer-message': () =>
    verifyMessage('reviewerMessage', 'reviewer', 'owner'),
  'verify-owner-message': () => verifyMessage('ownerMessage', 'owner', 'reviewer'),
  'verify-individual-reset': verifyIndividualReset,
  'verify-target-notification': verifyTargetNotification,
  'verify-moderator-added': () => verifyModerator(true),
  'verify-moderator-removed': () => verifyModerator(false),
  'verify-approved-pending': () => verifyPost('approvedPost', 'pending'),
  'verify-approved': () => verifyPost('approvedPost', 'approved'),
  'verify-rejected-pending': () => verifyPost('rejectedPost', 'pending'),
  'verify-rejected': () => verifyPost('rejectedPost', 'rejected'),
  'verify-block': verifyBlock,
  'verify-blocked-message-denied': () =>
    verifyWriteDenied('blockedMessage', 'message'),
  'verify-suspended': verifySuspended,
  'verify-suspended-post-denied': () =>
    verifyWriteDenied('suspendedPost', 'post'),
  'verify-reinstated': verifyReinstated,
  'create-restored-post': createRestoredPost,
  'verify-owner-protection': verifyOwnerProtection,
  cleanup,
  watchdog,
  get: () => getValue(argument),
  'scan-evidence': scanEvidence,
};

if (!(mode in operations)) throw new Error(`unknown_mode:${mode || 'empty'}`);
await operations[mode]();
