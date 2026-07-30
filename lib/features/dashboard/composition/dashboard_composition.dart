import 'dashboard_layout_model.dart';
import 'dashboard_section.dart';

/// Pure presentation policy for the dashboard.
///
/// Every runtime layout decision extracted from `dashboard_grid.dart` is owned
/// here. The context-specific entry points intentionally preserve the exact
/// pre-extraction expressions instead of normalising unlike layout contexts
/// through one generic calculation.
class DashboardComposition {
  const DashboardComposition._();

  static const double phoneBreakpoint = 600;
  static const double desktopBreakpoint = 900;
  static const double analyticsHorizontalBreakpoint = 1180;
  static const double bodyProfileCompactBreakpoint = 760;
  static const double bodyProfileThreeColumnBreakpoint = 1040;

  static const List<DashboardSection> sectionOrder = [
    DashboardSection.dailyCommand,
    DashboardSection.progress,
    DashboardSection.analyticsCenter,
    DashboardSection.bodyIdentity,
  ];

  /// Backward-compatible aggregate resolver retained as part of the approved
  /// Package 002 API. Runtime widgets use the context-specific entry points.
  static DashboardLayoutModel resolve({
    required double viewportWidth,
    required double contentWidth,
    required int metricCount,
  }) => _model(
    viewportWidth: viewportWidth,
    contentWidth: contentWidth,
    analyticsHorizontal: contentWidth >= analyticsHorizontalBreakpoint,
    metricColumns:
        viewportWidth >= desktopBreakpoint &&
            contentWidth >= bodyProfileCompactBreakpoint
        ? metricCount
        : 2,
    metricChildAspectRatio: viewportWidth >= desktopBreakpoint
        ? ((viewportWidth >= desktopBreakpoint &&
                          contentWidth >= bodyProfileCompactBreakpoint
                      ? metricCount
                      : 2) ==
                  metricCount
              ? 1.28
              : 1.55)
        : (contentWidth < 420 ? 1.08 : 1.42),
    pagedSectionBaseHeight: viewportWidth >= desktopBreakpoint
        ? 172
        : contentWidth >= 560
        ? 300
        : 390,
    bodyProfileCompact: contentWidth < bodyProfileCompactBreakpoint,
    bodyProfileColumns: contentWidth >= bodyProfileThreeColumnBreakpoint
        ? 3
        : 2,
    compactMetricTiles: viewportWidth >= analyticsHorizontalBreakpoint,
  );

  /// Exact extraction of the Analytics Center branching logic.
  static DashboardLayoutModel analytics({
    required double viewportWidth,
    required double contentWidth,
  }) => _model(
    viewportWidth: viewportWidth,
    contentWidth: contentWidth,
    analyticsHorizontal: contentWidth >= analyticsHorizontalBreakpoint,
  );

  /// Exact extraction of `_DashboardPagedSection` responsive decisions.
  static DashboardLayoutModel pagedSection({
    required double viewportWidth,
    required double contentWidth,
  }) => _model(
    viewportWidth: viewportWidth,
    contentWidth: contentWidth,
    pagedSectionBaseHeight: viewportWidth >= desktopBreakpoint
        ? 172
        : contentWidth >= 560
        ? 300
        : 390,
  );

  /// Exact extraction of `_MetricGridPage` column and ratio decisions.
  static DashboardLayoutModel metricGrid({
    required double viewportWidth,
    required double contentWidth,
    required int metricCount,
  }) {
    final wideScreen = viewportWidth >= desktopBreakpoint;
    final columns = wideScreen && contentWidth >= bodyProfileCompactBreakpoint
        ? metricCount
        : 2;
    return _model(
      viewportWidth: viewportWidth,
      contentWidth: contentWidth,
      metricColumns: columns,
      metricChildAspectRatio: wideScreen
          ? (columns == metricCount ? 1.28 : 1.55)
          : (contentWidth < 420 ? 1.08 : 1.42),
    );
  }

  /// Exact extraction of `_BodyProfileSnapshot` responsive decisions.
  static DashboardLayoutModel bodyProfile({required double contentWidth}) =>
      _model(
        viewportWidth: contentWidth,
        contentWidth: contentWidth,
        bodyProfileCompact: contentWidth < bodyProfileCompactBreakpoint,
        bodyProfileColumns: contentWidth >= bodyProfileThreeColumnBreakpoint
            ? 3
            : 2,
      );

  /// Exact extraction of `_CompactMetricTile` viewport decisions.
  static DashboardLayoutModel metricTile({required double viewportWidth}) =>
      _model(
        viewportWidth: viewportWidth,
        contentWidth: viewportWidth,
        compactMetricTiles: viewportWidth >= analyticsHorizontalBreakpoint,
      );

  static DashboardLayoutModel _model({
    required double viewportWidth,
    required double contentWidth,
    bool? analyticsHorizontal,
    int metricColumns = 2,
    double metricChildAspectRatio = 1.42,
    double pagedSectionBaseHeight = 390,
    bool? bodyProfileCompact,
    int bodyProfileColumns = 2,
    bool? compactMetricTiles,
  }) => DashboardLayoutModel(
    viewportWidth: viewportWidth,
    contentWidth: contentWidth,
    isPhone: viewportWidth < phoneBreakpoint,
    isDesktop: viewportWidth >= desktopBreakpoint,
    isUltraWide: contentWidth >= analyticsHorizontalBreakpoint,
    analyticsHorizontal:
        analyticsHorizontal ?? contentWidth >= analyticsHorizontalBreakpoint,
    metricColumns: metricColumns,
    metricChildAspectRatio: metricChildAspectRatio,
    pagedSectionBaseHeight: pagedSectionBaseHeight,
    bodyProfileCompact:
        bodyProfileCompact ?? contentWidth < bodyProfileCompactBreakpoint,
    bodyProfileColumns: bodyProfileColumns,
    compactMetricTiles:
        compactMetricTiles ?? viewportWidth >= analyticsHorizontalBreakpoint,
  );
}
