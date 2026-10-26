# BIL iOS39 internal configuration and release boundary

This is the signing configuration contract, not a QA certificate or permission to submit App Store review. The signing job hashes this file and retains that hash with its artifact evidence. The actual immutable source SHA is the job's `github.sha`, verified against completed integration CI before signing credentials are used.

## Identity

- Application: Body Intelligence Log.
- Bundle identifier: `com.bilhealth.bodyintelligencelog`.
- Marketing version: `1.0.0`.
- Internal build number: **39**, supplied to the build command; do not rewrite protected Build38 configuration.
- Protected source base: `155b079696430919f8272df934371f033fb11be2`.
- Integration branch: `bil39/integration-20261025`.
- Release trigger branch: `bil39/internal-testflight-20261025`, created at the already tested immutable integration SHA.
- Destination: existing internal TestFlight group only. No App Store review submission, public release, price change or subscription metadata edit.

## Required exact-source evidence

`tools/qa/bil39_internal_build_ci.py` requires all configured jobs in eight workflows at the same integration SHA: source/analysis and eight full Flutter shards, CodeQL/security/SQL/RLS, actual Android/iOS integration, Android API26/29/33/34/35/36 startup, cloud handler tests, Worker tests and real public video range delivery, Crystal checks on Linux/Windows, iPhone/iPad SwiftUI component tests, and negative fixtures/native PostgreSQL tests.

`BIL39_VERIFIED_CLOUD_SOURCE_SHA` must equal that candidate only after authorized Production Coach publication, exact-source readback and successful live verification. It is not set merely because local tests or an HTTP response succeeded. The existing cloud project is Production; an old configuration that points to those same resources is not staging evidence.

Before signing, the checkout must be clean, descend from the protected base, and preserve these blobs:

- Reviewed checkout waiting UI `lib/features/commerce/presentation/bil_dynamic_store_components.dart`: `fdd24dbfa5b16f78aad65a821a2f5cf1215f90d5`. Original iOS38 reference: `26303dce18ddc3f4f4ddceb859081283c0aebfe7`. The user explicitly requested one Splash indicator above checkout and none inside the button on26October; see `docs/qa_next/BIL39_PURCHASE_WAITING_UI_20261026.md`. Twelve idle/pressed/cancelled CTA frames, halos and geometry still match the protected original with zero pixel tolerance.
- Legacy glass `lib/shared/widgets/bil_glass_press_feedback.dart`: `653d424ddb6cca8adeb0d394f5c8f8866da3792d`.
- Remote `work/ios38-safe-fixes-20261025` must remain at the protected base.

## Production configuration and signing

Reuse the existing audited production application identity, Apple team, provisioning profile, privacy disclosures, health permissions, encryption declaration, mobile integrity requirements, AdMob configuration and Supabase endpoints. Secrets are supplied by GitHub Actions and must not be written into source or evidence. No test bypass, weakened RLS, entitlement grant, account reset or substitute encryption key is permitted.

The workflow validates the selected Xcode/iOS SDK, signing inputs, team/bundle identity, production push/App Attest permissions, release configuration and generated native plugin graph. After building it verifies the actual IPA, source/build identity, entitlement/privacy/configuration evidence and artifact hashes. An existing Build39 prevents duplicate upload. Apple processing and internal-group availability must be confirmed after upload.

## Acceptance that remains after upload

The signed artifact and TestFlight availability are distinct from full physical device acceptance. The installed Build39 still needs confirmation of account isolation, restore/sync, Coach, Smart Plan/session/video, purchase/restore and relevant Health/Watch behavior. Evidence from installed Build38 identifies regressions but cannot certify Build39. No public-release approval is implied by internal upload.
