import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_insights_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in <double>[320, 390, 900, 1280]) {
    testWidgets('collapsed insights exclude deep content at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardInsightsSurface(
              title: Text('Insights'),
              subtitle: Text('Open for details'),
              children: [
                Text(
                  'Why this action appears — evidence and confidence details',
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('Why this action appears — evidence and confidence details'),
        findsNothing,
      );
      expect(find.byKey(const Key('dashboard-insights-content')), findsNothing);

      await tester.tap(find.byKey(const Key('dashboard-insights-toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Why this action appears — evidence and confidence details'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dashboard-insights-content')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('dashboard-insights-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.text('Why this action appears — evidence and confidence details'),
        findsNothing,
      );
    });
  }

  testWidgets('insights disclosure exposes button and expanded semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardInsightsSurface(
            title: Text('Insights'),
            subtitle: Text('Open for details'),
            children: [Text('Evidence')],
          ),
        ),
      ),
    );

    Semantics semanticsWidget() => tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const Key('dashboard-insights-toggle')),
            matching: find.byType(Semantics),
          )
          .first,
    );

    expect(semanticsWidget().properties.button, isTrue);
    expect(semanticsWidget().properties.expanded, isFalse);

    await tester.tap(find.byKey(const Key('dashboard-insights-toggle')));
    await tester.pumpAndSettle();

    expect(semanticsWidget().properties.button, isTrue);
    expect(semanticsWidget().properties.expanded, isTrue);
  });
}
