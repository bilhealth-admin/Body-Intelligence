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

  test(
    'closed-test read failure still verifies separate paid mirror for owner',
    () async {
      const owner = '00000000-0000-4000-8002-000000000731';
      final now = DateTime.now().toUtc();
      var grantReads = 0;
      var mirrorReads = 0;
      var adminReads = 0;
      final stored = <String, String>{};
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_storage, (call) async {
        final params = Map<String, Object?>.from(call.arguments as Map);
        final key = params['key'] as String?;
        switch (call.method) {
          case 'read':
            return stored[key];
          case 'write':
            stored[key!] = params['value']! as String;
            return null;
          case 'delete':
            stored.remove(key);
            return null;
          default:
            throw StateError('Unexpected secure storage operation');
        }
      });
      final transport = MockClient((request) async {
        switch (request.url.path) {
          case '/rest/v1/bil_ai_closed_test_grants':
            grantReads++;
            throw http.ClientException('synthetic closed-test read failure');
          case '/rest/v1/bil_subscriptions':
            mirrorReads++;
            expect(
              request.url.queryParameters['owner_id'],
              'eq.$owner',
            );
            return http.Response(
              jsonEncode([
                {
                  'owner_id': owner,
                  'provider': 'google',
                  'plan_id': 'premium_ai_coach',
                  'lifecycle': 'active',
                  'started_at': now
                      .subtract(const Duration(days: 1))
                      .toIso8601String(),
                  'expires_at': now
                      .add(const Duration(days: 30))
                      .toIso8601String(),
                  'verified_at': now.toIso8601String(),
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          case '/rest/v1/rpc/bil_get_my_admin_subscription':
            adminReads++;
            return http.Response(
              'null',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          default:
            throw StateError('Unexpected fixture path: ${request.url.path}');
        }
      });

      try {
        await Supabase.initialize(
          url: 'https://reviewer-mirror-fixture.invalid',
          publishableKey: 'reviewer-mirror-fixture-public-key',
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
            'access_token': 'reviewer-fixture-token',
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
        final state = await const ServerEntitlementRepository().current();
        expect(grantReads, 1);
        expect(mirrorReads, 1);
        expect(adminReads, 1);
        expect(state.plan, CommercePlan.premiumAiCoach);
        expect(state.authority, EntitlementAuthority.verifiedServer);
        expect(state.canRestorePurchases, isTrue);
      } finally {
        await Supabase.instance.dispose();
        transport.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_storage, null);
      }
    },
  );
}
