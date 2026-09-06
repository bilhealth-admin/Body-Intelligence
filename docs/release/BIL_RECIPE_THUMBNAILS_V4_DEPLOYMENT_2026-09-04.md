# BIL recipe thumbnails v4 deployment evidence

Date: 2026-09-04  
Scope: additive recipe-card thumbnails, Cloudflare R2/Worker delivery, and the
Flutter selection/fallback client. No Android/iOS application build was run.

## Release contract

- Existing v3 source manifest remained byte-for-byte unchanged at SHA-256
  `e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3`.
- New bundled v4 manifest:
  `assets/catalogs/recipes/v1/recipe-thumbnails-v4.json`.
- v4 manifest SHA-256:
  `24055bdfa731250fcac4aa55e3ab691fe2fc01a84733a8086ca2accf232a9029`.
- Manifest length: 899,684 bytes; entries: 1,500.
- Each entry pins canonical ID, v3 source SHA, content-addressed R2 key,
  immutable delivery path, WebP MIME, byte length, SHA-256, width, and height.
- Transform: contain/no-upscale, maximum 512 by 512, Lanczos, WebP quality 78,
  method 6. The release-pinned builder used Pillow 12.3.0 and libwebp 1.6.0.
- `.gitattributes` marks only this manifest `-text` so a Windows checkout cannot
  change its byte pin through LF/CRLF conversion.

Generated WebP bodies were kept under `.tmp/recipe-thumbnails-v4` and were not
added to the repository. Only the manifest, builder, validators, Worker code,
and Flutter client are repository artifacts.

## Payload evidence

| Metric | v3 originals | v4 thumbnails |
| --- | ---: | ---: |
| Count | 1,500 | 1,500 |
| Total bytes | 3,811,262,661 | 73,802,850 |
| Average bytes | 2,540,842 | 49,202 |
| p50 bytes | 2,562,773 | 49,248 |
| p90 bytes | 2,807,841 | 61,046 |
| p95 bytes | 2,889,474 | 64,848 |
| Maximum bytes | 3,524,417 | 93,244 |

Aggregate byte reduction: 98.06%.

The release storage projection was 9,335,108,379 bytes, below the project's
conservative 9.5 GB guard. No paid Cloudflare Images feature or dynamic image
transformation was enabled.

## R2 publication safety and evidence

The publisher validates all 1,500 local SHA/size values before any upload and
can address only `recipes/v4/thumbnails/512/<id>-<sha>.webp`. It contains no
delete operation and cannot address `recipes/v1/images/`. Uploads set:

- `Content-Type: image/webp`
- `Content-Disposition: inline`
- `Cache-Control: public, max-age=31536000, immutable`

All 1,500 upload commands completed and produced content-addressed success
receipts. Direct R2 readbacks for the first, middle, and last objects matched
the manifest SHA-256 and byte length.

Cloudflare's aggregate `r2 bucket info` statistics still displayed the prior
1,500-object/3.81 GB snapshot immediately after publication. This aggregate is
not used as sole release evidence. The remote verifier subsequently performed
an exact `HEAD` validation for every one of the 1,500 v4 routes on both staging
and production, and full byte/SHA readbacks for first/middle/last on both.
Results:

```text
RECIPE_THUMBNAILS_V4_REMOTE verified=1500 byteReadbacks=3 origin=staging
RECIPE_THUMBNAILS_V4_REMOTE verified=1500 byteReadbacks=3 origin=production
```

An unchanged v3 source was also downloaded from production: 2,715,891 bytes,
with SHA-256
`7414183b2ae80fa7f6bfba0c2506935a27722ac6ca5801d565859f09a49afe8c`.

## Worker promotion and smoke results

- Staging version: `fc404161-c7af-4fa1-87cd-84817c739f44`.
- Production version: `59cd581f-28a4-4433-af16-a75adcbc548c`.
- Production custom domain: `https://workouts.bilhealth.com`.
- Previous production rollback version:
  `55433b52-2450-45e9-8a37-12fc452b1b8c`.

Pre-promotion evidence:

- TypeScript and generated Cloudflare type checks: pass.
- Worker tests: 23/23 pass.
- Staging and production dry-runs: pass; bundle gzip 279.94 KiB.
- v4 exact GET: `200`, correct WebP MIME/length/SHA/cache headers.
- v4 byte range: `206`, exact `Content-Range` and requested length.
- Wrong v4 digest and attempted R2 bucket-key route: `404`.
- Existing v3 route: `200` with original exact bytes/SHA.
- Existing public v2 manifest: `200`.
- Existing free-video byte range: `206`.
- Existing paid video without credentials: `401`.
- Allowed/disallowed CORS preflight: `204` / `403`.

Production like-for-like uncached sample (`algerian-chakhchoukha-chicken`):

| Delivery | Bytes | Total time |
| --- | ---: | ---: |
| v3 original | 2,715,891 | 6.316 s |
| v4 WebP | 62,204 | 0.326 s |

The v4 cache probe was `MISS` in 0.264 s, then `HIT` in 0.235 s; all downloaded
bodies retained the manifest SHA-256.

## Flutter behavior and verification

- Recipe cards and lists prefer v4 after strict manifest, source-SHA, size,
  MIME, and download-SHA verification.
- Any missing/malformed manifest, network/offline failure, wrong size, or wrong
  SHA falls back to the unchanged v3 path.
- The 16:9 recipe detail view deliberately requests the full v3 original; it
  does not stretch the 512px card thumbnail.
- Thumbnail and detail requests have separate cache identities, while each
  body remains content-addressed by SHA and safe extension.
- Focused thumbnail/detail/client/cache tests: 15/15 pass.
- Broader focused client/repository/cache integration: 27/27 pass.
- All named recipe tests executed by the client audit: 56/56 pass.
- Focused Flutter analyzer: no issues. No app build and no golden update.

## Rollback compatibility

The v4 route and R2 objects are purely additive. Rolling the Worker back to
`55433b52-2450-45e9-8a37-12fc452b1b8c` removes v4 routing immediately while v3
continues unchanged. Older clients never know the v4 keys. New clients fall
back to v3 if the v4 route is unavailable. The uploaded v4 objects can remain
in R2 inertly; no deletion or restoration of v3 data is required for rollback.

## Reproducible commands

```powershell
python .\tool\cloudflare_media\build_recipe_thumbnails_v4.py --workers 8
& .\cloudflare\workout-runtime\scripts\Publish-RecipeThumbnailsV4.ps1
& .\cloudflare\workout-runtime\scripts\Publish-RecipeThumbnailsV4.ps1 -Execute
Set-Location .\cloudflare\workout-runtime
npm run check
npm test
npm run dry-run:staging
npm run dry-run
node .\scripts\verify-recipe-thumbnails-v4.mjs https://workouts.bilhealth.com/
```
