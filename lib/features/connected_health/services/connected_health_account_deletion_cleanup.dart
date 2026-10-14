import '../../global_platform/persistence/owner_scoped_health_store.dart';
import '../../global_platform/runtime/global_product_composition_root.dart';

/// Clears BIL's local, account-scoped health cache after the server accepts an
/// account-deletion request. This does not modify Apple Health or Health
/// Connect records owned by the operating system.
Future<void> clearConnectedHealthCacheForAccountDeletion({
  required String ownerId,
  required String? Function() readCurrentOwnerId,
}) async {
  final host = GlobalNativeIntegrationHost.instance;
  await host.initialize();
  final inner = host.productFlows?.store;
  if (inner == null) {
    throw StateError('global_product_flows_not_initialized');
  }

  await OwnerScopedHealthStore(
    inner: inner,
    ownerId: ownerId,
    readCurrentOwnerId: readCurrentOwnerId,
  ).clearForAccountDeletion();
}
