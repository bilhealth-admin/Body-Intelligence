# Local PostgreSQL contracts

From the repository root (Node.js 24):

```sh
npm ci --prefix supabase/tests --ignore-scripts
npm test --prefix supabase/tests
```

PGlite is pinned in the adjacent lockfile, rather than loaded from an ignored
historical diagnostics directory. Each script starts and closes an isolated
in-memory PostgreSQL database. No account credentials, network connection,
Supabase deployment, device or media operations are involved in the tests.

The fixture baseline contains the relevant original schema/functions; tests
execute the real subsequent migrations, RPCs, constraints, roles and triggers.
It is not a complete production database migration rehearsal. PGlite serializes
queries: queued duplicates are covered, but independent-session lock contention
must be checked against PostgreSQL in a separate environment before deployment.

`community_free_access_test.mjs` executes the Free-community migration against
the real friendship RPCs, RLS and hardening triggers from the repository. It
proves Free requests/acceptance without granting Premium, and checks anonymous
access, ownership, blocks, suspension, recipient opt-out and rate limits. The
fixture is deliberately limited to friendship dependencies, not a replacement
for the complete Community policy/moderation integration suite.
