import 'dart:convert';
import 'dart:typed_data';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_specific_wearable_apis.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_wearable_adapters.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/wearables_platform.dart';
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
  }) async {
    return WearableHttpResponse(
      statusCode: 200,
      headers: const <String, String>{},
      body: Uint8List.fromList(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'records': <Object?>[
              <String, Object?>{
                'id': 'step-1',
                'type': 'steps',
                'value': 8000,
                'unit': 'count',
                'observedAt': '2026-01-01T10:00:00.000Z',
                'sourceId': 'watch',
                'deviceId': 'apple-watch',
                'confidence': .95,
              },
            ],
            'deletedIds': <String>['deleted-1'],
            'anchor': 'anchor-2',
            'changeToken': 'token-2',
            'hasMore': false,
          }),
        ),
      ),
    );
  }
}

void main() {
  test(
    'native payload traverses adapter runtime store cursor tombstone and evidence',
    () async {
      final store = InMemoryGlobalStore();
      final audit = InMemoryGlobalAuditSink();
      final adapter = ProviderWearableAdapter(
        vendor: WearableVendor.appleWatch,
        credentials: _Credentials(),
        api: AppleWatchWearableApi(_Transport()),
        store: store,
        audit: audit,
      );
      final runtime = WearableRuntime(
        providers: <WearableProvider>[adapter],
        store: store,
        audit: audit,
      );
      final result = await runtime.synchronize(DateTime.utc(2026, 1, 2));
      expect(result.single.key, 'steps');
      expect(
        (await store.get('wearable_cursor', 'appleWatch'))?['value'],
        'anchor-2',
      );
      expect(
        await store.get('wearable_tombstones', 'appleWatch:deleted-1'),
        isNotNull,
      );
      expect(
        audit.events.any((event) => event.action == 'wearables.synchronized'),
        isTrue,
      );
    },
  );
}
