# BIL v1 Epic 12 — Security, Privacy, and Store Closure

Status: code-complete boundary. Legal approval, public HTTPS publication,
credentialed RLS integration, binary network inspection, and human penetration
testing remain external gates and are never claimed by this document.

## Data inventory and lifecycle

| Data | Source and purpose | Consent | Local / cloud | Sharing | Retention, export, deletion |
|---|---|---|---|---|---|
| Account identity | User; authentication and support | Account action | Local session / Supabase Auth when enabled | Supabase processor | Session expiry; portable export; account deletion |
| Profile and demographics | User; calculations and display | Onboarding/profile | Encrypted OS sandbox / owner RLS | None unless cloud enabled | Until deletion; exportable |
| Health and measurements | Manual, HealthKit, Health Connect, BLE | Per source and read/write purpose | Local database / owner cloud records | Never public | Until user deletion; provenance retained |
| Meals, food, water, activity | User and verified catalogs | Feature action | Local / optional sync | Community only by separate submission | Until deletion; snapshot export |
| Meal photos and voice | User initiated analysis | Just-in-time camera/photo/mic plus remote-AI consent | Memory/request only; no app retention by default | Configured gateway only | Request lifetime; gateway contract forbids secondary use |
| Devices and tokens | OS/BLE/push registration | Pairing/notification consent | Platform/device store / protected server table | Push providers | Revoked on unlink, opt-out, deletion |
| Community, friends, messages | User authored | Content-policy acceptance | Supabase owner/participant RLS | Intended recipients/audience | Delete/soft-delete policy; moderation audit excludes bodies |
| Subscription | App Store/Play receipt | Purchase action | Store and verification service | Store processor | Store/legal schedule; entitlement is server-authoritative |
| Diagnostics | Explicit support action only | Separate opt-in | Redacted | Support destination selected by user | OWNER_REQUIRED support schedule |

Precise production retention values requiring legal ownership are
`OWNER_REQUIRED`. BIL does not silently introduce analytics, advertising,
location collection, or crash upload.

## Threat model and closed controls

- Authentication: generic errors resist account enumeration; Supabase rotates
  sessions; global sign-out is available; roles and entitlements are not trusted
  from client state. OTP/recovery links remain server single-use controls.
- Health/devices: least-privilege platform permissions, provenance and unit
  validation, local-first storage, deduplication, explicit unlinking.
- Community: RLS ownership/participant policies, block/report/moderator RPCs,
  abuse rate limits and body-free audit events.
- Images/voice: HTTPS-only authenticated gateway, bounded MIME/size/schema,
  explicit user action, idempotency/replay receipt, no invented nutrition.
- Payments: signed store receipt verification is server-authoritative; service
  role and store secrets are server environment values only.
- Export/deletion: OS destination picker avoids the global clipboard; local
  reset and authenticated cloud deletion are distinct and truthful.
- Background disclosure: an app-switcher privacy shield redacts health UI.

## Secrets, storage, transport, and logging

- No production secret belongs in source, Dart defines, logs, migrations, or
  client assets. Supabase anon/publishable identifiers are public configuration;
  service role, gateway, store, deletion, APNs and FCM credentials are server-only.
- Android backup is disabled; iOS protected sandbox/keychain are the platform
  boundary. Tokens must use SDK/platform secure session storage, never app
  preferences or health tables.
- Production endpoints require HTTPS/TLS validation. No permissive certificate
  callback exists. Certificate pinning is intentionally not used: operationally
  safe key rotation is not yet provisioned (`OWNER_REQUIRED`).
- Audit events contain identifiers and action metadata only, never message body,
  token, image, voice, or health values.

## Consent and permissions

Consent is purpose-specific (`health`, `camera`, `microphone`, `photos`,
`notifications`, `devices`, `remote_ai`) and versioned. OS permissions are
requested at the point of use. Denial keeps all reasonable manual/local paths
available. Revocation disables subsequent access; a new purpose or policy
version requires a new receipt.

## Export, deletion, and retention

- Local export is portable JSON through the OS share/save picker.
- Local reset creates a validated recovery snapshot, then removes local profile
  and records; it does not claim to delete external health-store history.
- Cloud account deletion disables push tokens, queues an authenticated request,
  deletes Auth ownership and cascade-owned records. Storage cleanup must be
  verified against the enabled production bucket list.
- Account deletion does not cancel App Store or Google Play subscriptions; the
  user must manage those with the respective store.
- Public deletion page template: `docs/public/account-deletion.html`. Its final
  HTTPS URL, owner identity, contact and legal retention text are OWNER_REQUIRED.

## Store/legal package

Existing drafts cover Privacy Policy, Apple App Privacy, Google Data Safety and
Health Apps Declaration. Before submission they must be reconciled with the
signed binaries and populated only by the owner/legal reviewer. Terms, support,
community/content/moderation, medical disclaimer, age suitability, processor
inventory, third-party notices, open-source licenses and content rights are
tracked below:

| Artifact | Repository status | External requirement |
|---|---|---|
| Privacy Policy / Terms | Draft; behavior-derived | OWNER_REQUIRED identity, jurisdiction, approval, HTTPS |
| Support / deletion | In-app flow plus publishable deletion page | OWNER_REQUIRED contact and URL |
| Data Safety / App Privacy / Health declaration | Drafts present | Signed-binary and console reconciliation |
| Community/moderation | Enforced RLS/RPC/policy acceptance | Legal/content reviewer approval |
| Child safety/age | No child-directed claim | OWNER_REQUIRED target-age decision |
| SDK/processors | Supabase, stores, push, optional vision gateway | Final enabled-build inventory and DPAs |
| Licenses/notices/rights | Dependency/content inventory required at release | Automated license report plus owner rights evidence |

## OWASP MASVS evidence matrix

Reference baseline: OWASP MASVS/MASTG 2.x living standard,
https://mas.owasp.org/MASVS/ (reviewed 2026-08-04). MASVS no longer uses the
old L1/L2/R verification levels; external testing is recorded explicitly.

| Area | Evidence | Remaining external gate |
|---|---|---|
| STORAGE | backup disabled, clipboard-free export, owner RLS | physical backup/keychain inspection |
| CRYPTO | platform/server crypto; no custom cipher | production key rotation review |
| AUTH | generic errors, JWT RPC ownership, global sign-out | credentialed multi-device/session tests |
| NETWORK | HTTPS-only gateways, default TLS validation | proxy inspection of signed binaries |
| PLATFORM | least permissions, safe deep-link allowlists, redaction | Android/iOS physical-device review |
| CODE | analyze/tests, secret/dependency/config audits | SAST vendor review if required |
| RESILIENCE | fail-closed feature flags and service configuration | human penetration test |
| PRIVACY | inventory, consent versions, export/delete, minimization | legal and store-console approval |

## Android Kotlin build integrity

- The Android host uses AGP 9 built-in Kotlin (`android.builtInKotlin=true`).
- BIL voice entry uses first-party Android `SpeechRecognizer` and iOS
  `SFSpeechRecognizer` bridges. Audio stays inside the operating-system
  recognizer boundary; only text accepted by the user reaches meal search.
- The legacy `speech_to_text` plugin was removed because its Android release
  unconditionally applied `kotlin-android`. The timezone and scanner plugins
  avoid that plugin when built-in Kotlin is active.
- The release gate fails if Flutter emits the legacy-KGP compatibility warning,
  even when the APK otherwise builds successfully.

## Release blockers

No known repository P0/P1 is accepted. Deployment remains blocked until all
`OWNER_REQUIRED` fields are supplied, migrations/functions are deployed,
credentialed two-account/anonymous/moderator RLS tests pass, public policies use
HTTPS, and a human reviewer records penetration and legal outcomes.
