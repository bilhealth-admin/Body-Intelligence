part of 'coach_memory_repository.dart';

const _memoryCloudColumns =
    'id,owner_id,kind,memory_text,status,source,confidence,learned_at,updated_at,expires_at,deleted_at';
String _memoryCheckpointKey(String id) => 'coach.memory.sync.$id.v1';

Map<String, Object?> _memoryCloudFact(Map row) => {
  'id': row['id'],
  'text': row['memory_text'],
  'kind': row['kind'],
  'status': row['status'],
  'source': row['source'],
  'confidence': row['confidence'],
  'savedAt': row['learned_at'],
  'updatedAt': row['updated_at'],
  if (row['expires_at'] != null) 'expiresAt': row['expires_at'],
};

Map<String, dynamic> _memoryCheckpoint(String? raw) {
  if (raw == null) return {};
  final value = jsonDecode(raw);
  if (value is! Map) {
    throw const FormatException('coach_memory_checkpoint_invalid');
  }
  return Map<String, dynamic>.from(value);
}

extension _CoachMemoryReadback on CoachMemoryRepository {
  Future<Map<String, dynamic>?> _readCloudMemory(
    String owner,
    String id,
  ) async {
    final value = await cloud!
        .from('bil_coach_memories')
        .select(_memoryCloudColumns)
        .eq('owner_id', owner)
        .eq('id', id)
        .maybeSingle()
        .retry(enabled: false);
    CommunityOwnerOperation.checkCurrent();
    if (value != null &&
        (value['owner_id'] != owner ||
            value['id'] != id ||
            value['memory_text'] is! String ||
            DateTime.tryParse('${value['updated_at']}') == null)) {
      throw const FormatException('coach_memory_readback_unverified');
    }
    return value;
  }

  Future<void> _syncMemoryWithReadback({
    required String owner,
    required String id,
    required Map<String, Object?>? local,
    required Map<String, Object?>? tombstone,
  }) async {
    final checkpointKey = _memoryCheckpointKey(id);
    final checkpointRaw = await preferences.get(checkpointKey);
    CommunityOwnerOperation.checkCurrent();
    final checkpoint = _memoryCheckpoint(checkpointRaw);
    Future<void> saveCheckpoint(Map<String, Object?> value) async {
      CommunityOwnerOperation.checkCurrent();
      final saved = await preferences.mutateIfUnchanged(
        expected: {checkpointKey: checkpointRaw},
        set: {checkpointKey: jsonEncode(value)},
        isCurrent: () =>
            cloud!.auth.currentUser?.id == owner &&
            preferences.localOwnerId == owner,
      );
      CommunityOwnerOperation.checkCurrent();
      if (!saved) throw StateError('coach_memory_revision_conflict');
    }

    try {
      if (local != null && checkpoint['deleted'] == true) {
        await saveCheckpoint({...checkpoint, 'state': 'conflict'});
        return;
      }
      final remote = await _readCloudMemory(owner, id);
      final remoteFact = remote == null ? null : _memoryCloudFact(remote);
      final decision = decideCoachMemorySync(
        local: local,
        remote: remoteFact,
        remoteVersion: remote?['updated_at'] as String?,
        remoteDeleted: remote?['deleted_at'] != null,
        baselineVersion:
            checkpoint['version'] as String? ??
            tombstone?['expectedCloudUpdatedAt'] as String?,
        baselineDigest:
            checkpoint['digest'] as String? ??
            tombstone?['deletedDigest'] as String?,
      );
      if (decision == CoachMemorySyncDecision.conflict) {
        await saveCheckpoint({...checkpoint, 'state': 'conflict'});
        return;
      }
      Map<String, dynamic>? verified = remote;
      final redactOldTombstone =
          local == null &&
          remote?['deleted_at'] != null &&
          remote?['memory_text'] != '[deleted]';
      if (decision != CoachMemorySyncDecision.verified || redactOldTombstone) {
        final now = DateTime.now().toUtc().toIso8601String();
        final payload = local == null
            ? <String, Object?>{
                'deleted_at': now,
                'updated_at': now,
                'memory_text': '[deleted]',
                'metadata': <String, Object?>{},
              }
            : <String, Object?>{
                'id': id,
                'owner_id': owner,
                'kind': local['kind'],
                'memory_text': local['text'],
                'status': local['status'],
                'source': local['source'],
                'confidence': local['confidence'],
                'learned_at': local['savedAt'],
                'updated_at': local['updatedAt'],
                'deleted_at': null,
                'expires_at': local['expiresAt'],
              };
        if (decision == CoachMemorySyncDecision.create) {
          await cloud!.from('bil_coach_memories').insert(payload);
        } else {
          final rows = await cloud!
              .from('bil_coach_memories')
              .update(payload)
              .eq('id', id)
              .eq('owner_id', owner)
              .eq('updated_at', remote!['updated_at'])
              .select(_memoryCloudColumns);
          CommunityOwnerOperation.checkCurrent();
          if (rows.length != 1) {
            throw StateError('coach_memory_revision_conflict');
          }
        }
        CommunityOwnerOperation.checkCurrent();
        verified = await _readCloudMemory(owner, id);
        if (verified == null ||
            (local == null
                ? verified['deleted_at'] == null ||
                      verified['memory_text'] != '[deleted]'
                : verified['deleted_at'] != null ||
                      coachMemoryFactDigest(_memoryCloudFact(verified)) !=
                          coachMemoryFactDigest(local) ||
                      !DateTime.parse(
                        verified['updated_at'] as String,
                      ).isAtSameMomentAs(
                        DateTime.parse(local['updatedAt']! as String),
                      ))) {
          throw StateError('coach_memory_write_unverified');
        }
      }
      await saveCheckpoint({
        'state': 'verified',
        'deleted': local == null,
        if (verified != null) 'version': verified['updated_at'],
        if (verified != null && local != null)
          'digest': coachMemoryFactDigest(_memoryCloudFact(verified)),
      });
    } on Object catch (error) {
      await saveCheckpoint({
        ...checkpoint,
        'state':
            error is StateError &&
                error.message == 'coach_memory_revision_conflict'
            ? 'conflict'
            : 'pending',
      });
      rethrow;
    }
  }
}
