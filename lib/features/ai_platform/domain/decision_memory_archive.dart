import 'dart:collection';

import 'decision_memory_record.dart';
import 'decision_outcome_transition.dart';

/// Immutable persistence-neutral export envelope for local Decision Memory.
final class DecisionMemoryArchive {
  DecisionMemoryArchive({
    required this.schemaVersion,
    required Iterable<DecisionMemoryArchiveEntry> entries,
  }) : entries = UnmodifiableListView<DecisionMemoryArchiveEntry>(
         entries.toList(growable: false),
       ) {
    if (schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'unsupported Decision Memory archive schema',
      );
    }
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final UnmodifiableListView<DecisionMemoryArchiveEntry> entries;
}

/// One immutable decision record and its append-only transition sequence.
final class DecisionMemoryArchiveEntry {
  DecisionMemoryArchiveEntry({
    required this.record,
    required Iterable<DecisionOutcomeTransition> transitions,
  }) : transitions = UnmodifiableListView<DecisionOutcomeTransition>(
         transitions.toList(growable: false),
       );

  final DecisionMemoryRecord record;
  final UnmodifiableListView<DecisionOutcomeTransition> transitions;
}
