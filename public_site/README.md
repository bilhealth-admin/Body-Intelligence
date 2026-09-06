# BIL public policy site

Static, deployment-ready source for the eight public `bilhealth.com` routes.
It contains no credentials and may be deployed through the repository's
Cloudflare Workers Static Assets configuration only after the owner reviews the
legal wording. Deployment and live HTTPS verification remain external; source
presence is not proof that any URL is published.

## Universal/App Link association inputs

The two `/.well-known` documents are generated deployment inputs and are not
committed. Before a production site deployment, set `APPLE_TEAM_ID` to the exact
Team ID shown in the Apple Developer account and set
`PLAY_APP_SIGNING_SHA256` to the **App signing key certificate** SHA-256 shown
in Google Play Console > App integrity (not the upload-key certificate), then
run:

```text
python tool/release/generate_app_link_associations.py
```

The generator validates both values, writes only
`public_site/.well-known/apple-app-site-association` and
`public_site/.well-known/assetlinks.json`, and reads both documents back before
reporting success. `wrangler.site.jsonc` routes every `/.well-known/*` request
through `tool/release/bilhealth_site_worker.mjs`; absent, malformed, or unknown
association documents return a non-HTML error and can never fall through to the
SPA shell. Deployment and signed-device verification remain external.
