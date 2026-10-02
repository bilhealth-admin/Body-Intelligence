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

The identifiers above are the current production ownership inputs, but **production
ad serving is not yet authorized** because both apps are still unpublished and
cannot yet be linked to their public store listings in AdMob.

Keep the production release gates fail-closed until all of the following are true:
1. the Android and iOS public store listings are live and linked in AdMob,
2. AdMob app review no longer reports `Requires review`,
3. the public `https://www.bilhealth.com/app-ads.txt` endpoint serves the exact
   publisher record above,
4. UMP/privacy configuration is verified on real Android and iOS builds.

Until those conditions are satisfied:
- `BIL_ADS_ENABLED=false`
- `BIL_AD_PROVIDER_READY=false`
- `BIL_ADMOB_PRODUCTION_READY=false`

Development/integration testing must continue to use Google's official test ad
units rather than the production banner IDs.

This file records configuration ownership only. It does not authorize a store
upload or production rollout.
