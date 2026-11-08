import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/settings/reference_settings_copy.dart';
import 'package:body_intelligence_log/features/settings/settings_page.dart';
import 'package:body_intelligence_log/shared/widgets/bil_navigation_feedback.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../visual_closure/visual_evidence_font.dart';

final _now = DateTime.utc(2026, 11, 8);
DateTime _clock() => _now;
const _capture = Key('membership-navigation-capture');
const _pending = AsyncLoading<SubscriptionState>();

SubscriptionState _free() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: FreePlan.entitlements,
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: true,
  canRestorePurchases: true,
);

SubscriptionState _paid() => SubscriptionState(
  plan: CommercePlan.premium,
  entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.premium),
  authority: EntitlementAuthority.verifiedServer,
  startedAt: _now.subtract(const Duration(hours: 1)),
  currentPeriodEndsAt: _now.add(const Duration(days: 1)),
  isPurchasable: true,
  canRestorePurchases: true,
);

Future<void> _frames(WidgetTester tester) async {
  // Includes the complete iOS route transition before comparing geometry.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _captureIfRequested(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('BIL_DASHBOARD_CAPTURE_DIR');
  if (output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('No rendered PNG');
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}

void main() {
  late AppDatabase database;
  setUpAll(() async {
    await loadVisualEvidenceFont();
    // This file performs no preference writes. Initialize one real local
    // database outside the widget fake clock, then share it read-only.
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
  });
  tearDownAll(() => database.close());

  for (final language in ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$language $brightness More keeps its arrow and opens real Plans during verification',
        (tester) async {
          final harness = _Harness(database);
          try {
            await harness.mount(tester, language, brightness, settings: true);
            final entry = find.byKey(const Key('more-premium-entry'));
            final arrow = find.descendant(
              of: entry,
              matching: find.byType(BilNavigationFeedback),
            );
            final indicator = find.descendant(
              of: entry,
              matching: find.byType(BilFeatureWelcomeStatus),
            );
            final copy = ReferenceSettingsCopy.of(tester.element(entry));
            expect(find.text(copy('Checking subscription')), findsOneWidget);
            expect(find.text(copy('Active')), findsNothing);
            expect(find.text(copy('Explore Premium')), findsNothing);
            expect(indicator, findsNothing);
            expect(arrow, findsOneWidget);
            expect(tester.widget<InkWell>(entry).onTap, isNotNull);
            final before = tester.getRect(entry);
            await _captureIfRequested(
              tester,
              'more-$language-${brightness.name}-pending',
            );
            await tester.tap(entry);
            await _frames(tester);
            expect(find.byType(BilStorePlansPage), findsOneWidget);
            expect(
              find.byKey(const Key('store-account-access-status')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('store-current-plan-status')),
              findsNothing,
            );
            harness.setAccess(AsyncData(_free()));
            await _frames(tester);
            expect(
              find.byKey(const Key('store-current-plan-status')),
              findsNothing,
            );
            harness.router.pop();
            await _frames(tester);
            expect(find.text(copy('Explore Premium')), findsOneWidget);
            expect(tester.getRect(entry), before);
            harness.setAccess(_pending);
            await _frames(tester);
            expect(arrow, findsOneWidget);
            expect(indicator, findsNothing);
            expect(tester.getRect(entry), before);
            expect(find.text(copy('Active')), findsNothing);
            harness.setAccess(AsyncData(_paid()));
            await _frames(tester);
            expect(find.text(copy('Active')), findsOneWidget);
            expect(tester.getRect(entry), before);
            await tester.tap(entry);
            await _frames(tester);
            expect(
              find.byKey(const Key('store-current-plan-status')),
              findsOneWidget,
            );
            // The existing authority contract retains a still-valid paid
            // lease during a same-owner refresh; this UI change must not
            // revoke it or invent a new grant. A verified Free decision does
            // remove the paid state, and its next recheck stays neutral.
            harness.setAccess(_pending);
            await _frames(tester);
            expect(
              harness.container
                  .read(verifiedSubscriptionAccessProvider)
                  .asData
                  ?.value
                  .plan,
              CommercePlan.premium,
            );
            expect(
              find.byKey(const Key('store-current-plan-status')),
              findsOneWidget,
            );
            harness.setAccess(AsyncData(_free()));
            await _frames(tester);
            harness.setAccess(_pending);
            await _frames(tester);
            expect(
              harness.container
                  .read(verifiedSubscriptionAccessProvider)
                  .isLoading,
              isTrue,
            );
            expect(
              find.byKey(const Key('store-current-plan-status')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          } finally {
            await harness.close(tester);
          }
        },
      );

      testWidgets(
        '$language $brightness nutrient arrow stays static while real chooser remains access guarded',
        (tester) async {
          final harness = _Harness(database);
          try {
            await harness.mount(tester, language, brightness, settings: false);
            final entry = find.byKey(
              const Key('dashboard-add-nutrient-goal-cards'),
            );
            await tester.scrollUntilVisible(
              entry,
              400,
              scrollable: find.byType(Scrollable).first,
            );
            await _frames(tester);
            final tile = tester.widget<ListTile>(entry);
            expect(tile.trailing, isA<BilNavigationFeedback>());
            expect(
              find.descendant(
                of: entry,
                matching: find.byType(BilFeatureWelcomeStatus),
              ),
              findsNothing,
            );
            final before = tester.getRect(entry);
            await tester.tap(entry);
            await _frames(tester);
            expect(find.byType(BottomSheet), findsNothing);
            await _captureIfRequested(
              tester,
              'nutrient-$language-${brightness.name}-pending',
            );
            harness.setAccess(AsyncData(_free()));
            await _frames(tester);
            expect(
              tester.widget<ListTile>(entry).trailing,
              isA<Icon>().having(
                (icon) => icon.icon,
                'Free crown',
                Icons.workspace_premium_rounded,
              ),
            );
            expect(tester.getRect(entry), before);
            await tester.tap(entry);
            await _frames(tester);
            expect(
              find.byKey(const Key('dashboard-nutrient-premium-page-label')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('dashboard-nutrient-goal-fat')),
              findsNothing,
            );
            Navigator.of(tester.element(find.byType(BottomSheet))).pop();
            await _frames(tester);
            harness.setAccess(_pending);
            await _frames(tester);
            expect(
              tester.widget<ListTile>(entry).trailing,
              isA<BilNavigationFeedback>(),
            );
            expect(tester.getRect(entry), before);
            await tester.tap(entry);
            await _frames(tester);
            expect(find.byType(BottomSheet), findsNothing);
            harness.setAccess(AsyncData(_paid()));
            await _frames(tester);
            expect(tester.getRect(entry), before);
            await tester.tap(entry);
            await _frames(tester);
            expect(
              find.byKey(const Key('dashboard-nutrient-goal-fat')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          } finally {
            await harness.close(tester);
          }
        },
      );
    }
  }
}

class _Harness {
  _Harness(this.database) {
    container = ProviderContainer(overrides: _overrides(_pending));
  }

  final AppDatabase database;
  late final ProviderContainer container;
  late GoRouter router;

  List<Override> _overrides(AsyncValue<SubscriptionState> access) => [
    databaseProvider.overrideWithValue(database),
    verifiedEntitlementClockProvider.overrideWithValue(_clock),
    verifiedEntitlementOwnerIdProvider.overrideWithValue('synthetic-owner'),
    verifiedSubscriptionStateProvider.overrideWithValue(access),
  ];

  void setAccess(AsyncValue<SubscriptionState> access) {
    container.updateOverrides(_overrides(access));
  }

  Future<void> mount(
    WidgetTester tester,
    String language,
    Brightness brightness, {
    required bool settings,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => settings
              ? const SettingsPage()
              : const DashboardPreferencesPage(),
        ),
        GoRoute(
          path: '/plans',
          builder: (_, _) =>
              const BilStorePlansPage(connectToDeviceStore: false),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: visualEvidenceTheme(
            BilFlagshipTheme.light(isArabic: language == 'ar'),
            fontFamily: language == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          darkTheme: visualEvidenceTheme(
            BilFlagshipTheme.dark(isArabic: language == 'ar'),
            fontFamily: language == 'ar'
                ? 'NotoArabicEvidence'
                : 'RobotoEvidence',
          ),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          routerConfig: router,
          builder: (context, child) => RepaintBoundary(
            key: _capture,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await _frames(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    router.dispose();
    tester.view.reset();
  }
}
