part of 'cloud_nutrition_snapshot_codec.dart';

extension _CloudVisionDayNutrition on CloudNutritionSnapshotCodec {
  static const _lifecycleSchema = 'bil.vision.estimate.day-lifecycle.v1';

  bool _sameVisionIdentity(FinalVisionNutrition snapshot, DailyLog log) =>
      snapshot.ownerKey == _ownerKey &&
      snapshot.dayKey == log.dayKey &&
      snapshot.logUuid == log.uuid;

  bool _validVisionState(FinalVisionNutrition snapshot, DailyLog log) =>
      _sameVisionIdentity(snapshot, log) &&
      (log.lifecycleState == 'closed'
          ? snapshot.matches(log, _ownerKey)
          : log.lifecycleState == 'open' && log.closedAt == null);

  /// Reopening retains the last closed JSON as an owner/identity witness, not
  /// as current nutrition. Open ledgers still read their current meal evidence.
  Future<Map<String, Object?>?> _captureVisionDayLifecycle(
    String dayKey,
  ) async {
    final log = await (database.select(
      database.dailyLogs,
    )..where((row) => row.dayKey.equals(dayKey))).getSingleOrNull();
    if (log == null || log.finalVisionNutrientEvidenceJson == null) {
      return null;
    }
    final raw = log.finalVisionNutrientEvidenceJson!;
    final snapshot = FinalVisionNutrition.decode(raw);
    if (!_validVisionState(snapshot, log)) {
      throw const FormatException('Invalid photo-day lifecycle binding.');
    }
    return {
      'schema': _lifecycleSchema,
      'state': log.lifecycleState,
      'lastClosedSnapshot': raw,
    };
  }

  /// Pure wire validation. Local day identity/conflict checks remain in apply.
  ({String state, String encoded, FinalVisionNutrition snapshot})
  _decodeVisionDayLifecycle(Object? raw, Meal meal) {
    if (raw is! Map<String, dynamic> ||
        raw.length != 3 ||
        raw['schema'] != _lifecycleSchema ||
        !raw.keys.toSet().containsAll({
          'schema',
          'state',
          'lastClosedSnapshot',
        }) ||
        !const {'open', 'closed'}.contains(raw['state']) ||
        raw['lastClosedSnapshot'] is! String) {
      throw const FormatException('Invalid photo-day lifecycle.');
    }
    final state = raw['state'] as String,
        encoded = raw['lastClosedSnapshot'] as String;
    final snapshot = FinalVisionNutrition.decode(encoded);
    if (snapshot.ownerKey != _ownerKey || snapshot.dayKey != meal.dayKey) {
      throw const FormatException('Photo-day owner/day mismatch.');
    }
    return (state: state, encoded: encoded, snapshot: snapshot);
  }

  /// The caller's existing CloudRestoreV2Engine has already checked the parent
  /// server revision/local fingerprint or the explicit reviewed conflict token.
  /// This attachment participates in every meal fingerprint. It has no parallel
  /// revision, device-clock ordering, entitlement or additional health scope.
  Future<void> _applyVisionDayLifecycle(Object? raw, Meal meal) async {
    // Historical envelopes have no lifecycle instruction. Absence never reopens.
    if (raw == null) {
      return;
    }
    final decoded = _decodeVisionDayLifecycle(raw, meal);
    final state = decoded.state, encoded = decoded.encoded;
    final snapshot = decoded.snapshot;
    final existing = await (database.select(
      database.dailyLogs,
    )..where((row) => row.dayKey.equals(meal.dayKey))).getSingleOrNull();
    if (existing != null) {
      final priorRaw = existing.finalVisionNutrientEvidenceJson;
      if (priorRaw == null || !_sameVisionIdentity(snapshot, existing)) {
        throw const FormatException('Conflicting local photo day.');
      }
      final prior = FinalVisionNutrition.decode(priorRaw);
      if (!_validVisionState(prior, existing)) {
        throw const FormatException('Invalid existing photo day.');
      }
      // Open instructions retain lineage only. A closed parent can carry an
      // aggregate from siblings rejected by per-parent server CAS; normalize
      // from the actually accepted immutable rows even when its wire JSON is
      // identical to the prior closed instruction.
      if (state == 'open' &&
          existing.lifecycleState == state &&
          priorRaw == encoded) {
        return;
      }
    }
    int? rounded(FoodNutrient n) => snapshot.nutrients[n]?.round();
    final values = DailyLogsCompanion(
      lifecycleState: Value(state),
      closedAt: Value(state == 'closed' ? snapshot.closedAtUtc : null),
      calories: Value(rounded(FoodNutrient.calories)),
      protein: Value(rounded(FoodNutrient.protein)),
      carbs: Value(rounded(FoodNutrient.carbohydrates)),
      fats: Value(rounded(FoodNutrient.fat)),
      finalFiber: Value(snapshot.nutrients[FoodNutrient.fiber]),
      finalNutrientEvidenceMask: Value(
        snapshot.nutrients[FoodNutrient.fiber] == null
            ? 0
            : NutrientEvidenceMask.bit(TrackedNutrient.fiber),
      ),
      finalVisionNutrientEvidenceJson: Value(encoded),
      updatedAt: Value(DateTime.now()),
    );
    if (existing == null) {
      await database
          .into(database.dailyLogs)
          .insert(
            values.copyWith(
              uuid: Value(snapshot.logUuid),
              date: Value(DateTime.parse(snapshot.dayKey)),
              dayKey: Value(snapshot.dayKey),
            ),
          );
      if (state == 'closed') {
        await _freezeAcceptedVisionRows(meal.dayKey, snapshot, encoded);
      }
      return;
    }
    // Touch only nutrition/lifecycle. Notes/sleep/steps/exercise remain intact.
    // All identity/lifecycle fields read above are compared inside this same
    // owner-checked restore transaction before the update is allowed to commit.
    final count =
        await (database.update(database.dailyLogs)..where(
              (row) =>
                  row.id.equals(existing.id) &
                  row.uuid.equals(existing.uuid) &
                  row.lifecycleState.equals(existing.lifecycleState!) &
                  (existing.closedAt == null
                      ? row.closedAt.isNull()
                      : row.closedAt.equals(existing.closedAt!)) &
                  row.finalVisionNutrientEvidenceJson.equals(
                    existing.finalVisionNutrientEvidenceJson!,
                  ),
            ))
            .write(values);
    if (count != 1) {
      throw const FormatException('Photo day changed while restoring.');
    }
    if (state == 'closed') {
      await _freezeAcceptedVisionRows(meal.dayKey, snapshot, encoded);
    }
  }

  /// A remote closed instruction supplies identity/closure, not authority over
  /// siblings whose server CAS may have rejected its source-device edits.
  /// Freeze a local observation of the immutable item evidence actually
  /// accepted in this SQL transaction. During a paged restore this describes
  /// the accepted local subset, never a claim that all cloud pages arrived.
  /// Local close/read/stage and catalog-only changes never call this method.
  Future<void> _freezeAcceptedVisionRows(
    String dayKey,
    FinalVisionNutrition instruction,
    String instructionRaw,
  ) async {
    await _checkOwner();
    final log = await (database.select(
      database.dailyLogs,
    )..where((row) => row.dayKey.equals(dayKey))).getSingle();
    if (!_sameVisionIdentity(instruction, log) ||
        log.lifecycleState != 'closed' ||
        log.closedAt?.toUtc() != instruction.closedAtUtc ||
        log.finalVisionNutrientEvidenceJson != instructionRaw) {
      throw const FormatException('Accepted photo-day identity changed.');
    }
    final meals =
        await (database.select(database.meals)..where(
              (row) => row.dayKey.equals(dayKey) & row.deletedAt.isNull(),
            ))
            .get();
    final items = meals.isEmpty
        ? const <MealItem>[]
        : await (database.select(database.mealItems)..where(
                (row) =>
                    row.mealId.isIn(meals.map((meal) => meal.id)) &
                    row.deletedAt.isNull(),
              ))
              .get();
    final frozen = FinalVisionNutrition.capture(
      ownerKey: _ownerKey,
      log: log,
      rows: [
        for (final item in items)
          MealFoodEvidence.read(item, ownerKey: _ownerKey),
      ],
      previous: instruction,
    );
    final encoded = frozen.encode();
    if (encoded == log.finalVisionNutrientEvidenceJson) {
      return;
    }
    int? rounded(FoodNutrient n) => frozen.nutrients[n]?.round();
    await _checkOwner();
    final count =
        await (database.update(database.dailyLogs)..where(
              (row) =>
                  row.id.equals(log.id) &
                  row.uuid.equals(log.uuid) &
                  row.lifecycleState.equals('closed') &
                  row.closedAt.equals(log.closedAt!) &
                  row.finalVisionNutrientEvidenceJson.equals(
                    log.finalVisionNutrientEvidenceJson!,
                  ),
            ))
            .write(
              DailyLogsCompanion(
                calories: Value(rounded(FoodNutrient.calories)),
                protein: Value(rounded(FoodNutrient.protein)),
                carbs: Value(rounded(FoodNutrient.carbohydrates)),
                fats: Value(rounded(FoodNutrient.fat)),
                finalFiber: Value(frozen.nutrients[FoodNutrient.fiber]),
                finalNutrientEvidenceMask: Value(
                  frozen.nutrients[FoodNutrient.fiber] == null
                      ? 0
                      : NutrientEvidenceMask.bit(TrackedNutrient.fiber),
                ),
                finalVisionNutrientEvidenceJson: Value(encoded),
              ),
            );
    if (count != 1) {
      throw const FormatException('Accepted photo day changed.');
    }
  }

  Future<void> _applyClosedVisionDay(Object? raw, Meal meal) async {
    if (raw == null) {
      return;
    }
    if (raw is! String) {
      throw const FormatException('Invalid closed photo backup.');
    }
    final snapshot = FinalVisionNutrition.decode(raw);
    if (snapshot.ownerKey != _ownerKey || snapshot.dayKey != meal.dayKey) {
      throw const FormatException('Closed photo owner/day mismatch.');
    }
    final existing = await (database.select(
      database.dailyLogs,
    )..where((row) => row.dayKey.equals(meal.dayKey))).getSingleOrNull();
    if (existing != null) {
      if (!snapshot.matches(existing, _ownerKey) ||
          existing.finalVisionNutrientEvidenceJson != raw) {
        throw const FormatException('Conflicting local closed photo day.');
      }
      return;
    }
    int? rounded(FoodNutrient n) => snapshot.nutrients[n]?.round();
    await database
        .into(database.dailyLogs)
        .insert(
          DailyLogsCompanion.insert(
            uuid: Value(snapshot.logUuid),
            date: DateTime.parse(snapshot.dayKey),
            dayKey: snapshot.dayKey,
            lifecycleState: const Value('closed'),
            closedAt: Value(snapshot.closedAtUtc),
            calories: Value(rounded(FoodNutrient.calories)),
            protein: Value(rounded(FoodNutrient.protein)),
            carbs: Value(rounded(FoodNutrient.carbohydrates)),
            fats: Value(rounded(FoodNutrient.fat)),
            finalFiber: Value(snapshot.nutrients[FoodNutrient.fiber]),
            finalNutrientEvidenceMask: Value(
              snapshot.nutrients[FoodNutrient.fiber] == null
                  ? 0
                  : NutrientEvidenceMask.bit(TrackedNutrient.fiber),
            ),
            finalVisionNutrientEvidenceJson: Value(raw),
          ),
        );
  }
}
