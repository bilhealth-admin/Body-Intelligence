import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/admin_entitlement_continuity_store.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:body_intelligence_log/features/commerce/repositories/verified_entitlement_continuity_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// C5 public APIs only. Actual HTTP client parsing and real repository; no SDK hooks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var owner = '';
  var activeScenario = const _Scenario('unset');
  final now = DateTime.utc(2026, 11, 18, 10, 35);
  final routes = <String>[];
  final statuses = <int>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://admin-continuity-counterexample.invalid',
      publishableKey: 'synthetic-public-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/auth/v1/logout') {
          return http.Response('', 204, request: request);
        }
        Object? body;
        var status = 200;
        switch (path) {
          case '/rest/v1/bil_ai_closed_test_grants':
            expect(request.url.queryParameters['owner_id'], 'eq.$owner');
            if (activeScenario.closedReadFails) {
              status = 403;
              body = {'code': '42501', 'message': 'synthetic denied read'};
            } else {
              body = <Object?>[];
            }
          case '/rest/v1/bil_subscriptions':
            expect(request.url.queryParameters['owner_id'], 'eq.$owner');
            body = <Object?>[];
          case '/rest/v1/rpc/bil_get_my_admin_subscription':
            if (activeScenario.adminReadFails) {
              status = 503;
              body = {'code': '503', 'message': 'synthetic admin outage'};
            } else if (activeScenario.paidAdmin) {
              body = {
                'owner_id': owner,
                'plan_id': 'premium',
                'created_at': now
                    .subtract(const Duration(days: 1))
                    .toIso8601String(),
                'expires_at': now
                    .add(const Duration(days: 1))
                    .toIso8601String(),
                'access_until': now
                    .add(const Duration(minutes: 5))
                    .toIso8601String(),
              };
            } else {
              body = null;
            }
          default:
            throw StateError('Unexpected synthetic request path: $path');
        }
        routes.add(path);
        statuses.add(status);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  const scenarios = [
    _Scenario('control complete negative authority'),
    _Scenario('HTTP200 admin-cache delete failure', failDelete: true),
    _Scenario('failed admin remains unknown', adminReadFails: true),
    _Scenario('unreadable closed grant remains unknown', closedReadFails: true),
    _Scenario(
      'fresh paid admin survives cache write failure',
      paidAdmin: true,
      failWrite: true,
    ),
  ];
  for (var index = 0; index < scenarios.length; index++) {
    final scenario = scenarios[index];
    test(scenario.name, () async {
      activeScenario = scenario;
      owner =
          'fc000000-0000-4000-8000-${(index + 11).toString().padLeft(12, '0')}';
      routes.clear();
      statuses.clear();
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'synthetic-admin-continuity-token',
          'token_type': 'bearer',
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      final admin = _Secure(
        failDelete: scenario.failDelete,
        failWrite: scenario.failWrite,
      );
      final repository = ServerEntitlementRepository(
        adminContinuityStore: AdminEntitlementContinuityStore(
          secureStore: admin,
        ),
        subscriptionContinuityStore: VerifiedEntitlementContinuityStore(
          secureStore: _Secure(),
        ),
        clock: () => now,
      );
      final state = await repository.current();
      expect(routes, [
        '/rest/v1/bil_ai_closed_test_grants',
        '/rest/v1/bil_subscriptions',
        '/rest/v1/rpc/bil_get_my_admin_subscription',
      ]);
      expect(statuses, [
        scenario.closedReadFails ? 403 : 200,
        200,
        scenario.adminReadFails ? 503 : 200,
      ]);
      expect(
        admin.deletes,
        scenario.adminReadFails || scenario.paidAdmin ? 0 : 1,
      );
      expect(admin.writes, scenario.paidAdmin ? 1 : 0);
      expect(
        state.plan,
        scenario.paidAdmin ? CommercePlan.premium : CommercePlan.free,
      );
      expect(
        state.authority,
        scenario.adminReadFails || scenario.closedReadFails
            ? EntitlementAuthority.localDefault
            : EntitlementAuthority.verifiedServer,
        reason:
            'Cache persistence cannot erase fresh complete proof; failed '
            'authority reads cannot manufacture verified Free.',
      );
      if (scenario.paidAdmin) {
        expect(state.currentPeriodEndsAt, now.add(const Duration(minutes: 5)));
      }
    });
  }
}

final class _Scenario {
  const _Scenario(
    this.name, {
    this.failDelete = false,
    this.failWrite = false,
    this.adminReadFails = false,
    this.closedReadFails = false,
    this.paidAdmin = false,
  });
  final String name;
  final bool failDelete, failWrite, adminReadFails, closedReadFails, paidAdmin;
}

final class _Secure implements AdminEntitlementSecureStore {
  _Secure({this.failDelete = false, this.failWrite = false});
  final bool failDelete, failWrite;
  int deletes = 0, writes = 0;
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (failWrite) {
      throw PlatformException(code: 'synthetic_secure_write_failed');
    }
  }

  @override
  Future<void> delete(String key) async {
    deletes++;
    if (failDelete) {
      throw PlatformException(code: 'synthetic_secure_delete_failed');
    }
  }
}
