import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_engine.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_page.dart';
import 'package:body_intelligence_log/features/analytics/weekly_report_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition/domain/catalog_pack.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/catalog_packs_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/catalog_pack_manager.dart';
import 'package:body_intelligence_log/features/nutrition_plans/data/diet_plan_repository.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_catalog.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _reload = StateProvider<int>((_) => 0);

class _Fixture {
  _Fixture() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    next = Future.value(paid());
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
        verifiedEntitlementOwnerProvider.overrideWith((_) => owners.stream),
        verifiedEntitlementClockProvider.overrideWithValue(() => now),
        verifiedEntitlementLoaderProvider.overrideWith((ref) {
          ref.watch(_reload);
          return () => next;
        }),
        preferencesRepositoryProvider.overrideWithValue(preferences),
        catalogPackManagerProvider.overrideWithValue(packs),
        accountCreatedAtProvider.overrideWithValue(null),
        userProfileProvider.overrideWith((_) => Stream.value(null)),
        weeklyReportProvider.overrideWith((_) async => report),
      ],
    );
  }

  DateTime now = DateTime.utc(2026, 11, 20, 12);
  final owners = StreamController<String?>.broadcast(sync: true);
  final packs = _Packs();
  late final AppDatabase database;
  late final PreferencesRepository preferences;
  late final ProviderContainer container;
  late Future<SubscriptionState> next;
  final pending = <Completer<SubscriptionState>>[];
  bool _closed = false;
  final report = const WeeklyReportEngine().build(
    asOf: DateTime(2026, 11, 20),
    mealCount: 0,
    nutrition: const [],
    water: const [],
    weights: const [],
    activity: const [],
  );

  SubscriptionState paid({DateTime? end}) => SubscriptionState(
    plan: CommercePlan.pro,
    entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.pro),
    authority: EntitlementAuthority.verifiedServer,
    startedAt: now.subtract(const Duration(hours: 1)),
    currentPeriodEndsAt: end ?? now.add(const Duration(hours: 1)),
    isPurchasable: false,
    canRestorePurchases: true,
  );

  Future<void> verify() async {
    await container.read(verifiedSubscriptionStateProvider.future);
    await container.pump();
  }

  Completer<SubscriptionState> reload() {
    final read = Completer<SubscriptionState>();
    pending.add(read);
    next = read.future;
    container.read(_reload.notifier).state += 1;
    container.read(verifiedSubscriptionStateProvider.future).ignore();
    return read;
  }

  Future<void> changeOwner(String owner, {bool flush = true}) async {
    final delivered = Completer<void>();
    final listener = container.listen(verifiedEntitlementOwnerProvider, (
      _,
      next,
    ) {
      if (next.asData?.value == owner && !delivered.isCompleted) {
        delivered.complete();
      }
    });
    try {
      owners.add(owner);
      await delivered.future.timeout(const Duration(seconds: 2));
      if (flush) await container.pump();
    } finally {
      listener.close();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    container.dispose();
    for (final read in pending) {
      if (!read.isCompleted) read.complete(FreePlan.createState());
    }
    await owners.close();
    await database.close();
  }
}

class _Packs extends CatalogPackManager {
  int installs = 0;
  @override
  Future<List<InstalledCatalogPack>> installed() async => const [];
  @override
  Future<List<CatalogPack>> fetchAvailable() async => [
    CatalogPack(
      id: 'verified-pro',
      version: '1',
      title: 'Verified Pro library',
      downloadUri: Uri.parse('https://example.invalid/verified.sqlite'),
      sha256: 'a' * 64,
      sizeBytes: 1024,
      access: CatalogPackAccess.pro,
    ),
  ];
  @override
  Future<InstalledCatalogPack> install(CatalogPack pack) async {
    installs += 1;
    return InstalledCatalogPack(
      id: pack.id,
      version: pack.version,
      path: 'unused-test-path',
      sizeBytes: pack.sizeBytes,
      installedAt: DateTime.utc(2026, 11, 20),
    );
  }
}

Widget _app(Widget home) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  for (final change in ['expired', '401', 'owner-change']) {
    testWidgets(
      'saved catalog Download callback cannot install after $change before a widget rebuild',
      (tester) async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.verify();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: _app(const CatalogPacksPage()),
          ),
        );
        await tester.pumpAndSettle();
        final download = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Download'))
            .onPressed!;
        if (change == 'expired') {
          fixture.now = fixture.now.add(const Duration(hours: 1));
          // Deliver the real cutoff timer without rendering a frame. The old
          // button remains enabled until a later widget pump.
          await tester.binding.delayed(const Duration(hours: 1));
        } else if (change == '401') {
          final read = fixture.reload();
          final observed = fixture.container
              .read(verifiedSubscriptionStateProvider.future)
              .then<void>((_) {}, onError: (Object _) {});
          read.completeError(
            const AuthException('synthetic invalid session', statusCode: '401'),
          );
          await observed;
        } else {
          await fixture.changeOwner('owner-b', flush: false);
          await fixture.container.read(
            verifiedSubscriptionStateProvider.future,
          );
        }
        // Invoke the previously enabled button without pumping the changed UI.
        download();
        await tester.pumpAndSettle();
        final installs = fixture.packs.installs;
        await tester.pumpWidget(const SizedBox());
        await fixture.close();
        await tester.pump();
        expect(installs, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'weekly Free CTA keeps its geometry throughout an uncompleted reread',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      fixture.next = Future.value(
        SubscriptionState(
          plan: CommercePlan.free,
          entitlements: FreePlan.entitlements,
          authority: EntitlementAuthority.verifiedServer,
          isPurchasable: false,
          canRestorePurchases: false,
        ),
      );
      await fixture.verify();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: _app(const WeeklyReportPage()),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('weekly-go-premium'));
      await tester.scrollUntilVisible(action, 350);
      await tester.pumpAndSettle();
      final rect = tester.getRect(action);
      final held = fixture.reload();
      await tester.pump();
      await tester.pump();
      expect(
        fixture.container.read(verifiedSubscriptionAccessProvider).isLoading,
        isTrue,
      );
      expect(tester.getRect(action), rect);
      expect(find.text('Checking subscription'), findsNothing);
      expect(find.byKey(const Key('weekly-entitlement-loading')), findsNothing);
      expect(find.text('Premium insight active'), findsNothing);
      held.completeError(StateError('offline fixture'));
      await tester.pump();
      await tester.pump();
      expect(tester.getRect(action), rect);
      expect(find.byKey(const Key('weekly-entitlement-error')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await fixture.close();
    },
  );

  for (final failed in [false, true]) {
    testWidgets(
      'weekly paid content stays stable during background failed=$failed',
      (tester) async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.verify();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: _app(const WeeklyReportPage()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('weekly-calories-premium-cta')),
          350,
        );
        await tester.pumpAndSettle();
        final before = tester.getRect(
          find.byKey(const Key('weekly-calories-section')),
        );
        final reload = fixture.reload();
        await tester.pump();
        if (failed) {
          reload.completeError(StateError('synthetic transport outage'));
          await tester.pump();
          await tester.pump();
        }
        expect(
          fixture.container.read(verifiedSubscriptionStateProvider).isLoading,
          !failed,
        );
        expect(
          find.byKey(const Key('weekly-entitlement-loading')),
          findsNothing,
        );
        expect(find.byKey(const Key('weekly-entitlement-error')), findsNothing);
        expect(find.byKey(const Key('weekly-go-premium')), findsNothing);
        expect(
          tester.getRect(find.byKey(const Key('weekly-calories-section'))),
          before,
        );
        expect(find.text('Premium insight active'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await fixture.close();
        await tester.pump();
      },
    );

    testWidgets(
      'diary paid row remains tappable during background failed=$failed',
      (tester) async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.verify();
        final reload = fixture.reload();
        if (failed) {
          reload.completeError(StateError('synthetic transport outage'));
        }
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const ReferenceDiarySettingsPage(),
            ),
            GoRoute(
              path: '/settings/diary/macro-display',
              builder: (_, _) =>
                  const Scaffold(body: Text('Opened macro display')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: MaterialApp.router(
              routerConfig: router,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.ancestor(
          of: find.byKey(const Key('diary-premium-feature-chevron')),
          matching: find.byType(ListTile),
        );
        expect(tester.widget<ListTile>(row).enabled, isTrue);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('Opened macro display'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await fixture.close();
        await tester.pump();
      },
    );

    testWidgets(
      'catalog download respects canonical paid access during background failed=$failed',
      (tester) async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.verify();
        final reload = fixture.reload();
        if (failed) {
          reload.completeError(StateError('synthetic transport outage'));
        }
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: _app(const CatalogPacksPage()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Plan required'), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, 'Download'));
        await tester.pumpAndSettle();
        expect(fixture.packs.installs, 1);
        await tester.pumpWidget(const SizedBox());
        await fixture.close();
        await tester.pump();
      },
    );

    test(
      'paid pathway activates during background failed=$failed without awaiting its read',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.verify();
        final reload = fixture.reload();
        if (failed) {
          reload.completeError(StateError('synthetic transport outage'));
          await fixture.container.pump();
        }
        await fixture.container
            .read(dietPlanCommandProvider)
            .activate(dietPresets['high-protein']!.toDraft())
            .timeout(const Duration(seconds: 2));
        expect(
          await fixture.preferences.get(DietPlanRepository.activePathwayKey),
          'high-protein',
        );
        expect(
          (await fixture.container
                  .read(nutritionGoalScheduleRepositoryProvider)
                  .read())
              .dayTargets,
          hasLength(7),
        );
      },
    );
  }

  for (final denial in ['expired', 'free', '401', '403']) {
    testWidgets('catalog cannot download after $denial', (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      if (denial == 'expired') {
        fixture.next = Future.value(fixture.paid(end: fixture.now));
      }
      await fixture.verify();
      if (denial != 'expired') {
        final reload = fixture.reload();
        if (denial == 'free') {
          reload.complete(_free());
        } else {
          reload.completeError(
            AuthException('synthetic invalid session', statusCode: denial),
          );
        }
        await fixture.container.pump();
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: _app(const CatalogPacksPage()),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Plan required'),
      );
      expect(button.onPressed, isNull);
      expect(fixture.packs.installs, 0);
      await tester.pumpWidget(const SizedBox());
      await fixture.close();
      await tester.pump();
    });
  }

  for (final denial in ['expired', 'free', 'owner-change', '401', '403']) {
    test('paid pathway cannot persist targets after $denial', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      if (denial == 'expired') {
        fixture.next = Future.value(fixture.paid(end: fixture.now));
      }
      await fixture.verify();
      if (denial == 'owner-change') {
        final read = Completer<SubscriptionState>();
        fixture.pending.add(read);
        fixture.next = read.future;
        await fixture.changeOwner('owner-b');
        final accessObserver = fixture.container.listen(
          verifiedSubscriptionAccessProvider,
          (_, _) {},
        );
        final activation = fixture.container
            .read(dietPlanCommandProvider)
            .activate(dietPresets['high-protein']!.toDraft())
            .timeout(const Duration(seconds: 2));
        final observed = expectLater(
          activation,
          throwsA(isA<NutritionPathwayActivationException>()),
        );
        await fixture.changeOwner('owner-a');
        read.complete(fixture.paid());
        await observed;
        accessObserver.close();
      } else {
        if (denial != 'expired') {
          final read = fixture.reload();
          if (denial == 'free') {
            read.complete(_free());
          } else {
            read.completeError(
              AuthException('synthetic invalid session', statusCode: denial),
            );
          }
          await fixture.container.pump();
        }
        await expectLater(
          fixture.container
              .read(dietPlanCommandProvider)
              .activate(dietPresets['high-protein']!.toDraft()),
          throwsA(isA<NutritionPathwayActivationException>()),
        );
      }
      expect(
        await fixture.preferences.get(DietPlanRepository.activePathwayKey),
        isNull,
      );
      expect(
        (await fixture.container
                .read(nutritionGoalScheduleRepositoryProvider)
                .read())
            .dayTargets,
        isEmpty,
      );
    });
  }
}

SubscriptionState _free() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: FreePlan.entitlements,
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);
