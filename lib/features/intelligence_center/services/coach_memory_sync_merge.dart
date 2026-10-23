part of 'coach_memory_repository.dart';

extension _CoachMemoryMerge on CoachMemoryRepository {
  Future<void> _mergeMemoryCloudWithCheckpoints() async {
    final client = cloud;
    final owner = client?.auth.currentUser?.id;
    if (client == null || owner == null || !await _remoteAiAllowed()) return;
    CommunityOwnerOperation.checkCurrent();
    final before = _strictMemoryEntries(
      await preferences.get(CoachMemoryRepository.storageKey),
    );
    CommunityOwnerOperation.checkCurrent();
    final active = await client
        .from('bil_coach_memories')
        .select(_memoryCloudColumns)
        .eq('owner_id', owner)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(50)
        .retry(enabled: false);
    CommunityOwnerOperation.checkCurrent();
    final rows = <String, Map<String, dynamic>>{};
    void addRows(List<Map<String, dynamic>> values) {
      for (final row in values) {
        if (row['owner_id'] != owner ||
            row['id'] is! String ||
            row['memory_text'] is! String ||
            DateTime.tryParse('${row['updated_at']}') == null) {
          throw const FormatException('coach_memory_readback_unverified');
        }
        rows[row['id'] as String] = row;
      }
    }

    addRows(active);
    // Retrieve tombstones for every locally held fact. Each bounded query has
    // different IDs and advances an explicit offset; errors stop the pass.
    final ids = before
        .where((entry) => entry['status'] != 'deleted')
        .map((entry) => entry['id']! as String)
        .toList(growable: false);
    final started = DateTime.now();
    for (var offset = 0; offset < ids.length; offset += 50) {
      if (DateTime.now().difference(started) > const Duration(seconds: 15)) {
        throw StateError('coach_memory_sync_deadline');
      }
      final known = await client
          .from('bil_coach_memories')
          .select(_memoryCloudColumns)
          .eq('owner_id', owner)
          .inFilter('id', ids.skip(offset).take(50).toList(growable: false))
          .limit(50)
          .retry(enabled: false);
      CommunityOwnerOperation.checkCurrent();
      addRows(known);
    }
    final currentRaw = await preferences.get(CoachMemoryRepository.storageKey);
    CommunityOwnerOperation.checkCurrent();
    final current = _strictMemoryEntries(currentRaw);
    final byId = {for (final entry in current) entry['id']! as String: entry};
    final expected = <String, String?>{
      CoachMemoryRepository.storageKey: currentRaw,
    };
    final changes = <String, String>{};
    for (final row in rows.values) {
      final id = row['id']! as String;
      final key = _memoryCheckpointKey(id);
      final raw = await preferences.get(key);
      CommunityOwnerOperation.checkCurrent();
      expected[key] = raw;
      final base = _memoryCheckpoint(raw);
      final prior = byId[id];
      if (prior?['status'] == 'deleted' ||
          (prior == null && base['deleted'] == true)) {
        continue;
      }
      final fact = _memoryCloudFact(row);
      final remoteDigest = coachMemoryFactDigest(fact);
      final localDigest = prior == null ? null : coachMemoryFactDigest(prior);
      if (row['deleted_at'] != null) {
        if (prior != null && base['digest'] == localDigest) {
          byId[id] = _memoryDeletionTombstone(prior);
          changes[key] = jsonEncode({
            'state': 'verified',
            'deleted': true,
            'version': row['updated_at'],
          });
        } else if (prior != null) {
          changes[key] = jsonEncode({...base, 'state': 'conflict'});
        }
        continue;
      }
      if (prior == null ||
          localDigest == remoteDigest ||
          base['digest'] == localDigest) {
        byId[id] = localDigest == remoteDigest ? prior! : fact;
        changes[key] = jsonEncode({
          'state': 'verified',
          'deleted': false,
          'version': row['updated_at'],
          'digest': remoteDigest,
        });
      } else {
        final sameBase =
            base['digest'] == remoteDigest &&
            base['version'] != null &&
            DateTime.parse(
              base['version'] as String,
            ).isAtSameMomentAs(DateTime.parse(row['updated_at'] as String));
        changes[key] = jsonEncode({
          ...base,
          'state': sameBase ? 'pending' : 'conflict',
        });
      }
    }
    final merged = byId.values.toList()
      ..sort(
        (a, b) =>
            '${b['updatedAt'] ?? ''}'.compareTo('${a['updatedAt'] ?? ''}'),
      );
    changes[CoachMemoryRepository.storageKey] = jsonEncode(
      _retainMemoryState(merged),
    );
    final saved = await preferences.mutateIfUnchanged(
      expected: expected,
      set: changes,
      isCurrent: () =>
          client.auth.currentUser?.id == owner &&
          preferences.localOwnerId == owner,
    );
    CommunityOwnerOperation.checkCurrent();
    if (!saved) return;
    // One pending operation per merge, with actual readback. No tight retry
    // loop over an unavailable transport or a conflicting remote revision.
    final ordered = [
      ...merged.where((entry) => entry['status'] == 'deleted'),
      ...merged.where((entry) => entry['status'] != 'deleted'),
    ];
    for (final entry in ordered) {
      final id = entry['id']! as String;
      final base = _memoryCheckpoint(
        await preferences.get(_memoryCheckpointKey(id)),
      );
      CommunityOwnerOperation.checkCurrent();
      if (const {'verified', 'conflict'}.contains(base['state'])) continue;
      await syncCommittedChange(
        id: id,
        expectedLocal: entry['status'] == 'deleted' ? null : entry,
      );
      break;
    }
  }
}
