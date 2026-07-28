# Google Play Data Safety — Working Draft

**Status: draft only. Do not submit until the final production SDK and cloud inventory is frozen.**

## Current code-derived position

- BIL stores profile, body measurements, weight, nutrition, meals, water, preferences, and local decision evidence on device.
- Cloud activation defaults to disabled and requires explicit build-time configuration.
- Health Connect permissions expose sensitive health and fitness data only after user authorization.
- No advertising SDK is present in the reviewed dependency set.
- Billing and Play Integrity are not activated.
- Runtime Google Fonts fetching is removed by this package.

## Must be reassessed before submission

- Supabase production activation and server logs.
- AI provider or proxy activation.
- Crash reporting, analytics, attribution, notifications, or support SDKs.
- Account identifiers and cloud deletion workflow.
- Any sharing/export workflow selected by the user.
- Every transitive SDK listed in the final release lockfile.

## Play Console work

Complete the Data Safety form even when a release remains local-first. The declaration must match the final privacy policy and every enabled SDK.
