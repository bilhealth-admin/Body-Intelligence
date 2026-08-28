import '../domain/cloud_sync_models.dart';

abstract interface class StartupCloudProfileReader {
  Future<CloudRecordEnvelope?> readLatestProfile(String ownerId);
}

typedef StartupOwnerReader = String? Function();
typedef StartupBoundOwnerReader = Future<String?> Function();
typedef StartupLocalProfileReader = Future<bool> Function();
typedef StartupLocalProfileApplier =
    Future<bool> Function(CloudRecordEnvelope profile);

/// A bounded, profile-only recovery used before startup routing.
///
/// The remote side is read-only. This coordinator never starts general cloud
/// synchronization and re-checks both session and local ownership immediately
/// before the one allowed mutation: restoring the decrypted profile into the
/// matching device-local database.
final class StartupCloudProfileRestoreService {
  const StartupCloudProfileRestoreService({
    required this.currentOwnerId,
    required this.readBoundOwnerId,
    required this.hasLocalProfile,
    required this.reader,
    required this.applyLocalProfile,
    this.timeout = const Duration(seconds: 6),
  });

  final StartupOwnerReader currentOwnerId;
  final StartupBoundOwnerReader readBoundOwnerId;
  final StartupLocalProfileReader hasLocalProfile;
  final StartupCloudProfileReader reader;
  final StartupLocalProfileApplier applyLocalProfile;
  final Duration timeout;

  Future<bool> restore(String ownerId) async {
    final owner = ownerId.trim();
    if (owner.isEmpty || timeout <= Duration.zero) return false;
    try {
      return await _restore(owner).timeout(timeout);
    } on Object {
      // Startup is local-first: timeout, offline, missing key, malformed remote
      // data, or a session switch simply leaves onboarding routing in control.
      return false;
    }
  }

  Future<bool> _restore(String ownerId) async {
    if (currentOwnerId() != ownerId) return false;
    if (await readBoundOwnerId() != ownerId) return false;
    if (await hasLocalProfile()) return true;

    final profile = await reader.readLatestProfile(ownerId);
    if (profile == null ||
        profile.ownerId != ownerId ||
        profile.entityKind != CloudEntityKind.profile ||
        profile.isTombstone) {
      return false;
    }

    // The account may change while the network read is in flight.
    if (currentOwnerId() != ownerId ||
        await readBoundOwnerId() != ownerId ||
        await hasLocalProfile()) {
      return false;
    }
    return applyLocalProfile(profile);
  }
}
