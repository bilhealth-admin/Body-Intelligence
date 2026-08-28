# BIL body model calculation contract

`BodyModelEngine` is the canonical local calculation path for energy, calorie
and macro targets, BMI, waist-to-height ratio, estimated body-fat percentage,
and estimated fat-free mass. These outputs are educational estimates, not a
diagnosis or a substitute for a measured clinical assessment.

## Inputs and formulas

- Resting energy: Mifflin-St Jeor, `10W + 6.25H - 5A + 5` for males and
  `10W + 6.25H - 5A - 161` for females, where W is kg and H is cm.
- TDEE: resting energy multiplied by the saved activity coefficient. Existing
  coefficients remain versioned product assumptions for compatibility; they
  are not presented as directly measured expenditure.
- BMI: `weightKg / heightMeters²`.
- Waist-to-height ratio: `waistCm / heightCm`. It is exposed as a continuous
  estimate rather than converted into a diagnosis.
- Male circumference body-fat estimate: the classic Hodgdon-Beckett equation
  historically associated with U.S. Navy screening, using abdomen/waist,
  neck, and height (converted to inches before log10).
- Female circumference body-fat estimate: the classic Hodgdon-Beckett equation
  requires natural waist, hips, neck, and height. Neck or hips is never
  silently discarded. When the full circumference set is unavailable, the
  result is explicitly the higher-uncertainty Deurenberg adult BMI-age-sex
  fallback. This legacy circumference estimate is not represented as the
  current U.S. Navy compliance procedure.
- Fat-free mass percentage: `100 - estimatedBodyFatPercent`; kilograms:
  `weightKg * fatFreeMassPercent / 100`.

No arbitrary normal-range clamp is applied. Invalid or non-physical results
are unavailable with a structured issue instead of being fabricated.

## Primary sources

- Mifflin MD et al. (1990), original REE equation study:
  https://pubmed.ncbi.nlm.nih.gov/2305711/
- CDC BMI calculation:
  https://www.cdc.gov/growth-chart-training/hcp/using-bmi/calculating-bmi.html
- Ashwell M (2014), waist-to-height screening evidence:
  https://pubmed.ncbi.nlm.nih.gov/25377944/
- Hodgdon JA and Beckett MB (1984), original military circumference/height
  body-composition reports, with historical context summarized by the U.S.
  National Academies:
  https://www.ncbi.nlm.nih.gov/books/NBK235939/
- Current U.S. Navy Guide 4 (consulted specifically to avoid presenting the
  legacy equations as the current compliance method):
  https://www.mynavyhr.navy.mil/Portals/55/Support/Culture%20Resilience/Physical/Guide-4%20Body%20Composition%20Assessment.pdf
- Deurenberg P et al. (1991), original adult BMI-age-sex body-fat prediction
  equation and reported standard error of estimate:
  https://pubmed.ncbi.nlm.nih.gov/2043597/

## Integration rule

Plan, BIL, dashboard, analytics, and AI Coach consumers must call
`BodyModelEngine.calculate` directly or consume the `bodyModel` attached to
`PlanRecommendation` / `BILResult`. The latest saved body-measurement record
takes precedence over onboarding profile fallbacks for waist, neck, and hips.
Consumers must not independently reimplement BMR, TDEE, BMI, or circumference
formulas.
