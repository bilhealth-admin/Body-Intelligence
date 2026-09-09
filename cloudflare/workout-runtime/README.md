# BIL wellness media runtime

This directory contains the source for the deployed Cloudflare delivery layer
for the reviewed Home Training (200 movements), Gym Programs (102 movements),
and 1,500 canonical recipe preview images plus 1,500 additive, compact WebP
thumbnails. One Worker keeps the two private R2 buckets behind separate
`WORKOUTS` and `RECIPES` bindings.

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

The v3 recipe source release is never mutated. The Worker imports the
release-pinned `recipe-images.json` contract (SHA-256
`e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3`)
and converts its 1,500 unique canonical IDs into a fixed in-bundle allowlist.
Every entry pins the private object key, SHA-256, byte length, MIME type, and
dimensions. The additive `recipe-thumbnails-v4.json` contract (SHA-256
`24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029`)
maps the same 1,500 source IDs and source digests to content-addressed 512px
WebP objects. It totals 73,802,850 bytes instead of 3,811,262,661 bytes for the
originals; no mutable alias or dynamic paid image service is involved.

## Runtime boundary

The Worker exposes four routes:

- `GET|HEAD /v2/manifest/<exact-sha-pinned-name>.json` is public. No alias or
  mutable `latest.json` route exists.
- `GET|HEAD /v2/objects/<allowlisted-key>` serves only the generated set of 15
  free-preview videos and their 15 exact posters without account sync. Every
  other object requires a valid Supabase Bearer JWT; packs and non-preview
  videos additionally require a current premium entitlement. The Worker checks
  asymmetric JWTs against the Supabase JWKS, delegates legacy HS256 validation
  to Supabase Auth, then queries owner-scoped subscription/closed-test rows
  through RLS with the same user token. Public JWKS are cached briefly per
  isolate; entitlement rows are not cached. The boundary fails closed on
  unavailable or stale authority.
- `GET|HEAD /v3/recipes/images/<canonical-id>/<sha256>` is a public discovery
  preview. The path must match one exact manifest ID and its exact digest; it
  never accepts an R2 key, filename alias, encoded alias, or mutable latest
  route. Recipe previews were already classified `public, immutable` by the
  media upload plan and remain visible beneath the existing premium glass;
  ingredients, instructions, nutrition actions, and paid interaction are not
  served by this route.
- `GET|HEAD /v4/recipes/thumbnails/<canonical-id>/<sha256>.webp` is the compact
  public discovery path. Both the v4 entry and its v3 source digest must match
  the bundled manifests. The R2 object must match the signed WebP MIME and byte
  length before any bytes are served. v3 remains available as the fallback for
  old clients and for a verified v4 fetch failure.

Objects are streamed directly from their R2 binding. Byte ranges, ETags,
conditional requests, MIME metadata, exact-origin CORS, and the appropriate
private/public cache directives are preserved. Recipe responses additionally
fail closed unless the R2 byte length and MIME agree with the signed mapping.
Full unauthenticated recipe-image `GET` responses are also stored in the
custom-domain data-center cache without changing a byte of the signed object.
Range, conditional, authorized, and browser-origin requests bypass that cache,
and any cache failure falls back to the authoritative R2 response.
Flutter receives no bucket/key and verifies the exact SHA-256 before promoting
a preview into its content-addressed media cache. Its Supabase Bearer allowlist
continues to cover protected workout paths only, so public recipe requests
never receive a session credential. The Worker has no service-role key.

## Reproducible local verification

From the repository root:

```powershell
python .\tool\wellness_content\build_cloudflare_workout_runtime.py --poster-workers 4
python .\tool\cloudflare_media\build_recipe_thumbnails_v4.py --workers 8
python -m unittest tool.wellness_content.test_build_cloudflare_workout_runtime tool.wellness_content.test_publish_wellness_catalog
& .\cloudflare\workout-runtime\scripts\Publish-RuntimeObjects.ps1
& .\cloudflare\workout-runtime\scripts\Publish-RecipeThumbnailsV4.ps1
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
`Publish-RecipeThumbnailsV4.ps1` is also validation-only by default. It verifies
all 1,500 generated files against the v4 manifest, requires the exact v3 source
pin, enforces the 9.5 GB project storage guard, and uploads only the
`recipes/v4/thumbnails/512/` prefix when `-Execute` is supplied. It has no delete
operation and cannot address a v3 key.

## Exact deployment workflow

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
   Publish the additive recipe thumbnails only after their separate validator
   reports exactly 1,500 entries and the projected storage guard passes:

   ```powershell
   & .\cloudflare\workout-runtime\scripts\Publish-RecipeThumbnailsV4.ps1 -Execute
   ```

   This command can only address content-addressed v4 WebP keys; the v3 prefix
   remains outside its upload contract.
4. Provision genuinely isolated staging Supabase and R2 resources, replace the
   staging bindings in `wrangler.jsonc`, then run
   `npm run check:staging-isolation`. The check deliberately fails while any
   staging Supabase URL/key or R2 bucket matches production, or while a
   placeholder/custom-domain route remains. Only after it passes, run
   `npm run dry-run:staging`, review the bundle, then run
   `npm run deploy:staging`. This creates a separate workers.dev staging Worker
   with no production custom-domain route.
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
   Confirm an exact generated free preview returns 200/206 without credentials,
   an uncredentialed paid request returns 401, a free account returns 403, an
   entitled account returns 200/206, and a wrong SHA filename returns 404. For
   recipes, confirm an exact ID+SHA returns 200/206 with the pinned
   length/MIME/SHA header, while a wrong digest, object key, encoded alias, or
   mismatched R2 metadata returns 404/502 as appropriate.
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

The complete public thumbnail inventory can be checked without trusting lagging
bucket aggregate counters:

```powershell
node .\cloudflare\workout-runtime\scripts\verify-recipe-thumbnails-v4.mjs https://workouts.bilhealth.com/
```

This performs exact HEAD metadata checks for all 1,500 objects, followed by
full SHA-256 and byte-length readbacks for first/middle/last entries.

### 2026-09-04 code-only deployment record

The recipe-image edge-cache change was deployed first to
`bil-workout-runtime-staging` (version
`6435e3fd-64d8-41d3-9876-ffda3da792c0`) and then to the production custom
domain (version `55433b52-2450-45e9-8a37-12fc452b1b8c`). Before promotion,
TypeScript/type checks, 19 Worker tests, staging and production dry-runs, and
the 305-object local SHA/size plan validation passed. Production smoke checks
then proved the exact manifest and free previews return `200`, a protected
video without a token returns `401`, recipe byte ranges return `206`, an
incorrect recipe digest returns `404`, and an allowed/disallowed CORS preflight
returns `204`/`403`. A full recipe image returned `MISS` then `HIT` while its
downloaded byte length and SHA-256 remained identical to the release manifest.

No R2 object upload or deletion was performed. Post-deployment bucket counts
remained 607 workout objects and 1,500 recipe objects.

### 2026-09-04 additive v4 thumbnail deployment record

Pillow 12.3.0 with libwebp 1.6.0 generated the deterministic 512px, quality-78
WebP release in the ignored `.tmp` workspace. The 1,500 thumbnails total
73,802,850 bytes (49,202-byte average, 64,848-byte p95) versus 3,811,262,661
bytes (2,540,842-byte average) for v3, a 98.06% aggregate payload reduction.
The exact manifest is 899,684 bytes with SHA-256
`24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029`.

Only `recipes/v4/thumbnails/512/` content-addressed keys were uploaded. The
uploader has no delete command and cannot address the v3 prefix. Cloudflare's
aggregate `bucket info` counter had not refreshed immediately after upload, so
release verification did not mistake that lag for object loss: direct R2
first/middle/last readbacks matched exact SHA/length, then the remote verifier
proved all 1,500 v4 routes on both staging and production and downloaded three
complete bodies from each. The original v3 route also returned its unchanged
2,715,891-byte source with the exact original SHA.

The staging Worker version is
`fc404161-c7af-4fa1-87cd-84817c739f44`; the promoted production version is
`59cd581f-28a4-4433-af16-a75adcbc548c`. Before promotion, 23 Worker tests,
TypeScript/type checks, both deployment dry-runs, all 1,500 remote metadata
checks, exact body readbacks, range/invalid-path/CORS tests, and workout access
regressions passed. A like-for-like uncached production sample fell from
2,715,891 bytes in 6.316 seconds (v3) to 62,204 bytes in 0.326 seconds (v4).
The v4 edge-cache probe returned `MISS` in 0.264 seconds and then `HIT` in
0.235 seconds without changing its SHA.

Flutter uses v4 only for recipe cards/lists. The 16:9 detail view explicitly
requests the original v3 media, and every v4 manifest/download/hash/offline
failure also falls back to v3. Rolling the Worker back to production version
`55433b52-2450-45e9-8a37-12fc452b1b8c` therefore restores the previous route
set immediately; the additive v4 R2 objects remain inert and no v3 data needs
restoration. No paid Cloudflare Images feature was enabled.
