# BIL App Store Connect availability audit

- Audited at: `2026-08-30T03:09:40.806Z`
- Mode: read-only App Store Connect API
- Mutation performed: `false`
- App: `BIL - Body Intelligence Log`
- App Store Connect app ID: `6805349703`
- Bundle ID: `com.bilhealth.bodyintelligencelog`

## Result

`AVAILABILITY_SELECTION_ALL_175=PASS`

- Apple currently reports `175` active App Store territories.
- BIL has `175` territory-availability records, all `175` have `available=true`, and none of Apple's active territories are missing.
- Every one of the `175` records contains the machine status `AVAILABLE_FOR_SALE_UNRELEASED_APP`. This is the API evidence corresponding to the App Store Connect state **Available on App Release**.
- `availableInNewTerritories=true`, so newly added App Store territories are selected automatically.
- No territory is configured for pre-order and no territory has a scheduled release date.
- iOS version `1.0` is currently `PREPARE_FOR_SUBMISSION`, with `releaseType=MANUAL` and `downloadable=true`.

## Important current blockers

`CURRENT_SELLABILITY=BLOCKED`

- All `175` territory records also contain `CANNOT_SELL`. The API does not give a per-territory reason for that flag in this response. The app is still unreleased (`PREPARE_FOR_SUBMISSION`), so the availability selection is ready for release but the app is not currently on sale.
- The following `27` EU territories additionally contain the explicit blocker `TRADER_STATUS_NOT_PROVIDED`: `AUT, BEL, BGR, CYP, CZE, DEU, DNK, ESP, EST, FIN, FRA, GRC, HRV, HUN, IRL, ITA, LTU, LUX, LVA, MLT, NLD, POL, PRT, ROU, SVK, SVN, SWE`.
- Completing the Digital Services Act trader-status requirement in App Store Connect is therefore required for EU distribution. This does not change the fact that all 175 territories are selected as Available on App Release.

## API evidence

All requests returned HTTP `200`:

| Purpose | Endpoint |
|---|---|
| Resolve BIL app | `GET /v1/apps?filter[bundleId]=com.bilhealth.bodyintelligencelog&limit=10` |
| Read app availability | `GET /v1/apps/6805349703/appAvailabilityV2` |
| Read all territory availability | `GET /v2/appAvailabilities/6805349703/territoryAvailabilities?include=territory&limit=200...` |
| Count active App Store territories | `GET /v1/territories?limit=200...` |

Apple API references:

- [List Availability for an App](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-appavailabilityv2)
- [Read app availability territories](https://developer.apple.com/documentation/appstoreconnectapi/get-v2-appavailabilities-_id_-territoryavailabilities)
- [Territories](https://developer.apple.com/documentation/appstoreconnectapi/territories)

Credential material was read only from the existing protected Apple metadata/key location. This report contains no issuer ID, API key ID, private-key path, private key, or token.
