import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/platform_wearable_transports.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_specific_wearable_apis.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_wearable_adapters.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/wearables_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _NeverRemote implements WearableHttpTransport {
  @override
  Future<WearableHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Uint8List? body,
  }) => throw StateError('remote_transport_must_not_run');
}

final class _NativeCredentials implements WearableCredentialBroker {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native payload reaches runtime and durable store without field loss',
    () async {
      const channel = MethodChannel('bil.test/native-wearable-e2e');
      final calls = <MethodCall>[];
      var page = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            final arguments = Map<Object?, Object?>.from(call.arguments as Map);
            expect(arguments.containsKey('types'), isFalse);
            page++;
            if (page == 1) {
              return <String, Object?>{
                'records': <Object?>[
                  <String, Object?>{
                    'kind': 'steps',
                    'value': 1234,
                    'unit': 'count',
                    'recordId': 'apple-1',
                    'sourceId': 'watch-series',
                    'deviceId': 'watch-device',
                    'observedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
                    'confidence': .96,
                  },
                ],
                'deletedIds': <Object?>['deleted-1'],
                'nextAnchor': 'anchor-2',
                'hasMore': true,
              };
            }
            expect(arguments['anchor'], 'anchor-2');
            return <String, Object?>{
              'records': <Object?>[
                <String, Object?>{
                  'kind': 'heart_rate',
                  'value': 72,
                  'unit': 'bpm',
                  'recordId': 'apple-2',
                  'sourceId': 'watch-series',
                  'deviceId': 'watch-device',
                  'observedAt': DateTime.utc(
                    2026,
                    1,
                    1,
                    0,
                    5,
                  ).toIso8601String(),
                  'confidence': .94,
                },
              ],
              'deletedIds': <Object?>[],
              'nextAnchor': 'anchor-final',
              'hasMore': false,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final store = InMemoryGlobalStore();
      await store.put(
        'wearable_record_seen',
        'appleWatch:deleted-1',
        <String, Object?>{'observedAt': DateTime.utc(2025).toIso8601String()},
      );
      final adapter = ProviderWearableAdapter(
        vendor: WearableVendor.appleWatch,
        credentials: _NativeCredentials(),
        api: AppleWatchWearableApi(
          PlatformAwareWearableTransport(
            remote: _NeverRemote(),
            appleChannel: channel,
          ),
        ),
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      final runtime = WearableRuntime(
        providers: <WearableProvider>[adapter],
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );

      final signals = await runtime.synchronize(DateTime.utc(2026, 1, 2));
      expect(calls, hasLength(2));
      expect(signals.map((signal) => signal.key).toSet(), <String>{
        'steps',
        'heart_rate',
      });
      expect(
        (await store.get('wearable_cursor', 'appleWatch'))?['value'],
        'anchor-final',
      );
      expect(
        await store.get('wearable_tombstones', 'appleWatch:deleted-1'),
        isNotNull,
      );
      expect(
        await store.get('wearable_record_seen', 'appleWatch:deleted-1'),
        isNull,
      );
    },
  );

  test('Wear OS change token is preserved across pagination', () async {
    const channel = MethodChannel('bil.test/wear-os-e2e');
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          expect(arguments.containsKey('types'), isFalse);
          calls++;
          if (calls == 1) {
            return <String, Object?>{
              'records': <Object?>[],
              'deletedIds': <Object?>['hc-deleted'],
              'nextAnchor': 'token-2',
              'hasMore': true,
            };
          }
          expect(arguments['anchor'], 'token-2');
          return <String, Object?>{
            'records': <Object?>[],
            'deletedIds': <Object?>[],
            'nextAnchor': 'token-final',
            'hasMore': false,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final store = InMemoryGlobalStore();
    final adapter = ProviderWearableAdapter(
      vendor: WearableVendor.wearOs,
      credentials: _NativeCredentials(),
      api: WearOsWearableApi(
        PlatformAwareWearableTransport(
          remote: _NeverRemote(),
          androidChannel: channel,
        ),
      ),
      store: store,
      audit: InMemoryGlobalAuditSink(),
    );
    await WearableRuntime(
      providers: <WearableProvider>[adapter],
      store: store,
      audit: InMemoryGlobalAuditSink(),
    ).synchronize(DateTime.utc(2026, 1, 2));

    expect(calls, 2);
    expect(
      (await store.get('wearable_cursor', 'wearOs'))?['value'],
      'token-final',
    );
    expect(
      await store.get('wearable_tombstones', 'wearOs:hc-deleted'),
      isNotNull,
    );
  });
}
