# BIL Cloudflare media publication

This directory publishes only the owner-approved media inventory to Cloudflare
R2. It does not build or release the Flutter application.

1. Build and validate the deterministic 1,802-object plan:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tool\cloudflare_media\Build-CloudflareMediaPlan.ps1
   ```

2. After `wrangler login --device` succeeds, upload with automatic resume:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tool\cloudflare_media\Start-CloudflareMediaUpload.ps1
   ```

If the Cloudflare account has not completed its one-time R2 subscription
checkout yet, the following monitor remains open and starts the same safe
uploader automatically as soon as R2 becomes available:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tool\cloudflare_media\Wait-And-StartCloudflareMediaUpload.ps1
   ```

The plan and its SHA-256 sidecar are written under
`artifacts/cloudflare_media`. The append-only NDJSON ledger records each
successful object, so rerunning the same command skips verified prior work.
Upload failures retry with exponential backoff and then stop without deleting
or rolling back any successful objects.

Buckets are created private. The recipe bucket remains private until a
Cloudflare custom domain and the app's final HTTPS origin are explicitly wired;
the premium workout bucket is intended to stay private behind entitlement
delivery.

The publication contract has a non-negotiable account ceiling of
10,000,000,000 bytes and a stricter 9,500,000,000-byte planning ceiling. The
current 1,802 media objects total 9,257,051,952 bytes. The scripts reject any
other object kind/count, changed source pin, or future plan above the safety
ceiling. No manifest or ledger object is uploaded to R2.
