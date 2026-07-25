import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
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
        accessTokenRef: 'token',
        refreshTokenRef: 'refresh',
        expiresAt: DateTime.utc(9999),
        revoked: false,
      );
}

final class _Api implements WearableRemoteApi {
  @override
  Future<Map<String, Object?>> fetch({
    required WearableVendor vendor,
    required String accessTokenRef,
    required String? cursor,
    required DateTime asOf,
  }) async => const <String, Object?>{
    'records': <Object?>[],
    'deletedIds': <Object?>[],
    'hasMore': false,
  };
}

void main() {
  test(
    'production catalog cannot reintroduce unimplemented Samsung provider',
    () {
      final adapters = WearableProviderCatalog.production(
        credentials: _Credentials(),
        api: _Api(),
        store: InMemoryGlobalStore(),
        audit: InMemoryGlobalAuditSink(),
      );
      expect(adapters, hasLength(4));
      expect(
        adapters.map((adapter) => adapter.vendor),
        isNot(contains(WearableVendor.samsung)),
      );
    },
  );
}
