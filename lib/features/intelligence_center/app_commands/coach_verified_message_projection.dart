import 'package:drift/drift.dart';
import '../../../data/database/app_database.dart';
import '../services/coach_native_command_repository.dart';
import '../../../data/database/database_scope.dart';
import '../domain/coach_message_presentation.dart';
import 'coach_message_nutrition_reader.dart';
import 'coach_health_read_guard.dart';
import '../domain/coach_context_preferences.dart';

/// Receives only the result of the existing owner/consent-verified local health
/// query, never a model result or an evidence string decoded from model prose.
final class CoachVerifiedMessageProjection {
  const CoachVerifiedMessageProjection(this.database, {required this.clock});
  final AppDatabase database;
  final DateTime Function() clock;

  /// Display only a committed native receipt. This read transaction never
  /// writes, replays a command, or treats an overwritten same-day snapshot as
  /// an earlier measurement. Unknown fields stay unknown.
  Future<CoachMessagePresentation?> committedMeasurement(
    CoachNativeCommit commit, {
    required void Function() checkAccess,
    required String savedNote,
    // No guard means no history query. A user-confirmed current receipt stays
    // visible independently of optional analytics context.
    CoachHealthReadGuard? previousReadGuard,
    String? Function(
      CoachVisualWeightPoint previous,
      CoachVisualWeightPoint saved,
    )?
    previousWeightNote,
    String? Function(
      CoachVisualNutritionColumn previous,
      CoachVisualNutritionColumn saved,
    )?
    previousMeasurementNote,
  }) async {
    checkAccess();
    if (previousReadGuard != null &&
        (previousReadGuard.focus != CoachContextFocus.analytics ||
            previousReadGuard.preferences.localOwnerId !=
                database.localOwnerId)) {
      throw ArgumentError(
        'Previous measurement needs this owner analytics guard',
      );
    }
    if (commit.state != CoachNativeResultState.committed ||
        commit.kind != CoachNativeCommandKind.weight &&
            commit.kind != CoachNativeCommandKind.measurements) {
      return null;
    }
    return database.transaction(() async {
      checkAccess();
      final captured = clock().toUtc();
      final owner = LocalDatabaseScope.keyForOwner(database.localOwnerId);
      if (commit.kind == CoachNativeCommandKind.weight) {
        final saved = commit.after.weight!;
        final savedDay = saved.dayKey;
        // Legacy records may have no trusted civil-day identity. Keep the
        // original readable receipt rather than inventing one from the clock.
        if (savedDay == null) return null;
        final table = database.weightEntries;
        final current = await (database.select(
          table,
        )..where((row) => row.id.equals(saved.id))).getSingleOrNull();
        checkAccess();
        if (current == null ||
            current.deletedAt != null ||
            current.uuid != saved.uuid ||
            current.revision != saved.revision ||
            current.date != saved.date ||
            current.dayKey != saved.dayKey ||
            current.weight != saved.weight ||
            current.measurementContext != saved.measurementContext) {
          return null;
        }
        WeightEntry? prior;
        if (previousReadGuard != null) {
          await previousReadGuard.verify();
          checkAccess();
          prior =
              await (database.select(table)
                    ..where(
                      (row) =>
                          row.deletedAt.isNull() &
                          row.dayKey.isSmallerThanValue(savedDay) &
                          row.date.isSmallerThanValue(saved.date),
                    )
                    ..orderBy([(row) => OrderingTerm.desc(row.date)])
                    ..limit(1))
                  .getSingleOrNull();
          previousReadGuard.check();
        }
        checkAccess();
        CoachVisualWeightPoint point(WeightEntry row, String day) =>
            CoachVisualWeightPoint(
              recordedAtUtc: row.date.toUtc(),
              dayKey: day,
              kg: row.weight,
              context: row.measurementContext,
            );
        final savedPoint = point(saved, savedDay);
        String? comparison;
        final priorDay = prior?.dayKey;
        if (prior != null &&
            priorDay != null &&
            prior.weight.isFinite &&
            prior.weight >= 20 &&
            prior.weight <= 500) {
          comparison = previousWeightNote?.call(
            point(prior, priorDay),
            savedPoint,
          );
        }
        await previousReadGuard?.verify();
        checkAccess();
        return CoachMessagePresentation.localRead(
          ownerKey: owner,
          capturedAtUtc: captured,
          kind: CoachVisualKind.weight,
          title: 'Weight',
          fromDay: savedDay,
          throughDay: savedDay,
          // A new save is one measured value, never a fabricated timeline.
          weightPoints: [savedPoint],
          notes: [savedNote, ?comparison],
        );
      }
      final saved = commit.after.measurement!;
      final table = database.bodyMeasurementEntries;
      final current = await (database.select(
        table,
      )..where((row) => row.id.equals(saved.id))).getSingleOrNull();
      checkAccess();
      bool sameFields(BodyMeasurementEntry a, BodyMeasurementEntry b) =>
          a.neckCm == b.neckCm &&
          a.waistCm == b.waistCm &&
          a.hipsCm == b.hipsCm &&
          a.chestCm == b.chestCm &&
          a.armCm == b.armCm &&
          a.thighCm == b.thighCm;
      if (current == null ||
          current.deletedAt != null ||
          current.uuid != saved.uuid ||
          current.revision != saved.revision ||
          current.date != saved.date ||
          current.dayKey != saved.dayKey ||
          !sameFields(current, saved)) {
        return null;
      }
      BodyMeasurementEntry? prior;
      if (previousReadGuard != null) {
        await previousReadGuard.verify();
        checkAccess();
        prior =
            await (database.select(table)
                  ..where(
                    (row) =>
                        row.deletedAt.isNull() &
                        row.dayKey.isSmallerThanValue(saved.dayKey) &
                        row.date.isSmallerThanValue(saved.date),
                  )
                  ..orderBy([(row) => OrderingTerm.desc(row.date)])
                  ..limit(1))
                .getSingleOrNull();
        previousReadGuard.check();
      }
      checkAccess();
      CoachVisualNutritionColumn column(BodyMeasurementEntry row) {
        final values = <String, double?>{
          'neck': row.neckCm,
          'waist': row.waistCm,
          'hips': row.hipsCm,
          'chest': row.chestCm,
          'arm': row.armCm,
          'thigh': row.thighCm,
        };
        return CoachVisualNutritionColumn(
          title: 'Body measurements',
          dayKey: row.dayKey,
          metrics: [
            for (final value in values.entries)
              CoachVisualMetric.localRead(
                id: value.key,
                knownSubtotal: value.value,
                knownItems: value.value == null ? 0 : 1,
                missingItems: value.value == null ? 1 : 0,
              ),
          ],
          sourceKinds: const ['saved_measurements'],
          capturedAtUtc: captured,
        );
      }

      final savedColumn = column(saved);
      final comparison = prior == null
          ? null
          : previousMeasurementNote?.call(column(prior), savedColumn);
      await previousReadGuard?.verify();
      checkAccess();
      return CoachMessagePresentation.localRead(
        ownerKey: owner,
        capturedAtUtc: captured,
        kind: CoachVisualKind.measurement,
        title: 'Body measurements',
        fromDay: saved.dayKey,
        throughDay: saved.dayKey,
        columns: [savedColumn],
        notes: [savedNote, ?comparison],
      );
    });
  }

  Future<CoachMessagePresentation?> health(
    Map<String, Object?> result, {
    required void Function() checkAccess,
    List<String> notes = const [],
  }) async {
    checkAccess();
    final rows = result['rows'];
    if (rows is! List ||
        rows.isEmpty ||
        rows.length > 31 ||
        rows.any((x) => x is! Map)) {
      return null;
    }
    final from = result['from'], through = result['through'];
    if (from is! String || through is! String) return null;
    final owner = LocalDatabaseScope.keyForOwner(database.localOwnerId);
    final captured = clock().toUtc();
    if (result['topic'] == 'daily') {
      return database.transaction(() async {
        final columns = <CoachVisualNutritionColumn>[];
        final reader = CoachMessageNutritionReader(database, clock: clock);
        for (final raw in rows) {
          checkAccess();
          final day = (raw as Map)['day'];
          if (day is! String) return null;
          final snapshot = await reader.readDay(
            DateTime.parse(day),
            checkAccess: checkAccess,
          );
          checkAccess();
          columns.add(snapshot.columns.single);
        }
        checkAccess();
        return CoachMessagePresentation.localRead(
          ownerKey: owner,
          capturedAtUtc: captured,
          kind: columns.length == 1
              ? CoachVisualKind.nutrition
              : CoachVisualKind.comparison,
          title: 'Day summary',
          notes: notes,
          fromDay: from,
          throughDay: through,
          columns: columns,
        );
      });
    }
    if (result['topic'] == 'weight' || result['topic'] == 'progress') {
      final points = <CoachVisualWeightPoint>[];
      for (final raw in rows) {
        final row = raw as Map,
            value = row['weightKg'],
            date = row['recordedAtUtc'],
            day = row['day'];
        if (value is! num ||
            !value.isFinite ||
            date is! String ||
            day is! String) {
          return null;
        }
        points.add(
          CoachVisualWeightPoint(
            recordedAtUtc: DateTime.parse(date).toUtc(),
            dayKey: day,
            kg: value.toDouble(),
            context: row['measurementContext'] is String
                ? row['measurementContext']! as String
                : '',
          ),
        );
      }
      points.sort((a, b) => a.recordedAtUtc.compareTo(b.recordedAtUtc));
      checkAccess();
      return CoachMessagePresentation.localRead(
        ownerKey: owner,
        capturedAtUtc: captured,
        kind: CoachVisualKind.weight,
        title: 'Weight',
        notes: notes,
        fromDay: from,
        throughDay: through,
        weightPoints: points,
      );
    }
    if (result['topic'] == 'measurements') {
      final columns = <CoachVisualNutritionColumn>[];
      const fields = {
        'neck': 'neckCm',
        'waist': 'waistCm',
        'hips': 'hipsCm',
        'chest': 'chestCm',
        'arm': 'armCm',
        'thigh': 'thighCm',
      };
      for (final raw in rows) {
        final row = raw as Map, day = row['day'];
        if (day is! String) return null;
        final metrics = <CoachVisualMetric>[];
        for (final field in fields.entries) {
          final value = row[field.value];
          final known = value is num && value.isFinite && value >= 0;
          metrics.add(
            CoachVisualMetric.localRead(
              id: field.key,
              knownSubtotal: known ? (value).toDouble() : null,
              knownItems: known ? 1 : 0,
              missingItems: known ? 0 : 1,
            ),
          );
        }
        columns.add(
          CoachVisualNutritionColumn(
            title: 'Body measurements',
            dayKey: day,
            metrics: metrics,
            sourceKinds: const ['saved_measurements'],
            capturedAtUtc: captured,
          ),
        );
      }
      checkAccess();
      return CoachMessagePresentation.localRead(
        ownerKey: owner,
        capturedAtUtc: captured,
        kind: columns.length == 1
            ? CoachVisualKind.measurement
            : CoachVisualKind.comparison,
        title: 'Body measurements',
        notes: notes,
        fromDay: from,
        throughDay: through,
        columns: columns,
      );
    }
    return null;
  }
}
