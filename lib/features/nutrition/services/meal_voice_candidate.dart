final class MealVoiceCandidate {
  const MealVoiceCandidate({
    required this.originalTranscript,
    required this.editableText,
    required this.foodQuery,
    required this.localeId,
    this.quantity,
    this.unit,
  });

  final String originalTranscript;
  final String editableText;
  final String foodQuery;
  final String localeId;
  final double? quantity;
  final String? unit;
}

abstract final class MealVoiceCandidateParser {
  static final _quantityPattern = RegExp(
    r'^\s*(\d+(?:[\.,]\d+)?)\s*(g|kg|mg|ml|l|oz|cup|cups|tsp|tbsp|جرام|غرام|كوب|مل|كغ|جم|tasse|tazas?|bardak)\b\s*(?:of\s+|من\s+|de\s+)?(.*)$',
    caseSensitive: false,
    unicode: true,
  );

  static MealVoiceCandidate parse({
    required String transcript,
    required String localeId,
  }) {
    final cleaned = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) throw const FormatException('voice_no_match');
    if (cleaned.length > 240) throw const FormatException('voice_too_long');
    final match = _quantityPattern.firstMatch(cleaned);
    final quantity = match == null
        ? null
        : double.tryParse(match.group(1)!.replaceAll(',', '.'));
    final query = (match?.group(3) ?? cleaned).trim();
    if (query.isEmpty) throw const FormatException('voice_no_food_name');
    return MealVoiceCandidate(
      originalTranscript: transcript,
      editableText: cleaned,
      foodQuery: query,
      localeId: localeId,
      quantity: quantity,
      unit: match?.group(2)?.toLowerCase(),
    );
  }
}

abstract final class MealVoiceLocaleResolver {
  static const _fallbacks = <String, List<String>>{
    'en': ['en-US', 'en-GB'],
    'fr': ['fr-FR', 'fr-CA'],
    'es': ['es-ES', 'es-MX', 'es-US'],
    'tr': ['tr-TR'],
    'ar': [
      'ar-EG',
      'ar-SA',
      'ar-AE',
      'ar-JO',
      'ar-LB',
      'ar-IQ',
      'ar-KW',
      'ar-QA',
      'ar-BH',
      'ar-OM',
      'ar-MA',
      'ar-DZ',
      'ar-TN',
    ],
  };

  static String? resolve({
    required String appLanguage,
    required String deviceLocale,
    required Iterable<String> availableLocales,
  }) {
    final available = availableLocales
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    if (available.isEmpty) return null;
    String normalize(String value) => value.replaceAll('_', '-').toLowerCase();
    final language = normalize(appLanguage).split('-').first;
    final device = normalize(deviceLocale);
    String? exact(String wanted) {
      final target = normalize(wanted);
      for (final locale in available) {
        if (normalize(locale) == target) return locale;
      }
      return null;
    }

    if (device.split('-').first == language) {
      final match = exact(device);
      if (match != null) return match;
    }
    for (final preferred in _fallbacks[language] ?? const <String>[]) {
      final match = exact(preferred);
      if (match != null) return match;
    }
    for (final locale in available) {
      if (normalize(locale).split('-').first == language) return locale;
    }
    return null;
  }
}

enum MealVoiceFailure {
  permissionDenied,
  timeout,
  noMatch,
  localeUnavailable,
  recognizerUnavailable,
  unknown,
}

MealVoiceFailure classifyMealVoiceFailure(String code) {
  final normalized = code.toLowerCase();
  if (normalized.contains('permission')) {
    return MealVoiceFailure.permissionDenied;
  }
  if (normalized.contains('timeout') || normalized.endsWith('_6')) {
    return MealVoiceFailure.timeout;
  }
  if (normalized.contains('no_match') || normalized.endsWith('_7')) {
    return MealVoiceFailure.noMatch;
  }
  if (normalized.contains('locale')) return MealVoiceFailure.localeUnavailable;
  if (normalized.contains('unavailable')) {
    return MealVoiceFailure.recognizerUnavailable;
  }
  return MealVoiceFailure.unknown;
}
