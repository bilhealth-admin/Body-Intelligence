import '../../engine/personal_baseline_engine.dart';

String localizedBaselineConfidence(
  BaselineConfidence confidence, {
  required bool arabic,
}) {
  if (!arabic) return confidence.name;
  return switch (confidence) {
    BaselineConfidence.insufficient => 'غير كافية',
    BaselineConfidence.low => 'منخفضة',
    BaselineConfidence.medium => 'متوسطة',
    BaselineConfidence.high => 'مرتفعة',
  };
}
