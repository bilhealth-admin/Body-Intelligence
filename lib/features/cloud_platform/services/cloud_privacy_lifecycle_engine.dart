import '../domain/cloud_operational_models.dart';
import 'cloud_durable_ports.dart';

final class CloudPrivacyLifecycleEngine {
  const CloudPrivacyLifecycleEngine({required this.store, required this.auth});
  final DurableCloudStore store;
  final CloudAuthenticationProvider auth;

  Future<void> withdrawConsent(String ownerId) =>
      store.deleteOwnerData(ownerId);

  Future<void> deleteAccountAndData(String ownerId) async {
    await store.deleteOwnerData(ownerId);
    await auth.deleteAccount(ownerId);
    await store.upsertAccount(
      CloudAccount(
        ownerId: ownerId,
        email: 'deleted@redacted.invalid',
        status: CloudAccountStatus.deleted,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        deletedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
