# BIL wellness media runtime

This directory contains the local, not-yet-deployed Cloudflare delivery layer
for the reviewed Home Training (200 movements), Gym Programs (102 movements),
and 1,500 canonical recipe preview images. One Worker keeps the two private R2
buckets behind separate `WORKOUTS` and `RECIPES` bindings.

The 302 logical MP4 records already belong to the existing R2 release. This
runtime never copies or re-uploads them. The deterministic builder verifies the
local SHA-256 and byte-length pins, derives a real middle-frame WebP poster for
each record, and emits exactly:

- 302 authenticated poster objects;
- 2 authenticated, content-addressed schema-v2 pack objects; and
- 1 public, content-addressed catalog object.

The generated upload plan therefore contains 305 runtime objects and zero MP4
objects. Its combined storage projection is below the configured 9.5 GB safety
ceiling. A separate generated 606-key allowlist contains exactly the 302
existing videos, 302 posters, and two packs that the Worker may serve.

Recipe delivery does not create or mutate an R2 object. The Worker imports the
release-pinned `recipe-images.json` contract (SHA-256
`e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3`)
and converts its 1,500 unique canonical IDs into a fixed in-bundle allowlist.
Every entry pins the private object key, SHA-256, byte length, MIME type, and
dimensions.

## Runtime boundary

The Worker exposes three routes:

- `GET|HEAD /v2/manifest/<exact-sha-pinned-name>.json` is public. No alias or
  mutable `latest.json` route exists.
- `GET|HEAD /v2/objects/<allowlisted-key>` requires a valid Supabase Bearer JWT
  and a current premium entitlement. The Worker checks asymmetric JWTs against
  the Supabase JWKS, delegates legacy HS256 validation to Supabase Auth, then
  queries owner-scoped subscription/closed-test rows through RLS with the same
  user token. Public JWKS are cached briefly per isolate; entitlement rows are
  not cached. The boundary fails closed on unavailable or stale authority.
- `GET|HEAD /v3/recipes/images/<canonical-id>/<sha256>` is a public discovery
  preview. The path must match one exact manifest ID and its exact digest; it
  never accepts an R2 key, filename alias, encoded alias, or mutable latest
  route. Recipe previews were already classified `public, immutable` by the
  media upload plan and remain visible beneath the existing premium glass;
  ingredients, instructions, nutrition actions, and paid interaction are not
  served by this route.

Objects are streamed directly from their R2 binding. Byte ranges, ETags,
conditional requests, MIME metadata, exact-origin CORS, and the appropriate
private/public cache directives are preserved. Recipe responses additionally
fail closed unless the R2 byte length and MIME agree with the signed mapping.
Flutter receives no bucket/key and verifies the exact SHA-256 before promoting
a preview into its content-addressed media cache. Its Supabase Bearer allowlist
continues to cover protected workout paths only, so public recipe requests
never receive a session credential. The Worker has no service-role key.

## Reproducible local verification

From the repository root:

```powershell
python .\tool\wellness_content\build_cloudflare_workout_runtime.py --poster-workers 4
python -m unittest tool.wellness_content.test_build_cloudflare_workout_runtime tool.wellness_content.test_publish_wellness_catalog
& .\cloudflare\workout-runtime\scripts\Publish-RuntimeObjects.ps1
```

The first command always regenerates all posters so an existing file can never
silently affect the signed runtime plan. It also pins the 302-video upload
ledger, prompt/contracts metadata inputs, and ffmpeg/ffprobe toolchain.

Then verify the Worker:

```powershell
Set-Location .\cloudflare\workout-runtime
npm ci
npm run types
npm run check
npm test
npm run dry-run
```

`Publish-RuntimeObjects.ps1` is validation-only unless `-Execute` is supplied.
The validation checks every local size and SHA-256 and rejects any plan that
contains an MP4 before invoking Wrangler.

## Exact deployment plan (not executed)

Deployment requires explicit release approval. Once approved:

1. Re-run every command in **Reproducible local verification** and confirm the
   summary remains `home=200 gym=102 posters=302 runtimeObjects=305
   videoUploads=0` and the catalog SHA is unchanged.
2. In `cloudflare/workout-runtime`, run `npx wrangler whoami` and confirm the
   intended Cloudflare account owns `bilhealth.com` and the existing
   `bil-premium-workouts-2026-v1` and `bil-recipes-2026-v1` R2 buckets. Run
   `npx wrangler r2 bucket info bil-premium-workouts-2026-v1 --json` and check
   `npx wrangler r2 bucket info bil-recipes-2026-v1 --json`; check the R2
   dashboard metrics against the audited inventory before creating any new
   runtime object.
3. Upload only the verified runtime plan:

   ```powershell
   Set-Location <repository-root>
   & .\cloudflare\workout-runtime\scripts\Publish-RuntimeObjects.ps1 -Execute
   ```

   The script creates the 305 content-pinned JSON/WebP objects. It cannot upload
   any `.mp4` object and does not delete or overwrite a mutable alias.
4. Return to `cloudflare/workout-runtime`, run `npm run dry-run:staging`, review
   the bundle, then run `npm run deploy:staging`. This creates a separate
   workers.dev staging Worker with no production custom-domain route.
5. Put an entitled staging user's short-lived access token in the process-only
   `BIL_STAGING_BEARER` environment variable. The inventory check verifies the
   byte length of all 302 existing videos without downloading them, and streams
   the 304 protected runtime objects plus the public manifest to temporary files
   to verify their exact SHA-256 and byte length:

   ```powershell
   Set-Location <repository-root>
   & .\cloudflare\workout-runtime\scripts\Test-RemoteInventory.ps1 `
     -BaseUrl 'https://<staging-worker>.workers.dev/' `
     -BearerToken $env:BIL_STAGING_BEARER
   ```

   Do not proceed if any object is missing, any remote byte length differs, or
   any of the 305 new objects fails its approved SHA-256 pin.
6. Run `npm run dry-run` and review the production R2 binding and custom-domain
   diff. Then run `npm run deploy`. Wrangler will attach
   `workouts.bilhealth.com` only after staging inventory succeeds.
7. Smoke-test the exact public manifest URL from
   `artifacts/workout_media/cloudflare_runtime_v2/runtime_build_summary_v2.json`.
   Confirm an uncredentialed protected request returns 401, a free account
   returns 403, an entitled account returns 200/206, and a wrong SHA filename
   returns 404. For recipes, confirm an exact ID+SHA returns 200/206 with the
   pinned length/MIME/SHA header, while a wrong digest, object key, encoded
   alias, or mismatched R2 metadata returns 404/502 as appropriate.
8. Build Flutter with the exact immutable manifest URL, for example:

   ```powershell
   flutter build appbundle --dart-define=BIL_WELLNESS_MANIFEST_URL=https://workouts.bilhealth.com/v2/manifest/wellness-workouts-v2-af6082ff28856f9154216067f16fe6a7147548c9a29f8e205b43bb81bc34efe8.json
   ```

   Recipe delivery is intentionally fail-safe and remains disabled in builds
   until the Worker smoke test passes. Enable it only in the promoted build:

   ```powershell
   flutter build appbundle --dart-define=BIL_RECIPE_IMAGE_DELIVERY_ENABLED=true
   ```

   The 15 already-bundled, byte-exact recipe images continue to render locally
   with no network request. Every other visible card requests its own
   ID+SHA-pinned preview lazily, keeps the designed artwork fallback while the
   download is pending or unavailable, and promotes the file only after exact
   length and SHA-256 verification. Thus all 1,500 canonical recipes have a
   real image path without eagerly downloading the 3.81 GB library.

9. Install both packs on a premium test account, take the device offline, and
   confirm cached poster/video reads still pass exact size and SHA-256 checks.
   Only after that validation should the mobile release be promoted.

No command with `-Execute` or `npm run deploy` was run while preparing this
runtime.
