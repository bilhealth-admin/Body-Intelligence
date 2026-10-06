import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_scope.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/body_measurement_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../data/repositories/water_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../domain/bil_tool_registry.dart';
import '../domain/coach_action_admission.dart';
import 'coach_memory_repository.dart';

part 'coach_native_command_models.dart';
part 'coach_native_command_snapshot.dart';
part 'coach_native_command_journal.dart';
part 'coach_native_command_writes.dart';
part 'coach_native_command_undo.dart';

/// The native Coach owns one transaction, one immutable proposal and one
/// durable readback. Ordinary editors keep their existing repository APIs.
final class CoachNativeCommandRepository {
  CoachNativeCommandRepository(
    this.database, {
    WaterRepository? water,
    WeightRepository? weights,
    UserProfileRepository? profiles,
    GoalRepository? goals,
    BodyMeasurementRepository? measurements,
    PreferencesRepository? preferences,
  }) : water = water ?? WaterRepository(database),
       weights = weights ?? WeightRepository(database),
       profiles = profiles ?? UserProfileRepository(database),
       goals = goals ?? GoalRepository(database),
       measurements = measurements ?? BodyMeasurementRepository(database),
       preferences = preferences ?? PreferencesRepository(database);

  final AppDatabase database;
  final WaterRepository water;
  final WeightRepository weights;
  final UserProfileRepository profiles;
  final GoalRepository goals;
  final BodyMeasurementRepository measurements;
  final PreferencesRepository preferences;

  Future<CoachNativeCommand> prepare({
    required String toolId,
    required String operationId,
    required Map<String, Object?> arguments,
    required CoachNativeOwnerScope scope,
    required DateTime now,
  }) async {
    final kind = _nativeKind(toolId);
    if (!CoachActionAdmission.validOperationId(operationId)) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.operationMismatch,
      );
    }
    final validated = const BilToolRegistry()
        .lookup(toolId)
        ?.validateArguments(arguments);
    if (validated == null ||
        kind == CoachNativeCommandKind.memory && validated['text'] is! String) {
      throw ArgumentError('Invalid native command arguments');
    }
    final inputDigest = _nativeDigest({
      'toolId': toolId,
      'arguments': validated,
    });
    return database.transaction(() async {
      final prior = await _readJournal(operationId, scope);
      if (prior != null) {
        if (prior.command.toolId != toolId ||
            prior.command.inputDigest != inputDigest) {
          throw const CoachNativeConflict(
            CoachNativeConflictReason.operationMismatch,
          );
        }
        return prior.command;
      }
      final resolved = <String, Object?>{
        ...validated,
        'occurredAt':
            (kind == CoachNativeCommandKind.water
                    ? validated['date'] != null
                          ? DateTime.parse(validated['date']! as String)
                          : DateTime.fromMillisecondsSinceEpoch(
                              now.millisecondsSinceEpoch ~/ 1000 * 1000,
                              isUtc: now.isUtc,
                            )
                    : now)
                .toIso8601String(),
      };
      if (kind == CoachNativeCommandKind.weight ||
          kind == CoachNativeCommandKind.measurements) {
        resolved['date'] = validated['date'] ?? dayKeyFor(now);
      }
      if (kind == CoachNativeCommandKind.memory) {
        resolved['text'] = (validated['text']! as String).trim();
        resolved['kind'] = validated['kind'] ?? 'user_fact';
      }
      final before = await _readSnapshot(kind, resolved, scope);
      if (kind == CoachNativeCommandKind.goal && before.profile == null) {
        throw const CoachNativeConflict(
          CoachNativeConflictReason.missingRecord,
        );
      }
      if (kind == CoachNativeCommandKind.memory) {
        final matching = before.memories!.where(
          (entry) =>
              (entry['text']! as String).toLowerCase() ==
              (resolved['text']! as String).toLowerCase(),
        );
        resolved['memoryId'] = matching.isEmpty
            ? const Uuid().v4()
            : matching.first['id'];
      }
      scope.check(database.localOwnerId);
      return CoachNativeCommand._(
        operationId: operationId,
        toolId: toolId,
        kind: kind,
        inputDigest: inputDigest,
        arguments: validated,
        resolved: resolved,
        before: before,
      );
    });
  }

  Future<CoachNativeCommit> commit({
    required CoachNativeCommand command,
    required CoachNativeOwnerScope scope,
  }) async {
    var replayed = false;
    await database.transaction(() async {
      final prior = await _readJournal(command.operationId, scope);
      if (prior != null) {
        _requireMatchingOperation(prior, command);
        replayed = true;
        return;
      }
      final before = await _readSnapshot(command.kind, command.resolved, scope);
      if (!_sameNativeSnapshot(command.before, before)) {
        throw const CoachNativeConflict(CoachNativeConflictReason.staleRecord);
      }
      final after = await _apply(command, before, scope);
      final journal = _NativeJournal(
        command: command,
        ownerScope: LocalDatabaseScope.keyForOwner(database.localOwnerId),
        committedAt: DateTime.now(),
        after: after,
      );
      await _writeJournal(journal, scope);
      scope.check(database.localOwnerId);
    });
    return _commitReadback(command.operationId, scope, replayed: replayed);
  }

  Future<CoachNativeCommit> undo({
    required String operationId,
    required String toolId,
    required String argumentsDigest,
    required CoachNativeOwnerScope scope,
  }) async {
    var replayed = false;
    await database.transaction(() async {
      final journal = await _readJournal(operationId, scope);
      if (journal == null ||
          journal.command.toolId != toolId ||
          journal.command.argumentsDigest != argumentsDigest) {
        throw const CoachNativeConflict(
          CoachNativeConflictReason.operationMismatch,
        );
      }
      if (journal.undoneAt != null) {
        replayed = true;
        return;
      }
      final current = await _readSnapshot(
        journal.command.kind,
        journal.command.resolved,
        scope,
        waterId: journal.after.water?.id,
      );
      if (!_sameNativeSnapshot(journal.after, current)) {
        throw const CoachNativeConflict(CoachNativeConflictReason.staleRecord);
      }
      final undoAfter = await _compensate(journal, scope);
      await _writeJournal(journal.compensated(undoAfter), scope);
      scope.check(database.localOwnerId);
    });
    return _commitReadback(operationId, scope, replayed: replayed);
  }
}
