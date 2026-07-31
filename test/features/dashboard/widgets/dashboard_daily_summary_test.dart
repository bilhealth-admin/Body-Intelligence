import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_daily_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves heading, streak badge, and manual carousel order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardDailySummarySection(
            title: 'Daily Summary',
            subtitle: 'Recorded references.',
            badge: DashboardStreakBadge(days: 4, arabic: false),
            pages: [
              Center(child: Text('First metrics page')),
              Center(child: Text('Second metrics page')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Daily Summary'), findsOneWidget);
    expect(find.text('Recorded references.'), findsOneWidget);
    expect(find.text('4 day streak'), findsOneWidget);
    expect(find.text('First metrics page'), findsOneWidget);
    expect(find.text('Second metrics page'), findsNothing);

    await tester.tap(find.byKey(const Key('dashboard-carousel-next')));
    await tester.pumpAndSettle();

    expect(find.text('First metrics page'), findsNothing);
    expect(find.text('Second metrics page'), findsOneWidget);
  });

  testWidgets(
    'preserves metric values, units, accents, and numeric direction',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 300,
              child: DashboardMetricGridPage(
                metrics: const [
                  DashboardMetricData(
                    Icons.local_fire_department_outlined,
                    'Calories',
                    '1840',
                    'kcal',
                    Colors.orange,
                  ),
                  DashboardMetricData(
                    Icons.fitness_center_outlined,
                    'Protein',
                    '132',
                    'g',
                    Colors.green,
                  ),
                  DashboardMetricData(
                    Icons.opacity_outlined,
                    'Fat',
                    '58',
                    'g',
                    Colors.purple,
                  ),
                  DashboardMetricData(
                    Icons.grass_outlined,
                    'Fiber',
                    '27',
                    'g',
                    Colors.lightGreen,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      for (final label in ['Calories', 'Protein', 'Fat', 'Fiber']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('1840'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);

      final numericDirection = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('1840'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(numericDirection.textDirection, TextDirection.ltr);
    },
  );

  testWidgets('preserves Arabic streak copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DashboardStreakBadge(days: 3, arabic: true)),
      ),
    );

    expect(find.text('3 أيام متتالية'), findsOneWidget);
  });
}
