import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/date_keys.dart';
import '../database/nutrient_evidence.dart';

enum DayLifecycleState { notStarted, open, closed }

final class AuthoritativeDailyLedger {
  const AuthoritativeDailyLedger({
    required this.date,
    required this.state,
    required this.weightKg,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.netCarbohydrates,
    required this.evidenceCompleteness,
  });

  final DateTime date;
  final DayLifecycleState state;
  final double? weightKg;
  final double? calories;
  final double? protein;
  final double? carbohydrates;
  final double? fat;
  final double? fiber;
  final double? netCarbohydrates;
  final double evidenceCompleteness;
}

class DailyLogRepository {
  final AppDatabase _database;

  DailyLogRepository(this._database);

  Future<void> save({
    required DateTime date,
    String? notes,
    double? sleepHours,
    int? steps,
    String? exerciseNotes,
  }) async {
    final key = dayKeyFor(date);
    final existing = await (_database.select(
      _database.dailyLogs,
    )..where((row) => row.dayKey.equals(key))).getSingleOrNull();
    final companion = DailyLogsCompanion(
      id: existing == null ? const Value.absent() : Value(existing.id),
      uuid: existing == null ? const Value.absent() : Value(existing.uuid),
      date: Value(date),
      dayKey: Value(key),
      notes: Value(notes),
      sleepHours: Value(sleepHours),
      steps: Value(steps),
      exerciseNotes: Value(exerciseNotes),
      createdAt: existing == null
          ? const Value.absent()
          : Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
    );
    await _database.into(_database.dailyLogs).insertOnConflictUpdate(companion);
  }

  Future<void> startDay(DateTime date) => save(date: date);

  Future<void> closeDay(DateTime date) async {
    final ledger = await readLedger(date);
    if (ledger.state == DayLifecycleState.notStarted) {
      throw StateError('Start the day before closing it.');
    }
    final key = dayKeyFor(date);
    final existing = await (_database.select(
      _database.dailyLogs,
    )..where((row) => row.dayKey.equals(key))).getSingle();
    await (_database.update(
      _database.dailyLogs,
    )..where((row) => row.id.equals(existing.id))).write(
      DailyLogsCompanion(
        lifecycleState: const Value('closed'),
        closedAt: Value(DateTime.now()),
        calories: Value(ledger.calories?.round()),
        protein: Value(ledger.protein?.round()),
        carbs: Value(ledger.carbohydrates?.round()),
        fats: Value(ledger.fat?.round()),
        finalFiber: Value(ledger.fiber),
        finalNutrientEvidenceMask: Value(
          ledger.fiber == null
              ? 0
              : NutrientEvidenceMask.bit(TrackedNutrient.fiber),
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reopenDay(DateTime date) async {
    final key = dayKeyFor(date);
    await (_database.update(
      _database.dailyLogs,
    )..where((row) => row.dayKey.equals(key))).write(
      DailyLogsCompanion(
        lifecycleState: const Value('open'),
        closedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Closed snapshots remain stable until an explicit [reopenDay].
  Future<AuthoritativeDailyLedger> readLedger(DateTime date) async {
    final key = dayKeyFor(date);
    final log = await (_database.select(
      _database.dailyLogs,
    )..where((row) => row.dayKey.equals(key))).getSingleOrNull();
    final weight =
        await (_database.select(_database.weightEntries)
              ..where((row) => row.dayKey.equals(key) & row.deletedAt.isNull()))
            .getSingleOrNull();
    if (log?.lifecycleState == 'closed') {
      final fiberKnown = NutrientEvidenceMask.contains(
        log!.finalNutrientEvidenceMask ?? 0,
        TrackedNutrient.fiber,
      );
      final carbs = log.carbs?.toDouble();
      final fiber = fiberKnown ? log.finalFiber : null;
      return AuthoritativeDailyLedger(
        date: date,
        state: DayLifecycleState.closed,
        weightKg: weight?.weight,
        calories: log.calories?.toDouble(),
        protein: log.protein?.toDouble(),
        carbohydrates: carbs,
        fat: log.fats?.toDouble(),
        fiber: fiber,
        netCarbohydrates: carbs != null && fiber != null
            ? (carbs - fiber).clamp(0, double.infinity)
            : null,
        evidenceCompleteness: log.calories == null ? 0 : 1,
      );
    }
    final meals = await (_database.select(
      _database.meals,
    )..where((row) => row.dayKey.equals(key) & row.deletedAt.isNull())).get();
    final ids = meals.map((meal) => meal.id).toSet();
    final items = ids.isEmpty
        ? <MealItem>[]
        : await (_database.select(_database.mealItems)
                ..where((row) => row.mealId.isIn(ids) & row.deletedAt.isNull()))
              .get();
    final allFiberKnown =
        items.isNotEmpty &&
        items.every(
          (item) => NutrientEvidenceMask.contains(
            item.nutrientEvidenceMask,
            TrackedNutrient.fiber,
          ),
        );
    double sum(double Function(MealItem) select) =>
        items.fold(0, (total, item) => total + select(item));
    final carbs = items.isEmpty ? null : sum((item) => item.carbs);
    final fiber = allFiberKnown ? sum((item) => item.fiber) : null;
    return AuthoritativeDailyLedger(
      date: date,
      state: log == null
          ? DayLifecycleState.notStarted
          : DayLifecycleState.open,
      weightKg: weight?.weight,
      calories: items.isEmpty ? null : sum((item) => item.calories),
      protein: items.isEmpty ? null : sum((item) => item.protein),
      carbohydrates: carbs,
      fat: items.isEmpty ? null : sum((item) => item.fats),
      fiber: fiber,
      netCarbohydrates: carbs != null && fiber != null
          ? (carbs - fiber).clamp(0, double.infinity)
          : null,
      evidenceCompleteness: items.isEmpty
          ? 0
          : items.where((item) => item.nutrientEvidenceMask != 0).length /
                items.length,
    );
  }

  Future<List<DailyLog>> getAll() {
    return _database.select(_database.dailyLogs).get();
  }

  Stream<List<DailyLog>> watchAll() {
    return (_database.select(
      _database.dailyLogs,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  }

  Stream<DailyLog?> watchLatest() {
    return (_database.select(_database.dailyLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<DailyLog?> watchForDay(DateTime date) {
    return (_database.select(_database.dailyLogs)
          ..where((row) => row.dayKey.equals(dayKeyFor(date)))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> deleteAll() async {
    await _database.delete(_database.dailyLogs).go();
  }
}
