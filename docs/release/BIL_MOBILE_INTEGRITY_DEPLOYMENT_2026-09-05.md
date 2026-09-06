# BIL mobile integrity deployment gate — 2026-09-05

This change is implemented in source but is **not deployed** by this change.
It provides just-in-time App Attest or Play Integrity authorization for the
request body of selected sensitive operations. It makes no integrity claim at
launch and does not trust a client-side verdict.

The implemented server-enforced action scope is exactly:

- `ai_coach.request`
- `admin.ai_coach.global_reset`
- `admin.ai_coach.individual_reset`
- `admin.ai_coach.notification`
- `admin.community.moderators.list`
- `admin.community.moderators.add`
- `admin.community.moderators.remove`
- `store.verify_purchase`
- `store.verify_ai_boost`

No other endpoint is covered by this increment. Account deletion remains
available without device attestation so an unsupported or lost device cannot
block the user's privacy right to delete their account.

## Authoritative platform contracts

- Apple: [Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- Apple: [Validating apps that connect to your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- Apple: [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide)
- Apple: [App Attest environment entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.devicecheck.appattest-environment)
- Apple: [Capabilities overview](https://developer.apple.com/help/account/capabilities/capabilities-overview/)
- Apple: [Apple App Attestation Root CA](https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem)
- Google: [Make a standard API request](https://developer.android.com/google/play/integrity/standard)
- Google: [Integrity verdicts](https://developer.android.com/google/play/integrity/verdicts)
- Google: [Set up Play Integrity](https://developer.android.com/google/play/integrity/setup)
- Google: [Play Integrity error codes](https://developer.android.com/google/play/integrity/error-codes)

## External values that an owner must supply

Do not infer or fabricate any of these values.

1. Enable App Attest for the exact App ID in the Apple developer account,
   regenerate the distribution provisioning profile, and replace
   `APPLE_PROVISIONING_PROFILE_BASE64`. The final profile and signed IPA must
   both contain
   `com.apple.developer.devicecheck.appattest-environment = production`.
2. Set `BIL_APP_ATTEST_APP_ID` in the server to the exact App ID prefix plus
   `com.bilhealth.bodyintelligencelog`. Obtain the prefix from Apple signing
   evidence; it is not safe to assume that it equals the Team ID.
3. Set `BIL_APP_ATTEST_ENVIRONMENTS=production` for production. Development
   must use an isolated non-production server configuration.
4. Set `BIL_APP_ATTEST_BUNDLE_VERSIONS` to a comma-separated allowlist of the
   exact `CFBundleVersion` values that may register new keys. Add the release
   workflow's new build number before distributing that build. Existing keys
   may survive an app upgrade, but a reinstall creates a new key and needs the
   current build number in this allowlist.
5. Confirm the Google Cloud project is linked in Play Console and Play
   Integrity is enabled for `com.bilhealth.bodyintelligencelog`. Set the GitHub
   repository variable `BIL_PLAY_INTEGRITY_PROJECT_NUMBER` to the actual
   numeric project number of that linked project.
6. Set the server secrets `BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON` and
   `BIL_PLAY_INTEGRITY_PACKAGE_NAME`. The service account must be the actual
   Play-linked project principal with only the access required to decode
   integrity tokens.

## Non-breaking rollout order

There are two independent gates:

- Client: `BIL_MOBILE_INTEGRITY_REQUIRED` defaults to `false`. Signed release
  workflows compile it as `true` only after their backend evidence gate.
- Server: `BIL_MOBILE_INTEGRITY_ENFORCEMENT` defaults to `off`. In `off`, the
  guard strips the private `_integrity` envelope and deliberately makes no
  integrity claim. Any value other than `off` or `enforce` fails with 503. In
  `enforce`, a missing migration/RPC or invalid/missing/expired/replayed grant
  fails closed.

Deploy in this order:

1. Review the complete pending migration chain before any linked `db push`.
   At the time of this record, `20260904030000_community_post_human_moderation.sql`
   and `20260904040000_push_delivery_idempotency.sql` precede the integrity
   migration `20260905010000_mobile_integrity_jit_grants.sql` and would be
   applied too; do not treat `db push` as an isolated integrity operation.
   Apply the accepted chain in a non-production project, then verify the three
   integrity tables plus
   `bil_consume_mobile_integrity_grant`.
2. Configure the real Apple and Google values above. Deploy `app-attest` and
   `play-integrity`; verify authenticated challenge, registration/token decode,
   assertion, grant issue, payload binding, expiry, and replay denial on
   physical devices installed through the appropriate Apple/Play channel.
3. Deploy the guarded versions of `ai-coach`, `ai-coach-global-reset`, and
   `verify-store-purchase` while server enforcement remains `off`. This is the
   compatibility phase for the currently installed app.
4. Exercise an internal build compiled with
   `BIL_MOBILE_INTEGRITY_REQUIRED=true`. Attestation is requested only when a
   protected operation is submitted, never at launch.
5. Repeat the entire flow in an isolated staging project with server
   enforcement set to `enforce`. Prove missing grant, changed body/action,
   expired grant, second consumption, invalid counter/verdict, missing RPC,
   and verifier outage all fail closed.
6. Record the reviewed backend deployment/evidence identifier in the GitHub
   secret `BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID`. The workflow checks only
   that owner evidence is present; it does **not** query or certify live server
   state. It also refuses Android release without the Cloud project-number
   variable and refuses iOS release unless the embedded profile and final
   signature both carry production App Attest.
7. Produce TestFlight and Play closed-track candidates and complete the
   physical-device scopes written into each workflow's gate artifact.
8. Before setting production server enforcement to `enforce`, account for old
   clients. The guarded function names are shared with existing versions, so
   enforcement immediately makes their sensitive requests fail. Use an
   established minimum-supported-version/mandatory-update rollout, or deploy a
   versioned endpoint migration, and monitor adoption first. Do not activate
   global enforcement merely because a new candidate exists.
9. Set `BIL_MOBILE_INTEGRITY_ENFORCEMENT=enforce`, redeploy the three guarded
   functions, and perform authenticated canaries. Only this final state is
   server-enforced mobile integrity.

## Exact deployment risks

- Deploying the guarded functions with `enforce` before the migration causes
  protected requests to return 503; it does not fall open.
- Shipping a client compiled with integrity required before both attestation
  functions and their real configuration exist causes only the selected
  sensitive operations to fail closed. Launch remains unaffected.
- Activating enforcement while old clients remain active breaks their AI
  coach, protected administrator reset/notice and moderator-roster calls, and
  store-verification calls because they have no grant envelope.
- The guarded function names are also shared by any web or desktop client.
  Global `enforce` makes these nine actions mobile-only; a client-supplied
  platform exemption would be bypassable and is intentionally absent. If
  legitimate non-mobile clients need them, provide a separately authenticated
  server trust mechanism or a versioned endpoint before activation.
- App Attest is unavailable on unsupported devices and can experience Apple
  service outages. The current policy fails protected operations closed; the
  product needs an explicit support/recovery message, not a client bypass.
- App Attest keys are installation-scoped and can disappear after reinstall or
  backup/restore. The client generates and registers a replacement key just in
  time; incorrect bundle-version or environment allowlists prevent this.
- A provisioning profile without the capability can compile from source yet
  cannot establish production App Attest. The signed-IPA gate is therefore
  authoritative, not the repository entitlement file alone.
- Play Integrity standard tokens require a Play-installed build and the linked
  Cloud project. Emulator, sideload, wrong package, stale timestamp, missing
  licensing/app/device verdicts, decode failure, or request-hash mismatch are
  denied by the server verifier.
- Google documents a default daily quota of 10,000 token requests and 10,000
  server decryptions per linked project. Measure the nine protected actions,
  configure quota alerts, request an increase if needed, and roll out gradually;
  quota exhaustion fails protected requests closed.
- The server stores Apple's receipt but does not currently submit it for an
  additional Apple risk metric. Do not describe receipt-based fraud scoring as
  implemented.
- Neither platform proves that unrelated APIs are protected. Only the actions
  wired through the one-use grant guard are covered.
