enum HealthEvidenceCategory {
  energy,
  nutrition,
  hydration,
  bodyComposition,
  weightPlanning,
  pregnancy,
  sleep,
  fasting,
  exercise,
  dietaryPattern,
}

final class HealthEvidenceSource {
  const HealthEvidenceSource({
    required this.id,
    required this.title,
    required this.organization,
    required this.url,
    required this.category,
    required this.shortDescription,
    required this.methodologyNote,
    required this.lastReviewed,
  });

  final String id;
  final String title;
  final String organization;
  final Uri url;
  final HealthEvidenceCategory category;
  final String shortDescription;
  final String methodologyNote;
  final DateTime lastReviewed;
}

abstract final class HealthEvidenceIds {
  static const cdcWeightLoss = 'cdc_weight_loss';
  static const weightEnergyApproximation = 'wishnofsky_weight_energy';
  static const dietaryReferenceIntakes = 'national_academies_dri';
  static const healthyEating = 'cdc_healthy_eating';
  static const whoSodiumPotassium = 'who_sodium_potassium';
  static const mifflinStJeor = 'mifflin_st_jeor';
  static const proteinExercise = 'issn_protein_exercise';
  static const cdcAdultBmi = 'cdc_adult_bmi';
  static const niceWaistToHeight = 'nice_waist_to_height';
  static const deurenbergBodyFat = 'deurenberg_body_fat';
  static const hodgdonBeckett = 'hodgdon_beckett_circumference';
  static const pregnancyIronFolate = 'who_pregnancy_iron_folate';
  static const pregnancyCalcium = 'who_pregnancy_calcium';
  static const pregnancyIodine = 'who_unicef_pregnancy_iodine';
  static const pregnancyEnergy = 'national_academies_pregnancy_energy';
  static const adultSleep = 'sleep_foundation_adult_duration';
  static const activityGuidelines = 'hhs_physical_activity_guidelines';
  static const exerciseMet = 'adult_compendium_met_2024';
  static const fastingSafety = 'niddk_intermittent_fasting_safety';
  static const dash = 'nhlbi_dash';
  static const mediterranean = 'predimed_2018';
  static const veryLowCalorieSupervision = 'niddk_vlcd_supervision';
}

abstract final class HealthEvidenceCatalog {
  static final DateTime _reviewed = DateTime.utc(2026, 9, 22);

  static final List<HealthEvidenceSource> all = List.unmodifiable([
    _source(
      HealthEvidenceIds.cdcWeightLoss,
      'Steps for Losing Weight',
      'U.S. Centers for Disease Control and Prevention (CDC)',
      'https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html',
      HealthEvidenceCategory.weightPlanning,
      'General gradual weight-loss and healthy-weight planning guidance.',
      'BIL timelines are planning estimates, not promised biological outcomes.',
    ),
    _source(
      HealthEvidenceIds.weightEnergyApproximation,
      'Caloric equivalents of gained or lost weight',
      'American Journal of Clinical Nutrition / PubMed',
      'https://pubmed.ncbi.nlm.nih.gov/13594881/',
      HealthEvidenceCategory.weightPlanning,
      'Historical source for the approximately 7,700 kcal per kilogram planning conversion.',
      'BIL uses this only as a transparent static planning approximation. Real weight change is dynamic and the estimate is not a promised outcome.',
    ),
    _source(
      HealthEvidenceIds.dietaryReferenceIntakes,
      'Dietary Reference Intakes',
      'U.S. National Academies / Office of Disease Prevention and Health Promotion',
      'https://odphp.health.gov/our-work/nutrition-physical-activity/dietary-guidelines/dietary-reference-intakes',
      HealthEvidenceCategory.nutrition,
      'Population reference framework for energy, nutrients, and total water.',
      'BIL uses this framework as context for editable planning estimates. The app-specific 35 mL/kg water starting point, optional 750 mL exercise allowance, activity multipliers, and macro split are disclosed planning heuristics rather than values prescribed by this source.',
    ),
    _source(
      HealthEvidenceIds.healthyEating,
      'Healthy Eating for a Healthy Weight',
      'U.S. Centers for Disease Control and Prevention (CDC)',
      'https://www.cdc.gov/healthy-weight-growth/healthy-eating/index.html',
      HealthEvidenceCategory.dietaryPattern,
      'General food-pattern guidance used across non-medical nutrition pathways.',
      'Food-pattern guidance does not replace allergy, medication, or clinical diet advice.',
    ),
    _source(
      HealthEvidenceIds.whoSodiumPotassium,
      'Healthy diet: sodium and potassium references',
      'World Health Organization (WHO)',
      'https://www.who.int/news-room/fact-sheets/detail/healthy-diet',
      HealthEvidenceCategory.nutrition,
      'Adult population reference of less than 2,000 mg sodium and at least 3,510 mg potassium per day.',
      'These population references are distinct from a saved or pathway-specific BIL target.',
    ),
    _source(
      HealthEvidenceIds.mifflinStJeor,
      'A new predictive equation for resting energy expenditure',
      'American Journal of Clinical Nutrition / PubMed',
      'https://pubmed.ncbi.nlm.nih.gov/2305711/',
      HealthEvidenceCategory.energy,
      'Published basis for the Mifflin–St Jeor resting-energy estimate.',
      'BMR and TDEE are calculated estimates, not direct metabolic measurements.',
    ),
    _source(
      HealthEvidenceIds.proteinExercise,
      'International Society of Sports Nutrition position stand: protein and exercise',
      'Journal of the International Society of Sports Nutrition / PubMed',
      'https://pubmed.ncbi.nlm.nih.gov/28642676/',
      HealthEvidenceCategory.nutrition,
      'Reference for the 1.4–2.0 g/kg range for most exercising adults.',
      'BIL uses 1.4 or 1.8 g/kg as an editable planning target; individual clinical needs can differ.',
    ),
    _source(
      HealthEvidenceIds.cdcAdultBmi,
      'Adult BMI categories',
      'U.S. Centers for Disease Control and Prevention (CDC)',
      'https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html',
      HealthEvidenceCategory.bodyComposition,
      'Adult BMI screening categories.',
      'BMI is a screening measure and is not a diagnosis or direct body-fat measurement.',
    ),
    _source(
      HealthEvidenceIds.niceWaistToHeight,
      'BMI and waist-to-height ratio recommendations',
      'UK National Institute for Health and Care Excellence (NICE)',
      'https://www.nice.org.uk/guidance/ng246/chapter/Recommendations#using-body-mass-index-bmi-and-waist-to-height-ratio-to-assess-overweight-obesity-and-central-adiposity',
      HealthEvidenceCategory.bodyComposition,
      'Reference for adult waist-to-height screening and the under-one-half message.',
      'Waist-to-height ratio is a screening estimate, not a diagnosis.',
    ),
    _source(
      HealthEvidenceIds.deurenbergBodyFat,
      'Body mass index as a measure of body fatness',
      'British Journal of Nutrition / PubMed',
      'https://pubmed.ncbi.nlm.nih.gov/2043597/',
      HealthEvidenceCategory.bodyComposition,
      'Source for the adult BMI-age-sex body-fat fallback equation.',
      'The publication reports an estimation error; BIL marks this fallback as higher uncertainty.',
    ),
    _source(
      HealthEvidenceIds.hodgdonBeckett,
      'Circumference-based body-fat equations (Hodgdon and Beckett)',
      'U.S. National Academies / Naval Health Research Center reference',
      'https://www.ncbi.nlm.nih.gov/books/NBK235955/',
      HealthEvidenceCategory.bodyComposition,
      'Historical methodology reference for sex-specific circumference estimates.',
      'BIL presents this result as an estimate, not a current service standard or clinical measurement.',
    ),
    _source(
      HealthEvidenceIds.pregnancyIronFolate,
      'Daily iron and folic acid supplementation in pregnancy',
      'World Health Organization (WHO)',
      'https://www.who.int/publications/i/item/9789241501996',
      HealthEvidenceCategory.pregnancy,
      'Supports the displayed 30–60 mg elemental iron and 400 µg folic-acid guidance.',
      'Supplement dosing must be reviewed with a qualified pregnancy-care clinician.',
    ),
    _source(
      HealthEvidenceIds.pregnancyCalcium,
      'Calcium supplementation during pregnancy',
      'World Health Organization (WHO)',
      'https://www.who.int/publications/i/item/9789241550451',
      HealthEvidenceCategory.pregnancy,
      'Supports 1.5–2.0 g elemental calcium where dietary calcium intake is low.',
      'This is conditional population guidance, not a universal supplement prescription.',
    ),
    _source(
      HealthEvidenceIds.pregnancyIodine,
      'Optimal iodine nutrition in pregnancy and lactation',
      'World Health Organization (WHO) / UNICEF',
      'https://www.who.int/publications/m/item/WHO-statement-IDD-pregnantwomen-children',
      HealthEvidenceCategory.pregnancy,
      'Public-health basis for the displayed 250 µg daily iodine reference.',
      'Supplementation depends on local iodine coverage and individual clinician guidance.',
    ),
    _source(
      HealthEvidenceIds.pregnancyEnergy,
      'Dietary Reference Intakes for pregnancy energy',
      'U.S. National Academies / National Library of Medicine',
      'https://www.ncbi.nlm.nih.gov/sites/books/NBK32812/',
      HealthEvidenceCategory.pregnancy,
      'Supports the +0, +340, and +452 kcal trimester energy increments.',
      'Energy needs vary with pre-pregnancy status, activity, and clinical care.',
    ),
    _source(
      HealthEvidenceIds.adultSleep,
      'Recommended amount of sleep for a healthy adult',
      'National Sleep Foundation expert panel / PubMed',
      'https://pubmed.ncbi.nlm.nih.gov/29073398/',
      HealthEvidenceCategory.sleep,
      'Consensus reference for the general 7–9 hour adult sleep range.',
      'Recorded sleep is not altered; this source supports only planning guidance.',
    ),
    _source(
      HealthEvidenceIds.activityGuidelines,
      'Physical Activity Guidelines for Americans',
      'U.S. Department of Health and Human Services',
      'https://health.gov/our-work/nutrition-physical-activity/physical-activity-guidelines/current-guidelines',
      HealthEvidenceCategory.exercise,
      'Evidence-based adult movement and muscle-strengthening guidance.',
      'Activity guidance is general and must be adapted for symptoms, pregnancy, injury, or medical restrictions.',
    ),
    _source(
      HealthEvidenceIds.exerciseMet,
      '2024 Adult Compendium of Physical Activities',
      'Journal of Sport and Health Science / PubMed Central',
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/',
      HealthEvidenceCategory.exercise,
      'Source for standardized MET intensity values used in manual energy estimates.',
      'Manual kcal is estimated as MET × kg × hours and never presented as device-measured active energy.',
    ),
    _source(
      HealthEvidenceIds.fastingSafety,
      'Intermittent fasting and type 2 diabetes',
      'U.S. National Institute of Diabetes and Digestive and Kidney Diseases (NIDDK)',
      'https://www.niddk.nih.gov/health-information/professionals/diabetes-discoveries-practice/patients-intermittent-fasting',
      HealthEvidenceCategory.fasting,
      'Discusses evidence limits and cautions for diabetes, pregnancy, eating-disorder history, and older adults.',
      'BIL does not imply fasting is universally appropriate; medication and medical risks require clinician review.',
    ),
    _source(
      HealthEvidenceIds.dash,
      'Following the DASH eating plan',
      'U.S. National Heart, Lung, and Blood Institute (NHLBI)',
      'https://www.nhlbi.nih.gov/health/dash/following-dash',
      HealthEvidenceCategory.dietaryPattern,
      'Primary reference for the DASH food pattern and calorie-level servings.',
      'Medical conditions and medication-related sodium or potassium limits require clinician guidance.',
    ),
    _source(
      HealthEvidenceIds.mediterranean,
      'Primary prevention with a Mediterranean diet — corrected PREDIMED report',
      'New England Journal of Medicine / PubMed',
      'https://pubmed.ncbi.nlm.nih.gov/29897866/',
      HealthEvidenceCategory.dietaryPattern,
      'Corrected trial publication supporting the Mediterranean dietary pattern evidence summary.',
      'BIL presents a flexible food pattern, not a treatment claim.',
    ),
    _source(
      HealthEvidenceIds.veryLowCalorieSupervision,
      'Choosing a safe and successful weight-loss program',
      'U.S. National Institute of Diabetes and Digestive and Kidney Diseases (NIDDK)',
      'https://www.niddk.nih.gov/-/media/Files/Weight-Management/Choosingprogram0208.pdf',
      HealthEvidenceCategory.dietaryPattern,
      'Reference for close medical supervision of very-low-calorie approaches.',
      'BIL marks PSMF as medical-supervision only and does not prescribe it independently.',
    ),
  ]);

  static final Map<String, HealthEvidenceSource> _byId = Map.unmodifiable({
    for (final source in all) source.id: source,
  });

  static HealthEvidenceSource? byId(String id) => _byId[id];

  static List<String> validateIds(Iterable<Object?> values) {
    final seen = <String>{};
    return List.unmodifiable(
      values
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => _byId.containsKey(value) && seen.add(value)),
    );
  }

  static List<HealthEvidenceSource> resolve(Iterable<String> ids) =>
      List.unmodifiable(validateIds(ids).map((id) => _byId[id]!));

  static List<String> forTopic(String? topic) {
    if (topic != null && topic.startsWith('pathway:')) {
      return forPathway(topic.substring('pathway:'.length));
    }
    return switch (topic) {
      'pregnancy' => const [
        HealthEvidenceIds.pregnancyIronFolate,
        HealthEvidenceIds.pregnancyCalcium,
        HealthEvidenceIds.pregnancyIodine,
        HealthEvidenceIds.pregnancyEnergy,
      ],
      'body-screening' || 'body-composition' => const [
        HealthEvidenceIds.cdcAdultBmi,
        HealthEvidenceIds.niceWaistToHeight,
        HealthEvidenceIds.hodgdonBeckett,
        HealthEvidenceIds.deurenbergBodyFat,
      ],
      'weight-planning' => const [
        HealthEvidenceIds.cdcWeightLoss,
        HealthEvidenceIds.weightEnergyApproximation,
      ],
      'sleep' => const [HealthEvidenceIds.adultSleep],
      'fasting' => const [HealthEvidenceIds.fastingSafety],
      'exercise-met' => const [
        HealthEvidenceIds.exerciseMet,
        HealthEvidenceIds.activityGuidelines,
      ],
      'heart-health' => const [HealthEvidenceIds.whoSodiumPotassium],
      'nutrition-targets' => const [
        HealthEvidenceIds.mifflinStJeor,
        HealthEvidenceIds.dietaryReferenceIntakes,
        HealthEvidenceIds.proteinExercise,
        HealthEvidenceIds.whoSodiumPotassium,
      ],
      'ai-coach' => all.map((source) => source.id).toList(growable: false),
      _ => const <String>[],
    };
  }

  static List<String> forPathway(String pathwayId) => switch (pathwayId) {
    'pregnancy' => forTopic('pregnancy'),
    'dash' => const [
      HealthEvidenceIds.dash,
      HealthEvidenceIds.whoSodiumPotassium,
    ],
    'mediterranean' => const [HealthEvidenceIds.mediterranean],
    'high-protein' || 'lean-mass' => const [
      HealthEvidenceIds.proteinExercise,
      HealthEvidenceIds.dietaryReferenceIntakes,
    ],
    'psmf' => const [
      HealthEvidenceIds.veryLowCalorieSupervision,
      HealthEvidenceIds.proteinExercise,
    ],
    'cutting' => const [
      HealthEvidenceIds.cdcWeightLoss,
      HealthEvidenceIds.weightEnergyApproximation,
    ],
    _ => const [
      HealthEvidenceIds.dietaryReferenceIntakes,
      HealthEvidenceIds.healthyEating,
    ],
  };

  static HealthEvidenceSource _source(
    String id,
    String title,
    String organization,
    String url,
    HealthEvidenceCategory category,
    String shortDescription,
    String methodologyNote,
  ) => HealthEvidenceSource(
    id: id,
    title: title,
    organization: organization,
    url: Uri.parse(url),
    category: category,
    shortDescription: shortDescription,
    methodologyNote: methodologyNote,
    lastReviewed: _reviewed,
  );
}
