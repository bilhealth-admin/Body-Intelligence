import 'cloud_nutrition_snapshot_codec.dart';
import 'cloud_restore_v2_engine.dart';
import 'cloud_restore_v2_journal.dart';

final class CloudRestoreConflictChoice {
  const CloudRestoreConflictChoice(
    this.engine,
    this.row,
    this.remote,
    this.local,
    this.token,
  );
  final CloudRestoreV2Engine engine;
  final RestoreJournalEntry row;
  final CloudNutritionSnapshot remote;
  final CloudNutritionSnapshot? local;
  final String token;
}

/// The prepared engine retains the exact consent/session lease of this review.
final class CloudRestoreConflictService {
  const CloudRestoreConflictService(this.prepare);
  final Future<CloudRestoreV2Engine> Function() prepare;

  Future<List<CloudRestoreConflictChoice>> read() async {
    final engine = await prepare();
    final choices = <CloudRestoreConflictChoice>[];
    for (final row in await engine.conflicts({'nutrition', 'goals'})) {
      final remote = await engine.conflictSnapshot(row);
      final locals = (await engine.codec.capture(
        scopes: {row.scope},
      )).where((value) => value.key == row.key);
      choices.add(
        CloudRestoreConflictChoice(
          engine,
          row,
          remote,
          locals.firstOrNull,
          await engine.conflictToken(row),
        ),
      );
    }
    return choices;
  }

  Future<CloudRestoreV2Report> resolve(
    CloudRestoreConflictChoice choice, {
    required bool keepLocal,
  }) async {
    await choice.engine.resolveConflict(
      choice.row.key,
      keepLocal: keepLocal,
      expectedToken: choice.token,
    );
    return choice.engine.run({choice.row.scope});
  }
}
