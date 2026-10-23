import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:crypto/crypto.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../data/bil_smart_plan_repository.dart';
import '../domain/bil_smart_plan.dart';

/// One SQLite transaction owns the plan, actual activity, and durable receipt.
/// A planned duration is never silently used as the performed duration.
class BilSmartPlanWorkoutService {
  BilSmartPlanWorkoutService(this.database, this.plans, this.checkAccess);
  final AppDatabase database;
  final BilSmartPlanRepository plans;
  final void Function() checkAccess;

  Future<BilSmartPlan> record({
    required BilSmartPlan expected,
    required String date,
    required DateTime now,
    required int actualMinutes,
    required bool completed,
    String sessionTitle = 'BIL training session',
  }) async {
    if (actualMinutes < 5 ||
        actualMinutes > 120 ||
        sessionTitle.trim().isEmpty ||
        sessionTitle.length > 120) {
      throw ArgumentError('minutes');
    }
    checkAccess();
    final key = 'bil.smart-plan.workout.${expected.id}.$date';
    final result = await database.transaction(() async {
      checkAccess();
      final saved = await plans.readFor(expected.ownerId);
      checkAccess();
      if (saved?.id != expected.id || saved?.revision != expected.revision) {
        throw StateError('smart_plan_revision_conflict');
      }
      final workout = saved!.onDate(BilPlanDate.parse(date))?.workout;
      if (workout == null || workout.completed == completed) {
        throw StateError('smart_plan_workout_state_changed');
      }
      final next = saved.recordWorkout(
        date: BilPlanDate.parse(date),
        now: now,
        completed: completed,
      );
      final daily = DailyLogRepository(database);
      // Date-only historical entries stay on the explicitly selected civil day.
      final day = DateTime.parse(date);
      final before = await daily.getForDay(day);
      checkAccess();
      if (before?.lifecycleState == 'closed' || before?.closedAt != null) {
        throw StateError('smart_plan_reopen_day_first');
      }
      final prefs = PreferencesRepository(database);
      if (completed) {
        final entry = jsonEncode({
          'id': 'smart-plan-${sha256.convert(utf8.encode(key))}',
          'name': sessionTitle.trim(),
          'minutes': actualMinutes,
          'recordedAt': day.toUtc().toIso8601String(),
        });
        // Retain the exact before/after field for bounded, conflict-safe Undo.
        await daily.appendExerciseNotes(date: day, encodedEntries: [entry]);
        checkAccess();
        final after = await daily.getForDay(day);
        checkAccess();
        if (after == null ||
            const LineSplitter()
                    .convert(after.exerciseNotes ?? '')
                    .where((line) => line == entry)
                    .length !=
                1) {
          throw StateError('smart_plan_workout_save_unverified');
        }
        await prefs.set(
          key,
          jsonEncode({
            'entry': entry,
            'beforeNotes': before?.exerciseNotes,
            'afterNotes': after.exerciseNotes,
            'ownerId': expected.ownerId,
            'planRevision': expected.revision,
            'templateId': workout.templateId,
            'exerciseIds': workout.exerciseIds,
            'source': 'explicit_user_confirmation',
          }),
        );
      } else {
        final raw = await prefs.get(key);
        checkAccess();
        if (raw == null) throw StateError('smart_plan_no_workout_receipt');
        final receipt = jsonDecode(raw) as Map;
        if (receipt['ownerId'] != expected.ownerId ||
            before?.exerciseNotes != receipt['afterNotes']) {
          throw StateError('smart_plan_workout_undo_conflict');
        }
        await (database.update(
          database.dailyLogs,
        )..where((row) => row.id.equals(before!.id))).write(
          DailyLogsCompanion(
            exerciseNotes: Value(receipt['beforeNotes'] as String?),
            updatedAt: Value(now),
          ),
        );
        await prefs.remove(key);
        final readback = await daily.getForDay(day);
        checkAccess();
        if (readback?.exerciseNotes != receipt['beforeNotes']) {
          throw StateError('smart_plan_workout_save_unverified');
        }
      }
      checkAccess();
      return plans.save(next, expectedRevision: expected.revision);
    });
    checkAccess();
    return result;
  }
}
