# Epic 3 visual comparison reference

## Provenance and limits

The product owner supplied MyFitnessPal screenshots in this project review on
2026-08-02 and 2026-08-03. They are comparison evidence only. BIL does not copy
the MyFitnessPal name, marks, photographs, illustrations, wording, or assets.
The screenshots inform hierarchy, density, platform conventions, and interaction
clarity; BIL retains its own medical-device, Body Twin, evidence, privacy, and
metallic-brand identity.

## Priority reference set

The seven priority screenshots are the owner-supplied files named:

- `WhatsApp Image 2026-08-03 at 12.15.52 AM.jpeg`
- `WhatsApp Image 2026-08-03 at 12.15.52 AM (1).jpeg`
- `WhatsApp Image 2026-08-03 at 12.15.52 AM (2).jpeg`
- `WhatsApp Image 2026-08-03 at 12.15.52 AM (3).jpeg`
- `WhatsApp Image 2026-08-03 at 12.15.52 AM (4).jpeg`
- `WhatsApp Image 2026-08-03 at 12.15.53 AM.jpeg`
- `WhatsApp Image 2026-08-03 at 12.15.53 AM (1).jpeg`

They cover Goals, calorie/macro targets, additional nutrient targets, Profile,
the dashboard summary, and profile overview. The earlier owner-supplied set from
`WhatsApp Image 2026-08-02 at 4.46.56 AM…` through
`WhatsApp Image 2026-08-02 at 4.47.17 AM…` covers onboarding, authentication,
diary/capture, plans, progress, recipes, exercise, devices, community, privacy,
settings, sleep, fasting, and notifications.

## Extracted rules adopted by BIL

| Reference trait | BIL Epic 3 interpretation | Evidence |
|---|---|---|
| Centered, predictable page headers | Centered app-bar titles with stable back/actions | `BilFlagshipTheme`, Epic 3 visual matrix |
| Native readable typography | Platform font; weights 400/600/700 | `epic3_unified_design_system_contract_test.dart` |
| Quiet neutral canvas and white content surfaces | Neutral light scaffold, restrained border/elevation | Theme contract and light goldens |
| Dense but legible settings/profile rows | 48+ targets, consistent row rhythm, secondary copy | Theme contract and profile/settings tests |
| Clear primary action and restrained premium accent | One dominant action; premium color is not routine chrome | Epic 3 visual matrix and commerce tests |
| Dashboard prioritizes the day’s core numbers | Summary before secondary intelligence | Dashboard goldens and composition tests |
| Arabic mirrors navigation and reading order | True RTL, not translated LTR | Arabic welcome/dashboard/system goldens |
| Dark mode is a complete theme | Dark surfaces and contrast, not a color inversion | Dark system-matrix goldens |

## Deliberate BIL differences

- No advertisements, fabricated social activity, or invented health readings.
- Medical-device and watch surfaces remain first-class BIL experiences.
- Confidence, provenance, privacy, and offline truth remain visible.
- BIL uses original icons and generated/owned imagery only.
