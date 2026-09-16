import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/engine/daily_return_engine.dart';
import 'package:body_intelligence_log/engine/data_honesty_engine.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/engine/what_changed_engine.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/connected_health_card.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/daily_return_card.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_header.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_shell.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:body_intelligence_log/features/dashboard/widgets/premium_dashboard_benchmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual_closure/visual_evidence_font.dart';

final _now = DateTime(2026, 9, 16, 16, 31);

final class _HealthFixture implements ConnectedHealthGateway {
  static final snapshot = ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.synchronized,
    platformSource: 'Apple Health',
    availableSources: const ['Apple Health'],
    signals: [
      for (final metric in const [
        ('steps', 4321.0, 'steps'),
        ('heartRate', 75.0, 'bpm'),
        ('activeEnergy', 321.0, 'kcal'),
      ])
        ConnectedHealthSignalView(
          key: metric.$1,
          value: metric.$2,
          unit: metric.$3,
          source: 'Apple Watch',
          observedAt: _now,
          confidence: .98,
        ),
    ],
    importedCount: 3,
    lastSyncAt: _now,
    failureCode: null,
    deviceVerified: true,
  );

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;
  @override
  Future<void> openSystemSettings() async {}
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
}

const _dailyReport = DailyReturnReport(
  state: DailyReturnState.partial,
  hasWeight: true,
  hasMeals: true,
  hasWater: false,
  bestAction: BestAction(
    type: BestActionType.none,
    title: '',
    reason: '',
    evidence: [],
  ),
  changed: WhatChangedReport(
    interpretation: ChangeInterpretation.insufficient,
    summary: '',
    evidence: [],
    alternatives: [],
  ),
  honesty: DataHonestyReport(
    score: 0,
    reliability: DataReliability.insufficient,
    strengths: [],
    missing: [],
  ),
  daysAway: 0,
);

Widget _subject(Locale locale, double scale) {
  final arabic = locale.languageCode == 'ar';
  return ProviderScope(
    overrides: [
      connectedHealthGatewayProvider.overrideWithValue(_HealthFixture()),
      liveHealthNowProvider.overrideWithValue(() => _now),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: visualEvidenceTheme(
        BilFlagshipTheme.light(isArabic: arabic),
        fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DashboardShell(
        onRefresh: () async {},
        child: RepaintBoundary(
          key: const Key('dashboard-polish-review'),
          child: ColoredBox(
            color: BilFlagshipTheme.light().scaffoldBackgroundColor,
            child: Column(
              children: [
                DashboardTopBar(onProfile: () {}),
                const SizedBox(height: 12),
                PremiumDashboardBenchmark(
                  arabic: arabic,
                  actionTitle: '',
                  actionReason: '',
                  actionEvidence: '',
                  confidence: '',
                  onAction: null,
                  hero: const DashboardHeader(),
                  dailyIntelligence: DailyReturnCard(
                    report: _dailyReport,
                    changedSummary: '',
                    actionTitle: '',
                    actionReason: '',
                    missingEvidence: '',
                    onPrimaryAction: null,
                    onWeightTap: () {},
                    onMealsTap: () {},
                    onWaterTap: () {},
                  ),
                  connectedHealth: ConnectedHealthCard(
                    languageCode: locale.languageCode,
                    compact: true,
                    dashboardCompact: true,
                  ),
                  bodyTwinSummary: arabic
                      ? 'التوأم الجسدي ينتظر وزنًا محليًا موثوقًا'
                      : 'Body Twin is waiting for a trusted local weight',
                  bodyTwinEvidence: '',
                  nutritionSummary: '',
                  nutritionEvidence: '',
                  trendSummary: '',
                  trendEvidence: '',
                  loggingItems: const [],
                  caloriesConsumed: 640,
                  caloriesGoal: 2100,
                  baseCaloriesGoal: 2100,
                  caloriesBurned: 321,
                  netCalories: 319,
                  remainingCalories: 1460,
                  weightTrendValues: const [87],
                  stepTrendValues: const [4321],
                  todaySteps: 4321,
                  nutrientDashboardPreset: 'Heart healthy',
                  visibleSections: const {
                    DashboardSectionIds.aiCoach,
                    DashboardSectionIds.connectedHealth,
                    DashboardSectionIds.calories,
                    DashboardSectionIds.macros,
                    DashboardSectionIds.activity,
                    DashboardSectionIds.bodyTwin,
                    DashboardSectionIds.discover,
                  },
                  premiumUnlocked: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final width in const [320.0, 390.0, 430.0]) {
      for (final scale in const [1.0, 1.6]) {
        testWidgets(
          '${locale.languageCode} ${width.toInt()} at ${scale}x retains all content and burned calories',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(_subject(locale, scale));
            final container = ProviderScope.containerOf(
              tester.element(find.byType(MaterialApp)),
            );
            await container.read(connectedHealthProvider.notifier).refresh();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            // Health and budget presentations must retain the verified value.
            expect(
              find.byKey(const Key('watch-metric-active-energy')),
              findsOneWidget,
            );
            final calories = find.byKey(
              const Key('dashboard-reference-calories-card'),
            );
            expect(calories, findsOneWidget);
            expect(
              find.byKey(const Key('dashboard-heart-circle-card')),
              findsNothing,
            );
            expect(
              find.descendant(of: calories, matching: find.text('321')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('dashboard-burn-policy-note')),
              findsOneWidget,
            );
            final remaining = tester.widget<Text>(
              find.byKey(
                const Key('dashboard-reference-calorie-remaining-value'),
              ),
            );
            expect(remaining.textSpan!.toPlainText(), '1460');

            // Inspect the lower half too; compact tiles and the single-point
            // trend must not overflow when accessibility fonts are enabled.
            final scroll = tester
                .widget<SingleChildScrollView>(
                  find.byKey(const Key('dashboard-scroll-view')),
                )
                .controller!;
            scroll.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(scroll.position.outOfRange, isFalse);

            if (Platform.environment['BIL_CAPTURE_DASHBOARD_POLISH'] == '1' &&
                width == 390 &&
                scale == 1) {
              scroll.jumpTo(0);
              await tester.pumpAndSettle();
              await settleVisualAssetImages(tester);
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('dashboard-polish-review')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 2);
                try {
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final directory = Directory('build/dashboard_polish_review');
                  await directory.create(recursive: true);
                  await File(
                    '${directory.path}/${locale.languageCode}.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                } finally {
                  image.dispose();
                }
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          },
        );
      }
    }
  }
}
