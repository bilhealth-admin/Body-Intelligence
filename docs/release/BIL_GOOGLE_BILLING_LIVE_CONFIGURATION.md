# BIL Google Billing live configuration

The purchase verifier accepts both licensed-test and production transactions.
The environment is never accepted from the client:

- Google test state comes from the authenticated Android Publisher API.
- Apple environment comes from the verified StoreKit transaction JWS.

`BIL_STORE_ENVIRONMENT` is therefore intentionally not required.

## Confirmed configuration

- Supabase project: `tgmanzhqulksykhslrzb`
- Android package: `com.bilhealth.bodyintelligencelog`
- Purchase endpoint: `https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/verify-store-purchase`
- Current Google products: `bil_premium`, `bil_premium_annual`,
  `bil_premium_ai_coach`, and `bil_premium_ai_coach_annual`
- `bil_ai_boost` is a consumable and remains outside the subscription registry.
- Two existing service-account credentials independently authenticate to the
  Android Publisher API for this package. Their key material must remain out of
  source, logs, mobile binaries and documentation.
- The live subscription catalog has active `P1M`/`P1Y` Premium plans without a
  trial, and active AI monthly/yearly plans with the exact active offer
  `trial-7-day`, tag `new-customer`, and one free `P7D` cycle. The erroneous
  monthly plan under the annual AI product is inactive, not deleted.
- The live consumable `bil_ai_boost` / `standard-2500` is active. Current US
  price is USD 4.99; this document does not authorize price changes.
- AI monthly and annual now both cover 168 configured regions. Belarus monthly
  is USD 7.19 from Google's current conversion and is included in the exact
  seven-day trial; Belarus annual USD 43.19 and Boost USD 6.00 were unchanged.
- Sanitized API evidence is stored under
  `artifacts/release/google/2026-08-31-api-audit/` and
  `artifacts/release/google/2026-08-31-exact-catalog-repair/`, with the isolated
  Belarus repair under
  `artifacts/release/google/2026-08-31-by-monthly-repair/`.

## Owner actions still required

1. Confirm that one existing Android Publisher account is the intended
   least-privilege production verifier. Do not create or download another key
   merely because this confirmation is pending.
2. Confirm that its complete JSON is stored in Supabase secret
   `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. When that dedicated secret is absent,
   the backend can reuse `BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON` if the same
   account has Android Publisher access. Never add either value to Git or the
   app.
3. Create a Pub/Sub topic for Google Play real-time developer notifications.
   Grant `google-play-developer-notifications@system.gserviceaccount.com` the
   `Pub/Sub Publisher` role on that topic.
4. Create a dedicated user-managed push service account in the same project.
   Grant the Pub/Sub service agent
   `service-{PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com` the
   `Service Account Token Creator` role on the push service account. The human
   or principal attaching it also needs `iam.serviceAccounts.actAs`.
5. Create a push subscription targeting the purchase endpoint above. Set its
   OIDC audience to that exact endpoint URL.
6. Store the exact audience in `GOOGLE_PUBSUB_AUDIENCE` and the exact push
   service-account email in `GOOGLE_PUBSUB_SERVICE_ACCOUNT`.
7. In Play Console, select the topic under Monetize setup / real-time developer
   notifications. Select **subscriptions and one-time products**, send Google's
   test notification, and confirm the matching inbox row becomes `processed`.
8. Use a licensed tester and Google test payment method for purchase tests.
   Never use a production purchase for configuration validation.

The confirmed package secret can be set independently as
`GOOGLE_PLAY_PACKAGE_NAME=com.bilhealth.bodyintelligencelog`.
