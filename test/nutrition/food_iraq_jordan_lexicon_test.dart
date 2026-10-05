import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/nutrition/services/food_iraq_jordan_lexicon.dart';
import '../../lib/features/nutrition/services/food_search_normalizer.dart';
import '../../lib/features/nutrition/services/food_multilingual_lexicon.dart';
import '../../lib/features/nutrition/services/trusted_food_network_search_resolver.dart';

void main() {
  test('all Iraqi and Jordanian authored spellings resolve', () {
    final owners = <String, String>{};
    for (final entry in FoodIraqJordanLexicon.aliases.entries) {
      for (final spelling in [entry.key, ...entry.value]) {
        final key = FoodSearchNormalizer.normalize(spelling);
        expect(owners[key] == null || owners[key] == entry.key, isTrue,
            reason: 'Conflicting alias $spelling');
        owners[key] = entry.key;
        expect(FoodIraqJordanLexicon.expand(spelling), contains(entry.key));
      }
    }
  });
  test('Iraqi letters and dialect work in the real hint path', () {
    const resolver = TrustedFoodNetworkSearchResolver();
    expect(resolver.searchHintForTesting('مسگوف'), 'masgouf');
    expect(resolver.searchHintForTesting('تمن'), 'rice');
    expect(FoodMultilingualLexicon.expand('كليچة'), contains('kleicha'));
    expect(resolver.searchHintForTesting('تمن باقلاء'), 'timman bagilla');
  });
  test('Jordanian dishes are not collapsed into generic ingredients', () {
    const resolver = TrustedFoodNetworkSearchResolver();
    expect(resolver.searchHintForTesting('رشوف'), 'rashouf');
    expect(resolver.searchHintForTesting('مكمورة'), 'makmoura');
    expect(resolver.searchHintForTesting('قلاية بندورة'), 'galyet bandora');
    expect(FoodIraqJordanLexicon.expand('جميد كركي'), contains('jameed karaki'));
  });
  test('amounts and unknown preparation qualifiers are not removed', () {
    expect(FoodIraqJordanLexicon.expand('تمن باقلاء ٢٠٠ غرام'),
        contains('timman bagilla 200 غرام'));
    expect(FoodIraqJordanLexicon.expand('مكمورة بدون دجاج'),
        contains('makmoura بدون دجاج'));
  });
  test('do not equate distinct kubba dishes, search is not nutrition', () {
    expect(FoodIraqJordanLexicon.expand('كبة موصل'), contains('kubba mosul'));
    expect(FoodIraqJordanLexicon.expand('كبة حلب'), contains('kubba halab'));
    expect(FoodIraqJordanLexicon.expand('كبة موصل'), isNot(contains('kubba halab')));
    expect(FoodIraqJordanLexicon.expand('كبسة'), ['كبسه']);
    expect(FoodIraqJordanLexicon.expand('اسم غير موجود'), ['اسم غير موجود']);
  });
}
