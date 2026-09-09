/// Default daily references used to animate the heart-health nutrient meters.
///
/// They are population-level WHO guidance for adults, not personal medical
/// prescriptions. A positive target saved by the user takes precedence.
final class DashboardHeartHealthPolicy {
  const DashboardHeartHealthPolicy._();

  /// WHO suggests at least 90 mmol (3510 mg) potassium a day for adults.
  static const int potassiumDailyTargetMg = 3510;

  /// WHO recommends less than 2000 mg sodium a day for adults.
  static const int sodiumDailyReferenceMg = 2000;

  /// WHO recommends at least 25 g naturally occurring dietary fibre daily.
  static const int fiberDailyTargetG = 25;

  static int potassiumGoal(int? savedGoal) =>
      savedGoal != null && savedGoal > 0 ? savedGoal : potassiumDailyTargetMg;

  static int sodiumGoal(int? savedGoal) =>
      savedGoal != null && savedGoal > 0 ? savedGoal : sodiumDailyReferenceMg;

  static int fiberGoal(int? savedGoal) =>
      savedGoal != null && savedGoal > 0 ? savedGoal : fiberDailyTargetG;

  /// Returns the visible fraction for a meter, capped at 100%.
  static double coverage({required num? recorded, required num maximum}) {
    if (recorded == null || !recorded.isFinite || maximum <= 0) return 0;
    return (recorded / maximum).clamp(0.0, 1.0).toDouble();
  }
}
