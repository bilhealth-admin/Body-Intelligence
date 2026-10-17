# BIL07 — Real PostgreSQL / PostgREST isolated JWT and RPC acceptance

This workflow runs an ephemeral PostgreSQL 16 database and PostgREST 12.2.8 inside GitHub Actions only. It applies the unchanged candidate BIL07 migrations to a fresh synthetic schema and tests actual JSON HTTP/RPC responses under three signed non-production owner tokens. It covers anon denial, member-only rooms, owner scopes, consent, idempotency, read receipts, moderator report decisions and removal.

Files under supabase/tests/fixtures are synthetic fixtures, never migrations: the fake consent checker accepts a test-only JWT field, whereas the real server must use durable community policy acceptance. Do NOT ship this fixture or its JWT/database passwords or treat it as equivalent to Supabase Auth. Existing PGlite and widget tests remain separate.

A full local Supabase Auth/PostgREST/RLS stack and physical devices will still be needed for release approval. No customer data, production server, TestFlight, Play or Codex worktree is altered here.
