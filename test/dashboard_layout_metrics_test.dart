import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_layout_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <(double, DashboardViewportClass)>[
    (320, DashboardViewportClass.compact),
    (390, DashboardViewportClass.compact),
    (600, DashboardViewportClass.medium),
    (768, DashboardViewportClass.medium),
    (1024, DashboardViewportClass.expanded),
    (1280, DashboardViewportClass.wide),
    (1600, DashboardViewportClass.wide),
    (1920, DashboardViewportClass.ultraWide),
  ];

  for (final entry in cases) {
    test('resolves ${entry.$1}px as ${entry.$2.name}', () {
      final metrics = DashboardLayoutMetrics.resolve(entry.$1);
      expect(metrics.viewportClass, entry.$2);
      expect(metrics.horizontalPadding, greaterThanOrEqualTo(16));
      expect(metrics.maxContentWidth, greaterThan(0));
      expect(metrics.regionGap, greaterThan(0));
    });
  }

  test('does not create two columns prematurely at common desktop width', () {
    expect(DashboardLayoutMetrics.resolve(1280).useTwoRegions, isFalse);
  });

  test('keeps the flagship hero full width on genuinely wide viewports', () {
    final metrics = DashboardLayoutMetrics.resolve(1600);
    expect(metrics.useTwoRegions, isFalse);
    expect(metrics.contentFlex, greaterThan(metrics.heroFlex));
  });
}
