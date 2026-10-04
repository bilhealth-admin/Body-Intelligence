import 'food_multilingual_core_lexicon.dart' as core;
import 'food_arabic_regional_lexicon.dart';

/// Preserve the established multilingual bridge and add regional spellings.
/// Search aliases are not nutrition equivalence or a claim of catalog coverage.
class FoodMultilingualLexicon {
  const FoodMultilingualLexicon._();

  static List<String> expand(String query) {
    final result = <String>{...core.FoodMultilingualLexicon.expand(query)};
    for (final regional in FoodArabicRegionalLexicon.expand(query).skip(1)) {
      result.addAll(core.FoodMultilingualLexicon.expand(regional));
    }
    return result.toList(growable: false);
  }
}
