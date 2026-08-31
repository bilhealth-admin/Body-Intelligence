# BIL App Privacy API readability audit

- Audited at: `2026-08-30T03:23:03.638Z`
- Mode: read-only App Store Connect API and official OpenAPI inspection
- Mutation performed: `false`
- App Store Connect app ID: `6805349703`
- Bundle ID: `com.bilhealth.bodyintelligencelog`

## Result

`LIVE_APP_PRIVACY_ANSWERS_VIA_ASC_API=NOT_EXPOSED`

The public App Store Connect API does not expose the live App Privacy/App Data Usage questionnaire answers. It therefore cannot return the live collected-data categories, whether each category is linked to the user, whether it is used for tracking, or its declared purposes.

This is an API-surface limitation, not an observed credential-scope failure:

- `GET /v1/apps/6805349703` returned HTTP `200`. Its live relationship list has no App Privacy, App Data Usage, or collected-data-answer resource.
- `GET /v1/apps/6805349703/appInfos?limit=200` returned HTTP `200`.
- `GET /v1/appInfos/{appInfoId}/appInfoLocalizations?limit=200` returned HTTP `200`. The `en-US` localization has a Privacy Policy URL, but no Privacy Choices URL or inline privacy-policy text.
- Apple's official OpenAPI specification version `4.4.1` contains `966` paths and `1,393` schemas. It contains zero paths and zero schemas for App Privacy answers, privacy details, data usage, data collection, linkage, tracking, or questionnaire purposes. The only relevant exposed metadata fields are `privacyPolicyUrl`, `privacyChoicesUrl`, and `privacyPolicyText` on app-info localizations, plus privacy-policy fields for Beta localizations.

Consequently, a live-versus-source answer comparison cannot be completed through the supported App Store Connect API. The exact remaining evidence step is to read/export the published App Privacy answers from the authenticated App Store Connect web interface and compare them with the source baseline below.

## Current source baseline

Source: `ios/Runner/PrivacyInfo.xcprivacy`

- SHA-256: `cca7803122e4c318ac40e371ca33285065a36231eacdc73c3b1ac4e639b182de`
- Global tracking: `false`
- Tracking domains: none
- Collected data types: `17`
- All 17 are linked to the user: `true`
- All 17 are used for tracking: `false`

| Data type | Linked | Tracking | Purposes |
|---|---:|---:|---|
| Name | Yes | No | App Functionality; Product Personalization |
| Email Address | Yes | No | App Functionality |
| Phone Number | Yes | No | App Functionality |
| Health | Yes | No | App Functionality; Product Personalization |
| Fitness | Yes | No | App Functionality; Product Personalization |
| User ID | Yes | No | App Functionality |
| Device ID | Yes | No | App Functionality |
| Other User Content | Yes | No | App Functionality; Product Personalization |
| Customer Support | Yes | No | App Functionality |
| Emails or Text Messages | Yes | No | App Functionality |
| Photos or Videos | Yes | No | App Functionality |
| Purchase History | Yes | No | App Functionality |
| Product Interaction | Yes | No | App Functionality |
| Search History | Yes | No | App Functionality |
| Performance Data | Yes | No | App Functionality |
| Other Diagnostic Data | Yes | No | App Functionality |
| Other Data Types | Yes | No | App Functionality; Product Personalization |

`LIVE_VS_SOURCE_COMPARISON=BLOCKED_BY_ASC_API_SURFACE`

Official references:

- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi/)
- [App Privacy reference](https://developer.apple.com/help/app-store-connect/reference/app-privacy/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)

No API key ID, issuer ID, private-key path, private key, token, private URL value, or user data is present in this report.
