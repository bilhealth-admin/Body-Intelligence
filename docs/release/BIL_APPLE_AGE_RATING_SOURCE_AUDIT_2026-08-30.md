# BIL Apple age-rating source audit — 2026-08-30

## Decision

`APPLE_AGE_RATING_DECLARATION=TRUTHFUL_WITH_18_PLUS_OVERRIDE`

BIL is an adult fitness, nutrition, and wellness product. The current `18+`
product boundary is deliberate and is enforced from exact date of birth in
onboarding and startup recovery. The higher App Store display is therefore not
evidence that BIL is a medical device or provides diagnosis. Do not reduce the
override to pursue a lower storefront rating while the product requires users
to be at least 18.

Apple states that an app whose minimum age in its EULA/product rules exceeds
the calculated questionnaire rating must use **Override to Higher Age Rating**.
Apple also assigns region-specific displays, so a Korean `19+` result is not by
itself a medical-content finding.

## Exact truthful questionnaire answers

These answers reflect the current release source and the signed iOS workflow,
not planned future functionality.

| Questionnaire item | Answer | Current source evidence |
|---|---|---|
| Parental Controls | No | BIL has no parent/guardian control surface. |
| Age Assurance | Yes | `AdultEligibility.minimumAge = 18`; onboarding collects exact DOB and startup sends an ineligible legacy profile back to the DOB gate. |
| Unrestricted Web Access | No | BIL opens fixed support/legal/provider links externally; it has no unrestricted in-app browser. |
| User-Generated Content | Yes | Authenticated Community supports user posts, profile media, and community food submissions. |
| Social Media | Yes | Community discovery and interaction distribute user-created content. |
| Social Media Disabled for Users Under 13 | No | The whole product blocks users under 18, but this special Apple flag requires at least the Declared Age Range API; BIL's current gate is its own exact-DOB policy. |
| Messaging and Chat | Yes | Authenticated users can use private messaging and public/community posting. |
| Advertising | No for version 1.0 iOS candidate | The signed iOS workflow does not enable `BIL_ADS_ENABLED` or `BIL_AD_PROVIDER_READY`; the release gateway fails closed. Re-answer before any build that enables ads. |
| Health or Wellness Topics | Yes | Calorie and macro tracking, diet guidance, exercise, sleep, fasting, body goals, and connected-fitness summaries are core features. |
| Medical or Treatment Information | Infrequent | BIL presents limited safety/emergency, medication, pregnancy, eating-disorder, diabetes-care, and clinician guidance. It does not diagnose or generate treatment. |
| Profanity or Crude Humor | None | Not authored or intended product content; UGC is covered separately and moderated. |
| Horror/Fear Themes | None | No such authored content. |
| Alcohol, Tobacco, or Drug Use or References | Infrequent | Product classification can identify and reject non-food tobacco/medicine products; alcohol can be logged and appears in a limited recovery summary. |
| Mature or Suggestive Themes | None | No such authored content. |
| Sexual Content or Nudity | None | No such authored content. |
| Graphic Sexual Content and Nudity | None | No such authored content. |
| Cartoon or Fantasy Violence | None | No such authored content. |
| Realistic Violence | None | No such authored content. |
| Prolonged Graphic or Sadistic Realistic Violence | None | No such authored content. |
| Guns or Other Weapons | None | No such authored content. |
| Gambling | None | No gambling. |
| Simulated Gambling | None | No simulated gambling. |
| Contests | Infrequent | BIL exposes private/shared fitness challenges for personal goals, without wagering or randomized rewards. |
| Loot Boxes | None | No randomized purchasable items. |

## Source boundaries that prevent medical overclaiming

- The public nutrition-pathway catalog excludes PSMF entirely. Exact lookup,
  draft loading, deep-linking, and activation all fail closed for `psmf`.
- HealthKit is optional and user initiated. The release bridge writes only the
  reviewed weight record type and does not enable background delivery.
- Body-composition output is labeled as an educational estimate, not a
  diagnosis.
- AI Coach safety copy refuses diagnosis/treatment and can only offer general
  information or direct urgent users to qualified/local emergency care.

These boundaries support **fitness/wellness positioning**, but they do not make
the limited safety and clinician references disappear. `Medical or Treatment
Information = Infrequent` is therefore safer and more accurate than `None`.

## Required release regression

Before attaching the final build:

1. verify the 18+ DOB gate using dates immediately on both sides of the exact
   birthday boundary;
2. verify a stored legacy under-18 profile is returned to DOB onboarding;
3. verify PSMF is absent from the public catalog and cannot be activated by an
   exact route/draft request;
4. confirm the final iOS workflow still leaves advertising disabled, or update
   the questionnaire before submission;
5. do not alter the current App Store Connect age-rating declaration unless
   the shipped source changes one of the answers above.

## Official Apple references

- Age-rating values, current questionnaire categories, and definitions:
  https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- Setting a rating and the mandatory higher-age override rule:
  https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/

