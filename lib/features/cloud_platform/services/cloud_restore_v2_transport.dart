/// V2 never falls back to V1: old clients keep their unchanged wire contract.
abstract interface class CloudRestoreV2Transport {
  Future<Map<String, Object?>> capabilities();
  Future<Map<String, Object?>> consent();
  Future<Map<String, Object?>> exchange({
    required String deviceId,
    required String scope,
    required int cursor,
    required List<Map<String, Object?>> operations,
    required int limit,
  });
}
