// Actual consent repository/runtime gate and SQLite; HTTP/Auth are host
// fixtures. This is not Production Auth, native sync, or provider evidence.
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_runtime_access_gate.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_sync_consent_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '00000000-0000-4000-8022-000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in ['newer denial', 'unknown version', 'tied denial']) {
    test('latest $scenario overrides an older current-policy grant', () async {
      final receipts = <Map<String, Object?>>[
        {
          'granted': true,
          'policy_version': '1',
          'recorded_at': '2026-10-04T12:00:00Z',
        },
        {
          'granted': scenario == 'unknown version',
          'policy_version': '2',
          'recorded_at': scenario == 'tied denial'
              ? '2026-10-04T12:00:00Z'
              : '2026-10-04T12:01:00Z',
        },
      ];
      final fixture = _ConsentFixture(receipts);
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final boundary = LocalDataAccountBoundary(database);
      await boundary.bindAuthenticatedOwner(_owner);
      final gate = CloudRuntimeAccessGate(
        client: fixture.client,
        accountBoundary: boundary,
      );
      final decision = await gate.evaluate();
      expect(
        decision.disposition,
        CloudRuntimeAccessDisposition.consentMissing,
      );
      final state = await CloudSyncConsentRepository(
        client: fixture.client,
      ).read();
      expect(state.granted, isFalse);
      expect(state.canDisable, isFalse);
      expect(state.canEnable, isTrue);
      expect(fixture.consentRequests, hasLength(2));
      for (final request in fixture.consentRequests) {
        expect(request.queryParameters.containsKey('granted'), isFalse);
        expect(request.queryParameters.containsKey('policy_version'), isFalse);
        expect(
          request.queryParameters['order'],
          'recorded_at.desc.nullslast,granted.asc.nullslast,policy_version.desc.nullslast',
        );
      }
    });
  }

  test(
    'latest supported grant unlocks and same-policy revocation blocks',
    () async {
      final fixture = _ConsentFixture([
        {
          'granted': true,
          'policy_version': '1',
          'recorded_at': '2026-10-04T12:01:00Z',
        },
        {
          'granted': false,
          'policy_version': '2',
          'recorded_at': '2026-10-04T12:00:00Z',
        },
      ]);
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final boundary = LocalDataAccountBoundary(database);
      await boundary.bindAuthenticatedOwner(_owner);
      final gate = CloudRuntimeAccessGate(
        client: fixture.client,
        accountBoundary: boundary,
      );
      final repository = CloudSyncConsentRepository(client: fixture.client);
      expect((await gate.evaluate()).isReady, isTrue);
      expect((await repository.read()).canDisable, isTrue);
      fixture.receipts.first['granted'] = false;
      expect(
        (await gate.evaluate()).disposition,
        CloudRuntimeAccessDisposition.consentMissing,
      );
      expect((await repository.read()).granted, isFalse);
      fixture.failRead = true;
      expect(
        (await gate.evaluate()).disposition,
        CloudRuntimeAccessDisposition.unavailable,
      );
      expect(
        (await repository.read()).availability,
        CloudSyncConsentAvailability.unavailable,
      );
    },
  );

  test(
    'session loss during consent read never authorizes the former owner',
    () async {
      final fixture = _ConsentFixture([
        {
          'granted': true,
          'policy_version': '1',
          'recorded_at': '2026-10-04T12:01:00Z',
        },
      ]);
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final boundary = LocalDataAccountBoundary(database);
      await boundary.bindAuthenticatedOwner(_owner);
      fixture.signOutDuringRead = true;
      final gate = CloudRuntimeAccessGate(
        client: fixture.client,
        accountBoundary: boundary,
      );
      expect(
        (await gate.evaluate()).disposition,
        CloudRuntimeAccessDisposition.notAuthenticated,
      );
      await fixture.signIn();
      final state = await CloudSyncConsentRepository(
        client: fixture.client,
      ).read();
      expect(state.granted, isFalse);
      expect(state.canChange, isFalse);
    },
  );
}

final class _ConsentFixture {
  _ConsentFixture(this.receipts) {
    client = SupabaseClient(
      'https://cloud-consent-fixture.invalid',
      'fixture-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(_handle),
    );
  }

  final List<Map<String, Object?>> receipts;
  final List<Uri> consentRequests = [];
  bool failRead = false;
  bool signOutDuringRead = false;
  late final SupabaseClient client;

  Future<void> signIn() => client.auth
      .signInWithPassword(email: 'owner@example.invalid', password: 'fixture')
      .then((_) {});

  Future<http.Response> _handle(http.Request request) async {
    expect(request.url.host, 'cloud-consent-fixture.invalid');
    Object body;
    if (request.url.path == '/auth/v1/token') {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})))
          .replaceAll('=', '');
      body = {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture-refresh-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': _owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-10-04T00:00:00Z',
        },
      };
    } else if (request.url.path == '/rest/v1/bil_consent_receipts') {
      if (failRead) {
        return http.Response('{"message":"fixture network failure"}', 503);
      }
      if (signOutDuringRead) {
        await client.auth.signOut(scope: SignOutScope.local);
      }
      consentRequests.add(request.url);
      final query = request.url.queryParameters;
      expect(query['user_id'], 'eq.$_owner');
      expect(query['purpose'], 'eq.cloud_sync');
      var rows = receipts.where((row) {
        return (query['policy_version'] == null ||
                query['policy_version'] == 'eq.${row['policy_version']}') &&
            (query['granted'] == null ||
                query['granted'] == 'eq.${row['granted']}');
      }).toList();
      final order = query['order'];
      if (order != null) {
        rows.sort((a, b) {
          for (final key in order.split(',')) {
            final parts = key.split('.');
            final field = parts.first;
            final compared = '${a[field]}'.compareTo('${b[field]}');
            if (compared != 0) {
              return parts[1] == 'desc' ? -compared : compared;
            }
          }
          return 0;
        });
      }
      rows = rows.take(int.parse(query['limit']!)).toList();
      body = rows;
    } else if (request.url.path == '/auth/v1/logout') {
      body = <String, Object?>{};
    } else {
      throw StateError('Unexpected HTTP path ${request.url.path}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}
