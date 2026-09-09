import crypto from 'node:crypto';
import fs from 'node:fs';

import {
  appendEvidence,
  atomicWriteState,
  blocks,
  creditBalance,
  digest,
  friendships,
  mask,
  ownerAdmin,
  requiredEnv,
  rpc,
  select,
  signIn,
  startedPath,
  suspendedMembers,
} from './runtime.mjs';
import { reviewerRunMarkers } from './run_identity.mjs';
import {
  createDisposableAccount,
  initializeDisposableState,
} from './disposable_account.mjs';
import { validateReviewerPremiumAiPreflight } from './reviewer_entitlement.mjs';

export async function bootstrap() {
  const ownerEmail = requiredEnv('OWNER_EMAIL');
  const ownerPassword = requiredEnv('OWNER_PASSWORD');
  const credentialsPath = requiredEnv('BIL_REVIEW_CREDENTIALS_PATH');
  const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  const reviewerEmail = String(credentials.email ?? '').trim();
  const reviewerPassword = String(credentials.password ?? '');
  if (!reviewerEmail || !reviewerPassword) {
    throw new Error('private_review_credentials_incomplete');
  }
  mask(ownerEmail, ownerPassword, reviewerEmail, reviewerPassword);
  const [owner, reviewer] = await Promise.all([
    signIn(ownerEmail, ownerPassword),
    signIn(reviewerEmail, reviewerPassword),
  ]);
  if (owner.userId === reviewer.userId) throw new Error('qa_accounts_not_independent');
  mask(
    owner.userId,
    owner.accessToken,
    owner.refreshToken,
    reviewer.userId,
    reviewer.accessToken,
    reviewer.refreshToken,
  );

  const [ownerProfileRows, reviewerProfileRows] = await Promise.all([
    select(owner.accessToken, 'bil_public_profiles', {
      select: 'user_id,display_name,discoverable,allow_friend_requests,allow_messages_from',
      user_id: `eq.${owner.userId}`,
    }),
    select(reviewer.accessToken, 'bil_public_profiles', {
      select: 'user_id,display_name,discoverable,allow_friend_requests,allow_messages_from',
      user_id: `eq.${reviewer.userId}`,
    }),
  ]);
  if (ownerProfileRows.length !== 1 || reviewerProfileRows.length !== 1) {
    throw new Error('community_profile_preflight_failed');
  }
  const ownerProfile = ownerProfileRows[0];
  const reviewerProfile = reviewerProfileRows[0];
  const ownerName = String(ownerProfile.display_name ?? '').trim();
  const reviewerName = String(reviewerProfile.display_name ?? '').trim();
  if (!ownerName || !reviewerName) throw new Error('community_display_name_missing');
  if (ownerProfile.discoverable !== true || ownerProfile.allow_friend_requests !== true) {
    throw new Error('owner_friend_request_precondition_failed');
  }
  mask(ownerName, reviewerName);

  const search = await rpc(reviewer.accessToken, 'bil_search_community_profiles', {
    p_query: ownerName,
    p_limit: 30,
  });
  const exactSearch = Array.isArray(search)
    ? search.filter((row) => String(row?.display_name ?? '').trim() === ownerName)
    : [];
  if (exactSearch.length !== 1 || exactSearch[0]?.user_id !== owner.userId) {
    throw new Error('owner_display_name_not_unique_for_safe_ui_request');
  }

  const [ownerModerator, reviewerModerator] = await Promise.all([
    rpc(owner.accessToken, 'bil_is_community_moderator'),
    rpc(reviewer.accessToken, 'bil_is_community_moderator'),
  ]);
  if (ownerModerator !== true || reviewerModerator !== false) {
    throw new Error('moderation_role_preflight_failed');
  }
  const reviewerDenied = await ownerAdmin(reviewer.accessToken, {
    operation: 'community_member_list',
    idempotency_key: `deny:${crypto.randomUUID()}`,
  }, [404]);
  if (reviewerDenied.status !== 404 || reviewerDenied.data?.error !== 'not_found') {
    throw new Error('reviewer_admin_denial_preflight_failed');
  }

  const [reviewerCredits, reviewerGrant, reviewerEntitlement, reviewerSubscription,
    reviewerUsage] = await Promise.all([
    creditBalance(reviewer.accessToken, reviewer.userId),
    select(reviewer.accessToken, 'bil_ai_closed_test_grants', {
      select: 'owner_id,active,expires_at',
      owner_id: `eq.${reviewer.userId}`,
    }),
    select(reviewer.accessToken, 'bil_entitlements', {
      select: 'owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,server_updated_at',
      owner_id: `eq.${reviewer.userId}`,
    }),
    select(reviewer.accessToken, 'bil_subscriptions', {
      select: 'owner_id,provider,product_id,plan_id,lifecycle,started_at,expires_at,grace_period_ends_at,verified_at',
      owner_id: `eq.${reviewer.userId}`,
    }),
    rpc(reviewer.accessToken, 'bil_get_ai_usage_status'),
  ]);
  const now = Date.now();
  const reviewerAccess = validateReviewerPremiumAiPreflight({
    expectedOwnerId: reviewer.userId,
    grantRows: reviewerGrant,
    entitlementRows: reviewerEntitlement,
    subscriptionRows: reviewerSubscription,
    usage: reviewerUsage,
    now,
  });
  if (!reviewerAccess.ok) {
    throw new Error(
      `reviewer_premium_ai_entitlement_preflight_failed:${reviewerAccess.reason}`,
    );
  }
  const state = {
    schema: 2,
    runId: crypto.randomUUID(),
    runDigest: '',
    createdAt: new Date().toISOString(),
    owner: { ...owner, displayName: ownerName },
    reviewer: { ...reviewer, displayName: reviewerName },
    markers: reviewerRunMarkers(),
    original: {
      friendshipCount: 0,
      blockCount: 0,
      reviewerSuspended: false,
      reviewerCredits,
      ownerModerator: true,
      reviewerModerator: false,
    },
    records: {
      friendshipId: null,
      messageIds: [],
      postIds: [],
      blockCreated: false,
      suspensionApplied: false,
      suspensionRestored: false,
      rewardDelta: null,
    },
  };
  initializeDisposableState(state);
  state.runDigest = digest(state.runId);
  const [friendRows, blockRows, suspended, activePolicies] = await Promise.all([
    friendships(state),
    blocks(state),
    suspendedMembers(owner.accessToken),
    select(owner.accessToken, 'bil_content_policies', {
      select: 'version',
      active: 'eq.true',
      order: 'effective_at.desc',
      limit: '2',
    }),
  ]);
  if (friendRows.length !== 0) {
    throw new Error('preexisting_friendship_must_not_be_overwritten');
  }
  if (blockRows.length !== 0) {
    throw new Error('preexisting_block_must_not_be_overwritten');
  }
  if (suspended.some((row) => row?.user_id === reviewer.userId)) {
    throw new Error('reviewer_was_already_suspended');
  }
  if (activePolicies.length !== 1) {
    throw new Error('community_policy_active_version_precondition_failed');
  }
  const version = String(activePolicies[0].version ?? '');
  for (const account of [owner, reviewer]) {
    const accepted = await select(account.accessToken, 'bil_content_policy_acceptances', {
      select: 'policy_version',
      user_id: `eq.${account.userId}`,
      policy_version: `eq.${version}`,
    });
    if (accepted.length !== 1) {
      throw new Error('community_policy_acceptance_precondition_failed');
    }
  }

  atomicWriteState(state);
  fs.writeFileSync(startedPath, `${state.runDigest}\n`, {
    encoding: 'utf8',
    mode: 0o600,
  });
  appendEvidence('cross-account-status.txt', [
    `CANARY_RUN_SHA256=${state.runDigest}`,
    'OWNER_IPHONE_IDENTITY=PASS',
    'APPLE_REVIEWER_IPAD_IDENTITY=PASS',
    'IDENTITIES_ARE_DISTINCT=PASS',
    'OWNER_MODERATOR_AUTHORITY=PASS',
    'REVIEWER_ADMIN_AND_MODERATOR_DENIAL=PASS',
    'ORIGINAL_FRIENDSHIP=NONE',
    'ORIGINAL_BLOCK=NONE',
    'ORIGINAL_REVIEWER_SUSPENSION=NONE',
    'ORIGINAL_REVIEWER_CREDIT_BALANCE=SNAPSHOT_PRIVATE',
    'APPLE_REVIEWER_ACTIVE_CLOSED_TEST_GRANT=PASS',
    'APPLE_REVIEWER_PREMIUM_AI_ENTITLEMENT=PASS',
    'APPLE_REVIEWER_ACTIVE_SUBSCRIPTION=PASS',
    `APPLE_REVIEWER_PREMIUM_AI_REPRESENTATION=${reviewerAccess.representation}`,
    'APPLE_REVIEWER_USABLE_AI_TOKENS_AT_LEAST_2500=PASS',
    'COMMUNITY_POLICY_PRECONDITION=PASS',
  ]);
  await createDisposableAccount(state);
}
