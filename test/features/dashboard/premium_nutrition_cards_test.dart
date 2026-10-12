import 'package:body_intelligence_log/features/commerce/presentation/premium_label_badge.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_value_mask.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required bool premiumUnlocked,
    double width = 390,
    double textScale = 1,
    bool arabic = false,
    bool dark = false,
    bool checking = false,
    bool unavailable = false,
    bool highContrast = true,
    VoidCallback? onRetry,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => RepaintBoundary(
            key: const Key('home-paid-region-capture'),
            child: Scaffold(
              body: PremiumDashboardBenchmark(
                arabic: arabic,
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
                potassiumEvidenceValue: 1200,
                potassiumGoal: 3500,
                nutrientDashboardPreset: 'Heart healthy',
                visibleSections: const {
                  DashboardSectionIds.calories,
                  DashboardSectionIds.macros,
                },
                premiumUnlocked: premiumUnlocked,
                premiumAccessResolved: !checking && !unavailable,
                premiumAccessChecking: checking,
                onPremiumRetry: unavailable ? onRetry : null,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/plans',
          builder: (_, _) => const Scaffold(body: Text('plans-destination')),
        ),
        GoRoute(
          path: '/settings/nutrition-goals',
          builder: (_, _) => const Scaffold(body: Text('goals-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          locale: Locale(arabic ? 'ar' : 'en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(
            dark
                ? BilFlagshipTheme.dark(isArabic: arabic)
                : BilFlagshipTheme.light(isArabic: arabic),
            fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
              highContrast: highContrast,
              accessibleNavigation: highContrast,
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (checking) {
      await tester.pump(const Duration(milliseconds: 250));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> revealHeartHealthy(WidgetTester tester) async {
    // A saved dietary preset must not displace Calories from the first page.
    expect(
      find.byKey(const Key('dashboard-reference-calories-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('dashboard-heart-circle-card')), findsNothing);
    expect(tester.takeException(), isNull);
    for (var page = 0; page < 2; page++) {
      await tester.drag(
        find.byKey(const Key('dashboard-calories-macros-horizontal')),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  }

  testWidgets('heart health reuses the three macro ring colors', (
    tester,
  ) async {
    await pumpDashboard(tester, premiumUnlocked: true);
    await revealHeartHealthy(tester);

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
    expect(find.text('Potassium'), findsOneWidget);
    expect(find.text('Sodium'), findsOneWidget);
    expect(find.text('Fiber'), findsOneWidget);
    expect(find.descendant(of: heart, matching: find.text('—')), findsNothing);
    expect(
      find.descendant(of: heart, matching: find.text('800')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: heart, matching: find.text('2300')),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const Key('dashboard-calories-macros-horizontal')),
      const Offset(320, 0),
    );
    await tester.pumpAndSettle();
    final macros = find.byKey(const Key('dashboard-reference-macros-card'));
    expect(
      find.descendant(
        of: macros,
        matching: find.text('40 g', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: macros,
        matching: find.textContaining('/ 100', findRichText: true),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('dashboard-premium-lock')), findsNothing);
  });

  testWidgets(
    'free users see Premium labels on macros and heart health locks',
    (tester) async {
      await pumpDashboard(tester, premiumUnlocked: false);
      await revealHeartHealthy(tester);

      final heartLock = find.descendant(
        of: find.byKey(const Key('dashboard-heart-premium-lock')),
        matching: find.byKey(const Key('dashboard-premium-lock')),
      );
      expect(heartLock, findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(const Key('dashboard-heart-public-title')))
            .overlaps(
              tester.getRect(
                find.byKey(const Key('dashboard-heart-paid-values')),
              ),
            ),
        isFalse,
      );
      expect(find.text('800'), findsNothing);
      expect(find.text('1200'), findsNothing);
      expect(find.text('Potassium · mg'), findsOneWidget);
      expect(find.text('Sodium · mg'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard-heart-premium-lock')),
          matching: find.byType(PremiumLabelBadge),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard-heart-premium-lock')),
          matching: find.byType(PremiumValueMask),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dashboard-premium-page-label')),
        findsNothing,
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
        tester
            .getRect(find.byKey(const Key('dashboard-macros-public-title')))
            .overlaps(
              tester.getRect(
                find.byKey(const Key('dashboard-macros-paid-values')),
              ),
            ),
        isFalse,
      );
      expect(find.text('40 g', findRichText: true), findsNothing);
      expect(find.text('Protein · g'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('dashboard-macros-premium-lock')),
          matching: find.byType(PremiumValueMask),
        ),
        findsOneWidget,
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
      expect(macroBadge, findsOneWidget);
      expect(
        find.descendant(of: macrosLock, matching: find.byType(Text)),
        findsOneWidget,
      );

      await tester.tap(macrosLock);
      await tester.pumpAndSettle();
      expect(find.text('plans-destination'), findsOneWidget);
    },
  );

  for (final arabic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Home public headings stay outside paid values 320 2x ${arabic ? 'ar' : 'en'} ${dark ? 'dark' : 'light'}',
        (tester) async {
          await pumpDashboard(
            tester,
            premiumUnlocked: false,
            width: 320,
            textScale: 2,
            arabic: arabic,
            dark: dark,
          );
          await tester.drag(
            find.byKey(const Key('dashboard-calories-macros-horizontal')),
            Offset(arabic ? 260 : -260, 0),
          );
          await tester.pumpAndSettle();
          final title = find.byKey(const Key('dashboard-macros-public-title'));
          final mask = find.byKey(const Key('dashboard-macros-paid-values'));
          expect(title, findsOneWidget);
          expect(tester.getRect(title).overlaps(tester.getRect(mask)), isFalse);
          final semantics = tester.ensureSemantics();
          expect(find.bySemanticsLabel(RegExp('40 g|80 g|30 g')), findsNothing);
          expect(
            find.text(arabic ? 'المغذيات الكبرى' : 'Macros'),
            findsOneWidget,
          );
          await captureClosureSurface(
            tester,
            find.byKey(const Key('home-paid-region-capture')),
            'home-paid-region-${arabic ? 'ar' : 'en'}-${dark ? 'dark' : 'light'}-320-2x',
          );
          semantics.dispose();
          await tester.tap(
            find.byKey(const Key('dashboard-reference-macros-edit')),
          );
          await tester.pumpAndSettle();
          expect(find.text('goals-destination'), findsOneWidget);
          expect(find.text('plans-destination'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Home normal glass public heading ar ${dark ? 'dark' : 'light'}',
      (tester) async {
        await pumpDashboard(
          tester,
          premiumUnlocked: false,
          arabic: true,
          dark: dark,
          highContrast: false,
        );
        await tester.drag(
          find.byKey(const Key('dashboard-calories-macros-horizontal')),
          const Offset(260, 0),
        );
        await tester.pumpAndSettle();
        final title = find.byKey(const Key('dashboard-macros-public-title'));
        final mask = find.byKey(const Key('dashboard-macros-paid-values'));
        expect(tester.getRect(title).overlaps(tester.getRect(mask)), isFalse);
        await captureClosureSurface(
          tester,
          find.byKey(const Key('home-paid-region-capture')),
          'home-normal-glass-ar-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Home access error retries without Premium or Plans', (
    tester,
  ) async {
    var retries = 0;
    await pumpDashboard(
      tester,
      premiumUnlocked: false,
      unavailable: true,
      onRetry: () => retries++,
    );
    await tester.drag(
      find.byKey(const Key('dashboard-calories-macros-horizontal')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('dashboard-macros-public-title')),
      findsOneWidget,
    );
    expect(find.byType(PremiumLabelBadge), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-macros-paid-values')),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    expect(retries, 1);
    expect(find.text('plans-destination'), findsNothing);
  });
}
