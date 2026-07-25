import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/wearables/provider_wearable_adapters.dart';

final class _Creds implements WearableCredentialBroker {
  WearableAuthSession? value = WearableAuthSession(
    providerId: 'garmin',
    accessTokenRef: 'a',
    refreshTokenRef: 'r',
    expiresAt: DateTime.utc(2020),
    revoked: false,
  );
  var refreshes = 0;

  @override
  Future<void> revoke(String id) async => value = null;

  @override
  Future<WearableAuthSession?> session(String id) async => value;

  @override
  Future<WearableAuthSession> refresh(WearableAuthSession session) async {
    refreshes++;
    return value = WearableAuthSession(
      providerId: session.providerId,
      accessTokenRef: 'a2',
      refreshTokenRef: 'r2',
      expiresAt: DateTime.utc(2030),
      revoked: false,
    );
  }
}

final class _Api implements WearableRemoteApi {
  var calls = 0;
  final List<String?> cursors = <String?>[];

  @override
  Future<Map<String, Object?>> fetch({
    required WearableVendor vendor,
    required String accessTokenRef,
    required String? cursor,
    required DateTime asOf,
  }) async {
    calls++;
    cursors.add(cursor);
    if (calls == 1) {
      throw StateError('temporary');
    }
    return <String, Object?>{
      'records': <Map<String, Object?>>[
        <String, Object?>{
          'kind': vendor == WearableVendor.garmin ? 'body_battery' : 'steps',
          'value': 1000,
          'unit': 'count',
          'recordId': '1',
          'observedAt': asOf.toIso8601String(),
        },
      ],
      'nextCursor': 'n',
      'hasMore': false,
      'rateLimitRemaining': 100,
    };
  }
}

void main() {
  test(
    'named adapters persist cursors, retry failures and deduplicate records',
    () async {
      final store = InMemoryGlobalStore();
      final credentials = _Creds();
      final api = _Api();
      final adapters = WearableProviderCatalog.production(
        credentials: credentials,
        api: api,
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      expect(
        adapters.map((adapter) => adapter.vendor).toSet(),
        <WearableVendor>{
          WearableVendor.appleWatch,
          WearableVendor.wearOs,
          WearableVendor.garmin,
          WearableVendor.fitbit,
        },
      );
      expect(
        adapters.any((adapter) => adapter.vendor == WearableVendor.samsung),
        isFalse,
        reason:
            'Samsung must not enter the production catalog without a verified SDK adapter.',
      );
      final garmin = adapters.singleWhere((adapter) => adapter.id == 'garmin');
      final first = await garmin.pull(cursor: null, asOf: DateTime.utc(2026));
      final second = await garmin.pull(
        cursor: null,
        asOf: DateTime.utc(2026, 1, 2),
      );
      expect(credentials.refreshes, 1);
      expect(api.calls, 3);
      expect(api.cursors.last, 'n');
      expect(first.signals.single.key, 'recovery_score');
      expect(second.signals, isEmpty);
      expect((await store.get('wearable_cursor', 'garmin'))?['value'], 'n');
    },
  );
}
