import 'dart:convert';
import 'dart:io';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_identity_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/supabase_cloud_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../community/support/community_rewards_rpc_fixture.dart';
import 'fixtures/release32_35_cloud_wire.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases =
      jsonDecode(
            File(
              'supabase/tests/fixtures/cloud_ledger_baseline/local_postgres_responses.json',
            ).readAsStringSync(),
          )
          as List;
  for (final raw in cases) {
    final row = raw as Map;
    test(
      'actual release parser and current SDK preserve native PostgreSQL ${row['client']}/${row['schema']} reply',
      () async {
        final operation = Map<String, Object?>.from(row['operation'] as Map);
        final response = Map<String, Object?>.from(row['response'] as Map);
        final id = (operation['record'] as Map)['record_id'];
        final actualRow = (response['records'] as List).cast<Map>().singleWhere(
          (r) => r['record_id'] == id,
        );
        final legacy = Release32CloudWire.decode(
          Map<String, Object?>.from(actualRow),
        );
        final now = DateTime.now().toUtc();
        final mutation = CloudSyncOperation(
          operationId: operation['operation_id'] as String,
          mutation: CloudMutationKind.upsert,
          record: legacy,
          createdAt: now,
        );
        var requests = 0;
        final client = SupabaseClient(
          'https://legacy-cloud.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests++;
            final body = jsonDecode(request.body) as Map;
            expect(body['p_device_id'], legacy.revision.deviceId);
            expect(body['p_operations'], [Release32CloudWire.encode(mutation)]);
            return http.Response(
              jsonEncode(response),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        try {
          await client.auth.recoverSession(
            jsonEncode(RewardsRpcFixture.session(legacy.ownerId)),
          );
          final result = await SupabaseCloudTransport(client).synchronize(
            ownerId: legacy.ownerId,
            deviceId: legacy.revision.deviceId,
            operations: [mutation],
            cursor: null,
            session: CloudSession(
              sessionId: 'synthetic',
              ownerId: legacy.ownerId,
              deviceId: legacy.revision.deviceId,
              issuedAt: now,
              expiresAt: now.add(const Duration(hours: 1)),
            ),
          );
          final current = result.remoteRecords.singleWhere(
            (r) => r.recordId == id,
          );
          expect(current.payload, legacy.payload);
          expect(current.ownerId, legacy.ownerId);
          expect(current.schemaVersion, legacy.schemaVersion);
          expect(current.updatedAt, legacy.updatedAt);
          expect(result.acknowledgedOperationIds, [operation['operation_id']]);
          expect(result.hasMore, isFalse);
          expect(requests, 1);
        } finally {
          await client.dispose();
        }
      },
    );
  }
}
