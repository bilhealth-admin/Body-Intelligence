import 'package:body_intelligence_log/features/commerce/presentation/premium_label_badge.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool premiumUnlocked,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PremiumDashboardBenchmark(
              arabic: false,
              actionTitle: '',
              actionReason: '',
              actionEvidence: '',
              confidence: '',
              onAction: null,
              dailyIntelligence: const SizedBox.shrink(),
              bodyTwinSummary: '',
              bodyTwinEvidence: '',
              nutritionSummary: '',
              nutritionEvidence: '',
              trendSummary: '',
              trendEvidence: '',
              loggingItems: const [],
              caloriesGoal: 2000,
              proteinConsumed: 40,
              proteinGoal: 100,
              carbohydratesConsumed: 80,
              carbohydratesGoal: 200,
              fatConsumed: 30,
              fatGoal: 60,
              fiberEvidenceValue: 12,
              fiberGoal: 30,
              sodiumEvidenceValue: 800,
              sodiumGoal: 2300,
              nutrientDashboardPreset: 'Heart healthy',
              visibleSections: const {
                DashboardSectionIds.calories,
                DashboardSectionIds.macros,
              },
              premiumUnlocked: premiumUnlocked,
            ),
          ),
        ),
        GoRoute(
          path: '/plans',
          builder: (_, _) => const Scaffold(body: Text('plans-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('heart health reuses the three macro ring colors', (
    tester,
  ) async {
    await pumpDashboard(tester, premiumUnlocked: true);

    final heart = find.byKey(const Key('dashboard-heart-circle-card'));
    expect(heart, findsOneWidget);
    final rings = tester
        .widgetList<CircularProgressIndicator>(
          find.descendant(
            of: heart,
            matching: find.byType(CircularProgressIndicator),
          ),
        )
        .toList();
    expect(rings, hasLength(3));
    expect(rings.map((ring) => ring.color), const [
      Color(0xFFF2B632),
      Color(0xFF7656C9),
      Color(0xFF38A66B),
    ]);
    expect(find.text('Saturated fat'), findsOneWidget);
    expect(find.text('Sodium'), findsOneWidget);
    expect(find.text('Fiber'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-premium-lock')), findsNothing);
  });

  testWidgets(
    'free users see minimal Premium locks on macros and heart health',
    (tester) async {
      await pumpDashboard(tester, premiumUnlocked: false);

      final heartLock = find.descendant(
        of: find.byKey(const Key('dashboard-heart-premium-lock')),
        matching: find.byKey(const Key('dashboard-premium-lock')),
      );
      expect(heartLock, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard-heart-premium-lock')),
          matching: find.byType(PremiumLabelBadge),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('dashboard-premium-page-label')),
        findsOneWidget,
      );
      expect(find.byType(PremiumLabelBadge), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('dashboard-calories-macros-horizontal')),
        const Offset(320, 0),
      );
      await tester.pumpAndSettle();
      final macrosLock = find.descendant(
        of: find.byKey(const Key('dashboard-macros-premium-lock')),
        matching: find.byKey(const Key('dashboard-premium-lock')),
      );
      expect(macrosLock, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard-macros-premium-lock')),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard-macros-premium-lock')),
          matching: find.byIcon(Icons.workspace_premium_rounded),
        ),
        findsNothing,
      );
      final macroBadge = find.descendant(
        of: find.byKey(const Key('dashboard-macros-premium-lock')),
        matching: find.byType(PremiumLabelBadge),
      );
      expect(macroBadge, findsNothing);
      expect(
        find.descendant(of: macrosLock, matching: find.byType(Text)),
        findsNothing,
      );

      await tester.tap(macrosLock);
      await tester.pumpAndSettle();
      expect(find.text('plans-destination'), findsOneWidget);
    },
  );
}
