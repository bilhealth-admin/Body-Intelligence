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
          final current = matching.isEmpty ? null : matching.single;
          if (!_sameMemoryJson(current, expectedLocal)) return;
          if (expectedLocal == null) {
            await client
                .from('bil_coach_memories')
                .update({
                  'deleted_at': DateTime.now().toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('id', id)
                .eq('owner_id', ownerId);
          } else {
            await client.from('bil_coach_memories').upsert({
              'id': id,
              'owner_id': ownerId,
              'kind': expectedLocal['kind'],
              'memory_text': expectedLocal['text'],
              'status': expectedLocal['status'],
              'source': expectedLocal['source'],
              'confidence': expectedLocal['confidence'],
              'learned_at': expectedLocal['savedAt'],
              'updated_at': expectedLocal['updatedAt'],
              'deleted_at': null,
            });
          }
          CommunityOwnerOperation.checkCurrent();
        },
        isCurrentOwner: isCurrentOwner,
        beforeDataSend: () async {
          final entries = _strictMemoryEntries(
            await preferences.get(CoachMemoryRepository.storageKey),
          );
          final matching = entries.where((entry) => entry['id'] == id);
          final current = matching.isEmpty ? null : matching.single;
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
