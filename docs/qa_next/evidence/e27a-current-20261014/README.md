# Current-source isolated evidence — 2026-10-14

Source: `e27a58984bff50b4bcf45044ea9893f344307e85`, branch `integration/bil-qa-media-policy-20261011`, worktree `bil-ios36-audit-snapshot-20261014`. Dirty working-tree status had 692 entries with SHA-256 `831bafe7606a18ed710625f745ae845209b7547f86b36911aa45a444b9add89d` when this evidence set was captured.

- `postgres-cloud-v1-v2.json`: PostgreSQL 17.6 native, isolated loopback, synthetic accounts, 23/23 PASS. Command: `python -X utf8 tools/qa/bil_postgres_restore_v2_test.py --psql G:\BIL_Project\qa-runtime\postgresql-17.6\pgsql\bin\psql.exe`.
- `postgres-community-messages.json`: isolated native PostgreSQL, 16/16 PASS. Command: `python -X utf8 tools/qa/bil_postgres_message_delivery_v2_test.py --psql G:\BIL_Project\qa-runtime\postgresql-17.6\pgsql\bin\psql.exe`.
- `postgres-community-safety-review.json`: isolated native PostgreSQL, 17/17 PASS. Command: `python -X utf8 tools/qa/bil_postgres_community_safety_review_test.py --psql G:\BIL_Project\qa-runtime\postgresql-17.6\pgsql\bin\psql.exe`.
- `sqlite-postgres-sqlite-cycle.json`: Flutter integration 1/1 PASS over A SQLite → loopback HTTP bridge → PostgreSQL 17.6 → empty B SQLite, with synthetic auth. The runner was invoked directly through the installed Flutter Dart snapshot because the optional Windows wrapper insists on a visible native console. The test itself executed and passed in this chat session.

These are local synthetic tests, not Supabase Auth/PostgREST/Storage, Production, real accounts, physical devices, store builds, or TestFlight. Original output JSON is retained under ignored `build/` directories as well; this evidence copy contains only test results, no auth secrets or server config.
