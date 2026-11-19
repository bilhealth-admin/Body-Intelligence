import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goal editors write real profile and preference repositories', () {
    final page = File(
      'lib/features/settings/reference_goals_page.dart',
    ).readAsStringSync();
    final parts = <String, String>{
      for (final name in [
        'reference_goals_components.dart',
        'reference_goals_validation.dart',
        'reference_goals_owner_visit.dart',
        'reference_goals_weight_editors.dart',
      ])
        name: File('lib/features/settings/$name').readAsStringSync(),
    };
    for (final entry in parts.entries) {
      expect(
        page
            .split(RegExp(r'\r?\n'))
            .where((line) => line == "part '${entry.key}';"),
        hasLength(1),
        reason: 'The tested implementation must be a declared Goals part.',
      );
      expect(
        entry.value.split(RegExp(r'\r?\n')).first,
        "part of 'reference_goals_page.dart';",
        reason: entry.key,
      );
    }
    final components = parts['reference_goals_components.dart']!;
    final editors = parts['reference_goals_weight_editors.dart']!;
    final owner = parts['reference_goals_owner_visit.dart']!;
    final goals = [page, ...parts.values].join('\n');
    expect(goals, contains('startingWeightEditor'));
    expect(goals, contains("Key('goals-starting-date')"));
    expect(goals, contains('repo.setManyInCurrentTransaction({'));
    expect(goals, contains("'goals.startingWeight':"));
    expect(goals, contains("'goals.startingDate':"));
    expect(goals, contains('userProfileRepositoryProvider'));
    expect(goals, contains("'goals.workoutsPerWeek' ? 14 : 300"));
    expect(components, contains('if (editorOpen) return'));

    String section(String source, String begin, String end) {
      final start = source.indexOf(begin);
      expect(start, greaterThanOrEqualTo(0), reason: begin);
      expect(source.indexOf(begin, start + begin.length), -1, reason: begin);
      final finish = source.indexOf(end, start + begin.length);
      expect(finish, greaterThan(start), reason: end);
      return source.substring(start, finish);
    }

    // These scopes bind the key and guards to the actual editors, rather than
    // finding matching text in an unrelated file or another method.
    const numberHead = '  Future<double?> numberEditor(';
    const startingHead =
        '  Future<({double weight, DateTime? date})?> startingWeightEditor(';
    final numberEditor = section(editors, numberHead, startingHead);
    final startingEditor = section(editors, startingHead, '\n}');
    final guardedEntry = RegExp(
      r'if\s*\(_numberEditorOpen\s*\|\|\s*!visit\.current\)\s*'
      r'\{\s*return null;\s*\}',
    );
    final guardedConfirmation = RegExp(
      r'if\s*\(!visit\.current\s*\|\|\s*!sheetContext\.mounted\)\s*'
      r'\{\s*return;\s*\}',
    );
    for (final editor in [numberEditor, startingEditor]) {
      expect(guardedEntry.allMatches(editor), hasLength(1));
      expect(guardedConfirmation.allMatches(editor), hasLength(1));
      expect(editor, contains('return visit.current ? result : null;'));
    }
    expect(startingEditor, contains("Key('goals-starting-date')"));
    expect(
      startingEditor,
      contains('selected != null &&\n                        visit.current &&'),
    );

    final startingRow = section(
      page,
      "label: c('Starting Weight'),",
      "label: c('Current Weight'),",
    );
    expect(startingRow, contains('await startingWeightEditor('));
    expect(startingRow, contains('if (value == null || !visit.current)'));
    expect(
      RegExp(
        r'final repo = visit\.preferences;\s*'
        r'final saved = await _writeGoal\(\s*visit,\s*'
        r'\(\) => repo\.setManyInCurrentTransaction\(\{',
      ).hasMatch(startingRow),
      isTrue,
    );
    expect(startingRow, contains("'goals.startingWeight':"));
    expect(startingRow, contains("'goals.startingDate':"));
    expect(startingRow, contains('if (saved && visit.current)'));

    final writeGoal = section(
      owner,
      '  Future<bool> _writeGoal(',
      '  String _goalWeightText(',
    );
    expect(writeGoal, contains('if (saving || !visit.current)'));
    expect(
      RegExp(
        r'await visit\.database\.transaction\(\(\) async \{\s*'
        r'visit\.check\(\);\s*await operation\(\);\s*'
        r'visit\.check\(\);\s*\}\);',
      ).hasMatch(writeGoal),
      isTrue,
    );
    expect(owner, contains('database.localOwnerId != identity.ownerId'));
    expect(owner, contains('repository.localOwnerId != database.localOwnerId'));
    expect(owner, contains('epoch == _goalOwnerEpoch'));
    expect(
      page,
      contains('final profiles = ref.read(userProfileRepositoryProvider)'),
    );
    expect(page, contains('await profiles.save('));
  });

  test('nutrition goals include complete persisted nutrient key set', () {
    final nutrition = [
      'lib/features/settings/reference_preferences_pages.dart',
      'lib/features/settings/reference_preferences_controls.dart',
      'lib/features/settings/reference_preferences_numeric.dart',
      'lib/features/settings/reference_preferences_macros.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final snapshot = File(
      'lib/features/nutrition/domain/nutrition_goal_snapshot.dart',
    ).readAsStringSync();
    for (final key in [
      'goal.calories',
      'goal.carbsPercent',
      'goal.proteinPercent',
      'goal.fatPercent',
      'goal.saturatedFat',
      'goal.polyunsaturatedFat',
      'goal.monounsaturatedFat',
      'goal.transFat',
      'goal.cholesterol',
      'goal.sodium',
      'goal.potassium',
      'goal.fiber',
      'goal.sugar',
      'goal.vitaminAMcg',
      'goal.vitaminCMg',
      'goal.calciumMg',
      'goal.ironMg',
      'goal.magnesium',
      'goal.phosphorus',
    ]) {
      expect(nutrition, contains("'$key'"), reason: key);
    }
    expect(snapshot, contains("'goal.vitaminAMcg': 'goal.vitaminA'"));
    expect(snapshot, contains("'goal.vitaminCMg': 'goal.vitaminC'"));
    expect(snapshot, contains("'goal.calciumMg': 'goal.calcium'"));
    expect(snapshot, contains("'goal.ironMg': 'goal.iron'"));
    expect(nutrition, contains('if (editorOpen) return'));
    expect(nutrition, contains('preferencesRepositoryProvider'));
  });
}
