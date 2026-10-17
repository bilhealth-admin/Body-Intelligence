import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases = <({
    String name,
    bool grantActive,
    bool closedTestFailure,
    bool mirrorFailure,
    bool grantFailure,
    bool paidStore,
    CommercePlan expectedPlan,
    EntitlementAuthority expectedAuthority,
  })>[
    (
      name: 'revoked grant plus confirmed empty store becomes verified Free',
      grantActive: false,
      closedTestFailure: false,
      mirrorFailure: false,
      grantFailure: false,
      paidStore: false,
      expectedPlan: CommercePlan.free,
      expectedAuthority: EntitlementAuthority.verifiedServer,
    ),
    (
      name: 'active gift continues to grant Premium',
      grantActive: true,
      closedTestFailure: false,
      mirrorFailure: false,
      grantFailure: false,
      paidStore: false,
      expectedPlan: CommercePlan.premium,
      expectedAuthority: EntitlementAuthority.verifiedServer,
    ),
    (
      name: 'independently verified store Premium survives gift revocation',
      grantActive: false,
      closedTestFailure: false,
      mirrorFailure: false,
      grantFailure: false,
      paidStore: true,
      expectedPlan: CommercePlan.premium,
      expectedAuthority: EntitlementAuthority.verifiedServer,
    ),
    (
      name: 'failed admin lookup cannot become verified Free',
      grantActive: false,
      closedTestFailure: false,
      mirrorFailure: false,
      grantFailure: true,
      paidStore: false,
      expectedPlan: CommercePlan.free,
      expectedAuthority: EntitlementAuthority.localDefault,
    ),
    (
      name: 'failed closed-test read cannot become verified Free',
      grantActive: false,
      closedTestFailure: true,
      mirrorFailure: false,
      grantFailure: false,
      paidStore: false,
      expectedPlan: CommercePlan.free,
      expectedAuthority: EntitlementAuthority.localDefault,
    ),
    (
      name: 'failed paid store read cannot become verified Free',
      grantActive: false,
      closedTestFailure: false,
      mirrorFailure: true,
      grantFailure: false,
      paidStore: false,
      expectedPlan: CommercePlan.free,
      expectedAuthority: EntitlementAuthority.localDefault,
    ),
  ];

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    final caseIndex = i;
    test(c.name, () async {
      final owner = '65000000-0000-4000-8000-00000000000' + (caseIndex + 1).toString();
      final now = DateTime.now().toUtc();
      final seen = <String>[];
      final saved = <String, String>{};
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_storage, (call) async {
        final args = Map<String, Object?>.from(call.arguments as Map);
        final key = args['key'] as String?;
        if (call.method == 'read') return saved[key];
        if (call.method == 'delete') {
          saved.remove(key);
          return null;
        }
        if (call.method == 'write') {
          saved[key!] = args['value']! as String;
          return null;
        }
        throw StateError('Unexpected storage operation');
      });

      final transport = MockClient((request) async {
        final path = request.url.path;
        seen.add(path);
        if (path == '/rest/v1/bil_ai_closed_test_grants') {
          if (c.closedTestFailure) throw http.ClientException('synthetic closed-test outage');
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/rest/v1/bil_subscriptions') {
          if (c.mirrorFailure) throw http.ClientException('synthetic mirror outage');
          final rows = c.paidStore
              ? [
                  {
                    'owner_id': owner,
                    'provider': 'google',
                    'plan_id': 'premium',
                    'lifecycle': 'active',
                    'started_at': now.subtract(const Duration(days: 1)).toIso8601String(),
                    'expires_at': now.add(const Duration(days: 30)).toIso8601String(),
                    'verified_at': now.toIso8601String(),
                  },
                ]
              : <Map<String, Object?>>[];
          return http.Response(jsonEncode(rows), 200, headers: {'content-type': 'application/json'});
        }
        if (path == '/rest/v1/rpc/bil_get_my_admin_subscription') {
          if (c.grantFailure) {
            return http.Response(
              jsonEncode({'code': 'PGRST500', 'message': 'synthetic read failure'}),
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          final gift = c.grantActive
              ? {
                  'owner_id': owner,
                  'plan_id': 'premium',
                  'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
                  'expires_at': now.add(const Duration(days: 30)).toIso8601String(),
                  'access_until': now.add(const Duration(minutes: 5)).toIso8601String(),
                }
              : null;
          return http.Response(jsonEncode(gift), 200, headers: {'content-type': 'application/json'});
        }
        throw StateError('Unexpected URL: ' + request.url.toString());
      });
      try {
        await Supabase.initialize(
          url: 'https://grant-revocation-test.invalid',
          publishableKey: 'synthetic-public-key',
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
          ),
          httpClient: transport,
        );
        await Supabase.instance.client.auth.setInitialSession(jsonEncode({
          'access_token': 'test-only-token',
          'token_type': 'bearer',
          'user': {
            'id': owner,
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }));
        final result = await const ServerEntitlementRepository().current();
        expect(result.plan, c.expectedPlan);
        expect(result.authority, c.expectedAuthority);
        expect(seen, contains('/rest/v1/bil_subscriptions'));
        expect(seen, contains('/rest/v1/bil_ai_closed_test_grants'));
        expect(seen, contains('/rest/v1/rpc/bil_get_my_admin_subscription'));
      } finally {
        await Supabase.instance.dispose();
        transport.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_storage, null);
      }
    });
  }

  test('Premium gift then revoked gift transitions to verified Free after fresh read',
      () async {
    const owner = '65000000-0000-4000-8000-000000000007';
    final now = DateTime.now().toUtc();
    final saved = <String, String>{};
    var giftActive = true;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, (call) async {
      final args = Map<String, Object?>.from(call.arguments as Map);
      final key = args['key'] as String?;
      if (call.method == 'read') return saved[key];
      if (call.method == 'write') {
        saved[key!] = args['value']! as String;
        return null;
      }
      if (call.method == 'delete') {
        saved.remove(key);
        return null;
      }
      throw StateError('Unexpected storage operation');
    });
    final transport = MockClient((request) async {
      final path = request.url.path;
      if (path == '/rest/v1/bil_ai_closed_test_grants' ||
          path == '/rest/v1/bil_subscriptions') {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      }
      if (path == '/rest/v1/rpc/bil_get_my_admin_subscription') {
        final gift = giftActive
            ? {
                'owner_id': owner,
                'plan_id': 'premium',
                'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
                'expires_at': now.add(const Duration(days: 30)).toIso8601String(),
                'access_until': now.add(const Duration(minutes: 5)).toIso8601String(),
              }
            : null;
        return http.Response(jsonEncode(gift), 200, headers: {'content-type': 'application/json'});
      }
      throw StateError('Unexpected URL: ' + request.url.toString());
    });
    try {
      await Supabase.initialize(
        url: 'https://grant-revocation-test.invalid',
        publishableKey: 'synthetic-public-key',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
        httpClient: transport,
      );
      await Supabase.instance.client.auth.setInitialSession(jsonEncode({
        'access_token': 'test-only-token',
        'token_type': 'bearer',
        'user': {
          'id': owner,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }));
      const repo = ServerEntitlementRepository();
      final premium = await repo.current();
      expect(premium.plan, CommercePlan.premium);
      expect(premium.authority, EntitlementAuthority.verifiedServer);
      giftActive = false;
      final free = await repo.current();
      expect(free.plan, CommercePlan.free);
      expect(free.authority, EntitlementAuthority.verifiedServer);
    } finally {
      await Supabase.instance.dispose();
      transport.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_storage, null);
    }
  });
}
