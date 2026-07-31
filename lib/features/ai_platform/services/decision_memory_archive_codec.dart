import '../domain/decision_memory_archive.dart';
import '../domain/decision_memory_record.dart';
import '../domain/decision_outcome_transition.dart';
import 'decision_memory.dart';

/// Deterministic, persistence-neutral Decision Memory export/import contract.
///
/// The codec owns no filesystem, database, cloud, retention, or encryption
/// policy. Adapters may persist the returned map without changing domain rules.
final class DecisionMemoryArchiveCodec {
  const DecisionMemoryArchiveCodec();

  DecisionMemoryArchive export(DecisionMemory memory) {
    final histories = memory.all.toList(growable: false)
      ..sort((left, right) {
        final time = left.record.createdAt.compareTo(right.record.createdAt);
        return time != 0 ? time : left.record.id.compareTo(right.record.id);
      });

    return DecisionMemoryArchive(
      schemaVersion: DecisionMemoryArchive.currentSchemaVersion,
      entries: histories.map(
        (history) => DecisionMemoryArchiveEntry(
          record: history.record,
          transitions: history.transitions,
        ),
      ),
    );
  }

  Map<String, Object?> encode(DecisionMemory memory) {
    final archive = export(memory);
    return <String, Object?>{
      'schemaVersion': archive.schemaVersion,
      'entries': archive.entries.map(_encodeEntry).toList(growable: false),
    };
  }

  DecisionMemory decode(Map<String, Object?> document) {
    final schemaVersion = _requiredInt(document, 'schemaVersion');
    if (schemaVersion != DecisionMemoryArchive.currentSchemaVersion) {
      throw FormatException(
        'Unsupported Decision Memory archive schema: $schemaVersion',
      );
    }

    final rawEntries = _requiredList(document, 'entries');
    final memory = DecisionMemory();
    final transitionIds = <String>{};

    for (final rawEntry in rawEntries) {
      final entry = _requiredMap(rawEntry, 'entry');
      final record = _decodeRecord(_requiredMap(entry['record'], 'record'));
      memory.remember(record);

      final rawTransitions = _requiredList(entry, 'transitions');
      for (final rawTransition in rawTransitions) {
        final transition = _decodeTransition(
          _requiredMap(rawTransition, 'transition'),
        );
        if (!transitionIds.add(transition.id)) {
          throw FormatException(
            'Duplicate outcome transition id: ${transition.id}',
          );
        }
        memory.appendOutcome(transition);
      }
    }

    return memory;
  }

  Map<String, Object?> _encodeEntry(DecisionMemoryArchiveEntry entry) {
    return <String, Object?>{
      'record': _encodeRecord(entry.record),
      'transitions': entry.transitions
          .map(_encodeTransition)
          .toList(growable: false),
    };
  }

  Map<String, Object?> _encodeRecord(DecisionMemoryRecord record) {
    return <String, Object?>{
      'id': record.id,
      'createdAt': record.createdAt.toUtc().toIso8601String(),
      'decisionKey': record.decisionKey,
      'selectedAction': record.selectedAction,
      'rationale': record.rationale,
      'confidence': record.confidence,
      'evidenceIds': record.evidenceIds.toList(growable: false),
      'outcomeState': record.outcomeState,
    };
  }

  Map<String, Object?> _encodeTransition(DecisionOutcomeTransition transition) {
    return <String, Object?>{
      'id': transition.id,
      'decisionRecordId': transition.decisionRecordId,
      'occurredAt': transition.occurredAt.toUtc().toIso8601String(),
      'fromState': transition.fromState.name,
      'toState': transition.toState.name,
      'reason': transition.reason,
      'evidenceIds': transition.evidenceIds.toList(growable: false),
    };
  }

  DecisionMemoryRecord _decodeRecord(Map<String, Object?> map) {
    return DecisionMemoryRecord(
      id: _requiredString(map, 'id'),
      createdAt: _requiredDateTime(map, 'createdAt'),
      decisionKey: _requiredString(map, 'decisionKey'),
      selectedAction: _requiredString(map, 'selectedAction'),
      rationale: _requiredString(map, 'rationale'),
      confidence: _requiredDouble(map, 'confidence'),
      evidenceIds: _requiredStringList(map, 'evidenceIds'),
      outcomeState: _requiredString(map, 'outcomeState'),
    );
  }

  DecisionOutcomeTransition _decodeTransition(Map<String, Object?> map) {
    return DecisionOutcomeTransition(
      id: _requiredString(map, 'id'),
      decisionRecordId: _requiredString(map, 'decisionRecordId'),
      occurredAt: _requiredDateTime(map, 'occurredAt'),
      fromState: _requiredOutcomeState(map, 'fromState'),
      toState: _requiredOutcomeState(map, 'toState'),
      reason: _requiredString(map, 'reason'),
      evidenceIds: _requiredStringList(map, 'evidenceIds'),
    );
  }

  static Map<String, Object?> _requiredMap(Object? value, String field) {
    if (value is! Map) {
      throw FormatException('$field must be an object.');
    }
    return value.map<String, Object?>(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  static List<Object?> _requiredList(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value is! List) {
      throw FormatException('$field must be a list.');
    }
    return value.cast<Object?>();
  }

  static String _requiredString(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string.');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value is! int) {
      throw FormatException('$field must be an integer.');
    }
    return value;
  }

  static double _requiredDouble(Map<String, Object?> map, String field) {
    final value = map[field];
    if (value is! num) {
      throw FormatException('$field must be numeric.');
    }
    return value.toDouble();
  }

  static DateTime _requiredDateTime(Map<String, Object?> map, String field) {
    final value = _requiredString(map, field);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field must be an ISO-8601 timestamp.');
    }
    return parsed.toUtc();
  }

  static List<String> _requiredStringList(
    Map<String, Object?> map,
    String field,
  ) {
    final values = _requiredList(map, field);
    if (values.any((value) => value is! String)) {
      throw FormatException('$field must contain only strings.');
    }
    return values.cast<String>();
  }

  static DecisionOutcomeState _requiredOutcomeState(
    Map<String, Object?> map,
    String field,
  ) {
    final value = _requiredString(map, field);
    for (final state in DecisionOutcomeState.values) {
      if (state.name == value) {
        return state;
      }
    }
    throw FormatException('$field contains an unsupported outcome state.');
  }
}
