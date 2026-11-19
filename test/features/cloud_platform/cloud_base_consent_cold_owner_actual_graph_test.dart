// Real singleton SDK / cloud providers / consent repository / Privacy page.
// Synthetic HTTP/Auth and SQLite only. No availability, owner, repository or
// readiness override. The Keep Local case permits one synthetic false choice;
// no consent grant, sync activation or production access is permitted.
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_sync_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_sync_consent_notice.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_sync_consent_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/settings/sharing_privacy_settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '00000000-0000-4000-8047-000000000001';
const _ownerB = '00000000-0000-4000-8047-000000000002';
const _host = 'base-consent-cold-owner.invalid';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerKeepLocalFirstUseProbe();

  testWidgets(
    'cold signed owner and actual Privacy converge from loading to available',
    (tester) async {
      final f = await _Fixture.open(tester, owner: _ownerA);
      try {
        await f.mount(tester);
        f.expectAvailable(tester, _ownerA);
        expect(
          f.samples.any((s) => s['owner_loading'] == true),
          isTrue,
          reason:
              'The cold production StreamProvider must actually be observed.',
        );
        final reads = f.baseReads.length;
        expect(reads, greaterThan(0));
        await tester.pump(const Duration(minutes: 3));
        await f.drain(tester);
        f.expectAvailable(tester, _ownerA);
        expect(
          f.baseReads.length,
          reads,
          reason: 'No consent polling or fake invalidation.',
        );
        expect(f.writes, isEmpty);
        expect(f.fixtureErrors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'real guest to signed owner and isolated base-consumer autoDispose reopen re-read typed false receipt',
    (tester) async {
      final f = await _Fixture.open(tester);
      try {
        await f.mount(tester, withPrivacyPage: false);
        expect(f.current.availability, CloudSyncConsentAvailability.signedOut);
        expect(f.baseReads, isEmpty);
        await tester.runAsync(() => f.signIn(_ownerA));
        await f.drain(tester);
        f.expectAvailable(tester, _ownerA, withPrivacyPage: false);
        final previousReads = f.baseReads.length;
        // Keep the production Flutter vsync attached while removing only the
        // consumer. Dropping UncontrolledProviderScope cancels its pending
        // dispose microtask in Flutter Riverpod3.3.2 provider_scope.dart:344-358,
        // 417-427; zero-duration pump alone does not prove disposal completed.
        await f.hideConsumer(tester);
        await f.container.pump();
        expect(
          f.container.read(cloudSyncConsentStateProvider.exists),
          isFalse,
          reason:
              'Do not retain a hidden test subscription across autoDispose.',
        );
        expect(f.container.read(cloudAuthOwnerIdProvider.exists), isFalse);
        await f.mount(tester, withPrivacyPage: false);
        f.expectAvailable(tester, _ownerA, withPrivacyPage: false);
        expect(f.baseReads.length, greaterThan(previousReads));
        expect(f.writes, isEmpty);
        expect(f.fixtureErrors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await f.close(tester);
      }
    },
  );

  for (final aba in [false, true]) {
    testWidgets(
      'held retired read cannot grant after real auth ${aba ? 'A B A' : 'A B'} rebind',
      (tester) async {
        final f = await _Fixture.open(tester, owner: _ownerA);
        f.holdNextA = true;
        try {
          await f.mount(tester, expectSettled: false);
          expect(
            f.heldRequest,
            isNotNull,
            reason: 'Actual production consent read must be in flight.',
          );
          final heldCount = f.baseReads.length;
          await tester.runAsync(() => f.signIn(_ownerB));
          await f.drain(tester);
          f.expectAvailable(tester, _ownerB);
          final expected = aba ? _ownerA : _ownerB;
          if (aba) {
            await tester.runAsync(() => f.signIn(_ownerA));
            await f.drain(tester);
            f.expectAvailable(tester, _ownerA);
          }
          expect(f.baseReads.length, greaterThan(heldCount));
          final freshReads = f.baseReads.length;
          // A hostile stale result is intentionally true, while all fresh reads
          // return false. This proves retirement, rather than equal-value luck.
          f.completeHeld(granted: true);
          await f.drain(tester);
          f.expectAvailable(tester, expected);
          expect(
            f.baseReads.length,
            freshReads,
            reason: 'Completing a stale generation cannot trigger a new poll.',
          );
          final afterRetirement = f.samples
              .skip(f.retirementSampleIndex)
              .toList();
          expect(
            afterRetirement.where((s) => s['granted'] == true),
            isEmpty,
            reason:
                'No frame or provider generation may publish the retired grant.',
          );
          expect(f.writes, isEmpty);
          expect(f.fixtureErrors, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          if (f.heldRequest != null && !f.held.isCompleted) {
            f.completeHeld(granted: false);
          }
          await f.close(tester);
        }
      },
    );
  }
}

class _Fixture {
  late Supabase sdk;
  late ProviderContainer container;
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final baseReads = <Map<String, Object?>>[];
  final writes = <String>[];
  final transportErrors = <String>[];
  var explicitFalseConsentWrites = 0;
  bool needsInitialChoice = false;
  bool choiceRecorded = false;
  final fixtureErrors = <String>[];
  final samples = <Map<String, Object?>>[];
  final held = Completer<http.Response>();
  http.Request? heldRequest;
  bool holdNextA = false;
  int retirementSampleIndex = 0;

  static Future<_Fixture> open(WidgetTester tester, {String? owner}) async {
    final f = _Fixture();
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      f.sdk = await Supabase.initialize(
        url: 'https://$_host',
        publishableKey: 'synthetic-base-consent-fixture-only',
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: _TracingOwnerHttpClient(
          f,
          CommunityOwnerHttpClient(MockClient(f.handle)),
        ),
      );
      if (owner != null) await f.signIn(owner);
    });
    expect(
      AppEnvironment.supabaseRuntimeReady,
      isTrue,
      reason: 'Read production readiness; never force/override it.',
    );
    f.container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(f.database),
        // Only unrelated diary summary is isolated from Drift subscription timers.
        diarySharingSummaryProvider.overrideWith(
          (_) => Stream.value('private'),
        ),
      ],
    );
    return f;
  }

  CloudSyncConsentState get current {
    final value = container.read(cloudSyncConsentStateProvider);
    expect(
      value.hasError,
      isFalse,
      reason: 'Actual provider AsyncError must remain visible.',
    );
    expect(
      value.isLoading,
      isFalse,
      reason: 'Production owner stream must converge.',
    );
    expect(value.value, isNotNull);
    return value.value!;
  }

  Future<void> mount(
    WidgetTester tester, {
    bool expectSettled = true,
    bool withPrivacyPage = true,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: _Capture(fixture: this, withPrivacyPage: withPrivacyPage),
        ),
      ),
    );
    await drain(tester);
    if (expectSettled) {
      expect(container.read(cloudSyncConsentStateProvider).isLoading, isFalse);
    }
  }

  Future<void> hideConsumer(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> drain(WidgetTester tester) async {
    // Bounded real event delivery, not a global timeout, skip, or fake grant.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
  }

  void expectAvailable(
    WidgetTester tester,
    String owner, {
    bool withPrivacyPage = true,
  }) {
    final raw = container.read(cloudAuthOwnerIdProvider);
    expect(raw.isLoading, isFalse);
    expect(raw.hasError, isFalse);
    expect(raw.value, owner);
    final state = current;
    expect(state.ownerId, owner);
    expect(state.availability, CloudSyncConsentAvailability.available);
    expect(state.granted, isFalse);
    expect(state.canEnable, isTrue);
    expect(state.recordedAt, DateTime.utc(2026, 11, 16, 21, 30));
    if (!withPrivacyPage) {
      expect(
        find.byKey(const Key('actual-base-consent-state')),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      return;
    }
    final finder = find.byKey(const Key('encrypted-cloud-sync-consent'));
    expect(finder, findsOneWidget);
    final tile = tester.widget<SwitchListTile>(finder);
    expect(tile.value, isFalse);
    expect(tile.onChanged, isNotNull);
    expect(find.text('Cloud sync is temporarily unavailable.'), findsNothing);
    expect(writes, isEmpty);
  }

  Future<void> signIn(String owner) async {
    retirementSampleIndex = samples.length;
    await sdk.client.auth.signInWithPassword(
      email: '$owner@example.invalid',
      password: 'synthetic-only',
    );
    await Future<void>.delayed(Duration.zero);
  }

  http.Response response(http.Request request, Object? body) => http.Response(
    jsonEncode(body),
    200,
    request: request,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  List<Map<String, Object?>> receipt({bool granted = false}) => [
    {
      'granted': granted,
      'recorded_at': '2026-11-16T21:30:00Z',
      'policy_version': '1',
    },
  ];

  Future<http.Response> handle(http.Request request) async {
    try {
      expectSync(request.url.host, _host);
      final path = request.url.path;
      if (path == '/auth/v1/token') {
        expectSync(request.method, 'POST');
        final email = (jsonDecode(request.body) as Map)['email'] as String;
        final owner = email.split('@').first;
        expectSync([_ownerA, _ownerB], contains(owner));
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'sub': owner,
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'exp': 4102444800,
                }),
              ),
            )
            .replaceAll('=', '');
        return response(request, {
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
          'refresh_token': 'synthetic-refresh-$owner',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'email': email,
            'aud': 'authenticated',
            'created_at': '2026-11-16T00:00:00Z',
            'email_confirmed_at': '2026-11-16T00:00:00Z',
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
          },
        });
      }
      if (path == '/rest/v1/bil_consent_receipts') {
        expectSync(request.method, 'GET');
        final q = request.url.queryParameters;
        if (q['purpose'] != 'eq.cloud_sync') {
          // Meal-photo consent reads are a separate unchanged category.
          expectSync(q['select'], 'granted,policy_version');
          return response(request, null);
        }
        final owner = q['user_id']?.replaceFirst('eq.', '');
        expectSync([_ownerA, _ownerB], contains(owner));
        expectSync(
          q['select']?.replaceAll(' ', ''),
          'granted,recorded_at,policy_version',
        );
        expectSync(
          q['order'],
          'recorded_at.desc.nullslast,granted.asc.nullslast,policy_version.desc.nullslast',
        );
        expectSync(q['limit'], '1');
        baseReads.add({
          'owner': owner,
          'authorization_present':
              request.headers['authorization']?.startsWith('Bearer ') == true,
        });
        if (needsInitialChoice && !choiceRecorded) return response(request, []);
        if (holdNextA && owner == _ownerA) {
          holdNextA = false;
          heldRequest = request;
          return held.future;
        }
        return response(request, receipt());
      }
      if (path == '/rest/v1/rpc/bil_record_consent') {
        expectSync(needsInitialChoice, isTrue);
        expectSync(request.method, 'POST');
        final payload = jsonDecode(request.body) as Map;
        expectSync(payload['p_purpose'], 'cloud_sync');
        expectSync(payload['p_policy_version'], '1');
        expectSync(payload['p_granted'], isFalse);
        explicitFalseConsentWrites++;
        expectSync(
          explicitFalseConsentWrites,
          1,
          reason: 'Only one explicit synthetic Keep Local denial is permitted.',
        );
        choiceRecorded = true;
        return response(request, null);
      }
      if (path == '/rest/v1/rpc/bil_cloud_restore_capabilities_v2') {
        expectSync(request.method, 'POST');
        return response(request, {
          'protocol_version': 2,
          'consent_policy_version': '1',
          'scopes': ['nutrition', 'goals'],
        });
      }
      if (path == '/rest/v1/rpc/bil_cloud_restore_consent_v2') {
        expectSync(request.method, 'POST');
        return response(request, {
          'nutrition': {'granted': false, 'policy_version': '1'},
          'goals': {'granted': false, 'policy_version': '1'},
        });
      }
      writes.add('${request.method}:$path');
      throw StateError(
        'Unexpected transport operation outside read-only model',
      );
    } on Object catch (error) {
      fixtureErrors.add(error.runtimeType.toString());
      rethrow;
    }
  }

  void completeHeld({required bool granted}) {
    held.complete(response(heldRequest!, receipt(granted: granted)));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await tester.runAsync(() async {
      await database.close();
      await sdk.dispose();
    });
    await tester.pump();
  }
}

class _Capture extends ConsumerWidget {
  const _Capture({required this.fixture, required this.withPrivacyPage});
  final _Fixture fixture;
  final bool withPrivacyPage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(cloudAuthOwnerIdProvider);
    final state = ref.watch(cloudSyncConsentStateProvider);
    fixture.samples.add({
      'ready': AppEnvironment.supabaseRuntimeReady,
      'owner_loading': raw.isLoading,
      'owner_error': raw.hasError,
      'owner': raw.value,
      'state_loading': state.isLoading,
      'state_error': state.hasError,
      'availability': state.value?.availability.name,
      'state_owner': state.value?.ownerId,
      'granted': state.value?.granted,
    });
    return withPrivacyPage
        ? const SharingPrivacySettingsPage()
        : Scaffold(
            body: Text(
              state.value?.availability.name ?? 'loading',
              key: const Key('actual-base-consent-state'),
            ),
          );
  }
}

// This wrapper only observes and rethrows the production transport fence.
// It does not replace CommunityOwnerOperation or detach any Zone value.
class _TracingOwnerHttpClient extends http.BaseClient {
  _TracingOwnerHttpClient(this.fixture, this.delegate);
  final _Fixture fixture;
  final http.Client delegate;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await delegate.send(request);
    } on Object catch (error) {
      fixture.transportErrors.add(error.runtimeType.toString());
      rethrow;
    }
  }

  @override
  void close() => delegate.close();
}

void _registerKeepLocalFirstUseProbe() {
  testWidgets(
    'actual Keep Local notice retires its operation before actual Privacy remains available',
    (tester) async {
      final f = await _Fixture.open(tester, owner: _ownerA);
      f.needsInitialChoice = true;
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  const CloudSyncConsentNotice(),
                  TextButton(
                    key: const Key('open-actual-sharing-privacy'),
                    onPressed: () => context.push('/settings/sharing-privacy'),
                    child: const Text('Open Privacy'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/settings/sharing-privacy',
            builder: (_, _) => _Capture(fixture: f, withPrivacyPage: true),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: f.container,
            child: MaterialApp.router(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              routerConfig: router,
            ),
          ),
        );
        await f.drain(tester);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cloud-sync-keep-local')), findsOneWidget);
        expect(f.explicitFalseConsentWrites, 0);
        await tester.ensureVisible(
          find.byKey(const Key('cloud-sync-keep-local')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('cloud-sync-keep-local')));
        // Exercise real event/frame scheduling after the owned operation returns.
        // Do not prime a new read or invalidate anything from the test Zone.
        await f.drain(tester);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cloud-sync-keep-local')), findsNothing);
        expect(f.explicitFalseConsentWrites, 1);
        expect(f.choiceRecorded, isTrue);
        await tester.tap(find.byKey(const Key('open-actual-sharing-privacy')));
        await f.drain(tester);
        await tester.pumpAndSettle();
        expect(find.byType(SharingPrivacySettingsPage), findsOneWidget);
        f.expectAvailable(tester, _ownerA);
        expect(
          f.transportErrors,
          isEmpty,
          reason:
              'A retired Keep Local operation must not own the independent Privacy read.',
        );
        expect(f.writes, isEmpty);
        expect(f.fixtureErrors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await f.close(tester);
        router.dispose();
      }
    },
  );
}
