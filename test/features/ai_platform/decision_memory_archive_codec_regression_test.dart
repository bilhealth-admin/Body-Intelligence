import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_archive_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = DecisionMemoryArchiveCodec();

  test('rejects duplicate records without replacing earlier evidence', () {
    final document = <String, Object?>{
      'schemaVersion': 1,
      'entries': <Object?>[_entry('duplicate'), _entry('duplicate')],
    };

    expect(() => codec.decode(document), throwsStateError);
  });

  test('rejects out-of-order transitions through established policy', () {
    final entry = _entry('decision-1');
    entry['transitions'] = <Object?>[
      _transition(
        id: 'transition-late',
        occurredAt: '2026-07-24T03:00:00.000Z',
      ),
      _transition(
        id: 'transition-early',
        occurredAt: '2026-07-24T02:00:00.000Z',
        fromState: 'succeeded',
        toState: 'failed',
      ),
    ];

    expect(
      () => codec.decode(<String, Object?>{
        'schemaVersion': 1,
        'entries': <Object?>[entry],
      }),
      throwsStateError,
    );
  });

  test('rejects unsupported schemas before reconstructing memory', () {
    expect(
      () => codec.decode(<String, Object?>{
        'schemaVersion': 99,
        'entries': const <Object?>[],
      }),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _entry(String id) {
  return <String, Object?>{
    'record': <String, Object?>{
      'id': id,
      'createdAt': '2026-07-24T01:00:00.000Z',
      'decisionKey': 'test',
      'selectedAction': 'observe',
      'rationale': 'Regression fixture.',
      'confidence': 0.5,
      'evidenceIds': <Object?>[],
      'outcomeState': 'pending',
    },
    'transitions': <Object?>[],
  };
}

Map<String, Object?> _transition({
  required String id,
  required String occurredAt,
  String fromState = 'pending',
  String toState = 'succeeded',
}) {
  return <String, Object?>{
    'id': id,
    'decisionRecordId': 'decision-1',
    'occurredAt': occurredAt,
    'fromState': fromState,
    'toState': toState,
    'reason': 'Regression fixture.',
    'evidenceIds': <Object?>[],
  };
}
