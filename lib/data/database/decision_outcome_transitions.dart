import 'package:drift/drift.dart';

import 'database_ids.dart';
import 'decision_memories.dart';

/// Append-only persistence for auditable decision outcome changes.
class DecisionOutcomeTransitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newDatabaseId).unique()();
  IntColumn get decisionMemoryId => integer().references(
    DecisionMemories,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get fromState => text()();
  TextColumn get toState => text()();
  TextColumn get reason => text()();
  TextColumn get evidenceIdsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
