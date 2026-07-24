import '../domain/cloud_sync_models.dart';

final class CloudConflictResolver {
  const CloudConflictResolver();

  CloudConflict resolve({
    required CloudRecordEnvelope local,
    required CloudRecordEnvelope remote,
  }) {
    if (local.stableKey != remote.stableKey ||
        local.ownerId != remote.ownerId) {
      return CloudConflict(
        local: local,
        remote: remote,
        resolution: CloudConflictResolution.manualReview,
        reason: 'Records do not represent the same owner-scoped entity.',
      );
    }

    if (local.isTombstone != remote.isTombstone) {
      final tombstone = local.isTombstone ? local : remote;
      final live = local.isTombstone ? remote : local;
      if (!tombstone.updatedAt.isBefore(live.updatedAt)) {
        return CloudConflict(
          local: local,
          remote: remote,
          resolution: local.isTombstone
              ? CloudConflictResolution.localWins
              : CloudConflictResolution.remoteWins,
          reason: 'Newest tombstone prevents deleted data from resurrecting.',
          merged: tombstone,
        );
      }
    }

    final timeOrder = local.updatedAt.compareTo(remote.updatedAt);
    if (timeOrder != 0) {
      final winner = timeOrder > 0 ? local : remote;
      return CloudConflict(
        local: local,
        remote: remote,
        resolution: timeOrder > 0
            ? CloudConflictResolution.localWins
            : CloudConflictResolution.remoteWins,
        reason: 'Latest bounded update wins deterministically.',
        merged: winner,
      );
    }

    if (local.revision.sequence != remote.revision.sequence) {
      final localWins = local.revision.sequence > remote.revision.sequence;
      return CloudConflict(
        local: local,
        remote: remote,
        resolution: localWins
            ? CloudConflictResolution.localWins
            : CloudConflictResolution.remoteWins,
        reason: 'Higher monotonic revision wins equal-time conflict.',
        merged: localWins ? local : remote,
      );
    }

    final localWins =
        local.revision.deviceId.compareTo(remote.revision.deviceId) <= 0;
    return CloudConflict(
      local: local,
      remote: remote,
      resolution: localWins
          ? CloudConflictResolution.localWins
          : CloudConflictResolution.remoteWins,
      reason: 'Stable device identifier breaks the final deterministic tie.',
      merged: localWins ? local : remote,
    );
  }
}
