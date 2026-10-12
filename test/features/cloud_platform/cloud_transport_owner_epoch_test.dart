import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_identity_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/supabase_cloud_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_account_key_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/supabase_startup_cloud_profile_reader.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../community/support/community_rewards_rpc_fixture.dart';

class _Secret implements CloudSecretStore {
  @override
  Future<String?> read(String key) async =>
      base64Encode(List.generate(32, (i) => i));
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late Completer<void> entered, release;
  var calls = 0;
  setUp(() async {
    entered = Completer<void>();
    release = Completer<void>();
    calls = 0;
    client = SupabaseClient(
      'https://cloud-owner.invalid',
      'synthetic-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: CommunityOwnerHttpClient(
        MockClient((request) async {
          calls++;
          expect(
            request.url.path,
            anyOf(
              '/rest/v1/rpc/bil_sync_records',
              '/rest/v1/bil_cloud_records',
            ),
          );
          entered.complete();
          await release.future;
          return http.Response(
            request.url.path.endsWith('/bil_cloud_records')
                ? '[]'
                : jsonEncode({
                    'records': [],
                    'acknowledged': [],
                    'cursor': 0,
                    'has_more': false,
                  }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    await client.auth.recoverSession(
      jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
    );
  });
  tearDown(() async {
    if (!release.isCompleted) release.complete();
    await client.dispose();
  });
  Future<Object> run() => SupabaseCloudTransport(client).synchronize(
    ownerId: rewardsOwnerA,
    deviceId: 'synthetic-device',
    operations: [],
    cursor: null,
    session: CloudSession(
      sessionId: 'synthetic-session',
      ownerId: rewardsOwnerA,
      deviceId: 'synthetic-device',
      issuedAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
  );

  for (final startup in [false, true]) {
    for (final aba in [false, true]) {
      test(
        'a pending cloud response is retired on account transition startup=$startup ABA=$aba',
        () async {
          final future = startup
              ? SupabaseStartupCloudProfileReader(
                  client: client,
                  keyRepository: CloudAccountKeyRepository(
                    client: client,
                    secureStore: _Secret(),
                  ),
                ).readRestoreRecords(rewardsOwnerA)
              : run();
          final assertion = expectLater(
            future,
            throwsA(isA<CommunityOwnerOperationCancelled>()),
          );
          await entered.future;
          await client.auth.recoverSession(
            jsonEncode(RewardsRpcFixture.session(rewardsOwnerB)),
          );
          if (aba) {
            await client.auth.recoverSession(
              jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
            );
          }
          release.complete();
          await assertion;
          expect(calls, 1);
        },
      );
    }
  }
  test(
    'same-owner token restoration retains a valid pending response',
    () async {
      final future = run();
      await entered.future;
      await client.auth.recoverSession(
        jsonEncode(RewardsRpcFixture.session(rewardsOwnerA)),
      );
      release.complete();
      await expectLater(future, completes);
      expect(calls, 1);
    },
  );
}
