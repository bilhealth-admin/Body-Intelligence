# BIL Supabase account-deletion fail-safe audit

- Applied at: `2026-08-30T03:43:02Z`
- Verified at: `2026-08-30T03:44:02Z`
- Project: `body-intelligence-log` (`tgmanzhqulksykhslrzb`)
- Production migration: `20260830034302_disable_unsafe_account_deletion_cron`

## Result

`UNSAFE_SQL_ONLY_ACCOUNT_DELETION_WORKER_DISABLED=PASS`

Before the change, production `cron.job` contained active job ID `1`, named
`bil-account-data-deletion-15m`, scheduled every 15 minutes to execute
`private.bil_process_account_deletions(25)`. The superseded implementation
deleted `auth.users` directly and could leave the user's Storage object bytes
behind.

The production-safe migration now:

1. unschedules the old SQL-only cron job;
2. replaces `private.bil_process_account_deletions(integer)` with a fail-closed
   guard that raises `storage_api_account_deletion_worker_required`; and
3. revokes function execution from `public`, `anon`, and `authenticated`.

Read-back evidence after the migration:

- matching old or storage-first cron jobs: `0`;
- fail-closed guard text present in the live function: `true`;
- `anon` can execute the function: `false`;
- `authenticated` can execute the function: `false`;
- deletion requests at the time of the safety change: `0`.

New account-deletion requests remain durably `pending`; production can no
longer delete the Auth user through the unsafe database-only path.

## Intentionally not deployed yet

Migration `20260830093000_account_deletion_storage_cleanup.sql` and Edge
Function `account-data-deletion` were not deployed. They must be deployed
together only after the canonical function URL, matching internal worker
secret, and publishable/anon JWT gate value are configured in Vault and the
matching Edge Function secret is configured. A test account with nested files
in both BIL Storage buckets must then prove Storage deletion before Auth
deletion. No secret or user data is present in this audit.
