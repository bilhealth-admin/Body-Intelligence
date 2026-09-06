# Meta business verification evidence — 2026-09-05

## Scope and handling

This record reflects the live Meta Business and Meta for Developers state
observed on 2026-09-05 after the owner authorized the verification submission.
It intentionally excludes legal identity values, document contents, secrets,
tokens, and key hashes.

## Business verification

- The portfolio is configured as a sole proprietorship / individual that is not
  yet registered.
- The legal organization name was entered as the owner's legal personal name,
  matching the submitted evidence; **BIL Health** was used only as the alternate
  or trade name.
- The business address, phone, website, and required postal field were reviewed
  in the verification flow.
- A business bank statement was submitted as the primary evidence and a utility
  bill as the secondary evidence.
- `bilhealth.com` was added to Meta Domains and its ownership status is
  **Verified**.
- The verification request was submitted successfully. A live recheck in Meta
  Security Centre now shows **Verified**, with Meta stating that the business
  was originally verified on 2026-09-05.
- Security Centre requires two-factor authentication for administrators and
  reports that no current administrator still needs to enable it. The portfolio
  currently has one administrator; the optional recommendation to add a backup
  administrator was not acted on.

## Meta app readiness

- The owner explicitly authorized the final mode change after reviewing the
  remaining blocker. Meta confirmed **Your app was successfully published** and
  **Your app is now available for the public to use**. Both the dashboard and
  the app-mode alert now show the app as **Published / Live**.
- The app Verification page associates the app with the portfolio above and
  shows the business verification as **Verified**.
- The first Publish attempt reached Meta's hard **Broken URL detected**
  dialog. The only item listed was the Android Google Play package link; the
  dialog offered no continue-or-publish-anyway path. Google Play Console shows
  the app in **Closed testing**, so its public store-detail page is not yet
  available to Meta's crawler.
- Meta's only immediate in-dashboard workaround was **Remove App Store**. Meta
  warned that the action could not be undone. After the owner explicitly
  confirmed that exact removal, the Android platform/store entry was removed
  temporarily and the change was saved. Its previously confirmed package,
  class, and key-hash configuration was captured before removal; literal hash
  values remain intentionally excluded from this document. This historical
  removal does not disable the implemented Supabase hosted browser-OAuth flow;
  reattachment is optional unless BIL later adopts a native Meta Android SDK or
  another feature that actually consumes the platform metadata.
- The Website and iOS platform entries remained saved after that change. The
  Website Site URL is `https://www.bilhealth.com/`, the app domain is
  `bilhealth.com`, and the privacy, terms, and account-deletion endpoints were
  rechecked immediately before publication and all returned HTTP 200.
- The Required actions page reports that there are currently no required
  actions. The dashboard independently reports the same result.
- Alert Inbox contained one informational app-mode alert confirming the switch
  to live mode. It was opened and marked read; the unread badge disappeared
  after the page was reloaded. The alert was not archived.
- The Facebook Login use case is configured with only `email` and
  `public_profile`; both are **Ready for testing**. No additional Facebook
  permissions were added. Meta's Testing page records successful API test calls
  for both permissions: five for `email` and ten for `public_profile`.
- Meta's own usage-guideline panels state that both `email` and
  `public_profile` are automatically granted to all apps. They therefore do not
  require an App Review submission for this login scope. Both permissions had
  been placed in an unsubmitted review draft; they were removed from that draft
  only, and the use-case page was rechecked to confirm that both permissions
  remain configured. App Review now says **Nothing has been added to this
  submission yet**. No review request was submitted.
- Client OAuth and Web OAuth are enabled, HTTPS and strict redirect matching are
  enforced, and the configured valid OAuth callback remains the project's
  Supabase callback URL after publication. Embedded-browser OAuth, device login,
  and JavaScript SDK login remain disabled. Meta's Redirect URI Validator had
  already reported the callback as valid.
- An iOS platform entry was added and saved using the confirmed Bundle ID
  `com.bilhealth.bodyintelligencelog`. No iPhone/iPad Store ID, URL suffix, or
  shared secret was guessed or entered.
- The Website testing instructions were corrected and saved. They now identify
  the public BIL site, state that Facebook Login is implemented in the mobile
  apps through Supabase external Web OAuth, and identify only `email` and
  `public_profile` as requested permissions.
- The iOS testing instructions were corrected and saved with the confirmed App
  Store Connect app ID. They state that Facebook Login is available in signed
  build `+8` and later, that store build `+7` predates the enabled release
  configuration, and that signed-device end-to-end validation remains required
  before distribution. The App Store ID was recorded in the testing
  instructions only; the iPhone/iPad Store ID platform fields remain empty.
- The app contact email and the advanced-settings change-notification email were
  populated with the confirmed administrator contact. The address itself is
  intentionally omitted from this evidence file.
- Advanced settings were rechecked after publication: the native/desktop-app
  setting is enabled; the app secret is not marked as embedded in the client;
  API calls target Graph API v26.0; the age restriction is Anyone (13+); no
  country restriction is enabled; and API access for changing app settings is
  disabled. No advanced-setting validation or required-action blocker was
  present.
- No Data Use Checkup item is currently present in the app navigation,
  dashboard, or Required actions. This records the current UI state; a future
  checkup must be completed if Meta later creates a required action.
- Meta's iOS platform was initially saved with its default automatic in-app
  event logging toggle enabled, while the Android automatic purchase-logging
  toggle remained disabled. The owner must disable the iOS toggle manually
  before introducing any native Meta SDK; do not treat that privacy alignment
  as complete until the saved UI state is rechecked.

- The roles page shows one administrator and no testers. The Test User Accounts
  page contains no test users. No roles, testers, or test accounts were created
  during publication.

The Meta app itself is now public, but this record does not claim a successful
end-to-end Facebook OAuth sign-in on either mobile platform. Complete that
device-level test before treating the login path as release-validated.

The reviewed source configuration now enables and readies the Facebook entry
point in both signed release workflows by passing
`BIL_FACEBOOK_LOGIN_ENABLED=true` and `BIL_FACEBOOK_LOGIN_READY=true`. Those
defines apply only when a future signed Android or iOS candidate is built from
the workflows; the in-source defaults remain `false`, so local, unsigned, and
ad-hoc builds still fail closed unless explicitly configured. This source-only
change did not create, sign, upload, distribute, or publish a build. Existing
store build `+7` is unchanged; Facebook device validation belongs to this
authorised signed candidate numbered exactly `+8`.

For that candidate, Android now obtains the Facebook authorization URL from
Supabase and hands only the allow-listed URL to a native `CustomTabsIntent`
bridge. The bridge pins a resolved Custom Tabs provider and returns unavailable
instead of falling back to an embedded WebView. iOS continues through
Supabase's `inAppBrowserView`, implemented by the locked iOS launcher as
`SFSafariViewController`. These are source contracts, not signed-device OAuth
success evidence.

The current integration contains no Meta Android/iOS SDK or Flutter Facebook
SDK dependency. Supabase's official Facebook Auth instructions define the
hosted OAuth prerequisites as the Facebook OAuth app, `email` and
`public_profile`, the exact Supabase `/auth/v1/callback`, matching Facebook keys
in the enabled Supabase provider, and client `signInWithOAuth`. They do not
require a Meta Android platform/store entry for this browser flow:
<https://supabase.com/docs/guides/auth/social-login/auth-facebook>. On that
source-and-contract evidence, the absent Android entry is **not** a blocker for
the implemented BIL login. A native Meta SDK integration would be a different
contract and would require a fresh platform/configuration/privacy review. The
focused browser-path contract tests passed 7/7 on 2026-09-06; this remains
source/test evidence rather than a signed Facebook session.

## Supabase and Instagram status

- Supabase already has the Facebook provider enabled, with the expected Meta
  App ID and the project OAuth callback. No secret value is recorded here.
- The Supabase Site URL is `https://www.bilhealth.com`.
- `https://www.bilhealth.com/auth/callback` was added to the Supabase redirect
  allow-list and its presence was confirmed after saving.
- The Meta app's **Add use cases** catalog did not offer an Instagram use case;
  it offered only app-install advertising in addition to the existing Facebook
  Login use case. No Instagram permissions or products were added.
- Instagram Professional APIs must not be represented as consumer sign-in for
  all BIL users. If required later, evaluate them as a separate professional
  account integration with the minimum permissions needed.

## Release gate

Meta Business Verification and Meta app publication are now complete. The
remaining operational checks are:

1. Under separate build authority, generate the signed Android and iOS
   candidates numbered exactly `+8`, then test Facebook Login end to end on
   both platforms without using the owner's administrator account as the
   consumer test identity.
2. Do not submit App Review for the current `email` and `public_profile` scope;
   Meta identifies both as automatically granted and the review draft is now
   empty. Reassess only if a future product change adds a permission that Meta
   explicitly says requires review.
3. Do not treat the absent Android platform/store entry as a gate for this
   Supabase hosted browser flow. Recreate it only if a separately reviewed
   native Meta SDK/store integration is introduced and the canonical Google
   Play details URL is publicly accessible.
4. Keep Instagram login disabled; no supported Instagram consumer-login use
   case is configured for this app.

## Official Meta references

- <https://www.facebook.com/business/help/2058515294227817>
- <https://www.facebook.com/business/help/2342133782492969>
- <https://www.facebook.com/business/help/159334372093366>
- <https://www.facebook.com/business/help/322526208728282>
- <https://www.facebook.com/business/help/321167023127050>
