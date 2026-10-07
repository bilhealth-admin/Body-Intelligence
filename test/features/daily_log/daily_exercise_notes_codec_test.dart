import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/daily_log/domain/daily_exercise_notes_codec.dart';

void main() {
  test('custom workout JSON exposes only its title to the UI', () {
    const raw =
        '{"kind":"custom_workout_routine","id":"custom-1","title":"CV","movementIds":["core"],"movementCount":1}';

    final view = DailyExerciseNotesCodec.decode(raw);

    expect(view.displayNames, const ['CV']);
    expect(view.manualText, isEmpty);
    expect(view.compose(manualText: ''), raw);
  });

  test('trusted and library workouts use title or name without leaking JSON', () {
    final view = DailyExerciseNotesCodec.decode(
      [
        '{"kind":"trusted_workout_routine","id":"x","title":"Core strength"}',
        '{"id":"walk","name":"Brisk walk","minutes":20,"recordedAt":"2026-10-07T08:00:00Z"}',
      ].join('\n'),
    );

    expect(view.displayNames, const ['Core strength', 'Brisk walk']);
    expect(view.manualText, isEmpty);
  });

  test('legacy free text stays editable while structured payload is preserved', () {
    const raw =
        '{"kind":"custom_workout_routine","id":"custom-1","title":"CV"}\nFelt strong today';

    final view = DailyExerciseNotesCodec.decode(raw);

    expect(view.displayNames, const ['CV']);
    expect(view.manualText, 'Felt strong today');
    expect(
      view.compose(manualText: 'Easy session'),
      '{"kind":"custom_workout_routine","id":"custom-1","title":"CV"}\nEasy session',
    );
  });

  test(
    'malformed JSON-shaped internal data is preserved but never displayed',
    () {
      const raw = '{"kind":"custom_workout_routine"';

      final view = DailyExerciseNotesCodec.decode(raw);

      expect(view.displayNames, isEmpty);
      expect(view.manualText, isEmpty);
      expect(view.compose(manualText: ''), raw);
    },
  );
}
