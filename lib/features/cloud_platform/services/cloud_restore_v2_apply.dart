part of 'cloud_restore_v2_engine.dart';

extension _CloudRestoreApplication on CloudRestoreV2Engine {
  Future<CloudNutritionSnapshot> _decodeRecord(
    Map<String, Object?> record,
    String scope,
  ) async {
    if (record['owner_id'] != ownerId ||
        record['scope'] != scope ||
        record['payload_version'] != 2 ||
        record['server_revision'] is! int ||
        (record['server_revision']! as int) < 1 ||
        record['deleted'] is! bool ||
        record['payload'] is! Map) {
      throw const _RestoreFailure('unsupported_record');
    }
    final payload = Map<String, Object?>.from(record['payload']! as Map);
    if (payload['key_id'] != keyId) {
      throw const _RestoreFailure('key_version_unavailable');
    }
    final clear = await cipher.decrypt(payload);
    _guard();
    for (final field in [
      'owner_id',
      'scope',
      'record_type',
      'record_id',
      'deleted',
      'payload_version',
    ]) {
      if (clear[field] != record[field]) {
        throw const _RestoreFailure('cipher_binding_mismatch');
      }
    }
    if (clear['key_id'] != keyId || clear['snapshot'] is! Map) {
      throw const _RestoreFailure('cipher_binding_mismatch');
    }
    final snapshot = CloudNutritionSnapshot.fromJson(
      Map<String, Object?>.from(clear['snapshot']! as Map),
    );
    if (snapshot.scope != scope ||
        snapshot.type != record['record_type'] ||
        snapshot.id != record['record_id'] ||
        snapshot.deleted != record['deleted']) {
      throw const _RestoreFailure('cipher_binding_mismatch');
    }
    return snapshot;
  }

  Future<bool> _installRecord(Map<String, Object?> record, String scope) async {
    final snapshot = await _decodeRecord(record, scope);
    final row =
        await journal.entry(snapshot.key) ??
        RestoreJournalEntry(
          scope: snapshot.scope,
          type: snapshot.type,
          id: snapshot.id,
        );
    final revision = record['server_revision']! as int;
    if (revision < row.revision) return false;
    final current = await codec.capture(
      scopes: {scope},
      recordType: snapshot.type,
      recordId: snapshot.id,
    );
    final matches = current.where((value) => value.key == snapshot.key);
    final local = matches.isEmpty ? null : matches.single;
    final localFingerprint = local != null
        ? snapshotFingerprint(local)
        : row.baseline == null
        ? null
        : snapshotFingerprint(
            row.type == 'goals'
                ? codec.emptyGoalsSnapshot()
                : CloudNutritionSnapshot(
                    scope: row.scope,
                    type: row.type,
                    id: row.id,
                    deleted: true,
                    data: const {},
                  ),
          );
    final incomingFingerprint = snapshotFingerprint(snapshot);
    if (row.conflict == null &&
        revision == row.revision &&
        row.baseline == incomingFingerprint &&
        localFingerprint != incomingFingerprint) {
      // Our acknowledged upload is already the trusted base. A newer local
      // edit needs the next CAS operation, not a conflict with our own upload.
      return false;
    }
    if (localFingerprint == incomingFingerprint &&
        (row.pendingSnapshot == null ||
            snapshotFingerprint(
                  CloudNutritionSnapshot.fromJson(row.pendingSnapshot!),
                ) ==
                incomingFingerprint)) {
      // An aggregate may hydrate a dependency before its standalone record's
      // page arrives. Equal content is convergence, not a competing edit.
      row.pending = null;
      row.pendingSnapshot = null;
      row.conflict = null;
    }
    if (row.pending != null ||
        row.conflict != null ||
        (localFingerprint != row.baseline &&
            localFingerprint != incomingFingerprint &&
            !(local == null && row.baseline == incomingFingerprint))) {
      row.conflict = record;
      await journal.save(row);
      return false;
    }
    // An acknowledged upload may already be visible locally. Do not rewrite
    // rows or emit milestones merely to acknowledge the same snapshot again.
    if (localFingerprint != incomingFingerprint) {
      // A tombstone without a local food row must still be persisted before
      // the next page can hydrate an older diary/recipe dependency.
      await codec.apply(snapshot);
    }
    _guard();
    final after = await codec.capture(
      scopes: {scope},
      recordType: snapshot.type,
      recordId: snapshot.id,
    );
    final restored = after.where((value) => value.key == snapshot.key);
    row.revision = revision;
    // The codec can retain a newer shared catalog dependency. Its immutable
    // historical item snapshots remain exact; baseline reflects actual rows.
    row.baseline = restored.isEmpty
        ? incomingFingerprint
        : snapshotFingerprint(restored.single);
    await journal.save(row);
    return true;
  }
}

/// Explicit conflict resolution retains the local preimage for recovery. A
/// cloud tombstone can only be accepted; re-creating is a NEW user record/ID.
extension CloudRestoreConflictResolution on CloudRestoreV2Engine {
  Future<CloudNutritionSnapshot> conflictSnapshot(
    RestoreJournalEntry row,
  ) async {
    await _authorized(row.scope);
    if (row.conflict == null) throw StateError('Conflict no longer exists');
    return _decodeRecord(row.conflict!, row.scope);
  }

  Future<String> conflictToken(RestoreJournalEntry row) async {
    _guard();
    final current = (await codec.capture(
      scopes: {row.scope},
    )).where((value) => value.key == row.key).map(snapshotFingerprint).toList();
    _guard();
    return sha256
        .convert(
          utf8.encode(
            jsonEncode(
              _canonical({
                'conflict': row.conflict,
                'local': current,
                'pending': row.pending,
              }),
            ),
          ),
        )
        .toString();
  }

  Future<List<RestoreJournalEntry>> conflicts(Set<String> scopes) async {
    _guard();
    await journal.initialize();
    final result = <RestoreJournalEntry>[];
    for (final scope in scopes) {
      if (!allowedScopes.contains(scope)) continue;
      result.addAll(
        (await journal.entries(scope)).where((row) => row.conflict != null),
      );
    }
    _guard();
    return result;
  }

  Future<void> resolveConflict(
    String key, {
    required bool keepLocal,
    String? expectedToken,
  }) => _RestoreDatabaseQueue.run(
    database,
    () => _resolveConflict(
      key,
      keepLocal: keepLocal,
      expectedToken: expectedToken,
    ),
  );

  Future<void> _resolveConflict(
    String key, {
    required bool keepLocal,
    String? expectedToken,
  }) async {
    _guard();
    final row = await journal.entry(key);
    if (row == null || row.conflict == null) {
      throw StateError('Conflict no longer exists');
    }
    await _authorized(row.scope);
    // A choice refers to the revision actually reviewed. Refresh the current
    // server record before replacing local data; CAS protects a local upload.
    var cursor = 0;
    Map<String, Object?>? refreshed;
    for (var page = 0; page < maximumPages; page++) {
      final response = await transport.exchange(
        deviceId: deviceId,
        scope: row.scope,
        cursor: cursor,
        operations: const [],
        limit: 100,
      );
      _guard();
      for (final raw in response['records']! as List) {
        final record = Map<String, Object?>.from(raw as Map);
        if (record['record_type'] == row.type &&
            record['record_id'] == row.id) {
          await _decodeRecord(record, row.scope);
          refreshed = record;
        }
      }
      if (refreshed != null || response['has_more'] == false) break;
      cursor = response['cursor']! as int;
    }
    if (refreshed == null) throw StateError('Conflict record unavailable');
    if (refreshed['server_revision'] != row.conflict!['server_revision']) {
      row.conflict = refreshed;
      await journal.save(row);
      throw StateError('Cloud version changed; refresh before choosing');
    }
    final remote = await _decodeRecord(row.conflict!, row.scope);
    if (keepLocal && remote.deleted) {
      throw StateError('Deleted identities cannot be resurrected');
    }
    await database.transaction(() async {
      _guard();
      final latest = await journal.entry(key);
      if (latest == null ||
          latest.conflict == null ||
          latest.conflict!['server_revision'] !=
              row.conflict!['server_revision'] ||
          (expectedToken != null &&
              await conflictToken(latest) != expectedToken)) {
        throw StateError('Conflict changed; refresh before choosing');
      }
      final current = (await codec.capture(
        scopes: {latest.scope},
      )).where((value) => value.key == key).toList();
      latest.recovery = {
        'local': current.map((value) => value.toJson()).toList(),
        'pending': latest.pending,
        'remote': latest.conflict,
      };
      await journal.preserve(key, latest.recovery!);
      latest.revision = latest.conflict!['server_revision']! as int;
      latest.pending = null;
      latest.pendingSnapshot = null;
      latest.conflict = null;
      if (!keepLocal) await codec.apply(remote);
      _guard();
      latest.baseline = snapshotFingerprint(remote);
      await journal.save(latest);
    });
    if (keepLocal) await _stage(row.scope);
  }
}
