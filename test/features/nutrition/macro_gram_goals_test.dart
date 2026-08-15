import 'package:body_intelligence_log/features/nutrition/domain/macro_gram_goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit gram targets override plan targets independently', () {
    const goals = MacroGramGoals(protein: 145, carbohydrates: 210, fat: 65);

    expect(goals.proteinOr(100), 145);
    expect(goals.carbohydratesOr(180), 210);
    expect(goals.fatOr(50), 65);
  });

  test('missing or corrupt persisted goals fail closed to plan targets', () {
    expect(MacroGramGoals.parse(null), isNull);
    expect(MacroGramGoals.parse('0'), isNull);
    expect(MacroGramGoals.parse('-1'), isNull);
    expect(MacroGramGoals.parse('NaN'), isNull);
    expect(MacroGramGoals.parse('1001'), isNull);
    expect(MacroGramGoals.parse('125.5'), 125.5);

    const goals = MacroGramGoals();
    expect(goals.proteinOr(120), 120);
    expect(goals.carbohydratesOr(200), 200);
    expect(goals.fatOr(70), 70);
  });
}
