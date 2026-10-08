part of 'coach_native_command_repository.dart';

extension _NativeCommandCompensation on CoachNativeCommandRepository {
  Future<CoachNativeSnapshot> _compensate(
    _NativeJournal journal,
    CoachNativeOwnerScope scope,
  ) async {
    final before = journal.command.before;
    final after = journal.after;
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
    );
    late final CoachNativeSnapshot expected;
    Future<void> changed(Future<int> Function() write) async {
      final count = await _awaitOwner(write, scope);
      if (count != 1) {
        throw const CoachNativeConflict(CoachNativeConflictReason.staleRecord);
      }
    }

    switch (journal.command.kind) {
      case CoachNativeCommandKind.health:
        await _awaitOwner(
          () => _healthCommands.compensate(
            resolved: journal.command.resolved,
            before: before.health!,
            after: after.health!,
            checkAccess: () => scope.check(database.localOwnerId),
          ),
          scope,
        );
        // The adapter verifies the intended restoration. Its actual revision
        // or tombstone is persisted as undoAfter by the existing native journal.
        return _readSnapshot(
          journal.command.kind,
          journal.command.resolved,
          scope,
        );
      case CoachNativeCommandKind.water:
        final saved = after.water!;
        await changed(
          () =>
              (database.update(database.waterEntries)..where(
                    (row) =>
                        row.id.equals(saved.id) &
                        row.uuid.equals(saved.uuid) &
                        row.revision.equals(saved.revision),
                  ))
                  .write(
                    WaterEntriesCompanion(
                      deletedAt: Value(now),
                      updatedAt: Value(now),
                      revision: Value(saved.revision + 1),
                      syncStatus: const Value('pendingDelete'),
                    ),
                  ),
        );
        expected = CoachNativeSnapshot(
          water: saved.copyWith(
            deletedAt: Value(now),
            revision: saved.revision + 1,
          ),
        );
      case CoachNativeCommandKind.weight:
        final saved = after.weight!;
        final prior = before.weight;
        await changed(
          () =>
              (database.update(database.weightEntries)..where(
                    (row) =>
                        row.id.equals(saved.id) &
                        row.uuid.equals(saved.uuid) &
                        row.revision.equals(saved.revision),
                  ))
                  .write(
                    prior == null
                        ? WeightEntriesCompanion(
                            deletedAt: Value(now),
                            updatedAt: Value(now),
                            revision: Value(saved.revision + 1),
                            syncStatus: const Value('pendingDelete'),
                          )
                        : prior
                              .toCompanion(false)
                              .copyWith(
                                updatedAt: Value(now),
                                revision: Value(saved.revision + 1),
                                syncStatus: const Value('pending'),
                              ),
                  ),
        );
        expected = CoachNativeSnapshot(
          weight: prior?.copyWith(revision: saved.revision + 1),
        );
      case CoachNativeCommandKind.goal:
        final savedProfile = after.profile!;
        final priorProfile = before.profile!;
        await changed(
          () =>
              (database.update(database.userProfile)..where(
                    (row) =>
                        row.id.equals(savedProfile.id) &
                        row.uuid.equals(savedProfile.uuid) &
                        row.revision.equals(savedProfile.revision),
                  ))
                  .write(
                    priorProfile
                        .toCompanion(false)
                        .copyWith(
                          updatedAt: Value(now),
                          revision: Value(savedProfile.revision + 1),
                          syncStatus: const Value('pending'),
                        ),
                  ),
        );
        final savedGoal = after.goal!;
        final priorGoal = before.goal;
        await changed(
          () =>
              (database.update(database.goals)..where(
                    (row) =>
                        row.id.equals(savedGoal.id) &
                        row.uuid.equals(savedGoal.uuid) &
                        row.revision.equals(savedGoal.revision),
                  ))
                  .write(
                    priorGoal == null
                        ? GoalsCompanion(
                            deletedAt: Value(now),
                            updatedAt: Value(now),
                            revision: Value(savedGoal.revision + 1),
                            syncStatus: const Value('pendingDelete'),
                          )
                        : priorGoal
                              .toCompanion(false)
                              .copyWith(
                                updatedAt: Value(now),
                                revision: Value(savedGoal.revision + 1),
                                syncStatus: const Value('pending'),
                              ),
                  ),
        );
        expected = CoachNativeSnapshot(
          profile: priorProfile.copyWith(revision: savedProfile.revision + 1),
          goal: priorGoal?.copyWith(revision: savedGoal.revision + 1),
        );
      case CoachNativeCommandKind.measurements:
        final saved = after.measurement!;
        final prior = before.measurement;
        await changed(
          () =>
              (database.update(database.bodyMeasurementEntries)..where(
                    (row) =>
                        row.id.equals(saved.id) &
                        row.uuid.equals(saved.uuid) &
                        row.revision.equals(saved.revision),
                  ))
                  .write(
                    prior == null
                        ? BodyMeasurementEntriesCompanion(
                            deletedAt: Value(now),
                            updatedAt: Value(now),
                            revision: Value(saved.revision + 1),
                            syncStatus: const Value('pendingDelete'),
                          )
                        : prior
                              .toCompanion(false)
                              .copyWith(
                                updatedAt: Value(now),
                                revision: Value(saved.revision + 1),
                                syncStatus: Value(
                                  prior.deletedAt == null
                                      ? 'pending'
                                      : 'pendingDelete',
                                ),
                              ),
                  ),
        );
        expected = CoachNativeSnapshot(
          measurement: prior == null
              ? saved.copyWith(
                  deletedAt: Value(now),
                  revision: saved.revision + 1,
                )
              : prior.copyWith(revision: saved.revision + 1),
        );
      case CoachNativeCommandKind.memory:
        // The collection itself is the version for legacy JSON memories. The
        // enclosing transaction compared it completely before compensation;
        // a later independent memory edit is never silently overwritten.
        await _awaitOwner(
          () => preferences.setManyInCurrentTransaction({
            CoachMemoryRepository.storageKey: jsonEncode(before.memories),
          }),
          scope,
        );
        expected = before;
    }
    final readback = await _readSnapshot(
      journal.command.kind,
      journal.command.resolved,
      scope,
      waterId: journal.after.water?.id,
    );
    if (!_sameNativeSnapshot(expected, readback)) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.readbackUnavailable,
      );
    }
    return readback;
  }
}
