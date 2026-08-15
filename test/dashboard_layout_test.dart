import 'package:body_intelligence_log/features/dashboard/composition/dashboard_composition.dart';
import 'package:body_intelligence_log/features/dashboard/composition/dashboard_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardComposition runtime characterization', () {
    test('section order remains stable and semantic', () {
      expect(DashboardComposition.sectionOrder, const [
        DashboardSection.dailyCommand,
        DashboardSection.progress,
        DashboardSection.analyticsCenter,
        DashboardSection.bodyIdentity,
      ]);
    });

    test('analytics reproduces the pre-extraction breakpoints', () {
      expect(
        DashboardComposition.analytics(
          viewportWidth: 390,
          contentWidth: 1179.99,
        ).analyticsHorizontal,
        isFalse,
      );
      expect(
        DashboardComposition.analytics(
          viewportWidth: 1024,
          contentWidth: 1180,
        ).analyticsHorizontal,
        isTrue,
      );
      expect(
        DashboardComposition.analytics(
          viewportWidth: 599.99,
          contentWidth: 800,
        ).isPhone,
        isTrue,
      );
      expect(
        DashboardComposition.analytics(
          viewportWidth: 600,
          contentWidth: 800,
        ).isPhone,
        isFalse,
      );
    });

    test('paged section reproduces desktop and content-width heights', () {
      expect(
        DashboardComposition.pagedSection(
          viewportWidth: 900,
          contentWidth: 400,
        ).pagedSectionBaseHeight,
        172,
      );
      expect(
        DashboardComposition.pagedSection(
          viewportWidth: 899.99,
          contentWidth: 560,
        ).pagedSectionBaseHeight,
        340,
      );
      expect(
        DashboardComposition.pagedSection(
          viewportWidth: 899.99,
          contentWidth: 559.99,
        ).pagedSectionBaseHeight,
        470,
      );
    });

    test('metric grid reproduces every original branch', () {
      final phoneNarrow = DashboardComposition.metricGrid(
        viewportWidth: 390,
        contentWidth: 419.99,
        metricCount: 4,
      );
      expect(phoneNarrow.metricColumns, 2);
      expect(phoneNarrow.metricChildAspectRatio, 0.82);

      final tablet = DashboardComposition.metricGrid(
        viewportWidth: 800,
        contentWidth: 800,
        metricCount: 4,
      );
      expect(tablet.metricColumns, 2);
      expect(tablet.metricChildAspectRatio, 1.08);

      final desktopConstrained = DashboardComposition.metricGrid(
        viewportWidth: 1024,
        contentWidth: 759.99,
        metricCount: 4,
      );
      expect(desktopConstrained.metricColumns, 2);
      expect(desktopConstrained.metricChildAspectRatio, 1.55);

      final desktopExpanded = DashboardComposition.metricGrid(
        viewportWidth: 1024,
        contentWidth: 760,
        metricCount: 4,
      );
      expect(desktopExpanded.metricColumns, 4);
      expect(desktopExpanded.metricChildAspectRatio, 1.28);
    });

    test('body profile reproduces compact and column decisions', () {
      expect(
        DashboardComposition.bodyProfile(
          contentWidth: 759.99,
        ).bodyProfileCompact,
        isTrue,
      );
      final twoColumns = DashboardComposition.bodyProfile(contentWidth: 760);
      expect(twoColumns.bodyProfileCompact, isFalse);
      expect(twoColumns.bodyProfileColumns, 2);
      expect(
        DashboardComposition.bodyProfile(contentWidth: 1040).bodyProfileColumns,
        3,
      );
    });

    test('metric tile reproduces phone and compact viewport decisions', () {
      expect(
        DashboardComposition.metricTile(viewportWidth: 599.99).isPhone,
        isTrue,
      );
      expect(
        DashboardComposition.metricTile(viewportWidth: 600).isPhone,
        isFalse,
      );
      expect(
        DashboardComposition.metricTile(
          viewportWidth: 1179.99,
        ).compactMetricTiles,
        isFalse,
      );
      expect(
        DashboardComposition.metricTile(viewportWidth: 1180).compactMetricTiles,
        isTrue,
      );
    });

    test('approved aggregate resolver remains backward compatible', () {
      final layout = DashboardComposition.resolve(
        viewportWidth: 1024,
        contentWidth: 1024,
        metricCount: 4,
      );
      expect(layout.isDesktop, isTrue);
      expect(layout.metricColumns, 4);
      expect(layout.metricChildAspectRatio, 1.28);
      expect(layout.pagedSectionBaseHeight, 172);
      expect(layout.bodyProfileColumns, 2);
    });
  });
}
