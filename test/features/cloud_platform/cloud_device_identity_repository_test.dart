import 'package:body_intelligence_log/features/cloud_platform/services/cloud_account_key_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_device_identity_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device id and registration time stay stable across owners', () async {
    final store = _MemorySecretStore();
    final repository = CloudDeviceIdentityRepository(
      secureStore: store,
      now: () => DateTime.utc(2026, 8, 17, 10),
    );

    final first = await repository.resolve('owner-a');
    final second = await repository.resolve('owner-b');

    expect(first.deviceId, isNotEmpty);
    expect(second.deviceId, first.deviceId);
    expect(second.registeredAt, first.registeredAt);
    expect(first.ownerId, 'owner-a');
    expect(second.ownerId, 'owner-b');
  });
}

final class _MemorySecretStore implements CloudSecretStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
