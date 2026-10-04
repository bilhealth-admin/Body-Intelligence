// Explicit opt-in, genuine Production Auth/RPC + production gate/widgets.
// Not part of portable tests. No credentials are persisted or printed.
// Root executes serially with BIL_REVIEWER_* environment variables supplied
// privately. This is HOST_WIDGET_NOT_NATIVE_TRANSACTION, not StoreKit/Play.
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/analytics/nutrition_analytics_page.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:body_intelligence_log/features/daily_log/providers/daily_log_provider.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _productionHost = 'tgmanzhqulksykhslrzb.supabase.co';
const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

// Inherits Dart's real native HttpClient factory, not Flutter test's 400 stub.
// https://api.dart.dev/dart-io/HttpOverrides/createHttpClient.html
final class _HostNetwork extends HttpOverrides {}

final class _ProductionOnlyClient extends http.BaseClient {
  _ProductionOnlyClient(this.inner);
  final http.Client inner;
  final Set<String> requests = {};
  int started = 0;
  int completed = 0;
  int inFlight = 0;
  int activityRevision = 0;
  int sendErrors = 0;
  int bodyErrors = 0;
  int cancelledBodies = 0;
  int httpErrors = 0;
  int rejectedRequests = 0;
  int requestsAfterClose = 0;
  bool _closed = false;

  Map<String, int> get completionEvidence => {
    'started': started,
    'completed': completed,
    'in_flight': inFlight,
    'send_errors': sendErrors,
    'body_errors': bodyErrors,
    'cancelled_bodies': cancelledBodies,
    'http_errors': httpErrors,
    'rejected_requests': rejectedRequests,
    'requests_after_close': requestsAfterClose,
  };
  static const _readRpc = {
    '/rest/v1/rpc/bil_get_my_admin_subscription',
    '/rest/v1/rpc/bil_get_ai_usage_status',
    '/rest/v1/rpc/bil_get_remote_ai_consent',
    '/rest/v1/rpc/bil_gold_balance_v1',
  };
  static const _ownRead = {
    '/rest/v1/bil_subscriptions',
    '/rest/v1/bil_ai_closed_test_grants',
    '/rest/v1/bil_coach_memories',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final method = request.method;
    final path = uri.path;
    final permitted =
        (method == 'POST' &&
            (path == '/auth/v1/token' ||
                path == '/auth/v1/logout' ||
                _readRpc.contains(path))) ||
        (method == 'GET' &&
            (path == '/auth/v1/user' || _ownRead.contains(path)));
    if (uri.scheme != 'https' ||
        uri.host != _productionHost ||
        uri.port != 443 ||
        !permitted ||
        (path == '/auth/v1/token' &&
            uri.queryParameters['grant_type'] != 'password') ||
        (_ownRead.contains(path) &&
            uri.queryParameters['owner_id'] !=
                'eq.${_required('BIL_REVIEWER_EXPECTED_OWNER')}')) {
      rejectedRequests++;
      throw StateError('Non-allowlisted reviewer host request refused');
    }
    request.followRedirects = false;
    requests.add('$method $path');
    started++;
    inFlight++;
    activityRevision++;
    if (_closed) requestsAfterClose++;
    try {
      final response = await inner.send(request);
      if (response.statusCode >= 400) httpErrors++;
      // Completion means the genuine full response body has finished, not
      // merely that response headers arrived. Preserve all transport metadata.
      return http.StreamedResponse(
        _trackBody(response.stream),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on Object {
      sendErrors++;
      _finishRequest();
      rethrow;
    }
  }

  Stream<List<int>> _trackBody(Stream<List<int>> source) async* {
    var reachedEnd = false;
    var failed = false;
    try {
      yield* source;
      reachedEnd = true;
    } on Object {
      failed = true;
      bodyErrors++;
      rethrow;
    } finally {
      if (!reachedEnd && !failed) cancelledBodies++;
      _finishRequest();
    }
  }

  void _finishRequest() {
    completed++;
    inFlight--;
    activityRevision++;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    inner.close();
  }
}

String _required(String name) {
  final raw = Platform.environment[name];
  if (raw == null || raw.trim().isEmpty) {
    throw StateError('Private environment variable missing: $name');
  }
  return name == 'BIL_REVIEWER_PASSWORD' ? raw : raw.trim();
}

Future<T> _live<T>(String boundary, Future<T> Function() action) async {
  try {
    return await action().timeout(const Duration(seconds: 40));
  } on Object catch (error) {
    // Do not surface Auth/HTTP response bodies or token-bearing objects.
    throw StateError(
      '$boundary failed (${error.runtimeType}); details redacted',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'ordinary reviewer login unlocks real paid route widgets',
    (tester) async {
      if (_required('BIL_REVIEWER_HOST_LIVE') != '1') {
        throw StateError('Explicit live reviewer opt-in required');
      }
      final kind = _required('BIL_REVIEWER_KIND');
      final authority = _required('BIL_REVIEWER_AUTHORITY');
      final owner = _required('BIL_REVIEWER_EXPECTED_OWNER');
      final expectedPlan = _required('BIL_REVIEWER_EXPECTED_PLAN');
      final expectedCredits = int.parse(
        _required('BIL_REVIEWER_EXPECTED_CREDITS'),
      );
      final expectedClosedGrant = _required(
        'BIL_REVIEWER_EXPECTED_CLOSED_TEST_ACTIVE',
      );
      if (!{'google', 'apple'}.contains(kind) ||
          !{'admin', 'store'}.contains(authority) ||
          !{'premium', 'premium_ai_coach'}.contains(expectedPlan) ||
          !{'true', 'false'}.contains(expectedClosedGrant) ||
          expectedCredits <= 0 ||
          AppEnvironment.supabaseUrl != 'https://$_productionHost' ||
          !AppEnvironment.supabaseAnonKey.startsWith('sb_publishable_')) {
        throw StateError('Reviewer target/authority expectations invalid');
      }
      final previousPreferenceStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance =
          InMemorySharedPreferencesStore.empty();
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = previousPreferenceStore,
      );
      final secureValues = <String, String>{};
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _secureChannel,
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
            case 'containsKey':
              return secureValues.containsKey(key);
            default:
              throw StateError('Unexpected secure-storage host operation');
          }
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('bil/tts'),
        (call) async {
          if (call.method != 'stop') {
            throw StateError('Host test does not exercise native voice');
          }
          return null;
        },
      );
      final network = HttpOverrides.runWithHttpOverrides(
        () => _ProductionOnlyClient(
          IOClient(
            HttpClient()..connectionTimeout = const Duration(seconds: 10),
          ),
        ),
        _HostNetwork(),
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        // Only host-local SQLite is substituted. ALL entitlement/credit/owner
        // providers and ServerEntitlementRepository remain production defaults.
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      final router = GoRouter(
        initialLocation: '/intelligence-center',
        routes: [
          GoRoute(
            path: '/intelligence-center',
            builder: (_, _) => const PremiumRouteGlassGate(
              feature: PremiumGateFeature.aiCoach,
              child: IntelligenceCenterPage(),
            ),
          ),
          GoRoute(
            path: '/analytics/nutrition',
            builder: (_, _) => const PremiumRouteGlassGate(
              feature: PremiumGateFeature.nutritionAnalytics,
              child: NutritionAnalyticsPage(),
            ),
          ),
        ],
      );
      var supabaseInitialized = false;
      var cleanedUp = false;
      Future<void> drainNetwork(String phase) async {
        stdout.writeln('HOST_CLEANUP_BEGIN:$phase');
        // Locked PostgREST 2.8.0 retries GET/HEAD at most three times with
        // 1s, 2s, 4s backoff. Observe a full >7s fake-scheduler quiet window,
        // alongside real I/O, without changing SDK retries or advancing the
        // disposed 5-minute paid-entitlement refresh timer.
        const frame = Duration(milliseconds: 100);
        const retryQuietWindow = Duration(seconds: 8);
        var quiet = Duration.zero;
        var lastRevision = network.activityRevision;
        final elapsed = Stopwatch()..start();
        while (elapsed.elapsedMilliseconds < 5000) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(frame);
          if (network.inFlight == 0 &&
              lastRevision == network.activityRevision) {
            quiet += frame;
          } else {
            quiet = Duration.zero;
          }
          lastRevision = network.activityRevision;
          if (quiet >= retryQuietWindow) {
            stdout.writeln(
              jsonEncode({
                'diagnostic': phase,
                'http_completion': network.completionEvidence,
              }),
            );
            expect(network.inFlight, 0, reason: 'Full HTTP bodies must finish');
            expect(network.completed, network.started);
            expect(network.sendErrors, 0, reason: 'Genuine HTTP send failures');
            expect(network.bodyErrors, 0, reason: 'Genuine HTTP body failures');
            expect(
              network.cancelledBodies,
              0,
              reason: 'Full bodies, not cancels',
            );
            expect(
              network.httpErrors,
              0,
              reason: 'Actual HTTP error responses',
            );
            expect(network.rejectedRequests, 0);
            expect(
              network.requestsAfterClose,
              0,
              reason: 'No owner reads may survive transport disposal',
            );
            expect(tester.takeException(), isNull);
            stdout.writeln('HOST_CLEANUP_END:$phase');
            return;
          }
        }
        stdout.writeln(
          jsonEncode({
            'diagnostic': phase,
            'http_completion': network.completionEvidence,
          }),
        );
        throw StateError('Host HTTP completion did not settle: $phase');
      }

      Future<void> finishCleanup(
        String phase,
        Future<void> Function() action,
      ) async {
        stdout.writeln('HOST_CLEANUP_BEGIN:$phase');
        var completed = false;
        Object? failure;
        StackTrace? failureStack;
        // Start exactly one genuine operation in the real-I/O zone, but do
        // not await it there: existing Drift/stream callbacks can belong to
        // Flutter's fake scheduler and require a frame to complete disposal.
        await tester.runAsync(() async {
          Future<void>.sync(action).then<void>(
            (_) {
              completed = true;
            },
            onError: (Object error, StackTrace stack) {
              failure = error;
              failureStack = stack;
              completed = true;
            },
          );
        });
        final elapsed = Stopwatch()..start();
        while (!completed && elapsed.elapsedMilliseconds < 5000) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        if (!completed) {
          throw StateError('Host cleanup did not complete: $phase');
        }
        if (failure != null) {
          Error.throwWithStackTrace(failure!, failureStack!);
        }
        stdout.writeln('HOST_CLEANUP_END:$phase');
      }

      Future<void> cleanup() async {
        if (cleanedUp) return;
        cleanedUp = true;
        // addTearDown runs AFTER Flutter's pending-timer invariant. Dispose the
        // genuine provider lifecycle here, before the test body can return.
        // In particular this cancels the real paid-access refresh timer.
        try {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        } finally {
          container.dispose();
          router.dispose();
          try {
            try {
              try {
                // Let already-started genuine owner reads and their logical
                // SDK continuations finish with Auth/transport/SQLite alive.
                await drainNetwork('OWNER_READS_BEFORE_LOGOUT');
              } finally {
                await finishCleanup('SQLITE_CLOSE', database.close);
              }
            } finally {
              if (supabaseInitialized) {
                try {
                  await finishCleanup(
                    'LOCAL_SESSION_LOGOUT',
                    () => Supabase.instance.client.auth.signOut(
                      scope: SignOutScope.local,
                    ),
                  );
                } finally {
                  await finishCleanup(
                    'SUPABASE_DISPOSE',
                    Supabase.instance.dispose,
                  );
                }
              }
            }
          } finally {
            network.close();
            try {
              // Any late cancellation/backoff must finish under the SDK's
              // genuine finite retry contract and still pass strict counters.
              await drainNetwork('HTTP_AFTER_DISPOSE');
            } finally {
              SharedPreferencesStorePlatform.instance = previousPreferenceStore;
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                _secureChannel,
                null,
              );
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                const MethodChannel('bil/tts'),
                null,
              );
              await tester.binding.setSurfaceSize(null);
            }
          }
        }
      }

      addTearDown(
        cleanup,
      ); // Idempotent emergency fallback, not primary cleanup.
      try {
        await tester.runAsync(() async {
          await _live(
            'Supabase initialization',
            () => Supabase.initialize(
              url: AppEnvironment.supabaseUrl,
              publishableKey: AppEnvironment.supabaseAnonKey,
              debug: false,
              httpClient: network,
              authOptions: const FlutterAuthClientOptions(
                autoRefreshToken: false,
                detectSessionInUri: false,
                localStorage: EmptyLocalStorage(),
              ),
            ),
          );
          supabaseInitialized = true;
        });
        final client = Supabase.instance.client;
        Map<String, dynamic>? usage;
        String? storeProvider;
        String? storePlan;
        var verifiedStoreActive = false;
        var closedGrantActive = false;
        await tester.runAsync(() async {
          final response = await _live(
            'Ordinary password authentication',
            () => client.auth.signInWithPassword(
              email: _required('BIL_REVIEWER_EMAIL'),
              password: _required('BIL_REVIEWER_PASSWORD'),
            ),
          );
          expect(
            response.user?.id == owner,
            isTrue,
            reason: 'Expected owner identity',
          );
          final serverUser = await _live(
            'Server user validation',
            client.auth.getUser,
          );
          expect(serverUser.user?.id == owner, isTrue);
          final session = client.auth.currentSession;
          expect(session != null, isTrue);
          final claims =
              jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(session!.accessToken.split('.')[1]),
                      ),
                    ),
                  )
                  as Map;
          expect(
            claims['role'] == 'authenticated' && claims['sub'] == owner,
            isTrue,
          );
          final grants = await _live(
            'Closed-test grant read',
            () => client
                .from('bil_ai_closed_test_grants')
                .select('active,expires_at')
                .eq('owner_id', owner)
                .limit(1),
          );
          closedGrantActive = grants.any(
            (row) =>
                row['active'] == true &&
                (DateTime.tryParse(
                      '${row['expires_at']}',
                    )?.isAfter(DateTime.now().toUtc()) ??
                    false),
          );
          expect(
            closedGrantActive,
            expectedClosedGrant == 'true',
            reason:
                'Actual pre-existing closed-test overlay is separately accounted',
          );
          final rows = await _live(
            'Verified store ledger read',
            () => client
                .from('bil_subscriptions')
                .select('provider,plan_id,lifecycle,verified_at,expires_at')
                .eq('owner_id', owner)
                .limit(1),
          );
          if (rows.isNotEmpty) {
            final row = rows.single;
            storeProvider = row['provider'] as String?;
            storePlan = row['plan_id'] as String?;
            verifiedStoreActive =
                {'apple', 'google'}.contains(storeProvider) &&
                isAcceptableServerVerificationTimestamp(
                  verifiedAt: DateTime.tryParse('${row['verified_at']}'),
                  now: DateTime.now().toUtc(),
                ) &&
                row['lifecycle'] == 'active' &&
                (DateTime.tryParse(
                      '${row['expires_at']}',
                    )?.isAfter(DateTime.now().toUtc()) ??
                    false);
          }
          final lease = await _live(
            'Admin lease read',
            () => client.rpc('bil_get_my_admin_subscription'),
          );
          if (authority == 'admin') {
            expect(
              verifiedStoreActive,
              isFalse,
              reason:
                  'Official admin gift must not be reported as a verified store purchase',
            );
            expect(
              lease is Map &&
                  lease['owner_id'] == owner &&
                  lease['plan_id'] == expectedPlan &&
                  (DateTime.tryParse(
                        '${lease['access_until']}',
                      )?.isAfter(DateTime.now().toUtc()) ??
                      false),
              isTrue,
              reason: 'Actual owner-bound server admin lease',
            );
          } else {
            expect(
              lease == null || (lease is Map && lease.isEmpty),
              isTrue,
              reason: 'Store reviewer must not resolve via an admin grant',
            );
            expect(
              verifiedStoreActive,
              isTrue,
              reason: 'Genuine pre-existing verified active store ledger',
            );
            expect(rows.length, 1);
            final row = rows.single;
            storeProvider = row['provider'] as String?;
            storePlan = row['plan_id'] as String?;
            expect({'apple', 'google'}.contains(storeProvider), isTrue);
            final expectedProvider =
                Platform.environment['BIL_REVIEWER_EXPECTED_PROVIDER'];
            if (expectedProvider?.isNotEmpty ?? false) {
              expect(storeProvider, expectedProvider);
            }
            expect(storePlan, _required('BIL_REVIEWER_EXPECTED_STORE_PLAN'));
            expect(row['lifecycle'], 'active');
            final verifiedAt = DateTime.tryParse('${row['verified_at']}');
            expect(
              isAcceptableServerVerificationTimestamp(
                verifiedAt: verifiedAt,
                now: DateTime.now().toUtc(),
              ),
              isTrue,
            );
            expect(
              DateTime.tryParse(
                '${row['expires_at']}',
              )?.isAfter(DateTime.now().toUtc()),
              isTrue,
            );
          }
          final value = await _live(
            'Reserved-aware server credit read',
            () => client.rpc('bil_get_ai_usage_status'),
          );
          expect(value is Map, isTrue);
          usage = Map<String, dynamic>.from(value as Map);
          final credits = usage!['credits'];
          expect(
            credits is Map && credits['total_remaining'] == expectedCredits,
            isTrue,
            reason: 'Exact actual reserved-aware credit balance',
          );
        });
        Future<void> pumpApp(
          Locale locale,
          TextScaler scale,
          Brightness brightness,
        ) => tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scale),
                child: child!,
              ),
            ),
          ),
        );
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpApp(
          const Locale('en'),
          TextScaler.noScaling,
          Brightness.light,
        );
        expect(
          find.byKey(const ValueKey('premium-route-glass-veil')),
          findsNothing,
        );
        await tester.runAsync(() async {
          final state = await _live(
            'Production entitlement repository',
            () => container.read(verifiedSubscriptionStateProvider.future),
          );
          expect(state.authority, EntitlementAuthority.verifiedServer);
          expect(state.plan.id, expectedPlan);
          expect(state.plan != CommercePlan.free, isTrue);
          expect(
            state.grants(CommerceEntitlement.advancedIntelligence),
            isTrue,
          );
          expect(
            await _live(
              'Production credit access provider',
              () => container.read(aiCoachCreditAccessProvider.future),
            ),
            isTrue,
          );
        });
        await tester.pump(const Duration(milliseconds: 2400));
        Future<void> waitForControl(
          Finder control, {
          Future<void> Function()? onMissing,
        }) async {
          final elapsed = Stopwatch()..start();
          while (control.evaluate().isEmpty &&
              elapsed.elapsedMilliseconds < 5000) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (control.evaluate().isEmpty && onMissing != null) {
            await onMissing();
          }
          expect(control, findsOneWidget);
        }

        for (final scenario in [
          (const Locale('en'), 1.0, const Size(430, 932), Brightness.light),
          (const Locale('ar'), 2.0, const Size(320, 568), Brightness.dark),
        ]) {
          stdout.writeln(
            'HOST_SCENARIO:${scenario.$1.languageCode}:${scenario.$2}:${scenario.$3.width}x${scenario.$3.height}',
          );
          await tester.binding.setSurfaceSize(scenario.$3);
          router.go('/intelligence-center');
          await pumpApp(
            scenario.$1,
            TextScaler.linear(scenario.$2),
            scenario.$4,
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 2400));
          expect(find.byType(IntelligenceCenterPage), findsOneWidget);
          final field = find.byKey(const Key('ai-coach-question-field'));
          await waitForControl(field.hitTestable());
          expect(field.hitTestable(), findsOneWidget);
          expect(tester.widget<TextField>(field).enabled, isTrue);
          await tester.enterText(
            field,
            scenario.$1.languageCode == 'ar' ? 'مسودة محلية' : 'Local draft',
          );
          expect(
            find.byKey(const ValueKey('premium-route-glass-veil')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('premium-route-access-unavailable')),
            findsNothing,
          );
          router.go('/analytics/nutrition');
          await tester.pump();
          await tester.runAsync(() async {
            await _live(
              'Paid subscription access',
              () => container.read(verifiedSubscriptionStateProvider.future),
            );
          });
          expect(tester.takeException(), isNull);
          Map<String, AsyncValue<Object?>> nutritionDependencies() => {
            'profile': container.read(userProfileProvider),
            'goal': container.read(activeGoalProvider),
            'meals': container.read(dailyMealsProvider),
            'dashboard': container.read(dashboardNutrientDashboardProvider),
            for (final key in [
              'goal.calories',
              'goal.carbsPercent',
              'goal.proteinPercent',
              'goal.fatPercent',
              'goal.sodium',
              'goal.fiber',
              'goal.potassium',
              'goal.sugar',
            ])
              key: container.read(dashboardNutrientGoalProvider(key)),
          };
          // StreamProvider delivery may depend on Flutter's fake scheduler.
          // Waiting its .future inside runAsync starves the required frames;
          // interleave bounded real SQLite I/O time with actual frame pumping.
          final nutritionWait = Stopwatch()..start();
          var dependencyStates = nutritionDependencies();
          while (dependencyStates.values.any((state) => !state.hasValue) &&
              !dependencyStates.values.any((state) => state.hasError) &&
              nutritionWait.elapsedMilliseconds < 5000) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 16));
            dependencyStates = nutritionDependencies();
          }
          stdout.writeln(
            jsonEncode({
              'diagnostic': 'NUTRITION_REAL_LOCAL_DEPENDENCIES',
              'scenario': '${scenario.$1.languageCode}:${scenario.$2}',
              'states': {
                for (final entry in dependencyStates.entries)
                  entry.key: {
                    'ready': entry.value.hasValue,
                    'loading': entry.value.isLoading,
                    'error': entry.value.hasError,
                    'error_type': '${entry.value.error?.runtimeType}',
                  },
              },
            }),
          );
          for (final entry in dependencyStates.entries) {
            expect(
              entry.value.hasError,
              isFalse,
              reason: 'Real local ${entry.key} failed',
            );
            expect(
              entry.value.hasValue,
              isTrue,
              reason: 'Real local ${entry.key} did not resolve',
            );
          }
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(NutritionAnalyticsPage), findsOneWidget);
          final nutritionControl = find.byKey(
            const Key('nutrition-empty-log-food'),
          );
          expect(
            find.byKey(const ValueKey('premium-route-glass-veil')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('premium-route-access-unavailable')),
            findsNothing,
          );
          if (nutritionControl.hitTestable().evaluate().isEmpty &&
              container.read(dailyMealsProvider).hasValue &&
              container
                  .read(dailyMealsProvider)
                  .requireValue
                  .every((meal) => meal.items.isEmpty)) {
            // The production empty-day ListView is lazy. At Arabic 200% on a
            // 320x568 viewport its real CTA can be below even the cache extent.
            // A bounded real user gesture must reveal it; merely constructing a
            // Finder/ensureVisible on an unbuilt child does not prove reachability.
            final list = find.descendant(
              of: find.byType(NutritionAnalyticsPage),
              matching: find.byType(ListView),
            );
            expect(list, findsOneWidget);
            final scrollable = find.descendant(
              of: list,
              matching: find.byType(Scrollable),
            );
            expect(scrollable, findsOneWidget);
            expect(
              tester.widget<Scrollable>(scrollable).axisDirection,
              anyOf(AxisDirection.down, AxisDirection.up),
            );
            await tester.scrollUntilVisible(
              nutritionControl,
              180,
              scrollable: scrollable,
              maxScrolls: 8,
            );
            await tester.pump(const Duration(milliseconds: 100));
            stdout.writeln(
              jsonEncode({
                'diagnostic': 'NUTRITION_REAL_USER_SCROLL',
                'scenario': '${scenario.$1.languageCode}:${scenario.$2}',
                'control_count': nutritionControl.evaluate().length,
                'hit_count': nutritionControl.hitTestable().evaluate().length,
              }),
            );
          }
          // Diagnosis only: keep the original strict hit-testable assertion.
          // A real scrollable off-screen CTA and an absent/loading CTA are
          // materially different. Never print provider data or private errors.
          Future<void> nutritionDiagnostic() async {
            final count = nutritionControl.evaluate().length;
            String stateSummary(AsyncValue<Object?> state) =>
                'loading=${state.isLoading},value=${state.hasValue},error=${state.hasError},type=${state.error?.runtimeType}';
            stdout.writeln(
              jsonEncode({
                'diagnostic': 'NUTRITION_HOST_NO_HIT',
                'scenario': '${scenario.$1.languageCode}:${scenario.$2}',
                'control_count': count,
                'hit_count': nutritionControl.hitTestable().evaluate().length,
                'rect': count == 1
                    ? tester.getRect(nutritionControl).toString()
                    : null,
                'surface': scenario.$3.toString(),
                'gate_veil_count': find
                    .byKey(const ValueKey('premium-route-glass-veil'))
                    .evaluate()
                    .length,
                'gate_unavailable_count': find
                    .byKey(const ValueKey('premium-route-access-unavailable'))
                    .evaluate()
                    .length,
                'gate_access': stateSummary(
                  container.read(verifiedSubscriptionAccessProvider),
                ),
                'profile': stateSummary(container.read(userProfileProvider)),
                'goal': stateSummary(container.read(activeGoalProvider)),
                'meals': stateSummary(container.read(dailyMealsProvider)),
                'dashboard': stateSummary(
                  container.read(dashboardNutrientDashboardProvider),
                ),
                'nutrient_goals': {
                  for (final key in [
                    'goal.calories',
                    'goal.carbsPercent',
                    'goal.proteinPercent',
                    'goal.fatPercent',
                    'goal.sodium',
                    'goal.fiber',
                    'goal.potassium',
                    'goal.sugar',
                  ])
                    key: stateSummary(
                      container.read(dashboardNutrientGoalProvider(key)),
                    ),
                },
              }),
            );
          }

          await waitForControl(
            nutritionControl.hitTestable(),
            onMissing: nutritionDiagnostic,
          );
          expect(
            find.byKey(const ValueKey('premium-route-glass-veil')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('premium-route-access-unavailable')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
        expect(
          network.requests.contains(
            'POST /rest/v1/rpc/bil_get_my_admin_subscription',
          ),
          isTrue,
        );
        expect(
          network.requests.contains(
            'POST /rest/v1/rpc/bil_get_ai_usage_status',
          ),
          isTrue,
        );
        expect(
          network.requests.contains('GET /rest/v1/bil_subscriptions'),
          isTrue,
        );
        stdout.writeln(
          jsonEncode({
            'evidence': 'HOST_WIDGET_NOT_NATIVE_TRANSACTION',
            'reviewer_kind': kind,
            'authority': authority,
            'verified_store_provider': storeProvider,
            'verified_store_plan': storePlan,
            'verified_store_active': verifiedStoreActive,
            'preexisting_closed_test_overlay': closedGrantActive,
            'plan': expectedPlan,
            'credits_total_remaining':
                (usage!['credits'] as Map)['total_remaining'],
            'routes': ['/intelligence-center', '/analytics/nutrition'],
            'scenarios': [
              'en-LTR-100%-430x932-light',
              'ar-RTL-200%-320x568-dark',
            ],
            'seams': [
              'empty secure-storage/sharedprefs',
              'empty local SQLite',
              'native TTS stop',
            ],
            'not_proved': [
              'native login UI',
              'StoreKit/Play transaction',
              'AI ask/consent/provider response',
              'other routes',
              'real device',
            ],
          }),
        );
      } finally {
        await cleanup();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
