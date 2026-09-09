# Cloudflare staging-isolation closure — 2026-09-08

## Outcome

**FIXED IN SOURCE; ISOLATED RESOURCES NOT YET PROVISIONED.** Unsafe staging
deployment is now blocked before Wrangler can upload a Worker. No Worker, R2
object, route, secret, or Cloudflare setting was changed by this recovery.

The live read-only inventory contains only the production buckets
`bil-premium-workouts-2026-v1` and `bil-recipes-2026-v1`. The existing staging
Worker remains present, but the checked-in `env.staging` configuration points
to the production Supabase project/key and those same two production buckets.
Naming the Worker "staging" therefore did not provide data isolation.

Cloudflare documents that environment variables and bindings are
non-inheritable and must be defined separately for every Wrangler environment:

- <https://developers.cloudflare.com/workers/wrangler/environments/>
- <https://developers.cloudflare.com/workers/local-development/>

## Source change

`cloudflare/workout-runtime/scripts/verify-staging-isolation.mjs` validates the
deployment configuration before either staging dry-run or deploy. It rejects:

- a missing staging environment or a reused Worker name;
- staging custom-domain routes or disabled `workers_dev`;
- missing, placeholder, or production-equal Supabase URL/publishable key;
- missing or duplicate R2 bindings;
- placeholder or production-equal R2 buckets for every production binding.

URL trailing slashes, surrounding whitespace, and R2 bucket-name case cannot
bypass the comparison. `package.json` makes this check a prerequisite for both
`dry-run:staging` and `deploy:staging`.

## Verification

| Check | Result |
| --- | --- |
| Generated Worker binding types + TypeScript | PASS |
| Staging-isolation unit tests | 5/5 PASS |
| Worker tests | 23/23 PASS |
| Check against current `wrangler.jsonc` | EXPECTED BLOCK |
| `npm run dry-run:staging` | EXPECTED BLOCK before Wrangler upload |

The current guard reports four concrete collisions: production Supabase URL,
production Supabase publishable key, production workout R2 bucket, and
production recipe R2 bucket.

## Required external provisioning

Provision a genuinely separate Supabase project plus separate workout and
recipe R2 buckets, then replace only the staging bindings and run:

```powershell
npm run check:staging-isolation
npm run dry-run:staging
```

Do not bypass the guard and do not put placeholder resource names into the
configuration. Creating those resources can affect billing and requires owner
resource selection; this recovery therefore did not create them implicitly.

## Rollback

Reverting the package-script and verifier changes restores the old commands,
but doing so would re-enable an unsafe path to production data. No live
Cloudflare rollback is required because no deployment or data mutation occurred.
