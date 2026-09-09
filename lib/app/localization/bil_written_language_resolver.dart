import 'dart:ui' show TextDirection;

/// Resolves strong signals in text the user actually entered.
///
/// Flutter has no reliable cross-platform API that exposes the currently
/// selected system-keyboard locale. This helper therefore never claims to
/// read it. Ambiguous Latin text stays unresolved, while script-specific text
/// can safely drive presentation direction and a bounded locale hint.
abstract final class BilWrittenLanguageResolver {
  static String? detectLocale(String text, {String? fallbackLocaleTag}) {
    final value = text.trim();
    if (value.isEmpty) return null;
    final fallback = _canonicalFallback(fallbackLocaleTag);

    if (RegExp(r'[\u0900-\u097f]').hasMatch(value)) return 'hi';
    if (RegExp(r'[\u0980-\u09ff]').hasMatch(value)) return 'bn';
    if (RegExp(r'[\u0e00-\u0e7f]').hasMatch(value)) return 'th';
    if (RegExp(r'[\u3040-\u30ff]').hasMatch(value)) return 'ja';
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(value)) return 'ko';

    if (RegExp(r'[\u0400-\u04ff]').hasMatch(value)) {
      final lower = value.toLowerCase();
      if (_containsAny(lower, const ['і', 'ї', 'є', 'ґ'])) return 'uk';
      if (fallback == 'ru' || fallback == 'uk') return fallback;
      return 'ru';
    }

    if (RegExp(r'[\u0600-\u06ff]').hasMatch(value)) {
      if (_containsAny(value, const ['ٹ', 'ڈ', 'ڑ', 'ں', 'ھ', 'ے'])) {
        return 'ur';
      }
      if (fallback == 'ar' || fallback == 'fa' || fallback == 'ur') {
        return fallback;
      }
      if (_containsAny(value, const ['پ', 'چ', 'ژ', 'گ', 'ک', 'ی'])) {
        return 'fa';
      }
      return 'ar';
    }

    if (RegExp(r'[\u3400-\u9fff]').hasMatch(value)) {
      if (_containsAny(value, _traditionalHanSignals)) return 'zh-Hant';
      if (_containsAny(value, _simplifiedHanSignals)) return 'zh-Hans';
      if (fallback == 'zh-Hans' || fallback == 'zh-Hant') return fallback;
      return 'zh-Hans';
    }

    // Latin script is shared by many BIL locales, so script alone cannot
    // reliably distinguish English, French, Turkish, Indonesian, and others.
    return null;
  }

  static TextDirection directionFor(
    String text, {
    required TextDirection fallback,
  }) {
    final rtl = RegExp(r'[\u0590-\u08ff]').allMatches(text).length;
    final ltr = RegExp(
      r'[A-Za-z\u00c0-\u024f\u0400-\u052f\u0900-\u0fff\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]',
    ).allMatches(text).length;
    if (rtl == ltr) return fallback;
    return rtl > ltr ? TextDirection.rtl : TextDirection.ltr;
  }

  static String? _canonicalFallback(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().replaceAll('_', '-').toLowerCase();
    if (normalized.startsWith('zh-hant') ||
        normalized == 'zh-tw' ||
        normalized == 'zh-hk') {
      return 'zh-Hant';
    }
    if (normalized.startsWith('zh')) return 'zh-Hans';
    if (normalized == 'pt-br') return 'pt-BR';
    if (normalized.startsWith('pt')) return 'pt-PT';
    return normalized.split('-').first;
  }

  static bool _containsAny(String value, List<String> signals) =>
      signals.any(value.contains);

  static const _traditionalHanSignals = <String>[
    '體',
    '雞',
    '蘋',
    '飯',
    '麵',
    '魚',
    '湯',
    '葉',
  ];
  static const _simplifiedHanSignals = <String>[
    '体',
    '鸡',
    '苹',
    '饭',
    '面',
    '鱼',
    '汤',
    '叶',
  ];
}
