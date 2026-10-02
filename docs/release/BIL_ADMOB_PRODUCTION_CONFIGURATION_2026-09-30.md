# BIL AdMob production configuration — updated 2026-10-02

Owner-confirmed public AdMob identifiers for **Body Intelligence Log**.

## Publisher

- Publisher ID: `pub-9688223318643509`
- app-ads.txt record:
  `google.com, pub-9688223318643509, DIRECT, f08c47fec0942fa0`

## Android

- App ID: `ca-app-pub-9688223318643509~2357875410`
- Banner ad unit ID: `ca-app-pub-9688223318643509/9430375211`
- Ad format: Banner only
- AdMob store-link state: not linked yet; the app is not public in Google Play
- AdMob approval state: requires review

## iOS

- App ID: `ca-app-pub-9688223318643509~4090504347`
- Banner ad unit ID: `ca-app-pub-9688223318643509/6445204944`
- Ad format: Banner only
- AdMob store-link state: not linked yet; the app is not public in the App Store
- AdMob approval state: requires review

## Runtime policy retained

BIL's reviewed advertising boundary remains unchanged:
- contextual/non-personalized Banner only,
- verified Free adult accounts only,
- Premium and Premium AI Coach remain ad-free,
- sensitive logging contexts remain ad-free,
- production IDs must all resolve to the single publisher above.

## Release state

On 2026-10-02 the owner explicitly authorized the next signed Android/iOS
candidate to compile the reviewed AdMob/UMP integration with the production
publisher, app IDs, and Banner unit IDs above **before public store launch**.

The apps are still unpublished and cannot yet be linked to public store
listings in AdMob. Ad serving may therefore remain limited or absent until the
store-link and AdMob app-review gates complete. That external limitation does
not require BIL to remove the SDK or substitute test IDs in the signed
candidate.

For the next signed candidate:
- `BIL_ADS_ENABLED=true`
- `BIL_AD_PROVIDER_READY=true`
- `BIL_ADMOB_PRODUCTION_READY=true`
- production IDs must match the single publisher above
- UMP remains mandatory before any ad request
- Premium/Premium AI Coach and sensitive logging surfaces remain ad-free

Development and automated integration tests continue to use Google's official
test ad units unless a test is explicitly validating the production identifier
format.

After the apps become public, link both store listings in AdMob and complete
the remaining AdMob app-review/app-ads.txt verification gates before treating
normal production serving as available.
