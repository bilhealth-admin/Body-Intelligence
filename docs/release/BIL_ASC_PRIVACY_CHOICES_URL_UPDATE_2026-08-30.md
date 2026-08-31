# BIL App Store Connect Privacy Choices URL update

- Read-before-write at: `2026-08-30T03:29:32.315Z`
- Verified read-back at: `2026-08-30T03:29:33.189Z`
- App Store Connect app ID: `6805349703`
- Bundle ID: `com.bilhealth.bodyintelligencelog`
- Locale: `en-US`
- App Info Localization ID: `2ed17031-9665-4f8f-9a75-e4efd2e4e178`

## Result

`ASC_PRIVACY_CHOICES_URL_UPDATE=PASS`

- Before: `privacyChoicesUrl` was absent (`null`).
- Updated exactly one attribute: `privacyChoicesUrl`.
- After: `privacyChoicesUrl=https://www.bilhealth.com/account-deletion`.
- Read-back matched the target URL exactly.
- `privacyPolicyUrl` was and remains exactly `https://www.bilhealth.com/privacy`.
- No App Privacy questionnaire answers, health answers, data categories, availability, version, build, or other localization attributes were changed.

## API evidence

| Step | Endpoint | HTTP status |
|---|---|---:|
| Resolve App Info | `GET /v1/apps/6805349703/appInfos?limit=200` | 200 |
| Resolve `en-US` localization | `GET /v1/appInfos/{appInfoId}/appInfoLocalizations?filter[locale]=en-US&limit=200` | 200 |
| Read before | `GET /v1/appInfoLocalizations/2ed17031-9665-4f8f-9a75-e4efd2e4e178?fields[appInfoLocalizations]=locale,privacyPolicyUrl,privacyChoicesUrl` | 200 |
| Single-field update | `PATCH /v1/appInfoLocalizations/2ed17031-9665-4f8f-9a75-e4efd2e4e178` | 200 |
| Verified read-back | `GET /v1/appInfoLocalizations/2ed17031-9665-4f8f-9a75-e4efd2e4e178?fields[appInfoLocalizations]=locale,privacyPolicyUrl,privacyChoicesUrl` | 200 |

The PATCH body contained only the resource type, localization ID, and `attributes.privacyChoicesUrl`.

Official API reference: [Modify an app info localization](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appinfolocalizations-_id_)

No API key ID, issuer ID, private-key path, private key, token, or user data is present in this report.
