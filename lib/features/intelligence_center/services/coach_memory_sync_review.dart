part of 'coach_memory_repository.dart';

/// Review snapshots are local and short lived. No contents or auth lifetime
/// tokens are serialized into preferences, telemetry or diagnostics.
class CoachMemorySyncReview {
  CoachMemorySyncReview._(
    this.id,
    this.owner,
    this.local,
    this.remote,
    this.remoteVersion,
    this.remoteDeleted,
    this._raw,
    this._checkpointRaw,
  );
  final String id, owner;
  final Map<String, Object?>? local, remote;
  final String? remoteVersion;
  final bool remoteDeleted;
  final String? _raw, _checkpointRaw;
  bool _current = true;
  StreamSubscription<AuthState>? _subscription;
  Future<void> dispose() async {
    _current = false;
    await _subscription?.cancel();
  }
}

extension CoachMemorySyncReviewFlow on CoachMemoryRepository {
  Future<List<({String id, String state, bool deleted})>>
  readSyncIssues() async {
    final entries = _strictMemoryEntries(
      await preferences.get(CoachMemoryRepository.storageKey),
    );
    final issues = <({String id, String state, bool deleted})>[];
    if (entries.isEmpty) return issues;
    final checkpoints = await preferences
        .watchSnapshot(
          entries.map((e) => _memoryCheckpointKey(e['id']! as String)),
        )
        .first;
    for (final entry in entries) {
      final id = entry['id']! as String;
      final checkpoint = _memoryCheckpoint(
        checkpoints[_memoryCheckpointKey(id)],
      );
      if (const {'pending', 'conflict'}.contains(checkpoint['state'])) {
        issues.add((
          id: id,
          state: checkpoint['state'] as String,
          deleted: entry['status'] == 'deleted',
        ));
      }
    }
    return List.unmodifiable(issues);
  }

  Future<CoachMemorySyncReview> reviewSyncConflict(String id) =>
      _runForMemoryOwner(() async {
        final owner = preferences.localOwnerId;
        if (cloud == null || owner == null || !await _remoteAiAllowed()) {
          throw StateError('coach_memory_cloud_unavailable');
        }
        CommunityOwnerOperation.checkCurrent();
        final raw = await preferences.get(CoachMemoryRepository.storageKey);
        final matches = _strictMemoryEntries(raw).where((e) => e['id'] == id);
        if (matches.length != 1) throw CoachMemoryVersionConflict(id);
        final checkpoint = await preferences.get(_memoryCheckpointKey(id));
        if (_memoryCheckpoint(checkpoint)['state'] != 'conflict') {
          throw CoachMemoryVersionConflict(id);
        }
        final row = await _readCloudMemory(owner, id);
        CommunityOwnerOperation.checkCurrent();
        final review = CoachMemorySyncReview._(
          id,
          owner,
          matches.single['status'] == 'deleted'
              ? null
              : Map.unmodifiable(matches.single),
          row == null || row['deleted_at'] != null
              ? null
              : Map.unmodifiable(_memoryCloudFact(row)),
          row?['updated_at'] as String?,
          row?['deleted_at'] != null,
          raw,
          checkpoint,
        );
        review._subscription = cloud!.auth.onAuthStateChange.listen((state) {
          if (state.event == AuthChangeEvent.signedOut ||
              state.event == AuthChangeEvent.signedIn ||
              state.session?.user.id != owner) {
            review._current = false;
          }
        });
        return review;
      });

  /// The caller must show both snapshots and obtain an explicit choice.
  /// Even that choice cannot overwrite a newer remote or local revision.
  Future<bool> resolveSyncConflict(
    CoachMemorySyncReview review, {
    required bool useCloud,
    bool Function()? isCurrentOwner,
  }) => _runForMemoryOwner(() async {
    void check() {
      CommunityOwnerOperation.checkCurrent();
      if (!review._current ||
          preferences.localOwnerId != review.owner ||
          cloud?.auth.currentUser?.id != review.owner ||
          isCurrentOwner?.call() == false) {
        throw const CommunityOwnerOperationCancelled();
      }
    }

    check();
    if (!await _remoteAiAllowed()) {
      throw StateError('coach_memory_cloud_unavailable');
    }
    check();
    final row = await _readCloudMemory(review.owner, review.id);
    check();
    final sameVersion = row == null
        ? review.remoteVersion == null
        : review.remoteVersion != null &&
              DateTime.parse(
                row['updated_at'] as String,
              ).isAtSameMomentAs(DateTime.parse(review.remoteVersion!));
    final remote = row == null || row['deleted_at'] != null
        ? null
        : _memoryCloudFact(row);
    if (!sameVersion ||
        !_sameMemoryJson(remote, review.remote) ||
        (row?['deleted_at'] != null) != review.remoteDeleted) {
      throw CoachMemoryVersionConflict(review.id);
    }
    if (!useCloud && review.local != null && review.remoteDeleted) {
      throw StateError('coach_memory_deleted_version_cannot_resurrect');
    }
    final entries = _strictMemoryEntries(review._raw);
    if (useCloud) {
      entries.removeWhere((e) => e['id'] == review.id);
      entries.insert(
        0,
        remote ??
            {
              'id': review.id,
              'text': '',
              'status': 'deleted',
              'source': 'local_privacy_deletion',
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            },
      );
    }
    final key = _memoryCheckpointKey(review.id);
    final saved = await preferences.mutateIfUnchanged(
      expected: {
        CoachMemoryRepository.storageKey: review._raw,
        key: review._checkpointRaw,
      },
      set: {
        CoachMemoryRepository.storageKey: jsonEncode(
          _retainMemoryState(entries),
        ),
        key: jsonEncode({
          'state': useCloud ? 'verified' : 'pending',
          'deleted': useCloud && remote == null,
          if (row != null) 'version': row['updated_at'],
          if (remote != null) 'digest': coachMemoryFactDigest(remote),
        }),
      },
      isCurrent: () =>
          review._current &&
          preferences.localOwnerId == review.owner &&
          cloud?.auth.currentUser?.id == review.owner &&
          isCurrentOwner?.call() != false,
    );
    check();
    if (!saved) throw CoachMemoryVersionConflict(review.id);
    if (!useCloud) {
      await syncCommittedChange(
        id: review.id,
        expectedLocal: review.local,
        isCurrentOwner: () =>
            review._current && isCurrentOwner?.call() != false,
      );
      check();
    }
    return _memoryCheckpoint(await preferences.get(key))['state'] == 'verified';
  }, isCurrentOwner: () => review._current && isCurrentOwner?.call() != false);
}
