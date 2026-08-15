import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('NotoNaskhArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    await font.load();
  });

  testWidgets('legacy insight deck is removed from the unified dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-one-best-action')), findsNothing);
    expect(find.byKey(const Key('dashboard-key-insights-deck')), findsNothing);
    expect(find.byKey(const Key('dashboard-nutrition-context')), findsNothing);
    expect(find.text('Daily Intelligence'), findsOneWidget);
  });

  testWidgets('unsupported recommendation keeps daily facts visible', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(showRecommendation: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-one-best-action')), findsNothing);
    expect(find.text('Daily Intelligence'), findsOneWidget);
  });

  testWidgets('light unified dashboard retains readable theme contrast', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(light: true));
    await tester.pumpAndSettle();
    expect(find.byType(_DailyNarrative), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports RTL large text high contrast and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Harness(
        arabic: true,
        highContrast: true,
        reducedMotion: true,
        textScaler: TextScaler.linear(1.8),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-compact-one-best-action')),
      findsOneWidget,
    );
    expect(find.text('اكتمال التسجيل'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final configuration in <(String, Size)>[
    ('phone', Size(390, 844)),
    ('tablet', Size(1024, 1366)),
    ('desktop', Size(1440, 1000)),
  ]) {
    testWidgets('${configuration.$1} premium dashboard golden', (tester) async {
      tester.view.physicalSize = configuration.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      await settleVisualAssetImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/premium_dashboard_${configuration.$1}_after.png',
        ),
      );
    });
  }

  testWidgets('corrected light morning premium dashboard golden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _Harness(light: true));
    await tester.pumpAndSettle();
    await settleVisualAssetImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/premium_dashboard_light_corrected.png'),
    );
  });

  testWidgets(
    'corrected light dashboard supports Arabic large text semantics',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const _Harness(
          light: true,
          arabic: true,
          textScaler: TextScaler.linear(1.8),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dashboard-body-twin-preview')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('dashboard-nutrition-context')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('dashboard-trend-explanation')),
        findsNothing,
      );
      expect(find.byType(_DailyNarrative), findsOneWidget);
      expect(find.byKey(const Key('dashboard-action-insight')), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

class _Harness extends StatelessWidget {
  const _Harness({
    this.arabic = false,
    this.highContrast = false,
    this.reducedMotion = false,
    this.textScaler = TextScaler.noScaling,
    this.light = false,
    this.showRecommendation = true,
  });

  final bool arabic;
  final bool highContrast;
  final bool reducedMotion;
  final TextScaler textScaler;
  final bool light;
  final bool showRecommendation;

  @override
  Widget build(BuildContext context) {
    final locale = Locale(arabic ? 'ar' : 'en');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      themeMode: light ? ThemeMode.light : ThemeMode.dark,
      theme:
          BilFlagshipTheme.light(
            highContrast: highContrast,
            isArabic: arabic,
          ).copyWith(
            textTheme: BilFlagshipTheme.light(
              highContrast: highContrast,
              isArabic: arabic,
            ).textTheme.apply(fontFamily: 'NotoNaskhArabic'),
          ),
      darkTheme:
          BilFlagshipTheme.dark(
            highContrast: highContrast,
            isArabic: arabic,
          ).copyWith(
            textTheme: BilFlagshipTheme.dark(
              highContrast: highContrast,
              isArabic: arabic,
            ).textTheme.apply(fontFamily: 'NotoNaskhArabic'),
          ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            highContrast: highContrast,
            disableAnimations: reducedMotion,
            textScaler: textScaler,
          ),
          child: Scaffold(
            backgroundColor: light
                ? const Color(0xFFEAF2F4)
                : const Color(0xFF01050D),
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(.1, -.3),
                  radius: 1.1,
                  colors: light
                      ? const [
                          Color(0xFFE1F2F3),
                          Color(0xFFF1F4EA),
                          Color(0xFFE7EFF1),
                        ]
                      : const [
                          Color(0x402071A5),
                          Color(0xFF071120),
                          Color(0xFF01050D),
                        ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: PremiumDashboardBenchmark(
                    arabic: arabic,
                    showRecommendation: showRecommendation,
                    actionTitle: arabic
                        ? 'سجّل وزن اليوم'
                        : 'Log today’s weight',
                    actionReason: arabic
                        ? 'القياس اليومي المتقارب يحسّن ثقة الاتجاه.'
                        : 'A comparable daily check-in improves trend confidence.',
                    actionEvidence: arabic
                        ? 'لم يُسجّل وزن اليوم'
                        : 'No weight check-in recorded today',
                    confidence: arabic ? 'قيد التكوين' : 'Emerging',
                    onAction: () {},
                    dailyIntelligence: _DailyNarrative(arabic: arabic),
                    bodyTwinSummary: arabic
                        ? 'لا يزال BIL يبني سيناريو شخصيًا آمنًا.'
                        : 'BIL is still building a safe personal scenario.',
                    bodyTwinEvidence: arabic
                        ? 'نحتاج 4 أيام وزن و6 أيام تغذية إضافية.'
                        : '4 more weight days · 6 more nutrition days',
                    nutritionSummary: arabic
                        ? 'البروتين هو أوضح فجوة تغذية قابلة للتنفيذ اليوم.'
                        : 'Protein is the clearest actionable nutrition gap today.',
                    nutritionEvidence: arabic
                        ? 'وجبتان · 62 جم بروتين مسجل'
                        : '2 meal records · 62 g protein recorded',
                    trendSummary: arabic
                        ? 'القراءة الأخيرة لا تكفي لتغيير الخطة.'
                        : 'The latest reading is not enough to change the plan.',
                    trendEvidence: arabic
                        ? 'ظروف القياس مختلفة'
                        : 'Measurement conditions differed',
                    loggingItems: [
                      DashboardLoggingItem(
                        label: arabic ? 'الوزن' : 'Weight',
                        recorded: false,
                      ),
                      DashboardLoggingItem(
                        label: arabic ? 'الوجبات' : 'Meals',
                        recorded: true,
                      ),
                      DashboardLoggingItem(
                        label: arabic ? 'الماء' : 'Water',
                        recorded: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyNarrative extends StatelessWidget {
  const _DailyNarrative({required this.arabic});

  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0D1B33)
          : const Color(0xFFE9F2F2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              arabic ? 'الذكاء اليومي' : 'Daily Intelligence',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              arabic
                  ? 'اليوم مفهوم جزئيًا. أكمل الملاحظة الأعلى قيمة فقط.'
                  : 'Today is partially understood. Complete only the highest-value observation.',
            ),
          ],
        ),
      ),
    );
  }
}
