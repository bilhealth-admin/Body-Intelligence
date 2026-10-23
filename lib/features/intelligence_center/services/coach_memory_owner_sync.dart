part of 'coach_memory_repository.dart';

extension _CoachMemoryOwner on CoachMemoryRepository {
  Future<T> _runForMemoryOwner<T>(
    Future<T> Function() action, {
    bool Function()? isCurrentOwner,
    Future<void> Function()? beforeDataSend,
  }) async {
    final client = cloud;
    if (isCurrentOwner?.call() == false) {
      throw const CommunityOwnerOperationCancelled();
    }
    if (client == null) {
      if (isCurrentOwner?.call() == false) {
        throw const CommunityOwnerOperationCancelled();
      }
      final result = await action();
      if (isCurrentOwner?.call() == false) {
        throw const CommunityOwnerOperationCancelled();
      }
      return result;
    }
    return CommunityOwnerOperation.run(
      client: client,
      ownerId: preferences.localOwnerId,
      isCurrentOwner: isCurrentOwner,
      beforeDataSend: beforeDataSend,
      action: (_) => action(),
    );
  }
}

extension CoachMemoryCommittedSync on CoachMemoryRepository {
  /// Synchronization follows a committed local snapshot. Its owner is captured
  /// before consent or token refresh, and the application transport checks the
  /// same inherited lifetime immediately before sending the data request.
  Future<void> syncCommittedChange({
    required String id,
    required Map<String, Object?>? expectedLocal,
    bool Function()? isCurrentOwner,
  }) async {
    final client = cloud;
    final ownerId = preferences.localOwnerId;
    if (expectedLocal == null && ownerId != null) {
      try {
        await _runForMemoryOwner(() async {
          await preferences.update(CoachMemoryRepository.storageKey, (raw) {
            CommunityOwnerOperation.checkCurrent();
            final entries = _strictMemoryEntries(raw);
            if (entries.any((entry) => entry['id'] == id)) return raw ?? '[]';
            return jsonEncode(
              _retainMemoryState([
                ...entries,
                {
                  'id': id,
                  'text': '',
                  'status': 'deleted',
                  'source': 'local_privacy_deletion',
                  'updatedAt': DateTime.now().toUtc().toIso8601String(),
                },
              ]),
            );
          });
        }, isCurrentOwner: isCurrentOwner);
      } on Object {
        return;
      }
    }
    if (client == null || ownerId == null) return;
    try {
      await _runForMemoryOwner(
        () async {
          if (!await _remoteAiAllowed()) return;
          CommunityOwnerOperation.checkCurrent();
          final entries = _strictMemoryEntries(
            await preferences.get(CoachMemoryRepository.storageKey),
          );
          CommunityOwnerOperation.checkCurrent();
          final matching = entries.where((entry) => entry['id'] == id);
          final current =
              matching.isEmpty || matching.single['status'] == 'deleted'
              ? null
              : matching.single;
          if (!_sameMemoryJson(current, expectedLocal)) return;
          await _syncMemoryWithReadback(
            owner: ownerId,
            id: id,
            local: expectedLocal,
            tombstone:
                matching.isNotEmpty && matching.single['status'] == 'deleted'
                ? matching.single
                : null,
          );
          CommunityOwnerOperation.checkCurrent();
        },
        isCurrentOwner: isCurrentOwner,
        beforeDataSend: () async {
          final entries = _strictMemoryEntries(
            await preferences.get(CoachMemoryRepository.storageKey),
          );
          final matching = entries.where((entry) => entry['id'] == id);
          final current =
              matching.isEmpty || matching.single['status'] == 'deleted'
              ? null
              : matching.single;
          if (!_sameMemoryJson(current, expectedLocal)) {
            throw const CommunityOwnerOperationCancelled();
          }
        },
      );
    } on Object {
      // The local journal/readback remains authoritative when optional sync
      // cannot finish. An owner cancellation must never move this data to B.
    }
  }
}

List<Map<String, Object?>> _strictMemoryEntries(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  final data = jsonDecode(raw);
  if (data is! List) throw const FormatException('Invalid memory collection');
  return data
      .map((entry) {
        if (entry is! Map ||
            entry['id'] is! String ||
            entry['text'] is! String) {
          throw const FormatException('Invalid memory entry');
        }
        return Map<String, Object?>.from(entry);
      })
      .toList(growable: true);
}

bool _sameMemoryJson(Object? a, Object? b) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList(growable: false);
    return value;
  }

  return jsonEncode(canonical(a)) == jsonEncode(canonical(b));
}

Map<String, Object?> _memoryDeletionTombstone(Map<String, Object?> entry) => {
  'id': entry['id'],
  'text': '',
  'status': 'deleted',
  'source': 'local_privacy_deletion',
  'updatedAt': DateTime.now().toUtc().toIso8601String(),
  if (entry['updatedAt'] != null) 'expectedCloudUpdatedAt': entry['updatedAt'],
  'deletedDigest': coachMemoryFactDigest(entry),
};

List<Map<String, Object?>> _retainMemoryState(
  List<Map<String, Object?>> entries,
) {
  final pending = entries
      .where((entry) => entry['status'] == 'deleted')
      .toList(growable: false);
  if (pending.length > 1000) {
    throw StateError('coach_memory_deletion_queue_full');
  }
  final active = entries
      .where((entry) => entry['status'] != 'deleted')
      .toList(growable: false);
  if (active.length > 1000) throw StateError('coach_memory_storage_full');
  return [...active, ...pending];
}
