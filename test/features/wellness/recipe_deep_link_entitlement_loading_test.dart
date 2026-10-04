// Real recipe assets, server repository, access providers and route widgets.
// Only Auth/HTTP and host secure storage are fixtures: this is not evidence of
// a genuine store transaction or current Production reviewer access.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
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
  late RecipeReleaseRepository recipes;
  late RecipeCatalogSummary recipe;
  var ownerSequence = 0;
  setUpAll(() async {
    recipes = RecipeReleaseRepository();
    final index = await recipes.loadIndex();
    recipe = index.singleWhere((entry) => entry.id == 'shakshuka');
    await recipes.loadDetail(recipe);
    await recipes.loadCardFacts(recipe.id);
  });

  for (final plan in [CommercePlan.premium, CommercePlan.free]) {
    testWidgets(
      '$plan recipe deep link waits for authoritative access without Plans',
      (tester) async {
        final owner =
            '00000000-0000-4000-8000-${(++ownerSequence).toString().padLeft(12, '0')}';
        var releaseLookup = Completer<void>();
        var lookupStarted = false;
        var lookupFinished = false;
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
          expect(request.url.host, 'recipe-fixture.invalid');
          expect(
            request.headers['authorization'],
            'Bearer recipe-fixture-token',
          );
          final now = DateTime.now().toUtc();
          Object? response;
          switch (request.url.path) {
            case '/rest/v1/bil_ai_closed_test_grants':
              expect(request.url.queryParameters['owner_id'], 'eq.$owner');
              lookupStarted = true;
              await releaseLookup.future;
              response = <Object?>[];
            case '/rest/v1/bil_subscriptions':
              expect(request.url.queryParameters['owner_id'], 'eq.$owner');
              response = [
                {
                  'owner_id': owner,
                  'provider': 'google',
                  'plan_id': plan.id,
                  'lifecycle': plan == CommercePlan.free
                      ? 'inactive'
                      : 'active',
                  'started_at': now
                      .subtract(const Duration(days: 1))
                      .toIso8601String(),
                  'expires_at': now
                      .add(const Duration(days: 7))
                      .toIso8601String(),
                  'verified_at': now.toIso8601String(),
                },
              ];
            case '/rest/v1/rpc/bil_get_my_admin_subscription':
              response = null;
              lookupFinished = true;
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
        });
        // Plugin initialization owns genuine asynchronous host work. Await it
        // outside Flutter's fake clock rather than starving required callbacks.
        await tester.runAsync(() async {
          await Supabase.initialize(
            url: 'https://recipe-fixture.invalid',
            publishableKey: 'recipe-fixture-publishable-key',
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
              'access_token': 'recipe-fixture-token',
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
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(database)],
        );
        var plansVisits = 0;
        final router = GoRouter(
          initialLocation: '/wellness/recipes?recipe=${recipe.id}',
          routes: [
            GoRoute(
              path: '/wellness/recipes',
              builder: (_, state) => RecipeLibraryPage(
                repository: recipes,
                remoteImageDeliveryEnabled: false,
                initialRecipeId: state.uri.queryParameters['recipe'],
              ),
            ),
            GoRoute(
              path: '/plans',
              builder: (_, state) {
                plansVisits++;
                return BilStorePlansPage(
                  connectToDeviceStore: false,
                  initialFocus: state.uri.queryParameters['focus'],
                );
              },
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
                lookupStarted &&
                find
                        .byKey(const ValueKey('recipe-detail-access-gate'))
                        .evaluate()
                        .length ==
                    1,
            'initial repository lookup and real detail gate',
          );
          expect(lookupStarted, isTrue);
          expect(lookupFinished, isFalse);
          expect(
            container.read(verifiedSubscriptionStateProvider).isLoading,
            isTrue,
          );
          expect(
            plansVisits,
            0,
            reason: 'Unresolved access is not verified Free',
          );
          expect(find.byType(BilStorePlansPage), findsNothing);
          expect(
            find.byKey(const ValueKey('recipe-detail-access-gate')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('recipe-detail-access-gate')),
              matching: find.byType(ListView),
            ),
            findsNothing,
            reason: 'Unresolved authority must not mount recipe detail content',
          );
          expect(
            find.byKey(const ValueKey('premium-route-glass-veil')),
            findsNothing,
          );
          final initialLibraryState = tester.state(
            find.byType(RecipeLibraryPage),
          );
          releaseLookup.complete();
          await _waitUntil(
            tester,
            () =>
                lookupFinished &&
                container.read(verifiedSubscriptionStateProvider).hasValue &&
                _detailResolved(plan),
            'resolved authoritative initial detail',
          );
          final subscription = container.read(
            verifiedSubscriptionStateProvider,
          );
          expect(subscription.hasValue, isTrue);
          expect(
            subscription.requireValue.authority,
            EntitlementAuthority.verifiedServer,
          );
          expect(subscription.requireValue.plan, plan);
          expect(lookupFinished, isTrue);
          expect(plansVisits, 0);
          expect(find.byType(BilStorePlansPage), findsNothing);
          expect(
            find.byKey(const ValueKey('recipe-detail-access-gate')),
            findsOneWidget,
          );
          if (plan == CommercePlan.free) {
            expect(
              find.byKey(const ValueKey('premium-route-glass-veil')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('premium-route-protected-content')),
              findsOneWidget,
            );
          } else {
            expect(
              find.byKey(const ValueKey('premium-route-glass-veil')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('premium-route-protected-content')),
              findsNothing,
            );
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('recipe-detail-access-gate')),
                matching: find.byType(ListView),
              ),
              findsOneWidget,
              reason:
                  'Real verified recipe content must appear, not only a shell',
            );
          }
          // Leave and re-enter the real route during an actual repository
          // refresh. Neither prior paid nor Free state may skip the fresh gate.
          final detail = find.byKey(
            const ValueKey('recipe-detail-access-gate'),
          );
          Navigator.of(tester.element(detail)).pop();
          await _waitUntil(
            tester,
            () => detail.evaluate().isEmpty,
            'detail route closed',
          );
          releaseLookup = Completer<void>();
          lookupStarted = false;
          lookupFinished = false;
          container.invalidate(verifiedSubscriptionStateProvider);
          // A FutureProvider invalidation is lazy once the detail observer has
          // gone. Start its genuine default repository future explicitly.
          final refresh = container.read(
            verifiedSubscriptionStateProvider.future,
          );
          await _waitUntil(
            tester,
            () => lookupStarted,
            'fresh repository lookup',
          );
          expect(lookupStarted, isTrue);
          expect(lookupFinished, isFalse);
          router.go('/plans');
          await _waitUntil(
            tester,
            () =>
                find.byType(BilStorePlansPage).evaluate().length == 1 &&
                !initialLibraryState.mounted,
            'intentional real Plans route and old library disposal',
          );
          final intentionalPlansVisits = plansVisits;
          expect(intentionalPlansVisits, greaterThan(0));
          router.go('/wellness/recipes?recipe=${recipe.id}');
          await _waitUntil(
            tester,
            () =>
                detail.evaluate().length == 1 &&
                find.byType(BilStorePlansPage).evaluate().isEmpty,
            'real recipe route re-entry',
          );
          expect(
            container.read(verifiedSubscriptionStateProvider).isLoading,
            isTrue,
          );
          expect(plansVisits, intentionalPlansVisits);
          expect(detail, findsOneWidget);
          expect(find.byType(BilStorePlansPage), findsNothing);
          expect(
            find.byKey(const ValueKey('premium-route-glass-veil')),
            findsNothing,
          );
          releaseLookup.complete();
          await _waitUntil(
            tester,
            () =>
                lookupFinished &&
                container.read(verifiedSubscriptionStateProvider).hasValue &&
                _detailResolved(plan),
            'resolved authoritative re-entry detail',
          );
          expect((await refresh).plan, plan);
          expect(
            container.read(verifiedSubscriptionStateProvider).requireValue.plan,
            plan,
          );
          expect(lookupFinished, isTrue);
          expect(plansVisits, intentionalPlansVisits);
          expect(detail, findsOneWidget);
          expect(
            find.byKey(const ValueKey('premium-route-glass-veil')),
            plan == CommercePlan.free ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        } finally {
          if (!releaseLookup.isCompleted) releaseLookup.complete();
          await _waitUntil(
            tester,
            () => !lookupStarted || lookupFinished,
            'outstanding owner lookup completed before disposal',
          );
          await tester.pumpWidget(const SizedBox.shrink());
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

bool _detailResolved(CommercePlan plan) {
  final detail = find.byKey(const ValueKey('recipe-detail-access-gate'));
  if (detail.evaluate().length != 1) return false;
  if (plan == CommercePlan.free) {
    return find
            .byKey(const ValueKey('premium-route-glass-veil'))
            .evaluate()
            .length ==
        1;
  }
  return find
          .descendant(of: detail, matching: find.byType(ListView))
          .evaluate()
          .length ==
      1;
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
  expect(ready(), isTrue, reason: 'Genuine route stage did not finish: $stage');
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
  expect(complete, isTrue, reason: 'Genuine host cleanup did not finish');
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}
