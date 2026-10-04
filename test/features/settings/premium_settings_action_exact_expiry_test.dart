// Actual Macro/Exercise pages, default ServerEntitlementRepository and SQLite.
// Auth/HTTP/secure storage and an unrelated host exercise-energy snapshot are
// fixtures. No paid/access provider, entitlement loader or preference is faked.
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
import 'package:body_intelligence_log/features/exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/presentation/exercise_calorie_settings_page.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/providers/exercise_calorie_providers.dart';
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
  for (final exercise in [false, true]) {
    final feature = exercise ? 'exercise' : 'macro';
    testWidgets('actual $feature settings denies cutoff-to-frame gesture', (
      tester,
    ) async {
      final owner =
          '00000000-0000-4000-8003-${(++ownerSequence).toString().padLeft(12, '0')}';
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
          expectSync(request.url.host, 'settings-action-fixture.invalid');
          expectSync(
            request.headers['authorization'],
            'Bearer settings-action-fixture-token',
          );
          Object? response;
          switch (request.url.path) {
            case '/rest/v1/bil_ai_closed_test_grants':
              expectSync(request.url.queryParameters['owner_id'], 'eq.$owner');
              authorityReads++;
              response = <Object?>[];
            case '/rest/v1/bil_subscriptions':
              expectSync(request.url.queryParameters['owner_id'], 'eq.$owner');
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
          url: 'https://settings-action-fixture.invalid',
          publishableKey: 'settings-action-fixture-publishable-key',
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
            'access_token': 'settings-action-fixture-token',
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
          if (exercise)
            todayAuthoritativeExerciseEnergyProvider.overrideWithValue(
              AsyncData(
                AuthoritativeExerciseEnergy(
                  kcal: 320,
                  observedAt: start,
                  source: 'Host health-channel fixture',
                  confidence: 1,
                ),
              ),
            ),
        ],
      );
      final cutoffObserver = container.listen(
        verifiedSubscriptionAccessProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final route = exercise
          ? '/settings/exercise-calories'
          : '/settings/diary/macro-display';
      final router = GoRouter(
        initialLocation: route,
        routes: [
          GoRoute(
            path: route,
            builder: (_, _) => exercise
                ? const VerifiedPremiumFeatureGate(
                    title: 'Exercise calories',
                    child: ExerciseCalorieSettingsPage(),
                  )
                : const MealMacroDisplayPage(),
          ),
          GoRoute(
            path: '/plans',
            builder: (_, _) =>
                const BilStorePlansPage(connectToDeviceStore: false),
          ),
        ],
      );
      final persistedKey = exercise
          ? exerciseCaloriesIncludedPreferenceKey
          : mealMacroDisplayEnabledKey;
      Finder switchControl() => exercise
          ? find.descendant(
              of: find.byKey(const Key('exercise-calories-include-switch')),
              matching: find.byType(Switch),
            )
          : find.byType(Switch);
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
              switchControl().hitTestable().evaluate().isNotEmpty,
          'genuine active Premium and actual $feature control',
        );
        expect(fixtureFailure, isNull);
        final verified = container
            .read(verifiedSubscriptionStateProvider)
            .requireValue;
        expect(verified.authority, EntitlementAuthority.verifiedServer);
        expect(verified.plan, CommercePlan.premium);
        expect(verified.currentPeriodEndsAt, boundary);
        expect(authorityReads, 1);
        expect(tester.widget<Switch>(switchControl()).onChanged, isNotNull);
        await tester.tap(switchControl());
        await _waitUntil(
          tester,
          () =>
              switchControl().evaluate().isNotEmpty &&
              tester.widget<Switch>(switchControl()).value &&
              tester.widget<Switch>(switchControl()).onChanged != null,
          'actual paid gesture persisted and reloaded',
        );
        String? initial;
        await _finishHost(tester, () async {
          initial = await preferences.get(persistedKey);
        });
        expect(initial, 'true');

        // Exercise event ordering: authority reaches its genuine exact cutoff
        // before the next rendering frame removes the previous Switch. This
        // recomputes the existing time view, not a synthetic paid/access state.
        clock = boundary;
        container.invalidate(verifiedSubscriptionAccessProvider);
        final expired = container
            .read(verifiedSubscriptionAccessProvider)
            .requireValue;
        expect(expired.plan, CommercePlan.free);
        expect(expired.lifecycle, SubscriptionLifecycle.expired);
        expect(
          container.read(verifiedSubscriptionStateProvider).requireValue.plan,
          CommercePlan.premium,
        );
        expect(authorityReads, 1);
        expect(switchControl().hitTestable(), findsOneWidget);
        await tester.tap(switchControl());
        String? persisted;
        await _finishHost(tester, () async {
          persisted = await preferences.get(persistedKey);
        });
        expect(
          persisted,
          'true',
          reason:
              'Actual expired $feature gesture cannot change local preferences',
        );
        await tester.pump();
        expect(switchControl().hitTestable(), findsNothing);
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
    });
  }
}

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
  }
  expect(ready(), isTrue, reason: 'Real settings stage did not finish: $stage');
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
