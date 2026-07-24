import '../domain/cloud_identity_models.dart';
import '../domain/cloud_operational_models.dart';
import 'cloud_durable_ports.dart';

final class CloudIdentityRuntime {
  const CloudIdentityRuntime({required this.store, required this.auth});
  final DurableCloudStore store;
  final CloudAuthenticationProvider auth;

  Future<CloudAccount> createAccount({
    required String email,
    required String secret,
  }) async {
    final account = await auth.signUp(email: email, secret: secret);
    await store.upsertAccount(account);
    return account;
  }

  Future<CloudSession> signIn({
    required String email,
    required String secret,
    required CloudDeviceRegistration device,
  }) async {
    await store.upsertDevice(device);
    return auth.signIn(email: email, secret: secret, deviceId: device.deviceId);
  }

  Future<void> revokeDevice(String deviceId, DateTime at) =>
      store.revokeDevice(deviceId, at);

  Future<void> requestDeletion(String ownerId) async {
    final current = await store.readAccount(ownerId);
    if (current == null) throw StateError('Account not found.');
    await store.upsertAccount(
      CloudAccount(
        ownerId: current.ownerId,
        email: current.email,
        status: CloudAccountStatus.pendingDeletion,
        createdAt: current.createdAt,
      ),
    );
    await auth.disableAccount(ownerId);
  }
}
