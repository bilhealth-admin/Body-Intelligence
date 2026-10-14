import '../../../app/localization/runtime_copy_coach_review.dart';

/// Presentation labels never replace the canonical serving unit used in maths.
String mealImageUnitLabel(String unit, String locale) =>
    unit == 'piece' ? CoachReviewRuntimeCopy.resolve('piece', locale)! : unit;

String mealImageCanonicalUnit(String entered, String locale) =>
    entered.trim() == mealImageUnitLabel('piece', locale)
    ? 'piece'
    : entered.trim();

/// A script check catches gross language regressions, not semantic language
/// detection. Latin-script languages additionally rely on the declared locale
/// and the provider's explicit all-fields language contract.
bool mealImageTextHasExpectedScript(String text, String locale) {
  if (text.trim().isEmpty) return true;
  final language = locale.split('-').first;
  if ({'ar', 'fa', 'ur'}.contains(language) && _hasMixedArabicLatinWord(text)) {
    return false;
  }
  final pattern = switch (language) {
    'ar' || 'fa' || 'ur' => r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]',
    'hi' => r'[\u0900-\u097f]',
    'bn' => r'[\u0980-\u09ff]',
    'ja' => r'[\u3040-\u30ff\u3400-\u9fff]',
    'ko' => r'[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]',
    'zh' => r'[\u3400-\u9fff]',
    'ru' || 'uk' => r'[\u0400-\u052f]',
    'th' => r'[\u0e00-\u0e7f]',
    _ => r'[A-Za-z\u00c0-\u024f\u1e00-\u1eff]',
  };
  return RegExp(pattern).hasMatch(text);
}

// Reject joined alphabets in human-facing words, not standalone scientific
// labels, brands, canonical units, digits, or source URLs.
final _arabicWord = RegExp(
  r'[A-Za-z\u0620-\u065f\u066e-\u06d3\u06fa-\u06ff\u0750-\u077f\u08a0-\u08c9]+',
);
final _arabicLetter = RegExp(
  r'[\u0620-\u064a\u066e-\u06d3\u06fa-\u06ff\u0750-\u077f\u08a0-\u08c9]',
);
final _latinLetter = RegExp(r'[A-Za-z]');
final _sourceUrl = RegExp(r'(?:https?://|www\.)\S+', caseSensitive: false);

bool _hasMixedArabicLatinWord(String text) {
  final humanText = text.replaceAll(_sourceUrl, ' ');
  return _arabicWord.allMatches(humanText).any((match) {
    final word = match.group(0)!;
    return _arabicLetter.hasMatch(word) && _latinLetter.hasMatch(word);
  });
}
