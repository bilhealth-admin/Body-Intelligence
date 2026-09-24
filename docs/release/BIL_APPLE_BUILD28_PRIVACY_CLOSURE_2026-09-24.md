# BIL Apple Build 28 privacy closure

Baseline: `14786b08fa24991ba7445e8c607a993413a840a6` (iOS 27 / Android 22 shared source).

## Verified root causes

- AI Coach already had client and server consent gates, but the user-facing disclosure did not unambiguously identify Google Gemini as a third-party AI service operated by Google or enumerate the personal context sent.
- Meal-photo analysis used Google Gemini in production but had no separate versioned `meal_vision_ai` consent enforced before image analysis.
- The public and in-app privacy language described a configurable provider instead of the exact production processor and transmission boundaries.
- App Store screenshots included non-iOS status-bar imagery.

## Production provider evidence

- AI Coach: Google Gemini, operated by Google; production provider `gemini`, model `gemini-3.7-flash`.
- Meal vision: Google Gemini, operated by Google; production provider `gemini`, model `gemini-3.7-flash`.

AI Coach receives the submitted question and only enabled, question-relevant context: weight/goals/body measurements; meals/nutrition/water/dietary preferences; activity/training; sleep/habits; and at most 12 recent conversation turns. Raw microphone audio is not sent.

Meal vision receives the selected image, requested app locale, MIME type, schema version, and bounded request/idempotency metadata needed for analysis. Food is not logged until the user reviews and confirms the result.

## Consent enforcement

- AI Coach policy version is `3`; client preflight and `bil_has_remote_ai_consent` both fail closed.
- Meal vision uses independent purpose `meal_vision_ai`, policy version `1`; the client asks before capture/selection and the Edge Function rejects before request parsing, quota reservation, or provider fetch when current consent is absent.
- Both surfaces offer `Allow & Continue` and `Don't Allow`; denial keeps local/manual functionality available.
- Withdrawal is available in AI Coach settings and Privacy settings and prevents future remote calls.

## Deployment boundary

Source changes are prepared only. The migration, `ai-coach`, `analyze-meal`, and public privacy page require a coordinated production deployment before Build 28 is submitted. No production deployment or App Store submission was performed in this task.

## App Store Connect manual actions

1. Deploy the listed backend/site changes and verify the live privacy policy.
2. Build and upload iOS build 28 from the final audited commit.
3. In Media Manager, replace every iPhone screenshot with the eight files in `C:\Users\HP 1040 G8\Desktop\BIL_App_Store_Build_28_Screenshots_FINAL\iPhone_6_9`.
4. Inspect every iPad size separately and remove any asset containing Android/non-iOS chrome; use authentic iPad captures if that size still has affected images.
5. Add the review notes below, then resubmit only after the deployed consent gates and live privacy page are verified.

## App Review reply draft

Hello App Review,

Thank you for the detailed feedback. We addressed both issues.

For Guideline 2.3.10, we replaced the affected App Store screenshots so the iOS listing no longer contains Android or other non-iOS status-bar/interface elements.

For Guidelines 5.1.1(i) and 5.1.2(i), BIL now presents an explicit disclosure before any personal data is transmitted to a third-party AI service. The disclosure identifies Google Gemini as a third-party AI service operated by Google, explains the specific categories of data that may be transmitted for an AI Coach request, and requires the user to choose Allow & Continue before the request proceeds. Users may choose Don't Allow and continue using local functionality, and may withdraw consent later in Settings. The server also verifies a current versioned consent record before any third-party request.

Meal-photo analysis has its own pre-upload disclosure and versioned consent. It identifies Google Gemini, states that the selected meal image and minimum request metadata are sent to identify visible foods, and explains that nothing is added to the diary until the user reviews and confirms the result. The server rejects image analysis before any provider call when current meal-photo consent is absent.

We also updated the Privacy Policy to identify the relevant data categories, purposes, third-party AI processor, consent controls, and retention/deletion behavior.

## App Review Notes

To test AI Coach consent: sign in, open More > AI Coach, submit a question, and observe the Google Gemini disclosure before the first cloud request. Choose Don't Allow to remain in local functionality with no request sent. Consent can be withdrawn under More > AI Coach settings.

To test meal-photo consent: open Food Log, choose meal photo/camera analysis, and observe the separate Google Gemini meal-photo disclosure before an image is selected or uploaded. Choose Don't Allow to return to manual food entry with no image sent. Consent can be withdrawn under More > Sharing & Privacy.
