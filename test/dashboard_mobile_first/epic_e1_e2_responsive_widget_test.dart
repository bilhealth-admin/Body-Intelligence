import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget subject({Set<String>? visibleSections}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PremiumDashboardBenchmark(
              arabic: false,
              actionTitle: 'Log water',
              actionReason: 'Hydration is the best next action.',
              actionEvidence: 'Water log is incomplete.',
              confidence: 'Useful',
              onAction: () {},
              dailyIntelligence: const SizedBox(height: 120),
              hero: const SizedBox(height: 160),
              progressSection: const SizedBox(height: 120),
              personalHealthAi: const ColoredBox(
                color: Colors.transparent,
                child: Center(child: Text('Personal Health AI test panel')),
              ),
              connectedHealth: const SizedBox(
                key: Key('connected-health-test-card'),
                height: 100,
              ),
              bodyTwinSummary:
                  'Current weight 93.4 kg · BMI 28.5 · Body fat 24.0%',
              bodyTwinEvidence: 'Cautious range 0.4 to 0.8 kg/week',
              nutritionSummary: 'Protein evidence is available.',
              nutritionEvidence: 'Three meals logged.',
              trendSummary: 'Weight trend is decreasing.',
              trendEvidence: 'Seven comparable weigh-ins.',
              loggingItems: const [
                DashboardLoggingItem(label: 'Weight', recorded: true),
                DashboardLoggingItem(label: 'Meals', recorded: true),
                DashboardLoggingItem(label: 'Water', recorded: false),
              ],
              visibleSections:
                  visibleSections ?? DashboardSectionIds.all.toSet(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> setViewport(
    WidgetTester tester, {
    required double width,
    required double height,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('phone exposes Body Twin without duplicating workout entry', (
    tester,
  ) async {
    await setViewport(tester, width: 390, height: 2200);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-mobile-summary-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-workout-library-card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsOneWidget,
    );
    final coachTop = tester.getTopLeft(
      find.byKey(const Key('dashboard-mobile-ai-coach-entry')),
    );
    final healthTop = tester.getTopLeft(
      find.byKey(const Key('connected-health-test-card')),
    );
    expect(find.byKey(const Key('connected-health-test-card')), findsOneWidget);
    expect(healthTop.dy, greaterThan(coachTop.dy));
    expect(find.textContaining('Current weight 93.4 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet uses its dedicated intelligence slot', (tester) async {
    await setViewport(tester, width: 800, height: 1600);
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    final ai = find.byKey(const Key('dashboard-tablet-personal-ai-slot'));
    expect(ai, findsOneWidget);
    expect(find.text('Personal Health AI test panel'), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard-mobile-workout-library-card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('dashboard-mobile-body-twin-snapshot')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone Health Hub follows the Edit visibility setting', (
    tester,
  ) async {
    await setViewport(tester, width: 390, height: 1200);
    await tester.pumpWidget(
      subject(visibleSections: const {DashboardSectionIds.aiCoach}),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-mobile-ai-coach-entry')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('connected-health-test-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
