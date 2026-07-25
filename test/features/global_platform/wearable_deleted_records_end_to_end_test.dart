import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_specific_wearable_apis.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_wearable_adapters.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Credentials implements WearableCredentialBroker {
  @override
  Future<void> revoke(String providerId) async {}

  @override
  Future<WearableAuthSession> refresh(WearableAuthSession session) async =>
      session;

  @override
  Future<WearableAuthSession?> session(String providerId) async =>
      WearableAuthSession(
        providerId: providerId,
        accessTokenRef: 'native',
        refreshTokenRef: 'native',
        expiresAt: DateTime.utc(9999),
        revoked: false,
      );
}

final class _Transport implements WearableHttpTransport {
  @override
  Future<WearableHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) async => WearableHttpResponse(
    statusCode: 200,
    headers: const <String, String>{},
    body: Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'records': <Object?>[],
          'deletedIds': <String>['gone-1'],
          'anchor': 'next-anchor',
          'hasMore': false,
        }),
      ),
    ),
  );
}

void main() {
  test('native deleted IDs become durable wearable tombstones', () async {
    final store = InMemoryGlobalStore();
    await store.put(
      'wearable_record_seen',
      'appleWatch:gone-1',
      <String, Object?>{'observedAt': DateTime.utc(2026).toIso8601String()},
    );
    final adapter = ProviderWearableAdapter(
      vendor: WearableVendor.appleWatch,
      credentials: _Credentials(),
      api: AppleWatchWearableApi(_Transport()),
      store: store,
      audit: InMemoryGlobalAuditSink(),
    );

    final batch = await adapter.pull(cursor: null, asOf: DateTime.utc(2026));
    expect(batch.deletedIds, <String>['gone-1']);
    expect(
      await store.get('wearable_record_seen', 'appleWatch:gone-1'),
      isNull,
    );
    expect(
      await store.get('wearable_tombstones', 'appleWatch:gone-1'),
      isNotNull,
    );
  });
}
