// Actual Customize Today page, default ServerEntitlementRepository and SQLite.
// Auth/HTTP/secure storage are host fixtures. Only the existing entitlement
// clock seam is overridden; no paid/access state, loader or callback is faked.
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var ownerSequence = 0;
  for (final openBeforeExpiry in [false, true]) {
    testWidgets(
      'actual dashboard denies ${openBeforeExpiry ? 'already-open save' : 'new chooser'} at exact expiry',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        final owner =
            '00000000-0000-4000-8004-${(++ownerSequence).toString().padLeft(12, '0')}';
        final start = DateTime.now().toUtc();
        final boundary = start.add(const Duration(seconds: 20));
        var clock = start;
        var authorityReads = 0;
        var authorityFinished = false;
        Object? fixtureFailure;
        final secureValues = <String, String>{};
        SharedPreferences.setMockInitialValues({});
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _secureStorage,
          (call) async {
            final args = Map<String, Object?>.from(call.arguments as Map);
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secureValues[key];
              case 'write':
                secureValues[key!] = args['value']! as String;
                return null;
              case 'delete':
                secureValues.remove(key);
                return null;
              default:
                throw StateError('Unexpected secure storage operation');
            }
          },
        );
        final transport = MockClient((request) async {
          try {
            expectSync(request.url.host, 'dashboard-expiry-fixture.invalid');
            expectSync(
              request.headers['authorization'],
              'Bearer dashboard-expiry-fixture-token',
            );
            Object? response;
            switch (request.url.path) {
              case '/rest/v1/bil_ai_closed_test_grants':
                expectSync(
                  request.url.queryParameters['owner_id'],
                  'eq.$owner',
                );
                authorityReads++;
                response = <Object?>[];
              case '/rest/v1/bil_subscriptions':
                expectSync(
                  request.url.queryParameters['owner_id'],
                  'eq.$owner',
                );
                response = [
                  {
                    'owner_id': owner,
                    'provider': 'google',
                    'plan_id': 'premium',
                    'lifecycle': 'active',
                    'started_at': start
                        .subtract(const Duration(days: 1))
                        .toIso8601String(),
                    'expires_at': boundary.toIso8601String(),
                    'verified_at': start.toIso8601String(),
                  },
                ];
              case '/rest/v1/rpc/bil_get_my_admin_subscription':
                response = null;
                authorityFinished = true;
              default:
                throw StateError('Unexpected fixture HTTP path');
            }
            return http.Response(
              jsonEncode(response),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          } on Object catch (error) {
            fixtureFailure = error;
            rethrow;
          }
        });
        await tester.runAsync(() async {
          await Supabase.initialize(
            url: 'https://dashboard-expiry-fixture.invalid',
            publishableKey: 'dashboard-expiry-fixture-publishable-key',
            debug: false,
            authOptions: const FlutterAuthClientOptions(
              autoRefreshToken: false,
              detectSessionInUri: false,
              localStorage: EmptyLocalStorage(),
            ),
            httpClient: transport,
          );
          await Supabase.instance.client.auth.setInitialSession(
            jsonEncode({
              'access_token': 'dashboard-expiry-fixture-token',
              'token_type': 'bearer',
              'user': {
                'id': owner,
                'app_metadata': {},
                'user_metadata': {},
                'aud': 'authenticated',
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
          );
        });
        final database = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        final preferences = PreferencesRepository(database);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            verifiedEntitlementClockProvider.overrideWithValue(() => clock),
          ],
        );
        final cutoffObserver = container.listen(
          verifiedSubscriptionAccessProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final router = GoRouter(
          initialLocation: '/dashboard/preferences',
          routes: [
            GoRoute(
              path: '/dashboard/preferences',
              builder: (_, _) => const DashboardPreferencesPage(),
            ),
            GoRoute(
              path: '/plans',
              builder: (_, _) =>
                  const BilStorePlansPage(connectToDeviceStore: false),
            ),
          ],
        );
        final nutrientTile = find.byKey(
          const Key('dashboard-add-nutrient-goal-cards'),
        );
        final fat = find.byKey(const Key('dashboard-nutrient-goal-fat'));
        final fiber = find.byKey(const Key('dashboard-nutrient-goal-fiber'));
        final save = find.widgetWithText(FilledButton, 'Save cards');
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(
                routerConfig: router,
                locale: const Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
              ),
            ),
          );
          await _waitUntil(
            tester,
            () =>
                authorityFinished &&
                container.read(verifiedSubscriptionStateProvider).hasValue &&
                find.byType(DashboardPreferencesPage).evaluate().isNotEmpty &&
                _pageScrollable().evaluate().length == 1,
            'default repository resolves actual dated server response',
          );
          expect(fixtureFailure, isNull);
          final verified = container
              .read(verifiedSubscriptionStateProvider)
              .requireValue;
          expect(verified.authority, EntitlementAuthority.verifiedServer);
          expect(verified.plan, CommercePlan.premium);
          expect(verified.currentPeriodEndsAt, boundary);
          expect(authorityReads, 1);
          await _reachNutrients(tester, nutrientTile);
          await _waitUntil(
            tester,
            () => container.read(dashboardNutrientGoalCardsProvider).hasValue,
            'real SQLite nutrient-card stream',
          );

          // Positive control: genuine Premium gestures persist through the real
          // chooser and repository before exercising the exact cutoff.
          await tester.tap(nutrientTile);
          await _waitUntil(
            tester,
            () => fat.hitTestable().evaluate().isNotEmpty,
            'real Premium chooser',
          );
          await tester.tap(fat);
          await _waitUntil(
            tester,
            () =>
                tester.widget<CheckboxListTile>(fat).value == true &&
                save.hitTestable().evaluate().length == 1,
            'real fat checkbox gesture',
          );
          await tester.tap(save);
          await _waitUntil(
            tester,
            () =>
                find.byType(BottomSheet).evaluate().isEmpty &&
                nutrientTile.hitTestable().evaluate().length == 1 &&
                container
                        .read(dashboardNutrientGoalCardsProvider)
                        .value
                        ?.contains('fat') ==
                    true,
            'real active Premium save and SQLite stream readback',
          );
          String? initial;
          await _finishHost(tester, () async {
            initial = await preferences.get('dashboard.nutrientGoalCards');
          });
          expect(initial, 'fat');
          if (openBeforeExpiry) {
            await tester.tap(nutrientTile);
            await _waitUntil(
              tester,
              () => fiber.hitTestable().evaluate().isNotEmpty,
              'already-open genuine paid chooser',
            );
            await tester.tap(fiber);
            await _waitUntil(
              tester,
              () =>
                  tester.widget<CheckboxListTile>(fiber).value == true &&
                  save.hitTestable().evaluate().length == 1,
              'unsaved fiber gesture before cutoff',
            );
          }

          clock = boundary;
          container.invalidate(verifiedSubscriptionAccessProvider);
          final expired = container
              .read(verifiedSubscriptionAccessProvider)
              .requireValue;
          expect(expired.plan, CommercePlan.free);
          expect(expired.lifecycle, SubscriptionLifecycle.expired);
          expect(
            expired.grants(CommerceEntitlement.advancedIntelligence),
            isFalse,
          );
          expect(
            container.read(verifiedSubscriptionStateProvider).requireValue.plan,
            CommercePlan.premium,
          );
          expect(authorityReads, 1);
          if (openBeforeExpiry) {
            // Pointer event precedes the next frame. An old mounted Save must
            // still re-check current access before committing local data.
            expect(save.hitTestable(), findsOneWidget);
            await tester.tap(save);
            String? persisted;
            await _finishHost(tester, () async {
              persisted = await preferences.get('dashboard.nutrientGoalCards');
            });
            expect(
              persisted,
              'fat',
              reason: 'An expired Save cannot persist the added fiber card',
            );
          } else {
            await tester.pump();
            expect(nutrientTile.hitTestable(), findsOneWidget);
            await tester.tap(nutrientTile);
            await _waitUntil(
              tester,
              () => find.byType(BottomSheet).evaluate().isNotEmpty,
              'expired actual nutrient-card entry',
            );
            expect(
              find.byType(CheckboxListTile),
              findsNothing,
              reason: 'Expired access cannot open the paid chooser',
            );
            expect(
              find.byKey(const Key('dashboard-nutrient-glass-group')),
              findsOneWidget,
            );
          }
          expect(authorityReads, 1);
          expect(fixtureFailure, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          cutoffObserver.close();
          container.dispose();
          router.dispose();
          await _finishHost(tester, database.close);
          await _finishHost(tester, Supabase.instance.dispose);
          transport.close();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _secureStorage,
            null,
          );
          tester.view.reset();
          await tester.pump();
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  }
}

Future<void> _reachNutrients(WidgetTester tester, Finder target) async {
  final scrollable = _pageScrollable();
  expect(scrollable, findsOneWidget);
  for (var gesture = 0; gesture < 20; gesture++) {
    if (target.hitTestable().evaluate().length == 1) return;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
  }
  fail('Actual nutrient-card tile not reachable after bounded pointer drags');
}

Finder _pageScrollable() => find.descendant(
  of: find.byType(DashboardPreferencesPage),
  matching: find.byWidgetPredicate(
    (widget) => widget is Scrollable && widget.axis == Axis.vertical,
  ),
);

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsedMilliseconds < 5000) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull, reason: stage);
  }
  expect(ready(), isTrue, reason: 'Genuine dashboard stage stalled: $stage');
}

Future<void> _finishHost(
  WidgetTester tester,
  Future<void> Function() operation,
) async {
  var complete = false;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    Future<void>.sync(operation).then<void>(
      (_) => complete = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        complete = true;
      },
    );
  });
  final elapsed = Stopwatch()..start();
  while (!complete && elapsed.elapsedMilliseconds < 5000) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(complete, isTrue, reason: 'Genuine host operation did not finish');
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}
