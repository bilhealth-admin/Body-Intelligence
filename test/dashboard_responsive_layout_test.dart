import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_composition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[320, 390, 600, 768, 1024, 1280]) {
    testWidgets('dashboard remains stacked at $width px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardComposition(
              hero: SizedBox(key: Key('hero-region'), height: 220),
              content: SizedBox(key: Key('content-region'), height: 500),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('dashboard-composition-stacked')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard-composition-wide')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in <double>[1600, 1920]) {
    testWidgets('dashboard preserves full-width hero at $width px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardComposition(
              hero: SizedBox(key: Key('hero-region'), height: 220),
              content: SizedBox(key: Key('content-region'), height: 500),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('dashboard-composition-stacked')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard-composition-wide')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
