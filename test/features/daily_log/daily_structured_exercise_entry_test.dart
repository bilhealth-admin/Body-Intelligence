import 'package:body_intelligence_log/features/daily_log/domain/daily_exercise_notes_codec.dart';
import 'package:flutter_test/flutter_test.dart';

const _first =
    '{"id":"bench","name":"Bench push-up","minutes":10,"recordedAt":"2026-11-17T08:00:00Z"}';
const _second =
    '{"id":"bench","name":"Bench push-up","minutes":20,"recordedAt":"2026-11-17T09:00:00Z"}';
const _walk =
    '{"id":"walk","name":"Walk","minutes":30,"recordedAt":"2026-11-17T10:00:00Z"}';

void main() {
  test('removing a workout preserves untouched whitespace-only neighbours', () {
    const raw = '  \r\n$_first\r\n \t\n';
    final selected = DailyExerciseNotesCodec.decode(raw).entries.single;
    expect(DailyExerciseNotesCodec.removeEntry(raw, selected), '  \r\n \t\n');
  });

  test(
    'remove one repeated exercise occurrence without normalizing any other bytes',
    () {
      const damaged = '{"kind":"future_payload"';
      const raw =
          '  Warm-up  \r\n$_first\r\n$damaged\n$_second\r$_walk\n  Cool down  \n';
      final view = DailyExerciseNotesCodec.decode(raw);
      expect(view.displayNames, ['Bench push-up', 'Walk']);
      expect(view.entries.map((entry) => entry.displayName), [
        'Bench push-up',
        'Bench push-up',
        'Walk',
      ]);
      expect(view.entries.map((entry) => entry.sourceLineIndex), [1, 3, 4]);
      final actual = DailyExerciseNotesCodec.removeEntry(raw, view.entries[1]);
      expect(
        actual,
        '  Warm-up  \r\n$_first\r\n$damaged\n$_walk\n  Cool down  \n',
      );
      expect(
        DailyExerciseNotesCodec.decode(actual).manualText,
        'Warm-up\nCool down',
      );
    },
  );

  test('removing the last structured entry clears only its own line', () {
    final entry = DailyExerciseNotesCodec.decode(_first).entries.single;
    expect(DailyExerciseNotesCodec.removeEntry(_first, entry), isNull);
    const mixed = '  My note  \n$_first';
    final mixedEntry = DailyExerciseNotesCodec.decode(mixed).entries.single;
    expect(
      DailyExerciseNotesCodec.removeEntry(mixed, mixedEntry),
      '  My note  \n',
    );
  });

  test('a stale position cannot delete the adjacent workout', () {
    const raw = '$_first\n$_second\n$_walk';
    final selected = DailyExerciseNotesCodec.decode(raw).entries[1];
    expect(
      () => DailyExerciseNotesCodec.removeEntry('$_first\n$_walk', selected),
      throwsStateError,
    );
    expect(
      () => DailyExerciseNotesCodec.removeEntry(_first, selected),
      throwsStateError,
    );
  });

  test('custom routine titles have independent removable occurrences', () {
    const routine =
        '{"kind":"custom_workout_routine","id":"routine","title":"CV","movementIds":["core"]}';
    final view = DailyExerciseNotesCodec.decode('$routine\n$_first');
    expect(view.entries.first.displayName, 'CV');
    expect(
      DailyExerciseNotesCodec.removeEntry(
        '$routine\n$_first',
        view.entries.first,
      ),
      _first,
    );
    expect(view.compose(manualText: 'New note'), '$routine\n$_first\nNew note');
  });
}
