part of 'coach_native_command_repository.dart';

extension _NativeCommandWrites on CoachNativeCommandRepository {
  Future<CoachNativeSnapshot> _apply(
    CoachNativeCommand command,
    CoachNativeSnapshot before,
    CoachNativeOwnerScope scope,
  ) async {
    final args = command.resolved;
    int? waterId;
    switch (command.kind) {
      case CoachNativeCommandKind.water:
        waterId = await _awaitOwner(
          () => water.add(
            occurredAt: DateTime.parse(args['occurredAt']! as String),
            amountMl: args['amountMl']! as int,
          ),
          scope,
        );
      case CoachNativeCommandKind.weight:
        final prior = before.weight;
        final date = command.arguments['date'] == null
            ? DateTime.parse(args['occurredAt']! as String)
            : DateTime.parse(args['date']! as String);
        final id = await _awaitOwner(
          () => weights.addWeight(
            (args['weightKg']! as num).toDouble(),
            date: date,
            note: prior?.note,
            progressPhotoPath: prior?.progressPhotoPath,
            measurementContext:
                prior?.measurementContext ?? 'differentConditions',
          ),
          scope,
        );
        if (id <= 0) {
          throw const CoachNativeConflict(
            CoachNativeConflictReason.readbackUnavailable,
          );
        }
      case CoachNativeCommandKind.goal:
        final prior = before.profile;
        if (prior == null || prior.deletedAt != null) {
          throw const CoachNativeConflict(
            CoachNativeConflictReason.missingRecord,
          );
        }
        final history = await _awaitOwner(weights.getAll, scope);
        final currentWeight = history.isEmpty
            ? prior.currentWeight
            : history.first.weight;
        final target = (args['targetWeightKg']! as num).toDouble();
        final type = target < currentWeight
            ? 'lose'
            : target > currentWeight
            ? 'gain'
            : 'maintain';
        await _awaitOwner(
          () => profiles.save(
            gender: prior.gender,
            age: prior.age,
            height: prior.height,
            currentWeight: currentWeight,
            targetWeight: target,
            activityLevel: prior.activityLevel,
            exercises: prior.exercises,
            medicalConditions: prior.medicalConditions,
            waist: prior.waist,
            neck: prior.neck,
            chest: prior.chest,
            arm: prior.arm,
            thigh: prior.thigh,
          ),
          scope,
        );
        final id = await _awaitOwner(
          () => goals.save(
            uuid: before.goal?.uuid,
            profileUuid: prior.uuid,
            type: type,
            targetWeight: target,
            targetDate: args['targetDate'] == null
                ? null
                : DateTime.parse(args['targetDate']! as String),
          ),
          scope,
        );
        if (id <= 0) {
          throw const CoachNativeConflict(
            CoachNativeConflictReason.readbackUnavailable,
          );
        }
      case CoachNativeCommandKind.measurements:
        double? number(String key) => (args[key] as num?)?.toDouble();
        await _awaitOwner(
          () => measurements.saveForDay(
            date: DateTime.parse(args['date']! as String),
            neckCm: number('neckCm'),
            waistCm: number('waistCm'),
            hipsCm: number('hipsCm'),
            chestCm: number('chestCm'),
            armCm: number('armCm'),
            thighCm: number('thighCm'),
            preserveExistingValues: true,
          ),
          scope,
        );
      case CoachNativeCommandKind.memory:
        final id = args['memoryId']! as String;
        final prior = before.memory(id);
        final at = DateTime.parse(
          args['occurredAt']! as String,
        ).toUtc().toIso8601String();
        final entry = <String, Object?>{
          'id': id,
          'text': args['text'],
          'kind': args['kind'],
          'status': 'confirmed',
          'confidence': 1.0,
          'savedAt': prior?['savedAt'] ?? at,
          'updatedAt': at,
          'source': 'explicit_user_confirmation',
        };
        final entries = [
          entry,
          for (final old in before.memories!)
            if ((old['text']! as String).toLowerCase() !=
                (args['text']! as String).toLowerCase())
              old,
        ].take(50).toList(growable: false);
        await _awaitOwner(
          () => preferences.setManyInCurrentTransaction({
            CoachMemoryRepository.storageKey: jsonEncode(entries),
          }),
          scope,
        );
    }
    final after = await _readSnapshot(
      command.kind,
      args,
      scope,
      waterId: waterId,
    );
    if (!_matchesNativeWrite(command, before, after)) {
      throw const CoachNativeConflict(
        CoachNativeConflictReason.readbackUnavailable,
      );
    }
    return after;
  }
}

bool _matchesNativeWrite(
  CoachNativeCommand command,
  CoachNativeSnapshot before,
  CoachNativeSnapshot after,
) {
  final args = command.resolved;
  switch (command.kind) {
    case CoachNativeCommandKind.water:
      return after.water != null &&
          after.water!.deletedAt == null &&
          after.water!.amountMl == args['amountMl'] &&
          after.water!.occurredAt ==
              DateTime.parse(args['occurredAt']! as String);
    case CoachNativeCommandKind.weight:
      final row = after.weight;
      final prior = before.weight;
      return row != null &&
          row.deletedAt == null &&
          row.weight == args['weightKg'] &&
          row.dayKey == args['date'] &&
          (prior == null ||
              row.uuid == prior.uuid &&
                  row.revision == prior.revision + 1 &&
                  row.note == prior.note &&
                  row.progressPhotoPath == prior.progressPhotoPath);
    case CoachNativeCommandKind.goal:
      final profile = after.profile;
      final goal = after.goal;
      return profile != null &&
          goal != null &&
          profile.uuid == before.profile!.uuid &&
          profile.revision == before.profile!.revision + 1 &&
          profile.targetWeight == args['targetWeightKg'] &&
          goal.targetWeight == profile.targetWeight &&
          goal.profileUuid == profile.uuid &&
          goal.targetDate ==
              (args['targetDate'] == null
                  ? null
                  : DateTime.parse(args['targetDate']! as String)) &&
          (before.goal == null ||
              goal.uuid == before.goal!.uuid &&
                  goal.revision == before.goal!.revision + 1);
    case CoachNativeCommandKind.measurements:
      final row = after.measurement;
      if (row == null || row.deletedAt != null || row.dayKey != args['date']) {
        return false;
      }
      if (before.measurement != null &&
          (row.uuid != before.measurement!.uuid ||
              row.revision != before.measurement!.revision + 1)) {
        return false;
      }
      final saved = after.receiptPayload(command);
      final prior = before.receiptPayload(command);
      return const [
        'neckCm',
        'waistCm',
        'hipsCm',
        'chestCm',
        'armCm',
        'thighCm',
      ].every((key) => saved[key] == (args[key] ?? prior[key]));
    case CoachNativeCommandKind.memory:
      final entry = after.memory(args['memoryId']! as String);
      return entry != null &&
          entry['text'] == args['text'] &&
          entry['kind'] == args['kind'] &&
          entry['status'] == 'confirmed';
  }
}
