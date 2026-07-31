/// Immutable presentation decisions produced by [DashboardComposition].
class DashboardLayoutModel {
  const DashboardLayoutModel({
    required this.viewportWidth,
    required this.contentWidth,
    required this.isPhone,
    required this.isDesktop,
    required this.isUltraWide,
    required this.analyticsHorizontal,
    required this.metricColumns,
    required this.metricChildAspectRatio,
    required this.pagedSectionBaseHeight,
    required this.bodyProfileCompact,
    required this.bodyProfileColumns,
    required this.compactMetricTiles,
  });

  final double viewportWidth;
  final double contentWidth;
  final bool isPhone;
  final bool isDesktop;
  final bool isUltraWide;
  final bool analyticsHorizontal;
  final int metricColumns;
  final double metricChildAspectRatio;
  final double pagedSectionBaseHeight;
  final bool bodyProfileCompact;
  final int bodyProfileColumns;
  final bool compactMetricTiles;
}
