/// Reference maxima used to color the heart-health nutrient meters.
///
/// These are display/reference caps, not medical advice or personal
/// prescriptions. A saved user target takes precedence in the dashboard.
final class DashboardHeartHealthPolicy {
  const DashboardHeartHealthPolicy._();

  static const int potassiumMaximumMg = 4700;
  static const int sodiumMaximumMg = 2300;
  static const int fiberMaximumG = 35;

  /// Returns the visible fraction for a meter, capped at 100%.
  static double coverage({required num? recorded, required num maximum}) {
    if (recorded == null || !recorded.isFinite || maximum <= 0) return 0;
    return (recorded / maximum).clamp(0.0, 1.0).toDouble();
  }
}
