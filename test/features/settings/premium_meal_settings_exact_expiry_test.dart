// Actual settings gate, real default server entitlement repository and SQLite.
// Auth/HTTP/secure storage are host fixtures; only the existing entitlement
// clock seam is overridden. No fabricated paid/access provider or fake page.
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/settings/premium_meal_features_page.dart';
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
      'actual meal settings rejects ${openBeforeExpiry ? 'already-open' : 'new'} edit at exact expiry',
      (tester) async {
        final owner =
            '00000000-0000-4000-8002-${(++ownerSequence).toString().padLeft(12, '0')}';
        final start = DateTime.now().toUtc();
        final boundary = start.add(const Duration(seconds: 20));
        var clock = start;
        var authorityReads = 0;
        var authorityFinished = false;
        final requestPaths = <String>[];
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
          requestPaths.add(request.url.path);
          try {
            // This callback was registered before pumpWidget. expectSync keeps
            // the strict HTTP assertions without a conflicting widget guard.
            expectSync(request.url.host, 'meal-expiry-fixture.invalid');
            expectSync(
              request.headers['authorization'],
              'Bearer meal-expiry-fixture-token',
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
                throw StateError(
                  'Unexpected fixture HTTP path: ${request.url.path}',
                );
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
            url: 'https://meal-expiry-fixture.invalid',
            publishableKey: 'meal-expiry-fixture-publishable-key',
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
              'access_token': 'meal-expiry-fixture-token',
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
        // Observe the genuine exact-cutoff view without replacing its behavior,
        // independently of whichever snapshot the actual settings UI consumes.
        final cutoffObserver = container.listen(
          verifiedSubscriptionAccessProvider,
          (_, _) {},
          fireImmediately: true,
        );
        final router = GoRouter(
          initialLocation: '/settings/nutrition-meal-calorie-goals',
          routes: [
            GoRoute(
              path: '/settings/nutrition-meal-calorie-goals',
              builder: (_, _) => const MealCalorieGoalsPage(),
            ),
            GoRoute(
              path: '/plans',
              builder: (_, _) =>
                  const BilStorePlansPage(connectToDeviceStore: false),
            ),
          ],
        );
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
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
              ),
            ),
          );
          await _waitUntil(
            tester,
            () =>
                authorityFinished &&
                find.text('Breakfast').hitTestable().evaluate().isNotEmpty,
            'genuine active paid snapshot and actual unlocked meal settings',
            diagnostics: () {
              final state = container.read(verifiedSubscriptionStateProvider);
              final goals = container.read(mealCalorieGoalsProvider);
              return 'reads=$authorityReads; finished=$authorityFinished; '
                  'subscription=$state; mealGoals=$goals; '
                  'requests=$requestPaths; '
                  'fixtureFailure=$fixtureFailure; '
                  'plan=${state.value?.plan}; '
                  'auth=${Supabase.instance.client.auth.currentUser?.id}; '
                  'owner=${container.read(verifiedEntitlementOwnerIdProvider)}; '
                  'breakfast=${find.text('Breakfast').evaluate().length}; '
                  'hit=${find.text('Breakfast').hitTestable().evaluate().length}';
            },
          );
          final verified = container
              .read(verifiedSubscriptionStateProvider)
              .requireValue;
          expect(fixtureFailure, isNull);
          expect(verified.authority, EntitlementAuthority.verifiedServer);
          expect(verified.plan, CommercePlan.premium);
          expect(verified.currentPeriodEndsAt, boundary);
          expect(
            container
                .read(verifiedSubscriptionAccessProvider)
                .requireValue
                .plan,
            CommercePlan.premium,
          );
          expect(authorityReads, 1);

          // Prove that the same production widget/callback really saves locally
          // while its authoritative paid period is valid, not just a UI shell.
          await tester.tap(find.text('Breakfast'));
          await _waitUntil(
            tester,
            () => find.byType(AlertDialog).evaluate().isNotEmpty,
            'initial actual meal edit dialog',
          );
          await tester.enterText(find.byType(TextField), '620');
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await _waitUntil(
            tester,
            () =>
                find.byType(AlertDialog).evaluate().isEmpty &&
                find.text('620 kcal').evaluate().isNotEmpty,
            'initial SQLite write/readback',
          );
          String? initial;
          await _finishHost(tester, () async {
            initial = await preferences.get(mealCalorieGoalKey('breakfast'));
          });
          expect(initial, '620.0');

          if (openBeforeExpiry) {
            await tester.tap(find.text('Breakfast'));
            await _waitUntil(
              tester,
              () => find.byType(AlertDialog).evaluate().isNotEmpty,
              'real dialog remains open while paid access expires',
            );
            await tester.enterText(find.byType(TextField), '900');
          }
          // Fire the actual exact-boundary timer, before the raw 30s refresh.
          // No paid state, entitlement loader or access provider is overridden.
          clock = boundary;
          await tester.pump(const Duration(seconds: 20));
          await tester.pump();
          final expired = container
              .read(verifiedSubscriptionAccessProvider)
              .requireValue;
          expect(expired.plan, CommercePlan.free);
          expect(expired.lifecycle, SubscriptionLifecycle.expired);
          expect(
            container.read(verifiedSubscriptionStateProvider).requireValue.plan,
            CommercePlan.premium,
            reason: 'Raw successful server snapshot has not refreshed yet',
          );
          expect(
            authorityReads,
            1,
            reason:
                'Exact local cutoff must not wait for the next network refresh',
          );

          // Try the actual local gesture only if the production route still
          // exposes it. Correct lock/removal also passes the invariant below.
          if (!openBeforeExpiry &&
              find.text('Breakfast').hitTestable().evaluate().isNotEmpty) {
            await tester.tap(find.text('Breakfast'));
            await _waitUntil(
              tester,
              () => find.byType(AlertDialog).evaluate().isNotEmpty,
              'post-expiry stale real editor',
            );
            await tester.enterText(find.byType(TextField), '900');
          }
          final staleSave = find
              .widgetWithText(FilledButton, 'Save')
              .hitTestable();
          if (staleSave.evaluate().isNotEmpty) {
            await tester.tap(staleSave);
          }
          await _waitUntil(
            tester,
            () => find.byType(AlertDialog).evaluate().isEmpty,
            'stale real editor is closed without a new SQLite write',
          );
          String? persisted;
          await _finishHost(tester, () async {
            persisted = await preferences.get(mealCalorieGoalKey('breakfast'));
          });
          expect(
            persisted,
            '620.0',
            reason:
                'An expired paid callback must not persist a new local meal goal',
          );
          expect(
            find.text('Breakfast').hitTestable(),
            findsNothing,
            reason: 'Expired settings controls must become inaccessible',
          );
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
          await tester.pump();
        }
      },
    );
  }
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() ready,
  String stage, {
  String Function()? diagnostics,
}) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsedMilliseconds < 5000) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    ready(),
    isTrue,
    reason:
        'Actual settings stage did not finish: $stage; ${diagnostics?.call() ?? ''}',
  );
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
