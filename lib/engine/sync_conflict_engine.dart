class SyncRecordMetadata {
  const SyncRecordMetadata({
    required this.revision,
    required this.updatedAt,
    required this.deleted,
  });
  final int revision;
  final DateTime updatedAt;
  final bool deleted;
}

enum SyncWinner { local, remote, equal }

class SyncConflictEngine {
  const SyncConflictEngine._();

  static SyncWinner resolve({
    required SyncRecordMetadata local,
    required SyncRecordMetadata remote,
  }) {
    if (local.revision != remote.revision) {
      return local.revision > remote.revision
          ? SyncWinner.local
          : SyncWinner.remote;
    }
    if (local.deleted != remote.deleted) {
      return local.deleted ? SyncWinner.local : SyncWinner.remote;
    }
    final comparison = local.updatedAt.compareTo(remote.updatedAt);
    if (comparison == 0) return SyncWinner.equal;
    return comparison > 0 ? SyncWinner.local : SyncWinner.remote;
  }
}
