class CoachLanguageResolution {
  const CoachLanguageResolution({
    required this.languageTag,
    required this.detected,
  });
  final String languageTag;
  final bool detected;
}

/// Selects response language independently from the UI locale. It does not
/// alter structured tool names or arguments.
class CoachLanguageResolver {
  const CoachLanguageResolver();

  CoachLanguageResolution resolve({
    required String input,
    required String uiLocale,
  }) {
    final value = input.trim();
    final uiTag = _canonicalTag(uiLocale);
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(value)) {
      if (RegExp(
        r'[\u0679\u0688\u0691\u06BA\u06BE\u06C1\u06D2]',
      ).hasMatch(value)) {
        return const CoachLanguageResolution(languageTag: 'ur', detected: true);
      }
      if (RegExp(r'[\u067E\u0686\u0698\u06AF\u06A9]').hasMatch(value)) {
        return CoachLanguageResolution(
          languageTag: uiTag == 'ur' ? 'ur' : 'fa',
          detected: true,
        );
      }
      return CoachLanguageResolution(
        languageTag: const {'ar', 'ur', 'fa'}.contains(uiTag) ? uiTag : 'ar',
        detected: true,
      );
    }
    if (RegExp(r'[\u0400-\u04ff]').hasMatch(value)) {
      return CoachLanguageResolution(
        languageTag: RegExp(r'[іїєґІЇЄҐ]').hasMatch(value) ? 'uk' : 'ru',
        detected: true,
      );
    }
    if (RegExp(r'[\u3040-\u30ff]').hasMatch(value)) {
      return const CoachLanguageResolution(languageTag: 'ja', detected: true);
    }
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(value)) {
      return const CoachLanguageResolution(languageTag: 'ko', detected: true);
    }
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(value)) {
      final traditional = RegExp(
        // Traditional-exclusive forms only. Common Han characters such as
        // 熱 and 量 must not override an explicit zh-Hans UI preference.
        r'[\u9ad4\u81fa\u7063\u9ede\u5b78\u91ab]',
      ).hasMatch(value);
      return CoachLanguageResolution(
        languageTag: traditional || uiTag == 'zh-Hant' ? 'zh-Hant' : 'zh-Hans',
        detected: true,
      );
    }
    if (RegExp(r'[\u0900-\u097f]').hasMatch(value)) {
      return const CoachLanguageResolution(languageTag: 'hi', detected: true);
    }
    if (RegExp(r'[\u0980-\u09ff]').hasMatch(value)) {
      return const CoachLanguageResolution(languageTag: 'bn', detected: true);
    }
    if (RegExp(r'[\u0e00-\u0e7f]').hasMatch(value)) {
      return const CoachLanguageResolution(languageTag: 'th', detected: true);
    }
    final latin = _resolveLatin(value);
    if (latin != null) {
      final resolved = latin == 'pt' && const {'pt-BR', 'pt-PT'}.contains(uiTag)
          ? uiTag
          : latin;
      return CoachLanguageResolution(languageTag: resolved, detected: true);
    }
    return CoachLanguageResolution(languageTag: uiTag, detected: false);
  }

  String _canonicalTag(String raw) {
    final parts = raw.trim().replaceAll('_', '-').split('-');
    if (parts.isEmpty || !RegExp(r'^[A-Za-z]{2,3}$').hasMatch(parts.first)) {
      return 'en';
    }
    final language = parts.first.toLowerCase();
    if (parts.length > 1 && RegExp(r'^[A-Za-z]{4}$').hasMatch(parts[1])) {
      final script = parts[1];
      return '$language-${script[0].toUpperCase()}${script.substring(1).toLowerCase()}';
    }
    if (parts.length > 1 && RegExp(r'^[A-Za-z]{2}$').hasMatch(parts[1])) {
      return '$language-${parts[1].toUpperCase()}';
    }
    return language;
  }

  String? _resolveLatin(String input) {
    final words = input
        .toLowerCase()
        .split(RegExp(r'[^\p{L}]+', unicode: true))
        .where((word) => word.length > 1)
        .toSet();
    const markers = <String, Set<String>>{
      'en': {
        'how',
        'many',
        'calories',
        'remaining',
        'weight',
        'today',
        'sleep',
        'general',
        'short',
        'tip',
      },
      'id': {'tersisa', 'kebutuhan', 'asupan', 'kemarin'},
      'ms': {'berbaki', 'keperluan', 'pengambilan', 'semalam'},
      'de': {'wie', 'viel', 'kalorien', 'übrig', 'gewicht', 'heute'},
      'it': {'quante', 'calorie', 'rimangono', 'peso', 'oggi', 'proteine'},
      'pt': {'quantas', 'calorias', 'restam', 'peso', 'hoje', 'proteína'},
      'fr': {'combien', 'calories', 'reste', 'poids', 'aujourd', 'protéines'},
      'es': {'cuántas', 'calorías', 'quedan', 'peso', 'hoy', 'proteína'},
      'tr': {'kaç', 'kalori', 'kaldı', 'kilo', 'bugün', 'protein'},
      'vi': {'bao', 'nhiêu', 'calo', 'còn', 'lại', 'hôm', 'nay'},
      'pl': {'ile', 'kalorii', 'zostało', 'waga', 'dzisiaj', 'białko'},
      'nl': {'hoeveel', 'calorieën', 'over', 'gewicht', 'vandaag', 'eiwit'},
    };
    String? best;
    var bestScore = 1;
    var tied = false;
    for (final entry in markers.entries) {
      final score = words.intersection(entry.value).length;
      if (score > bestScore) {
        best = entry.key;
        bestScore = score;
        tied = false;
      } else if (score == bestScore && score >= 2) {
        tied = true;
      }
    }
    return tied ? null : best;
  }
}
