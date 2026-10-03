# BIL Community global architecture — 2026-10-03

## Authority boundaries

BIL Community is a public/social subsystem. It must never use private health measurements, body metrics, diary data, or subscription identity as implicit social data.

The durable database state is authoritative. Push notifications are delivery only. Realtime is an invalidation signal only. Client counters, reward claims, and push payloads never create authoritative state.

## Existing production foundations to preserve

- `bil_public_profiles`, `bil_social_handles_v2`, `bil_follows`, and `bil_friendships` already separate public identity, one-way follows, and mutual friendships.
- `bil_community_posts` plus the social-v2 like/save/comment tables already provide moderated publishing and interactions.
- `bil_community_notifications` is the durable in-app Community attention substrate. It currently emits `friend_accepted`; it will be evolved compatibly into the Activity inbox rather than replaced with a second competing source of truth.
- `private.bil_attention_snapshot_v1` remains the authoritative badge snapshot.
- The legacy moderated-post reward path grants AI credits directly through `bil_ai_credit_balances`. Those historical receipts remain historical AI-credit records. They are **not** BIL Gold and are not retroactively converted.

## BIL Gold

BIL Gold is spendable Community currency and is separate from Premium, subscriptions, trial quotas, store purchases, QA/admin grants, and the existing AI-credit ledger.

V1 uses:
- `bil_gold_ledger`: append-only authority with signed deltas, owner-scoped idempotency keys, payload digests, optional references, and explicit reversal entries.
- `bil_gold_accounts`: atomically maintained balance projection only; clients never mutate it.
- `private.bil_post_gold_ledger_v1`: the only v1 posting primitive. It is not executable by app roles.
- `bil_gold_balance_v1` and cursor-bounded `bil_gold_history_v1`: authenticated owner reads.

No reward amount or AI exchange rate is embedded in the ledger. Economic values belong in versioned server-side policy/configuration.

## Community XP and levels

XP is permanent reputation, not currency. Spending Gold never decreases XP or level.

V1 now uses an append-only XP event ledger, an owner XP projection, and a versioned level-policy table. The initial policy contains only Level 1 at 0 XP; future thresholds remain configurable instead of being baked into the client. Negative XP is forbidden except as an explicit reversal of a prior XP event.

## Activity inbox

Activity v2 now evolves `bil_community_notifications` in place with typed entity identity, safe copy keys, safe Community deep-link paths, bounded metadata, cursor pagination, per-kind unseen counts, and seen state. Target kinds are:
`friend_request`, `friend_accepted`, `post_like`, `post_save`, `comment`, `reply`, `follow`, `reward_earned`, `quest_completed`, `badge_earned`, and `challenge_update`.

Compatibility is explicit: v1 list/attention surfaces remain narrowed to `friend_accepted` until every shipped client that consumes Activity v2 can parse the broader kind set. No new kind is emitted merely because the schema accepts it. Blocked or suspended actors are filtered from Activity reads and attention counts. The Activity row is the source; push is derived delivery.

## Rewards and quests

Reward definitions are server-managed and versioned. Client code renders title/copy/progress/reward state but never decides eligibility or grants value.

Quest lifecycle:
`Go -> Pending -> Ready to claim -> Claimed`.

Progress and claims are owner-scoped and idempotent. A successful claim posts Gold through the private ledger primitive in the same transaction and emits a durable Activity event.

Posting rewards are quality rewards, not “post equals coins”. Policies will support moderation approval, unique meaningful engagement, caps, account trust, and anti-farming checks. Amounts stay configurable.

## Referrals

Deferred invites use an opaque invite code and server attribution. No reward is granted for sharing a link.

A referral can become reward-eligible only after a real distinct invitee account is attributed and the defined relationship/acceptance condition is satisfied. The same inviter/invitee pair is rewardable at most once. Device/integrity and abuse signals can block reward eligibility without exposing those signals to clients.

## Profiles

The global Community profile composes existing public profile, handle, follow/friend relationships, authored posts, reputation, badges, and privacy controls through bounded projection RPCs to avoid N+1 loading.

Own-profile UI may show exact Gold balance. Exact Gold balance is not public by default. Health/private-account data is never joined into the public Community projection.

Posts support Grid and List presentation from cursor-paginated author-post RPCs. Counts are server projections, not client full-table calculations.

## Topics and Circles

Topics and Circles are separate concepts:
- Topic: taxonomy/discovery metadata and ranked/featured state.
- Circle: membership container with public/private access, rules, moderators, feed, and optional challenges.

Neither will be implemented as free-form client-only tags with authority semantics. Sensitive health conditions are not default targeting dimensions.

## Anti-abuse invariants

- server-side grant decisions only
- owner-scoped idempotency + payload mismatch detection
- explicit reversals instead of ledger edits
- daily/weekly caps in policy
- no self rewards
- one-time pair constraints where applicable
- no delete/recreate farming
- rate limits and moderation gates
- integrity/device signals when available
- suspicious-reward audit and reconciliation
- bounded cursor pagination and indexed lookup paths

## Migration sequence

1. Friend-acceptance Activity and reliable push registration — complete.
2. Gold ledger foundation — isolated, no earn/spend product integration yet.
3. XP/reputation foundation — complete.
4. Activity schema expansion with backward-compatible v1/v2 reads — complete; new event emitters remain gated on v2 Flutter parsing.
5. Quest/reward definitions, progress, claim engine, and anti-abuse audit.
6. Referral/deferred-attribution contract.
7. Profile projection and authored-post pagination.
8. Rewards Center + AI Coach Earn entry.
9. Feed/Topics/Circles/composer expansion.
10. Security advisors, migration drift, transactional E2E, and mobile QA before any release build.
