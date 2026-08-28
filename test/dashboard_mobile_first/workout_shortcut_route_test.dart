import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phone workout shortcut opens the verified routines library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: PremiumDashboardBenchmark(
                arabic: false,
                actionTitle: 'Log water',
                actionReason: 'Hydration is the best next action.',
                actionEvidence: 'Water log is incomplete.',
                confidence: 'Useful',
                onAction: () {},
                dailyIntelligence: const SizedBox(height: 120),
                progressSection: const SizedBox(height: 120),
                personalHealthAi: const SizedBox(height: 120),
                bodyTwinSummary: 'Current body model summary',
                bodyTwinEvidence: 'Local evidence',
                nutritionSummary: 'Protein evidence is available.',
                nutritionEvidence: 'Three meals logged.',
                trendSummary: 'Weight trend is decreasing.',
                trendEvidence: 'Seven comparable weigh-ins.',
                loggingItems: const [
                  DashboardLoggingItem(label: 'Weight', recorded: true),
                  DashboardLoggingItem(label: 'Meals', recorded: true),
                  DashboardLoggingItem(label: 'Water', recorded: false),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/wellness/workouts/routines',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('verified-workout-routines')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workout Videos'), findsOneWidget);
    expect(find.text('302 approved workout guides'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('dashboard-mobile-workout-library-card')),
    );
    await tester.pumpAndSettle();

    expect(find.text('verified-workout-routines'), findsOneWidget);
  });
}
