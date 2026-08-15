import 'package:body_intelligence_log/features/nutrition/services/food_search_assistance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assistance = FoodSearchAssistance();

  test('expands Arabic and misspelled chicken queries', () {
    expect(assistance.expand('دجاج'), contains('chicken'));
    expect(assistance.expand('شيكن'), contains('chicken'));
    expect(assistance.expand('chek'), contains('chicken'));
    expect(assistance.expand('chiken'), contains('chicken'));
  });

  test('generates useful Arabic names', () {
    expect(assistance.arabicNameFor('Chicken, ground, raw'), contains('دجاج'));
    expect(assistance.arabicNameFor('APPLES, FUJI'), 'تفاح فوجي');
  });
}
