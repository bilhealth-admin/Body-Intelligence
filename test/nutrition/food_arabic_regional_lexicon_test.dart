import 'package:flutter_test/flutter_test.dart';

import '../../lib/features/nutrition/services/trusted_food_network_search_resolver.dart';

import '../../lib/features/nutrition/services/food_arabic_regional_lexicon.dart';
import '../../lib/features/nutrition/services/food_multilingual_lexicon.dart';
import '../../lib/features/nutrition/services/food_multilingual_core_lexicon.dart'
    as core;
import '../../lib/features/nutrition/services/food_search_assistance.dart';

void main() {
  test('every authored spelling resolves without ambiguous aliases', () {
    for (final entry in FoodArabicRegionalLexicon.aliases.entries) {
      for (final alias in entry.value) {
        expect(FoodArabicRegionalLexicon.expand(alias), contains(entry.key),
            reason: alias);
      }
    }
  });

  test('Arabic diacritics, spelling and tatweel normalize', () {
    expect(FoodArabicRegionalLexicon.expand('  مُجَدَّرَة  '),
        contains('mujaddara'));
    expect(FoodArabicRegionalLexicon.expand('كــبسه'), contains('kabsa'));
  });

  test('brand and food can be searched together', () {
    expect(FoodMultilingualLexicon.expand('جهينة حليب'),
        contains('juhayna milk'));
    expect(const FoodSearchAssistance().expand('مزارع دينا حليب'),
        contains('dina farms milk'));
  });

  test('longest phrase wins and numeric qualifiers are retained', () {
    expect(FoodArabicRegionalLexicon.expand('دبس الرمان ٢٥٠ غرام'),
        contains('pomegranate molasses 250 غرام'));
    expect(FoodArabicRegionalLexicon.expand('جهينة حليب خالي الدسم'),
        contains('juhayna حليب خالي الدسم'));
  });

  test('do not guess a product from a brand substring', () {
    expect(FoodArabicRegionalLexicon.expand('superjuhayna'),
        ['superjuhayna']);
    expect(FoodArabicRegionalLexicon.expand('نادكم'), ['نادكم']);
  });

  test('distinct dishes never turn into interchangeable nutrition', () {
    expect(FoodArabicRegionalLexicon.expand('منسف'), isNot(contains('rice')));
    expect(FoodArabicRegionalLexicon.expand('طعمية'),
        isNot(contains('falafel')));
    expect(FoodArabicRegionalLexicon.expand('حمص بالطحينة'),
        contains('hummus'));
  });

  test('empty and unknown searches stay honest', () {
    expect(FoodArabicRegionalLexicon.expand(''), isEmpty);
    expect(FoodArabicRegionalLexicon.expand('منتج غير معروف'),
        ['منتج غير معروف']);
    expect(FoodArabicRegionalLexicon.expand('3017624010701'),
        ['3017624010701']);
  });

  test('all previous language expansions remain a stable prefix', () {
    for (final query in [
      'りんご', 'яблоко', 'মাছ', '닭고기', '苹果', 'manzana', 'pomme',
      'tavuk', 'दूध', 'susu', 'thịt bò', 'ข้าว', 'جبن', 'دجاج',
      'جهينة حليب', 'كشري', 'unknown item',
    ]) {
      final before = core.FoodMultilingualLexicon.expand(query);
      final after = FoodMultilingualLexicon.expand(query);
      expect(after.take(before.length).toList(), before, reason: query);
      expect(after.toSet().length, after.length, reason: query);
    }
  });
  test('actual outbound network hint retains regional brands', () {
    const resolver = TrustedFoodNetworkSearchResolver();
    expect(resolver.searchHintForTesting('جهينة حليب'), 'juhayna milk');
    expect(resolver.searchHintForTesting('مزارع دينا حليب'), 'dina farms milk');
    expect(resolver.searchHintForTesting('المراعي حليب'), 'almarai milk');
  });

  test('actual outbound hint retains a dish and its translated ingredient', () {
    const resolver = TrustedFoodNetworkSearchResolver();
    expect(resolver.searchHintForTesting('كبسة دجاج'), 'kabsa chicken');
    expect(resolver.searchHintForTesting('كشري'), 'koshari');
  });

  test('established single-food fallback is retained', () {
    const resolver = TrustedFoodNetworkSearchResolver();
    expect(resolver.searchHintForTesting('بطيخ الكيوي'), 'watermelon');
    expect(resolver.searchHintForTesting('りんご'), 'apple');
    expect(resolver.searchHintForTesting('яблоко'), 'apple');
    expect(resolver.searchHintForTesting(''), isNull);
  });

}
