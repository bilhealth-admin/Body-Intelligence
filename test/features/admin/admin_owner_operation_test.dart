import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/admin/services/admin_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../community/support/community_rewards_rpc_fixture.dart';

void main() {
  late SupabaseClient client;
  late List<http.Request> sent;
  Completer<void>? edgeEntered, edgeRelease;
  var status = 200;
  setUp(() async {
    sent = [];
    status = 200;
    edgeEntered = null;
    edgeRelease = null;
    client = SupabaseClient(
      'https://admin-owner.invalid',
      'synthetic-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('{}', 200);
        }
        sent.add(request);
        edgeEntered?.complete();
        await edgeRelease?.future;
        return http.Response(
          jsonEncode({'success': status == 200}),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.setInitialSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
    );
  });
  tearDown(() async {
    if (edgeRelease != null && !edgeRelease!.isCompleted) {
      edgeRelease!.complete();
    }
    await client.dispose();
  });
  Future<void> recover(String owner) =>
      client.auth.recoverSession(jsonEncode(RewardsRpcFixture.session(owner)));
  Future<void> change(bool roundTrip) async {
    await recover(rewardsOwnerB);
    if (roundTrip) await recover(rewardsOwnerA);
    await Future<void>.delayed(Duration.zero);
  }

  Future<FunctionResponse> invoke({
    Future<Map<String, Object?>> Function()? prepare,
  }) => AdminOwnerOperation.invoke(
    client,
    integrityAction: 'qa-only',
    body: const {'operation': 'subscription_list'},
    prepare: prepare ?? () async => {'operation': 'subscription_list'},
  );

  test('original JWT is explicit and no client actor is added', () async {
    final expected = client.auth.currentSession!.accessToken;
    final response = await invoke();
    expect(response.status, 200);
    expect(sent.single.url.path, '/functions/v1/ai-coach-global-reset');
    expect(sent.single.headers['authorization'], 'Bearer $expected');
    expect(jsonDecode(sent.single.body), {'operation': 'subscription_list'});
  });
  for (final roundTrip in [false, true]) {
    test(
      'account transition during integrity preparation cancels ABA=$roundTrip before send',
      () async {
        final release = Completer<Map<String, Object?>>();
        final pending = invoke(prepare: () => release.future);
        final assertion = expectLater(pending, throwsA(isA<StateError>()));
        await change(roundTrip);
        release.complete({'operation': 'subscription_list'});
        await assertion;
        expect(sent, isEmpty);
      },
    );
    test(
      'late administrative receipt is retired ABA=$roundTrip and original JWT stays fixed',
      () async {
        edgeEntered = Completer<void>();
        edgeRelease = Completer<void>();
        final token = client.auth.currentSession!.accessToken;
        final pending = invoke();
        final assertion = expectLater(pending, throwsA(isA<StateError>()));
        await edgeEntered!.future;
        await change(roundTrip);
        edgeRelease!.complete();
        await assertion;
        expect(sent.single.headers['authorization'], 'Bearer $token');
        // Retirement cannot retract a decision the server may have committed.
        // The caller must reconcile its idempotent receipt, never assume rollback.
      },
    );
  }
  test('sign out retires a pending preparation', () async {
    final release = Completer<Map<String, Object?>>();
    final pending = invoke(prepare: () => release.future);
    final assertion = expectLater(pending, throwsA(isA<StateError>()));
    await client.auth.signOut();
    release.complete({});
    await assertion;
    expect(sent, isEmpty);
  });
  test(
    'missing session and denied server response are explicit failures',
    () async {
      status = 403;
      await expectLater(invoke(), throwsA(isA<FunctionException>()));
      await client.auth.signOut();
      final count = sent.length;
      await expectLater(invoke(), throwsA(isA<StateError>()));
      expect(sent.length, count);
    },
  );
}
