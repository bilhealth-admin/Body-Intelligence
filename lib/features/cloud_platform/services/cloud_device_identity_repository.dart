import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/cloud_identity_models.dart';
import 'cloud_account_key_repository.dart';

/// Stable per-install device identity used by the cloud revision ledger.
///
/// The id is not a credential, but it is stored in the same platform-backed
/// secure store so reinstall/account-switch behavior cannot accidentally reuse
/// another app's preferences namespace.
final class CloudDeviceIdentityRepository {
  CloudDeviceIdentityRepository({
    CloudSecretStore? secureStore,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _secureStore = secureStore ?? FlutterSecureCloudSecretStore(),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? DateTime.now;

  static const _deviceIdKey = 'bil.cloud.device-id.v1';
  static const _registeredAtKey = 'bil.cloud.device-registered-at.v1';

  final CloudSecretStore _secureStore;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<CloudDeviceRegistration> resolve(String ownerId) async {
    final owner = ownerId.trim();
    if (owner.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty');
    }

    var deviceId = (await _secureStore.read(_deviceIdKey))?.trim();
    if (deviceId == null || deviceId.length < 3) {
      deviceId = _uuid.v4();
      await _secureStore.write(_deviceIdKey, deviceId);
    }

    final storedRegisteredAt = await _secureStore.read(_registeredAtKey);
    var registeredAt = storedRegisteredAt == null
        ? null
        : DateTime.tryParse(storedRegisteredAt)?.toUtc();
    if (registeredAt == null) {
      registeredAt = _now().toUtc();
      await _secureStore.write(
        _registeredAtKey,
        registeredAt.toIso8601String(),
      );
    }

    return CloudDeviceRegistration(
      deviceId: deviceId,
      ownerId: owner,
      displayName: _platformName(),
      registeredAt: registeredAt,
    );
  }

  static String _platformName() => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android device',
    TargetPlatform.iOS => 'iPhone or iPad',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.windows => 'Windows device',
    TargetPlatform.linux => 'Linux device',
    TargetPlatform.fuchsia => 'BIL device',
  };
}
