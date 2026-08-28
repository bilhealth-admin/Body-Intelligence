class FoodSearchNormalizer {
  const FoodSearchNormalizer._();

  static final RegExp _diacritics = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
  );
  // Food search is intentionally script agnostic. The previous ASCII + Arabic
  // allow-list silently erased Cyrillic, Devanagari, Bengali, Thai, CJK, Hangul
  // and every accented Latin character. A non-empty query such as `яблоко` or
  // `りんご` therefore became an empty query and surfaced the fixed default
  // catalog rows instead of search results.
  static final RegExp _separators = RegExp(
    r'[^\p{L}\p{M}\p{N}]+',
    unicode: true,
  );
  static final RegExp _spaces = RegExp(r'\s+');

  static String normalize(String input) {
    var value = input.toLowerCase().trim();
    value = _normalizeDigits(value);
    value = value.replaceAll('ـ', '');
    value = value.replaceAll(_diacritics, '');
    value = value
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه');
    value = value.replaceAll(_separators, ' ');
    return value.replaceAll(_spaces, ' ').trim();
  }

  static List<String> tokens(String input) {
    final normalized = normalize(input);
    return normalized.isEmpty
        ? const <String>[]
        : normalized.split(' ').where((token) => token.isNotEmpty).toList();
  }

  static String normalizeBarcode(String input) =>
      _normalizeDigits(input).replaceAll(RegExp(r'\D'), '');

  static String _normalizeDigits(String input) {
    const source = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
    const target = '01234567890123456789';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final character = String.fromCharCode(rune);
      final index = source.indexOf(character);
      buffer.write(index == -1 ? character : target[index]);
    }
    return buffer.toString();
  }
}
