part of 'daily_log_repository.dart';

extension _DailyLogVisionNutrition on DailyLogRepository {
  Future<List<MealFoodEvidence>> _visionDayRows(String key) async {
    final meals = await (_database.select(
      _database.meals,
    )..where((row) => row.dayKey.equals(key) & row.deletedAt.isNull())).get();
    if (meals.isEmpty) return const [];
    final items =
        await (_database.select(_database.mealItems)..where(
              (row) =>
                  row.mealId.isIn(meals.map((meal) => meal.id)) &
                  row.deletedAt.isNull(),
            ))
            .get();
    final owner = LocalDatabaseScope.keyForOwner(_database.localOwnerId);
    return [
      for (final item in items) MealFoodEvidence.read(item, ownerKey: owner),
    ];
  }

  Future<void> _freezeVisionNutrition(
    DateTime date, {
    String? previousRaw,
  }) async {
    final rows = await _visionDayRows(dayKeyFor(date));
    final previous = previousRaw == null
        ? null
        : FinalVisionNutrition.decode(previousRaw);
    if (!FinalVisionNutrition.containsVision(rows) && previous == null) return;
    final log = await getForDay(date);
    if (log == null || log.closedAt == null) {
      throw const FormatException('Missing closed photo day.');
    }
    final snapshot = FinalVisionNutrition.capture(
      ownerKey: LocalDatabaseScope.keyForOwner(_database.localOwnerId),
      log: log,
      rows: rows,
      previous: previous,
    );
    final count =
        await (_database.update(_database.dailyLogs)..where(
              (row) =>
                  row.id.equals(log.id) &
                  row.uuid.equals(log.uuid) &
                  row.closedAt.equals(log.closedAt!),
            ))
            .write(
              DailyLogsCompanion(
                finalVisionNutrientEvidenceJson: Value(snapshot.encode()),
              ),
            );
    if (count != 1) throw StateError('Closed photo day changed.');
  }

  /// A present but invalid new snapshot cannot become legacy-derived evidence.
  FinalVisionNutrition? _finalVisionNutrition(DailyLog log) {
    final raw = log.finalVisionNutrientEvidenceJson;
    if (raw == null) return null;
    try {
      final snapshot = FinalVisionNutrition.decode(raw);
      return snapshot.matches(
            log,
            LocalDatabaseScope.keyForOwner(_database.localOwnerId),
          )
          ? snapshot
          : null;
    } on FormatException {
      return null;
    }
  }
}
