import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/services/food_search_assistance.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_search_normalizer.dart';
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

  test('localizes common cucumber USDA variants without losing meaning', () {
    expect(
      assistance.arabicNameFor('Cucumber, with peel, raw'),
      'خيار بقشره نيّئ',
    );
    expect(
      assistance.arabicNameFor('Pickles, cucumber, dill or kosher dill'),
      'مخلل خيار شبت كوشير',
    );
    expect(
      assistance.arabicNameFor('Cucumber, peeled, raw'),
      'خيار مقشّر نيّئ',
    );
  });

  test('does not publish lossy Arabic display names', () {
    expect(
      assistance.arabicNameFor(
        'Duck, scoter, white-winged, meat (Alaska Native)',
      ),
      isNull,
    );
    expect(
      assistance.arabicNameFor('Chicken breast roasted skinless'),
      'دجاج صدر مشوي بدون جلد',
    );
  });

  test('expands common food names independently of UI language', () {
    expect(assistance.expand('яблоко'), contains('apple'));
    expect(assistance.expand('りんご'), contains('apple'));
    expect(assistance.expand('鸡肉'), contains('chicken'));
    expect(assistance.expand('आलू'), contains('potato'));
    expect(assistance.expand('มันฝรั่ง'), contains('potato'));
  });

  test('empty-state correction never invents a fuzzy neighbouring food', () {
    expect(assistance.explicitCorrectionFor('chiken'), 'chicken');
    expect(assistance.explicitCorrectionFor('totally unknown dish'), isNull);

    final foodPage = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();
    expect(foodPage, contains('_assistance.explicitCorrectionFor(trimmed)'));
    expect(foodPage, isNot(contains('_assistance.correctionFor(trimmed)')));
  });

  test('normalizer preserves every supported writing system', () {
    expect(FoodSearchNormalizer.normalize('ЯБЛОКО'), 'яблоко');
    expect(FoodSearchNormalizer.normalize('りんご'), 'りんご');
    expect(FoodSearchNormalizer.normalize('鸡肉'), '鸡肉');
    expect(FoodSearchNormalizer.normalize('आलू'), 'आलू');
    expect(FoodSearchNormalizer.normalize('มันฝรั่ง'), 'มันฝรั่ง');
  });
}
