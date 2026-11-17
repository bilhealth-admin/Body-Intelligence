import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/presentation/cloud_sync_consent_notice.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_sync_providers.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_sync_consent_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/settings/sharing_privacy_settings_page.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '00000000-0000-4000-8030-000000000001';
const _ownerB = '00000000-0000-4000-8030-000000000002';

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets(
      'category discovery opens real Privacy, grants nothing, and returns without a nag: $locale',
      (tester) async {
        final harness = await _mount(
          tester,
          locale: Locale(locale),
          scale: 1.7,
        );
        final manage = find.byKey(const Key('cloud-sync-manage-categories'));
        final oldCallback = tester.widget<TextButton>(manage).onPressed!;
        await tester.ensureVisible(manage);
        await tester.pumpAndSettle();
        await tester.tap(manage);
        await tester.pumpAndSettle();
        expect(
          harness
              .router
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation,
          '/settings/sharing-privacy',
        );
        expect(find.byType(SharingPrivacySettingsPage), findsOneWidget);
        expect(harness.privacyOwners, [_ownerA]);
        expect(harness.fixture.writes, isEmpty);
        expect(harness.syncCalls, 0);
        // A delayed callback from the departed sheet cannot pop Privacy.
        oldCallback();
        await tester.pumpAndSettle();
        expect(
          harness
              .router
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation,
          '/settings/sharing-privacy',
        );
        harness.router.pop();
        await tester.pumpAndSettle();
        expect(
          harness
              .router
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation,
          '/dashboard',
        );
        expect(manage, findsNothing);
        expect(harness.current.recordedAt, isNull);
        expect(harness.current.granted, isFalse);
        expect(harness.fixture.writes, isEmpty);
        expect(harness.syncCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final transition in ['A to B', 'A to B to A']) {
    testWidgets('old notice cannot open Privacy after $transition', (
      tester,
    ) async {
      final harness = await _mount(tester);
      final manage = find.byKey(const Key('cloud-sync-manage-categories'));
      final callback = tester.widget<TextButton>(manage).onPressed!;
      await harness.changeOwner(tester, transition);
      callback();
      await tester.pumpAndSettle();
      expect(
        harness.router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/dashboard',
      );
      expect(harness.privacyOwners, isEmpty);
      expect(harness.fixture.writes, isEmpty);
      expect(harness.syncCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    testWidgets(
      'return from category discovery cancels the original visit after $transition',
      (tester) async {
        final harness = await _mount(tester);
        await tester.ensureVisible(
          find.byKey(const Key('cloud-sync-manage-categories')),
        );
        await tester.tap(find.byKey(const Key('cloud-sync-manage-categories')));
        await tester.pumpAndSettle();
        expect(harness.privacyOwners, [_ownerA]);
        await harness.changeOwner(tester, transition);
        harness.router.pop();
        await tester.pumpAndSettle();
        expect(
          harness
              .router
              .routerDelegate
              .currentConfiguration
              .last
              .matchedLocation,
          '/dashboard',
        );
        expect(harness.privacyOwners, [_ownerA]);
        expect(harness.fixture.writes, isEmpty);
        expect(harness.syncCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final enable in [true, false]) {
    testWidgets(
      'explicit Progress choice $enable writes only base consent and preserves other permissions',
      (tester) async {
        final harness = await _mount(tester);
        final choice = find.byKey(
          Key(enable ? 'cloud-sync-enable-backup' : 'cloud-sync-keep-local'),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        // The synthetic transport rejects every non-base consent request, including
        // restore scopes, Health, third-party AI and advertising permissions.
        expect(harness.fixture.writes, [(_ownerA, enable)]);
        expect(harness.syncCalls, enable ? 1 : 0);
        expect(harness.privacyOwners, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}

Future<_Harness> _mount(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) async {
  final fixture = (await tester.runAsync(() async {
    final fixture = _ConsentHttpFixture();
    await fixture.signIn(_ownerA);
    return fixture;
  }))!;
  final harness = _Harness(fixture);
  addTearDown(fixture.client.dispose);
  addTearDown(harness.database.close);
  addTearDown(harness.container.dispose);
  addTearDown(harness.router.dispose);
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routerConfig: harness.router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

final class _Harness {
  _Harness(this.fixture) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        // Diary visibility is unrelated to the consent navigation under test.
        diarySharingSummaryProvider.overrideWith(
          (_) => Stream.value('private'),
        ),
        cloudSyncConsentRepositoryProvider.overrideWithValue(
          CloudSyncConsentRepository(client: fixture.client),
        ),
        cloudSyncConsentStateProvider.overrideWith((_) async => current),
        cloudManualSyncStatusProvider.overrideWith(
          (_) => CloudManualSyncStatusController(
            preferences: PreferencesRepository(database),
            cloudAvailable: true,
            ownerId: _ownerA,
            runSync: () async {
              syncCalls++;
              return const CloudManualSyncResult(
                disposition: CloudManualSyncDisposition.unavailable,
              );
            },
          ),
        ),
      ],
    );
    router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: CloudSyncConsentNotice()),
        ),
        GoRoute(
          path: '/settings/sharing-privacy',
          builder: (_, _) {
            privacyOwners.add(fixture.client.auth.currentUser!.id);
            return const SharingPrivacySettingsPage();
          },
        ),
      ],
    );
  }
  final _ConsentHttpFixture fixture;
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  late final ProviderContainer container;
  late final GoRouter router;
  var current = const CloudSyncConsentState(
    availability: CloudSyncConsentAvailability.available,
    ownerId: _ownerA,
  );
  var syncCalls = 0;
  final privacyOwners = <String>[];

  Future<void> changeOwner(WidgetTester tester, String transition) async {
    for (final owner
        in transition == 'A to B' ? [_ownerB] : [_ownerB, _ownerA]) {
      await tester.runAsync(() => fixture.signIn(owner));
      current = CloudSyncConsentState(
        availability: CloudSyncConsentAvailability.available,
        ownerId: owner,
        recordedAt: DateTime.utc(2026, 11, 16),
      );
      container.invalidate(cloudSyncConsentStateProvider);
      await tester.pumpAndSettle();
    }
  }
}

// Only synthetic Auth/RPC HTTP is used. No hosted backend or OS health store.
final class _ConsentHttpFixture {
  _ConsentHttpFixture() {
    client = SupabaseClient(
      'https://cloud-owner-choice.invalid',
      'fixture-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(MockClient(_handle)),
    );
  }

  late final SupabaseClient client;
  final writes = <(String, bool)>[];

  Future<void> signIn(String owner) async {
    await client.auth.signInWithPassword(
      email: '$owner@example.invalid',
      password: 'fixture',
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<http.Response> _handle(http.Request request) async {
    expect(request.url.host, 'cloud-owner-choice.invalid');
    final Object body;
    if (request.url.path == '/auth/v1/token') {
      final email = (jsonDecode(request.body) as Map)['email'] as String;
      final owner = email.split('@').first;
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture-refresh-token-$owner',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-10-20T00:00:00Z',
        },
      };
    } else if (request.url.path == '/rest/v1/rpc/bil_record_consent') {
      final token = request.headers['Authorization']!.split(' ').last;
      final owner =
          (jsonDecode(
                    utf8.decode(
                      base64Url.decode(
                        base64Url.normalize(token.split('.')[1]),
                      ),
                    ),
                  )
                  as Map)['sub']
              as String;
      final params = jsonDecode(request.body) as Map;
      expect(params['p_purpose'], 'cloud_sync');
      expect(params['p_policy_version'], '1');
      writes.add((owner, params['p_granted'] as bool));
      body = {'recorded': true};
    } else {
      throw StateError('Unexpected synthetic request: ${request.url.path}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
