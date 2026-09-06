# BIL production association-document handoff

The repository does not contain guessed production association values. Two
owner-controlled values are required before generating the public files:

1. `APPLE_TEAM_ID`: the exact ten-character Team ID from the Apple Developer
   membership used to sign `com.bilhealth.bodyintelligencelog`.
2. `PLAY_APP_SIGNING_SHA256`: the SHA-256 fingerprint of the **App signing key
   certificate** in Google Play Console > App integrity. The upload-key
   fingerprint is a different value and must not be substituted.

With those environment variables present, run from the repository root:

```text
python tool/release/generate_app_link_associations.py
```

The command validates and normalizes the inputs, atomically generates these
gitignored deployment inputs, and reads them back before passing:

- `public_site/.well-known/apple-app-site-association`
- `public_site/.well-known/assetlinks.json`

Local contract checks that do not deploy anything:

```text
python tool/release/generate_app_link_associations.py --self-test
node --test tool/release/bilhealth_site_worker.test.mjs
```

`wrangler.site.jsonc` requires Workers Static Assets routing with an `ASSETS`
binding and `run_worker_first` for `/.well-known/*` (Wrangler 4.20.0 or newer).
The Worker rejects a missing file, SPA `index.html`, malformed JSON, and unknown
well-known paths instead of returning a misleading HTTP 200 HTML page.

Generation is not publication evidence. After an authorized deployment, record
that both production URLs return HTTP 200 directly, without redirect, with
`Content-Type: application/json`; then verify `/auth/callback` and
`/auth/reset-password` on installed App Store/TestFlight- and Play-signed apps.
