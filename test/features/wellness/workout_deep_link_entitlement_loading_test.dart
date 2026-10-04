// Real release-approved workout metadata/assets, the default server repository,
// access providers and route widgets. Only owner Auth/HTTP, secure storage and
// an empty host packs directory are fixtures. Not Production/native billing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/domain/workout_free_preview_policy.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
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
  late Directory packs;
  late HttpClient catalogClient;
  late WellnessContentPackManager manager;
  late WellnessMediaCache mediaCache;
  late WellnessContentItem workout;
  var ownerSequence = 0;
  setUpAll(() async {
    packs = await Directory.systemTemp.createTemp('bil-workout-route-');
    catalogClient = HttpClient();
    mediaCache = WellnessMediaCache(
      directory: Directory('${packs.path}/media'),
    );
    manager = WellnessContentPackManager(
      client: catalogClient,
      packsDirectory: packs,
      mediaCache: mediaCache,
    );
    final items = await manager.loadWorkoutLibraryItems(locale: 'en');
    workout = items.firstWhere(
      (item) => !WorkoutFreePreviewPolicy.isPreview(item),
    );
    expect(workout.minimumAccess, WellnessContentAccess.pro);
    expect(workout.verified, isTrue);
    expect(workout.releaseKey, isNotNull);
  });
  tearDownAll(() async {
    mediaCache.dispose();
    catalogClient.close(force: true);
    // This is only the unique directory this fixture created, never a user
    // packs directory, workspace, or broad system temporary directory.
    expect(packs.parent.absolute.path, Directory.systemTemp.absolute.path);
    expect(
      packs.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      startsWith('bil-workout-route-'),
    );
    await packs.delete(recursive: true);
  });

  for (final scenario in [
    (CommercePlan.premiumAiCoach, '/wellness/workouts'),
    (CommercePlan.free, '/wellness/workouts/routines'),
  ]) {
    final (plan, route) = scenario;
    testWidgets('$plan genuine workout deep link waits before Plans', (
      tester,
    ) async {
      // Do not reuse a Future cached by the previous widget test's fake async
      // zone. Each route still loads and verifies the genuine bundled assets.
      rootBundle.clear();
      final owner =
          '00000000-0000-4000-8001-${(++ownerSequence).toString().padLeft(12, '0')}';
      final releaseLookup = Completer<void>();
      var lookupStarted = false;
      var lookupFinished = false;
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
          expectSync(request.url.host, 'workout-fixture.invalid');
          expectSync(
            request.headers['authorization'],
            'Bearer workout-fixture-token',
          );
          final now = DateTime.now().toUtc();
          Object? response;
          switch (request.url.path) {
            case '/rest/v1/bil_ai_closed_test_grants':
              expectSync(request.url.queryParameters['owner_id'], 'eq.$owner');
              lookupStarted = true;
              await releaseLookup.future;
              response = <Object?>[];
            case '/rest/v1/bil_subscriptions':
              expectSync(request.url.queryParameters['owner_id'], 'eq.$owner');
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
        } on Object catch (error) {
          fixtureFailure = error;
          rethrow;
        }
      });
      await tester.runAsync(() async {
        await Supabase.initialize(
          url: 'https://workout-fixture.invalid',
          publishableKey: 'workout-fixture-publishable-key',
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
            'access_token': 'workout-fixture-token',
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
      String? plansFocus;
      final router = GoRouter(
        initialLocation:
            '$route?item=${Uri.encodeQueryComponent(workout.stableId)}',
        routes: [
          for (final path in [
            '/wellness/workouts',
            '/wellness/workouts/routines',
          ])
            GoRoute(
              path: path,
              builder: (_, state) => BilWorkoutRoutinesPage(
                manager: manager,
                mediaCache: mediaCache,
                offline: true,
                initialItemId: state.uri.queryParameters['item'],
              ),
            ),
          GoRoute(
            path: '/plans',
            builder: (_, state) {
              plansVisits++;
              plansFocus = state.uri.queryParameters['focus'];
              return BilStorePlansPage(
                connectToDeviceStore: false,
                initialFocus: plansFocus,
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
              (find
                      .byKey(const ValueKey('workout-library-tab-0'))
                      .evaluate()
                      .isNotEmpty ||
                  plansVisits > 0),
          'real library and held owner lookup',
          diagnostics: () =>
              'lookupStarted=$lookupStarted; lookupFinished=$lookupFinished; '
              'failure=$fixtureFailure; plans=$plansVisits; '
              'library=${find.byKey(const ValueKey('workout-library-tab-0')).evaluate().length}; '
              'catalogBuilders=${find.byType(FutureBuilder<List<WellnessContentItem>>).evaluate().length}; '
              'gymBuilders=${tester.allWidgets.where((w) => w.runtimeType.toString().startsWith('FutureBuilder<GymSixMonthPlan')).length}; '
              'subscription=${container.read(verifiedSubscriptionStateProvider)}; '
              'texts=${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).take(12).toList()}',
        );
        expect(fixtureFailure, isNull);
        // The next frame must process the catalog's real post-frame item action.
        await tester.pump(const Duration(milliseconds: 16));
        expect(lookupFinished, isFalse);
        expect(
          container.read(verifiedSubscriptionStateProvider).isLoading,
          isTrue,
        );
        expect(
          plansVisits,
          0,
          reason:
              'A genuine paid item cannot infer verified Free while authority is pending',
        );
        expect(find.byType(BilStorePlansPage), findsNothing);
        expect(find.byKey(const ValueKey('log-workout-cta')), findsNothing);
        expect(
          find.byKey(const ValueKey('details-save-routine')),
          findsNothing,
        );
        releaseLookup.complete();
        await _waitUntil(
          tester,
          () =>
              lookupFinished &&
              container.read(verifiedSubscriptionStateProvider).hasValue &&
              (plan == CommercePlan.free
                  ? find.byType(BilStorePlansPage).evaluate().isNotEmpty
                  : find
                        .byType(BilWorkoutRoutineDetailsPage)
                        .evaluate()
                        .isNotEmpty),
          'resolved actual paid or Free item destination',
        );
        final state = container
            .read(verifiedSubscriptionStateProvider)
            .requireValue;
        expect(state.authority, EntitlementAuthority.verifiedServer);
        expect(state.plan, plan);
        if (plan == CommercePlan.free) {
          expect(plansVisits, greaterThan(0));
          expect(plansFocus, 'subscription');
          expect(find.byKey(const ValueKey('log-workout-cta')), findsNothing);
        } else {
          expect(plansVisits, 0);
          expect(find.byType(BilStorePlansPage), findsNothing);
          expect(find.byType(BilWorkoutRoutineDetailsPage), findsOneWidget);
          expect(find.byKey(const ValueKey('log-workout-cta')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('details-save-routine')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('unlock-workout-cta')),
            findsNothing,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('log-workout-cta')),
                )
                .onPressed,
            isNotNull,
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        if (!releaseLookup.isCompleted) releaseLookup.complete();
        await _waitUntil(
          tester,
          () => !lookupStarted || lookupFinished,
          'held owner read completed before cleanup',
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
    });
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
        'Genuine route stage did not finish: $stage; ${diagnostics?.call() ?? ''}',
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
  expect(complete, isTrue, reason: 'Genuine host cleanup did not finish');
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}
