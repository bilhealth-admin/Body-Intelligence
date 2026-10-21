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
  for (final surface in ['notice', 'settings']) {
    for (final transition in ['same owner', 'A to B', 'A to B to A']) {
      testWidgets(
        'cloud choice belongs to the visit that opened it: $surface / $transition',
        (tester) async {
          final fixture = (await tester.runAsync(() async {
            final fixture = _ConsentHttpFixture();
            await fixture.signIn(_ownerA);
            return fixture;
          }))!;
          addTearDown(fixture.client.dispose);
          debugPrint('Cloud consent fixture signed in: $surface / $transition');
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          var current = const CloudSyncConsentState(
            availability: CloudSyncConsentAvailability.available,
            ownerId: _ownerA,
          );
          var syncCalls = 0;
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(database),
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
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: const Locale('en'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: surface == 'notice'
                    ? const Scaffold(body: CloudSyncConsentNotice())
                    : const SharingPrivacySettingsPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          debugPrint('Cloud consent surface ready: $surface / $transition');
          if (surface == 'settings') {
            await tester.tap(
              find.byKey(const Key('encrypted-cloud-sync-consent')),
            );
            await tester.pumpAndSettle();
          }
          final confirmation = surface == 'notice'
              ? find.byKey(const Key('cloud-sync-enable-backup'))
              : find.byType(FilledButton).last;
          expect(confirmation, findsOneWidget);
          if (transition != 'same owner') {
            final owners = transition == 'A to B'
                ? [_ownerB]
                : [_ownerB, _ownerA];
            for (final owner in owners) {
              await tester.runAsync(() => fixture.signIn(owner));
              current = CloudSyncConsentState(
                availability: CloudSyncConsentAvailability.available,
                ownerId: owner,
                recordedAt: DateTime.utc(2026, 10, 20),
              );
              container.invalidate(cloudSyncConsentStateProvider);
              await tester.pumpAndSettle();
            }
          }
          await tester.ensureVisible(confirmation);
          await tester.tap(confirmation);
          await tester.pumpAndSettle();
          debugPrint('Cloud consent choice completed: $surface / $transition');
          if (transition == 'same owner') {
            expect(fixture.writes, [(_ownerA, true)]);
            expect(syncCalls, 1);
          } else {
            expect(
              fixture.writes,
              isEmpty,
              reason:
                  'An old account visit cannot record consent for a new visit.',
            );
            expect(syncCalls, 0);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
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
