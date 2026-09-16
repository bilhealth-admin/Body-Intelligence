import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/dashboard/dashboard_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/meal_vision_usage_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_vision_usage_contract.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../visual_closure/visual_evidence_font.dart';

final _now = DateTime(2026, 9, 16, 16, 31);

// Entirely isolated visual fixtures. No user's database, account, store,
// network, or native HealthKit source is accessed by this capture.
final class _PreviewHealth
    implements ConnectedHealthGateway, ConnectedHealthDailyActivityGateway {
  static final snapshot = ConnectedHealthSnapshot(
    status: ConnectedHealthStatus.synchronized,
    platformSource: 'Apple Health',
    availableSources: const ['Apple Health'],
    signals: [
      for (final metric in const [
        ('steps', 108.0, 'count'),
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
    // Simulate the verified-source presentation only within the test.
    deviceVerified: true,
  );

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;
  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() async => snapshot;
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

Future<void> _capture(WidgetTester tester, String name) async {
  if (Platform.environment['BIL_CAPTURE_DASHBOARD_POLISH'] != '1') return;
  await settleVisualAssetImages(tester);
  await tester.pumpAndSettle();
  // The Today button deliberately uses a platform-default font. Flutter's
  // headless engine substitutes its block-shaped test font when no family is
  // specified, even after loading the normal theme fonts. Supply the same
  // evidence face here without changing production widgets, labels, or sizes.
  final today = find.descendant(
    of: find.byKey(const Key('dashboard-reference-calories-edit')),
    matching: find.byType(RichText),
  );
  final paragraph = tester.renderObject<RenderParagraph>(today);
  final span = paragraph.text as TextSpan;
  paragraph.text = TextSpan(
    text: span.text,
    children: span.children,
    style: (span.style ?? const TextStyle()).copyWith(
      fontFamily: name.endsWith('-ar')
          ? 'NotoArabicEvidence'
          : 'RobotoEvidence',
    ),
    locale: span.locale,
    semanticsLabel: span.semanticsLabel,
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('dashboard-current-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/dashboard_polish_review');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in const ['en', 'ar']) {
    testWidgets('$language current production dashboard and dock preview', (
      tester,
    ) async {
      final originalDisableShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = originalDisableShadows);
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await UserProfileRepository(db).save(
        gender: 'male',
        age: 35,
        height: 181,
        currentWeight: 87,
        targetWeight: 82,
        activityLevel: 'light',
        exercises: true,
      );
      await WeightRepository(db).addWeight(87, date: _now);
      await PreferencesRepository(db).setMany({
        'goal.calories': '2100',
        'diary.nutrientDashboard': 'Heart healthy',
      });
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                ResponsiveAppShell(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final font = language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dashboardClockProvider.overrideWithValue(() => _now),
            liveHealthNowProvider.overrideWithValue(() => _now),
            connectedHealthGatewayProvider.overrideWithValue(_PreviewHealth()),
            mealVisionUsageProvider.overrideWithValue(
              const AsyncData(MealVisionUsageSnapshot.unavailable()),
            ),
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(
                SubscriptionState(
                  plan: CommercePlan.premium,
                  entitlements: {
                    ...FreePlan.entitlements,
                    CommerceEntitlement.adFree,
                    CommerceEntitlement.advancedAnalytics,
                    CommerceEntitlement.mealPlanning,
                    CommerceEntitlement.connectedHealth,
                    CommerceEntitlement.premiumPrograms,
                    CommerceEntitlement.customGoals,
                    CommerceEntitlement.advancedIntelligence,
                  },
                  authority: EntitlementAuthority.verifiedServer,
                  isPurchasable: true,
                  canRestorePurchases: true,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: visualEvidenceTheme(
              BilFlagshipTheme.light(
                isArabic: language == 'ar',
              ).copyWith(platform: TargetPlatform.iOS),
              fontFamily: font,
            ),
            builder: (context, child) => RepaintBoundary(
              key: const Key('dashboard-current-capture'),
              child: visualEvidenceTextSurface(child, fontFamily: font),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container.read(connectedHealthProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.byType(ResponsiveAppShell), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard-reference-calories-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dashboard-heart-circle-card')),
        findsNothing,
      );
      expect(find.byKey(const Key('shell-quick-add')), findsOneWidget);
      final header = tester.getRect(
        find.byKey(const Key('dashboard-identity-header')),
      );
      final wordmark = tester.getRect(
        find.byKey(const Key('dashboard-wordmark')),
      );
      expect(header.height, 48);
      final profile = tester.getRect(
        find.byKey(const Key('dashboard-profile-control')),
      );
      final notifications = tester.getRect(
        find.byKey(const Key('dashboard-notifications')),
      );
      expect(wordmark.center.dx, closeTo(header.center.dx, .1));
      expect(header.center.dx, closeTo(215, .1));
      expect(header.width, closeTo(426, .1));
      expect(profile.left, closeTo(header.left, .1));
      expect(notifications.left - wordmark.right, closeTo(2, .1));
      expect(wordmark.width, greaterThanOrEqualTo(246));
      expect(
        tester.getRect(find.byKey(const Key('dashboard-edit-today'))).right,
        closeTo(header.right, .1),
      );
      final edit = tester.getSize(
        find.byKey(const Key('dashboard-edit-today')),
      );
      expect(edit.width, 44);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(edit.height, greaterThanOrEqualTo(44));
      expect(
        find.byKey(const Key('dashboard-fitness-side-by-side')),
        findsOneWidget,
      );
      final watchRect = tester.getRect(
        find.byKey(const Key('dashboard-live-fitness-watch-slot')),
      );
      final summaryRect = tester.getRect(
        find.byKey(const Key('dashboard-fitness-summary-column')),
      );
      expect(watchRect.overlaps(summaryRect), isFalse);
      expect(summaryRect.left, greaterThan(watchRect.right));
      final fitnessRow = tester.getRect(
        find.byKey(const Key('dashboard-fitness-side-by-side')),
      );
      expect(summaryRect.right, closeTo(fitnessRow.right, .1));
      expect(summaryRect.width, lessThan(fitnessRow.width * .45));
      expect(watchRect.top, lessThan(summaryRect.bottom));
      expect(summaryRect.top, lessThan(watchRect.bottom));
      final weightValue = find.descendant(
        of: find.byKey(const Key('dashboard-summary-weight')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '87.0 kg',
        ),
      );
      expect(weightValue, findsOneWidget);
      final weightText = tester.widget<Text>(weightValue);
      expect(weightText.style?.fontWeight, FontWeight.w800);
      expect(weightText.style?.fontSize, 14);
      expect(weightText.textDirection, TextDirection.ltr);
      for (final section in ['weight', 'meals', 'water']) {
        final cardRect = tester.getRect(
          find.byKey(Key('dashboard-summary-$section')),
        );
        expect(cardRect.height, greaterThanOrEqualTo(48));
        expect(cardRect.left, summaryRect.left);
        expect(cardRect.right, summaryRect.right);
      }
      expect(find.byKey(const Key('dashboard-ai-coach-entry')), findsOneWidget);
      expect(
        find.byKey(const Key('watch-metric-active-energy')),
        findsOneWidget,
      );
      await _capture(tester, 'dashboard-current-phone-$language');

      // An extended canvas shows the entire real page at phone width. It is
      // not presented as a physical-device screenshot or a redesigned mockup.
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('dashboard-scroll-view')),
          )
          .controller!;
      final fullHeight = (932 + scroll.position.maxScrollExtent).ceilToDouble();
      tester.view.physicalSize = Size(430, fullHeight);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(scroll.position.maxScrollExtent, lessThanOrEqualTo(1));
      await _capture(tester, 'dashboard-current-full-$language');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDisableShadows = originalDisableShadows;
    });
  }
}
