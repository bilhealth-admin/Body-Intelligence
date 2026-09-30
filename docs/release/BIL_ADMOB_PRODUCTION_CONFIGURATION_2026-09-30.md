# BIL AdMob production configuration — 2026-09-30

Owner-confirmed public AdMob identifiers for **Body Intelligence Log**.

## Publisher

- Publisher ID: `pub-2630393550537588`
- app-ads.txt record:
  `google.com, pub-2630393550537588, DIRECT, f08c47fec0942fa0`

## Android

- App ID: `ca-app-pub-2630393550537588~1063981798`
- Banner ad unit ID: `ca-app-pub-2630393550537588/1281361803`

## iOS

- App ID: `ca-app-pub-2630393550537588~3636062400`
- Banner ad unit ID: `ca-app-pub-2630393550537588/4458189488`

## Release state

These identifiers are production configuration inputs only.

Advertising remains **disabled** in the audited Android/iOS release workflows:
- `BIL_ADS_ENABLED=false`
- `BIL_AD_PROVIDER_READY=false`

The signed release workflows continue to remove/defer native AdMob integration while those gates are false. Do not change the gates until:
1. the Android/iOS store listings are linked in AdMob,
2. the public `https://www.bilhealth.com/app-ads.txt` endpoint serves the exact record above,
3. AdMob/app readiness and consent configuration are verified.

This file does not authorize an Android/iOS build or any store upload.
