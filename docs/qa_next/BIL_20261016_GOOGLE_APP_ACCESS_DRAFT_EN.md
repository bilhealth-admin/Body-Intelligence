> Latest16Oct server readback: the existing dedicated Google account is `google-play-review-20261004@bilhealth.com`, with server Premium=true and AI=ai_coach and no Admin/Moderator. Use this intended Google identity in the secure App Access fields after normal-login verification; keep its existing password secure. ASC uses the separate Apple account. Current suspended Play App Access values remain unread. See the current account-alignment report.

# Google Play App Access draft — 16 October 2026

**LOCAL DRAFT / NOT SAVED / NOT AN APPEAL.** This text follows the current source at `ed963053c62cc549cbe50757279bd39d73a10e35` plus its preserved dirty changes. It has not been verified on a signed Android 33 artifact or the dedicated review account. Previously delivered build 32 is unchanged. Use the access claims below only after they have been demonstrated on the exact version that Google can review.

See the [Arabic preparation and evidence map](BIL_20261016_GOOGLE_STORE_METADATA_PREPARATION_AR.md). Play Console currently blocks App content navigation because the app is suspended. No credentials, passwords, tokens or payment receipts belong in this document or GitHub.

## Account identity correction

The owner explicitly identified `dr.kadem.nana@gmail.com` and `bilhealth.app@gmail.com` as **personal test accounts, not store reviewer accounts**. Any earlier assignment of either identity, or the aliases Reviewer-R1 / Reviewer-R2, to the store review role is withdrawn. This documentation correction changes no live authentication, role, entitlement or balance.

The root agent found the dedicated account `play-review@bilhealth.com` in live App Store Connect; the original Apple manifest agrees. The local historical file `docs/release/BIL_EPIC15_PLATFORM_METADATA.json`, field `google_play.app_access`, also references that identity. **Current Google Play App Access identity has not been read back.** The suspended Console page remains inaccessible, so historical Play metadata and live ASC evidence must not be presented as current live Google Play settings or as proof of a working account.

## Secure fields to complete in Play Console

- Instruction name: **Reusable review account — full feature access**.
- Username/email: **[DEDICATED REVIEW ACCOUNT EMAIL — enter securely in Console after verification]**. Use the dedicated identity identified above; do not substitute either personal test account. This placeholder is not a current Play readback.
- Password: **[REUSABLE DEDICATED ACCOUNT PASSWORD — enter only in the secure Console field]**. No password is stored in this draft.
- Account setup: verify that the dedicated account remains available from all reviewer locations and has the feature access and AI balance needed throughout review. Complete any first-use profile setup or document the actual steps. Do not claim that a database grant alone proves the interface opens.

## Sign-in instructions

> Select English using the language selector if needed. On the account screen, tap **Sign in**. On the next screen, tap **Store reviewer access**. Enter the email address and password provided in the App Access fields, then tap **Sign in**. Use this dedicated email/password entry; the regular email verification flow sends a one-time code.

Source labels: `premium_account_gateway_page.dart` (**Sign in**), `premium_login_page.dart:410` (**Store reviewer access**), and `login_page.dart` (**Email address**, **Password**, **Sign in**). These are source observations, not proof of a successful real login or of the labels in the old Play binary.

## Access statement — conditional on the exact account test

The following paragraph is **not yet verified**. Do not save it as a factual statement until its claims pass the actual review-account journey:

> The supplied account has the feature access and AI balance required for review. No purchase, payment card, invitation, one-time code or community posting is required to reach the review features. Subscription purchases remain optional. If an access check reports a temporary connection problem, use **Retry**; do not purchase access to continue.

If the test does not support any sentence, correct the underlying access or rewrite that sentence accurately before saving. A failed sign-in, exhausted AI balance or unexpected Plans screen is an unresolved issue, not a step to ask the reviewer to bypass.

## Navigation instructions — confirm on the intended binary

1. From **More → Goals**, open **Calorie, Carbs, Protein and Fat Goals**, **Additional Nutrient Goals**, and **Calorie Goals By Meal**. Use the in-app back control to return.
2. From **More**, open **Nutrition**, **My Meals, Recipes & Foods**, and **Recipe Discovery**.
3. From **More → AI Coach**, read the third-party AI disclosure before choosing whether to consent and send a question. Cloud AI needs internet access. A report control is available on a Coach response; verify its actual delivery against the deployed service before claiming operational review readiness.
4. From **Today**, tap **Quick Add** (+). **Analyze meal photo** opens the meal-image flow after its consent; **Scan barcode** opens barcode capture; **Exercise library** opens the exercise flow. Allow camera permission only for the camera functions being tested.
5. From **More → Apps & Devices**, the Android page is titled **Health Connect**. This release source requests read access to steps, distance and active calories only. An available Health Connect service and records from a compatible source are needed to see connected readings. Bluetooth journeys need compatible hardware and system permissions; do not describe them as simulated medical measurements.
6. From **More → Community**, review the content policy and the available reporting/blocking controls. Community posting is optional and must not be a prerequisite for the supplied account's paid or AI access.
7. From **More → Help**, open **Terms of Service** or **Delete Account**. Review deletion using a separate, disposable test account supplied for that purpose so the reusable review account remains available. Document that account securely if deletion testing is required; do not invent one here.

These steps are prepared from source. Health/device unavailability must be described accurately; it does not prove a failed entitlement. Required consent is not implied by the account's review status. Verify any first-use or restore prompts, reporting labels and actual feature availability on the exact binary before converting this draft into saved instructions.

## Administrative surfaces

The ordinary review account and Premium/AI access do not establish administrator, moderation or financial powers. If Google needs access to a role-restricted administrative surface, supply a separate, documented and safely isolated review arrangement through the secure review channel. Do not claim full access to a required surface that has not been provided, or grant financial powers over real users as a shortcut.

## Validation receipt needed before use

Record the exact version code, source commit, installable artifact SHA-256, account alias, test time, successful cold sign-in/reopen, Goals/Coach/Vision access, sufficient AI balance and any hardware limitations. Record the secure Console save/readback separately when the suspended app allows it. Do not upload or add a build, submit a review or send an appeal under this preparation task.

Google's [review sign-in requirements](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en), read on 16 October 2026, require English instructions, continuously valid reusable access regardless of reviewer location, and access to restricted features without payment. This draft is not evidence that BIL has passed those checks.
