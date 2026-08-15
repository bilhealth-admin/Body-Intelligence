enum BilGlossaryDomain { nutrition, measurement, commerce, safety, ai }

class BilGlossaryTerm {
  const BilGlossaryTerm({
    required this.key,
    required this.english,
    required this.domain,
  });
  final String key;
  final String english;
  final BilGlossaryDomain domain;
}

/// Canonical meanings to send to professional translators. This file is not a
/// translation catalog and therefore cannot expose unreviewed target copy.
abstract final class BilHealthGlossary {
  static const terms = <BilGlossaryTerm>[
    BilGlossaryTerm(
      key: 'calories',
      english: 'Calories',
      domain: BilGlossaryDomain.nutrition,
    ),
    BilGlossaryTerm(
      key: 'protein',
      english: 'Protein',
      domain: BilGlossaryDomain.nutrition,
    ),
    BilGlossaryTerm(
      key: 'carbohydrates',
      english: 'Carbohydrates',
      domain: BilGlossaryDomain.nutrition,
    ),
    BilGlossaryTerm(
      key: 'fat',
      english: 'Fat',
      domain: BilGlossaryDomain.nutrition,
    ),
    BilGlossaryTerm(
      key: 'sodium',
      english: 'Sodium',
      domain: BilGlossaryDomain.nutrition,
    ),
    BilGlossaryTerm(
      key: 'serving',
      english: 'Serving',
      domain: BilGlossaryDomain.nutrition,
    ),
    BilGlossaryTerm(
      key: 'weight',
      english: 'Weight',
      domain: BilGlossaryDomain.measurement,
    ),
    BilGlossaryTerm(
      key: 'waist',
      english: 'Waist circumference',
      domain: BilGlossaryDomain.measurement,
    ),
    BilGlossaryTerm(
      key: 'premium',
      english: 'Premium',
      domain: BilGlossaryDomain.commerce,
    ),
    BilGlossaryTerm(
      key: 'premium_ai_coach',
      english: 'Premium AI Coach',
      domain: BilGlossaryDomain.commerce,
    ),
    BilGlossaryTerm(
      key: 'ai_boost',
      english: 'BIL AI Boost',
      domain: BilGlossaryDomain.commerce,
    ),
    BilGlossaryTerm(
      key: 'uncertain',
      english: 'Uncertain result',
      domain: BilGlossaryDomain.ai,
    ),
    BilGlossaryTerm(
      key: 'not_medical_diagnosis',
      english: 'Not a medical diagnosis',
      domain: BilGlossaryDomain.safety,
    ),
  ];
}
