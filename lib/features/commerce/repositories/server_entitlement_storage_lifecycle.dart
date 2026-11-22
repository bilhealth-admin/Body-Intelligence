part of 'server_entitlement_repository.dart';

extension _ServerEntitlementStorageLifecycle on ServerEntitlementRepository {
  // A read can delete an invalid slot. Serialize its complete operation with
  // accepted writes and revocations so old cleanup cannot erase a newer lease.
  Future<T> _withAdminStorage<T>(
    String ownerId,
    Future<T> Function() operation,
  ) async {
    final previous =
        ServerEntitlementRepository._adminStorageOperations[ownerId];
    final next = previous == null
        ? Future<T>.sync(operation)
        : previous.then<T>((_) => operation());
    // Only the queue barrier absorbs errors; this caller still receives next.
    final settled = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    ServerEntitlementRepository._adminStorageOperations[ownerId] = settled;
    try {
      return await next;
    } finally {
      if (identical(
        ServerEntitlementRepository._adminStorageOperations[ownerId],
        settled,
      )) {
        ServerEntitlementRepository._adminStorageOperations.remove(ownerId);
      }
    }
  }

  Future<bool> _clearRejectedSession(String ownerId) async {
    ServerEntitlementRepository._startupContinuityConsumed.add(ownerId);
    ServerEntitlementRepository._settledAdminReads[ownerId] =
        ++ServerEntitlementRepository._adminReadGeneration;
    final denied = FreePlan.createState();
    final now = _now();
    for (final cache in [
      ServerEntitlementRepository._sessionCache,
      ServerEntitlementRepository._adminSessionCache,
      ServerEntitlementRepository._closedTestSessionCache,
    ]) {
      cache.remember(ownerId: ownerId, state: denied, now: now);
    }
    try {
      await Future.wait([
        _subscriptionStore.clear(ownerId),
        _withAdminStorage(ownerId, () => _adminContinuityStore.clear(ownerId)),
      ]);
      return true;
    } on Object {
      return false;
    }
  }
}
