# External Launch 003 — Privacy Policy Publication Readiness

## Scope

This gate audits the existing privacy-policy draft and prepares publication
evidence. It does not claim legal approval or a live URL.

## Required publication evidence

- Final legally reviewed privacy-policy content.
- Product-owner/contact identity with no placeholders.
- Accurate health-data, deletion, retention, sharing, security, children, and
  jurisdiction disclosures.
- Public stable `https://` URL reachable without login.
- HTTP success response and final resolved URL.
- UTC verification time and SHA-256 of the published body.
- Matching URL entered in both store consoles when those accounts are active.

## Evidence boundary

Local audit evidence belongs under `.bil-package-evidence/external_launch/`.
Publication is `BLOCKED_EXTERNAL` until legal approval, hosting authority, and a
real HTTPS response exist. A repository document is not a published policy.
