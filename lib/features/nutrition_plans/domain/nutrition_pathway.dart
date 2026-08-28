enum NutritionPathwaySafety { standard, clinicianReview, medicalSupervision }

/// Commercial access for a nutrition pathway.
///
/// Premium is the fail-closed default so a newly added pathway cannot become
/// free merely because its catalog entry forgot to declare an access tier.
enum NutritionPathwayAccess { free, premium }

class NutritionPathway {
  const NutritionPathway({
    required this.id,
    required this.arTitle,
    required this.enTitle,
    required this.arSubtitle,
    required this.enSubtitle,
    required this.asset,
    required this.arTags,
    required this.enTags,
    required this.arApproach,
    required this.enApproach,
    required this.arTracking,
    required this.enTracking,
    this.safety = NutritionPathwaySafety.standard,
    this.access = NutritionPathwayAccess.premium,
  });

  final String id;
  final String arTitle;
  final String enTitle;
  final String arSubtitle;
  final String enSubtitle;
  final String asset;
  final List<String> arTags;
  final List<String> enTags;
  final List<String> arApproach;
  final List<String> enApproach;
  final List<String> arTracking;
  final List<String> enTracking;
  final NutritionPathwaySafety safety;
  final NutritionPathwayAccess access;
}
