import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'calorie save repairs legacy percentages from carbs and fat anchors',
    () {
      final snapshot = nutritionGoalSnapshotForCalories(
        calories: 950,
        carbsPercent: 30,
        fatPercent: 30,
      );

      expect(snapshot['goal.calories'], '950');
      expect(snapshot['goal.carbsPercent'], '30');
      expect(snapshot['goal.proteinPercent'], '40');
      expect(snapshot['goal.fatPercent'], '30');
      expect(snapshot['goal.carbsGrams'], '71.25');
      expect(snapshot['goal.proteinGrams'], '95');
      expect(snapshot['goal.fatGrams'], '31.67');
    },
  );

  test('invalid macro anchors fall back to a balanced 45/30/25 snapshot', () {
    final snapshot = nutritionGoalSnapshotForCalories(
      calories: 950,
      carbsPercent: 90,
      fatPercent: 30,
    );

    expect(snapshot['goal.carbsPercent'], '45');
    expect(snapshot['goal.proteinPercent'], '30');
    expect(snapshot['goal.fatPercent'], '25');
    expect(snapshot['goal.carbsGrams'], '106.88');
    expect(snapshot['goal.proteinGrams'], '71.25');
    expect(snapshot['goal.fatGrams'], '26.39');
  });

  test('opening goals repairs a legacy split above 100 percent', () {
    final repair = nutritionGoalRepairSnapshot({
      'goal.calories': '950',
      'goal.carbsPercent': '20',
      'goal.proteinPercent': '70',
      'goal.fatPercent': '20',
    });

    expect(repair, isNotNull);
    expect(repair!['goal.carbsPercent'], '20');
    expect(repair['goal.proteinPercent'], '60');
    expect(repair['goal.fatPercent'], '20');
    expect(repair['goal.carbsGrams'], '47.5');
    expect(repair['goal.proteinGrams'], '142.5');
    expect(repair['goal.fatGrams'], '21.11');
  });

  test('a complete canonical goal does not produce a redundant write', () {
    final canonical = nutritionGoalSnapshotForCalories(
      calories: 950,
      carbsPercent: 30,
      fatPercent: 30,
    );

    expect(
      nutritionGoalRepairSnapshot(
        canonical.map((key, value) => MapEntry<String, String?>(key, value)),
      ),
      isNull,
    );
  });
}
