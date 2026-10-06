part of 'meal_repository.dart';

extension CoachMealCompensation on MealRepository {
  /// Compensates exactly one committed operation, once, at its saved versions.
  /// Every precondition is checked before the first row changes.
  Future<CoachMealCommit> undoCoachMeal({
    required String operationId,
    required String toolId,
    required String argumentsDigest,
    required CoachMealOwnerScope scope,
  }) async {
    scope.check(_database.localOwnerId);
    final replayed = await _database.transaction(() async {
      final journal = await _readCoachJournal(operationId, scope);
      if (journal == null) {
        throw const CoachMealConflict(CoachMealConflictReason.invalidJournal);
      }
      if (journal.toolId != toolId ||
          journal.argumentsDigest != argumentsDigest) {
        throw const CoachMealConflict(
          CoachMealConflictReason.operationMismatch,
        );
      }
      if (journal.undoneAt != null) return true;

      final current = <int, CoachMealSnapshot>{};
      for (final expected in journal.after) {
        final actual = await _requireCoachSnapshot(expected.item.id, scope);
        if (!_sameCoachItem(expected.item, actual.item) ||
            !_sameCoachMeal(expected.meal, actual.meal)) {
          throw const CoachMealConflict(CoachMealConflictReason.staleItem);
        }
        if (actual.meal.deletedAt != null) {
          throw const CoachMealConflict(CoachMealConflictReason.missingMeal);
        }
        await _requireCoachOpenDay(actual.meal.dayKey, scope);
        current[actual.item.id] = actual;
      }
      for (final before in journal.before) {
        final parent = await _coachAwait(
          () => (_database.select(
            _database.meals,
          )..where((row) => row.id.equals(before.meal.id))).getSingleOrNull(),
          scope,
        );
        if (parent == null ||
            parent.deletedAt != null ||
            !_sameCoachMeal(before.meal, parent)) {
          throw const CoachMealConflict(CoachMealConflictReason.missingMeal);
        }
        await _requireCoachOpenDay(parent.dayKey, scope);
      }

      // Drift stores DateTime values at second precision. Compare the intended
      // persisted snapshot at that same precision after the database writes.
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
      );
      final expectedItems = <int, MealItem>{};
      final expectedMeals = <int, Meal>{
        for (final row in journal.before) row.meal.id: row.meal,
        for (final row in journal.after) row.meal.id: row.meal,
      };
      if (journal.before.isEmpty) {
        for (final actual in current.values) {
          expectedItems[actual.item.id] = actual.item.copyWith(
            deletedAt: Value(now),
            updatedAt: now,
            revision: actual.item.revision + 1,
            syncStatus: 'pendingDelete',
          );
          await _writeCoachItemVersion(
            actual.item,
            MealItemsCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              revision: Value(actual.item.revision + 1),
              syncStatus: const Value('pendingDelete'),
            ),
            scope,
          );
        }
      } else {
        for (final before in journal.before) {
          final actual = current[before.item.id];
          if (actual == null) {
            throw const CoachMealConflict(
              CoachMealConflictReason.invalidJournal,
            );
          }
          // Restore the saved immutable item, including its original parent,
          // position and unknown nutrient mask. Never consult today's catalog.
          final restored = before.item.copyWith(
            revision: actual.item.revision + 1,
            updatedAt: now,
            syncStatus: before.item.deletedAt == null
                ? 'pending'
                : 'pendingDelete',
          );
          expectedItems[before.item.id] = restored;
          await _writeCoachItemVersion(
            actual.item,
            restored.toCompanion(false),
            scope,
          );
        }
      }
      expectedMeals.addAll(
        await _removeEmptyCoachBuckets(journal.createdMeals, scope, now),
      );
      final readback = <CoachMealSnapshot>[];
      for (final row in journal.after) {
        final actual = await _requireCoachSnapshot(row.item.id, scope);
        final expected = expectedItems[row.item.id];
        if (expected == null || !_sameCoachItem(expected, actual.item)) {
          throw const CoachMealConflict(
            CoachMealConflictReason.readbackUnavailable,
          );
        }
        readback.add(actual);
      }
      for (final expected in expectedMeals.values) {
        final actual = await _coachAwait(
          () => (_database.select(
            _database.meals,
          )..where((row) => row.id.equals(expected.id))).getSingleOrNull(),
          scope,
        );
        if (actual == null || !_sameCoachMeal(expected, actual)) {
          throw const CoachMealConflict(
            CoachMealConflictReason.readbackUnavailable,
          );
        }
      }
      await _writeCoachJournal(journal.compensated(now, readback), scope);
      scope.check(_database.localOwnerId);
      return false;
    });
    return _coachCommitReadback(operationId, scope, replayed: replayed);
  }
}

extension _CoachMealBucketCompensation on MealRepository {
  Future<Map<int, Meal>> _removeEmptyCoachBuckets(
    List<Meal> createdMeals,
    CoachMealOwnerScope scope,
    DateTime now,
  ) async {
    final expected = <int, Meal>{};
    for (final created in createdMeals) {
      final current = await _coachAwait(
        () => (_database.select(
          _database.meals,
        )..where((row) => row.id.equals(created.id))).getSingleOrNull(),
        scope,
      );
      if (current == null || !_sameCoachMeal(created, current)) continue;
      final remaining = await _coachAwait(
        () =>
            (_database.select(_database.mealItems)
                  ..where(
                    (row) =>
                        row.mealId.equals(created.id) & row.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull(),
        scope,
      );
      if (remaining != null) continue;
      await _coachAwait(
        () =>
            (_database.update(_database.meals)..where(
                  (row) =>
                      row.id.equals(created.id) &
                      row.uuid.equals(created.uuid) &
                      row.revision.equals(created.revision),
                ))
                .write(
                  MealsCompanion(
                    deletedAt: Value(now),
                    updatedAt: Value(now),
                    revision: Value(current.revision + 1),
                    syncStatus: const Value('pendingDelete'),
                  ),
                ),
        scope,
      );
      expected[current.id] = current.copyWith(
        deletedAt: Value(now),
        updatedAt: now,
        revision: current.revision + 1,
        syncStatus: 'pendingDelete',
      );
    }
    return expected;
  }
}
