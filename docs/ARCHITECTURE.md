# Architecture

BIL uses a practical feature-first Flutter structure:

- `lib/app`: router, localization, environment, persisted app settings, themes.
- `lib/data/database`: Drift schema, explicit migrations, seed catalog.
- `lib/data/repositories`: local persistence operations and reactive queries.
- `lib/engine`: pure Dart health calculations and explainable intelligence.
- `lib/features`: Riverpod providers and screens grouped by user capability.
- `lib/shared`: reusable presentation components.

Drift/SQLite schema v21 is the local health-log source of truth. Meal-item nutrient snapshots
produce daily nutrition totals, and individual water entries produce hydration
totals. Legacy daily total columns are retained only so schema-v4 databases can
upgrade without losing data; current repositories do not write them.

User-originated records carry UUIDs, timestamps, revisions, tombstones where
useful, and a sync-status marker. These fields support versioned persistence
and recovery boundaries; their presence alone does not prove that a cloud
synchronization adapter is enabled.

## Authority boundaries

| State | Authority | Client consumers |
| --- | --- | --- |
| Signed-in owner | Supabase Auth session, verified server-side for privileged requests | Auth coordinators and owner-scoped providers |
| Health logs, profile, goals | Drift repositories and transactions | Riverpod queries; AI changes require the same reviewed write path |
| Paid subscriptions | Server-verified Apple/Google receipts and lifecycle rows | Entitlement repository and fail-closed cached access |
| Complimentary Premium | Separate administrator grant and short server lease | Commerce access merges it with valid store access; revocation removes only the grant |
| AI allowance and Boost | Server usage/reservation/settlement and credit ledger | Coach/Vision/Voice credit policies; Premium alone does not invent tokens |
| Community profiles, friends and posts | Authenticated Supabase RPCs, RLS, policy and moderation | Owner-scoped repositories; request results cannot be reused for another owner |
| Connected-health evidence | Native permission-bounded readings and local aggregation | Dashboard charts consume dated evidence, not decorative histories |

Community, friendships and private messaging are Free account features. Their
routes and friend actions do not depend on subscription, storefront, Boost or
administrator status. Server identity, relationship consent, blocks, suspension,
policy acceptance, moderation and rate limits still apply. This access never
creates a Premium entitlement or alters any paid subscription or AI balance.

Display-name edits from Profile, onboarding, the account gateway and Community
atomically persist the local name and a pending-sync marker. Owner-scoped
`DisplayNameSync` serializes cloud writes and clears that marker only after an
acknowledged write whose local snapshot is still current. Remote hydration
cannot overwrite a pending or newer edit. Offline failures retain the local
name; changing a private profile does not create a discoverable Community row.

The reset trigger tops up remaining Boost to 2,500, not by 2,500. Higher balances,
paid purchases and reservations are preserved. Administrative subscription
grants, token top-ups and paid subscriptions are deliberately different ledgers.

The engine imports no Flutter, Riverpod, Drift, or Supabase packages. Insights
are deterministic objects containing explanation, evidence, suggested action,
priority, and confidence. Plateau and possible water-retention indications are
gated by data sufficiency and are never diagnoses.

Supabase is disabled by default. Missing credentials leave the complete local
experience available and cloud controls visibly disabled.

Adaptive logging is derived from repeated local meal-item combinations and
requires an explicit user action before copying. Personal experiments store
hypothesis, controlled factors, required evidence, adherence, result,
confidence, and limitations. Challenges award only recorded supportive
behavior. Share Studio renders a local PNG and hides actual weight by default
and by implementation.

External services are represented by policies and capability states rather
than simulated implementations. Client builds contain no service-role keys,
payment secrets, AI provider secrets, administrator credentials, or signing
credentials.

Build-time environment profiles use `BIL_ENVIRONMENT` and default to
production-safe behavior. External feature flags are compile-time gates; remote
overrides remain disabled until a signed configuration service exists. Logging
is structured and redacts identity and health fields. Analytics is a replaceable
no-op boundary and crash reporting is local-only: neither uploads data or
pretends that an external service is configured. Framework, platform, and zoned
errors converge on the same privacy-safe boundary.

Repository CI formats, analyzes, tests, builds an Android debug artifact, and
uploads that artifact. Release signing and distribution remain separate
credentialed gates.
