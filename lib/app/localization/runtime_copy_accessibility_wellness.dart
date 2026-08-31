import 'package:intl/intl.dart';

/// Human-reviewed copy added for accessibility and workout-library surfaces.
///
/// Keep every production locale explicit: these labels are short, visible,
/// and must never fall back to English on a localized device.
abstract final class AccessibilityWellnessRuntimeCopy {
  static const supported = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };

  static const values = <String, Map<String, String>>{
    // Premium is a brand/tier name. Keeping it identical in every locale is
    // intentional, but registering it avoids a false missing-copy warning.
    'Premium': {
      'ar': 'Premium',
      'en': 'Premium',
      'fr': 'Premium',
      'es': 'Premium',
      'tr': 'Premium',
      'de': 'Premium',
      'it': 'Premium',
      'pt-BR': 'Premium',
      'pt-PT': 'Premium',
      'ur': 'Premium',
      'fa': 'Premium',
      'hi': 'Premium',
      'id': 'Premium',
      'ms': 'Premium',
      'ja': 'Premium',
      'ko': 'Premium',
      'zh-Hans': 'Premium',
      'zh-Hant': 'Premium',
      'ru': 'Premium',
      'bn': 'Premium',
      'vi': 'Premium',
      'th': 'Premium',
      'pl': 'Premium',
      'nl': 'Premium',
      'uk': 'Premium',
    },
    'Read answer aloud': {
      'ar': 'قراءة الإجابة بصوت عالٍ',
      'en': 'Read answer aloud',
      'fr': 'Lire la réponse à voix haute',
      'es': 'Leer la respuesta en voz alta',
      'tr': 'Yanıtı sesli oku',
      'de': 'Antwort vorlesen',
      'it': 'Leggi la risposta ad alta voce',
      'pt-BR': 'Ler a resposta em voz alta',
      'pt-PT': 'Ler a resposta em voz alta',
      'ur': 'جواب بلند آواز میں پڑھیں',
      'fa': 'پاسخ را با صدای بلند بخوان',
      'hi': 'उत्तर ज़ोर से पढ़ें',
      'id': 'Bacakan jawaban',
      'ms': 'Baca jawapan dengan kuat',
      'ja': '回答を読み上げる',
      'ko': '답변 소리 내어 읽기',
      'zh-Hans': '朗读回答',
      'zh-Hant': '朗讀回答',
      'ru': 'Прочитать ответ вслух',
      'bn': 'উত্তরটি পড়ে শোনান',
      'vi': 'Đọc to câu trả lời',
      'th': 'อ่านคำตอบออกเสียง',
      'pl': 'Przeczytaj odpowiedź na głos',
      'nl': 'Lees het antwoord voor',
      'uk': 'Прочитати відповідь уголос',
    },
    'Wellness programs': {
      'ar': 'برامج العافية',
      'en': 'Wellness programs',
      'fr': 'Programmes de bien-être',
      'es': 'Programas de bienestar',
      'tr': 'Sağlıklı yaşam programları',
      'de': 'Wellnessprogramme',
      'it': 'Programmi benessere',
      'pt-BR': 'Programas de bem-estar',
      'pt-PT': 'Programas de bem-estar',
      'ur': 'فلاح و بہبود کے پروگرام',
      'fa': 'برنامه‌های تندرستی',
      'hi': 'वेलनेस कार्यक्रम',
      'id': 'Program kebugaran',
      'ms': 'Program kesejahteraan',
      'ja': 'ウェルネスプログラム',
      'ko': '웰니스 프로그램',
      'zh-Hans': '健康计划',
      'zh-Hant': '健康計畫',
      'ru': 'Оздоровительные программы',
      'bn': 'সুস্থতা কর্মসূচি',
      'vi': 'Chương trình chăm sóc sức khỏe',
      'th': 'โปรแกรมสุขภาวะ',
      'pl': 'Programy wellness',
      'nl': "Wellnessprogramma's",
      'uk': 'Оздоровчі програми',
    },
    'Verified workout video library': {
      'ar': 'مكتبة فيديوهات تمارين موثّقة',
      'en': 'Verified workout video library',
      'fr': "Bibliothèque de vidéos d’entraînement vérifiées",
      'es': 'Biblioteca de vídeos de entrenamiento verificados',
      'tr': 'Doğrulanmış egzersiz video kitaplığı',
      'de': 'Bibliothek geprüfter Trainingsvideos',
      'it': 'Libreria di video di allenamento verificati',
      'pt-BR': 'Biblioteca de vídeos de treino verificados',
      'pt-PT': 'Biblioteca de vídeos de treino verificados',
      'ur': 'تصدیق شدہ ورزش ویڈیوز کی لائبریری',
      'fa': 'کتابخانه ویدیوهای تمرینی تأییدشده',
      'hi': 'सत्यापित कसरत वीडियो लाइब्रेरी',
      'id': 'Pustaka video latihan terverifikasi',
      'ms': 'Pustaka video senaman yang disahkan',
      'ja': '検証済みワークアウト動画ライブラリ',
      'ko': '검증된 운동 동영상 라이브러리',
      'zh-Hans': '经验证的锻炼视频库',
      'zh-Hant': '經驗證的運動影片庫',
      'ru': 'Библиотека проверенных видео тренировок',
      'bn': 'যাচাইকৃত ব্যায়াম ভিডিও লাইব্রেরি',
      'vi': 'Thư viện video tập luyện đã xác minh',
      'th': 'คลังวิดีโอออกกำลังกายที่ผ่านการตรวจสอบ',
      'pl': 'Biblioteka zweryfikowanych filmów treningowych',
      'nl': "Bibliotheek met geverifieerde trainingsvideo's",
      'uk': 'Бібліотека перевірених відео тренувань',
    },
  };

  static const _workoutVideoCounts = <String, _PluralCopy>{
    'ar': _PluralCopy(
      zero: 'لا توجد فيديوهات تمارين موثّقة',
      one: 'فيديو تمرين موثّق واحد',
      two: 'فيديوها تمرين موثّقان',
      few: '{count} فيديوهات تمارين موثّقة',
      many: '{count} فيديو تمرين موثّقًا',
      other: '{count} فيديو تمرين موثّق',
    ),
    'en': _PluralCopy(
      one: '{count} verified workout video',
      other: '{count} verified workout videos',
    ),
    'fr': _PluralCopy(
      one: '{count} vidéo d’entraînement vérifiée',
      other: '{count} vidéos d’entraînement vérifiées',
    ),
    'es': _PluralCopy(
      one: '{count} vídeo de entrenamiento verificado',
      other: '{count} vídeos de entrenamiento verificados',
    ),
    'tr': _PluralCopy(other: '{count} doğrulanmış antrenman videosu'),
    'de': _PluralCopy(
      one: '{count} geprüftes Trainingsvideo',
      other: '{count} geprüfte Trainingsvideos',
    ),
    'it': _PluralCopy(
      one: '{count} video di allenamento verificato',
      other: '{count} video di allenamento verificati',
    ),
    'pt-BR': _PluralCopy(
      one: '{count} vídeo de treino verificado',
      other: '{count} vídeos de treino verificados',
    ),
    'pt-PT': _PluralCopy(
      one: '{count} vídeo de treino verificado',
      other: '{count} vídeos de treino verificados',
    ),
    'ur': _PluralCopy(
      one: 'ایک تصدیق شدہ ورزش ویڈیو',
      other: '{count} تصدیق شدہ ورزش ویڈیوز',
    ),
    'fa': _PluralCopy(other: '{count} ویدیوی تمرینی تأییدشده'),
    'hi': _PluralCopy(other: '{count} सत्यापित कसरत वीडियो'),
    'id': _PluralCopy(other: '{count} video latihan terverifikasi'),
    'ms': _PluralCopy(other: '{count} video senaman yang disahkan'),
    'ja': _PluralCopy(other: '検証済みワークアウト動画{count}本'),
    'ko': _PluralCopy(other: '검증된 운동 동영상 {count}개'),
    'zh-Hans': _PluralCopy(other: '{count} 个经验证的锻炼视频'),
    'zh-Hant': _PluralCopy(other: '{count} 部經驗證的運動影片'),
    'ru': _PluralCopy(
      one: '{count} проверенное тренировочное видео',
      few: '{count} проверенных тренировочных видео',
      many: '{count} проверенных тренировочных видео',
      other: '{count} проверенных тренировочных видео',
    ),
    'bn': _PluralCopy(other: '{count}টি যাচাইকৃত ব্যায়ামের ভিডিও'),
    'vi': _PluralCopy(other: '{count} video tập luyện đã xác minh'),
    'th': _PluralCopy(
      other: 'วิดีโอออกกำลังกายที่ผ่านการตรวจสอบ {count} รายการ',
    ),
    'pl': _PluralCopy(
      one: '{count} zweryfikowany film treningowy',
      few: '{count} zweryfikowane filmy treningowe',
      many: '{count} zweryfikowanych filmów treningowych',
      other: '{count} zweryfikowanych filmów treningowych',
    ),
    'nl': _PluralCopy(
      one: '{count} geverifieerde trainingsvideo',
      other: '{count} geverifieerde trainingsvideo’s',
    ),
    'uk': _PluralCopy(
      one: '{count} перевірене тренувальне відео',
      few: '{count} перевірені тренувальні відео',
      many: '{count} перевірених тренувальних відео',
      other: '{count} перевірених тренувальних відео',
    ),
  };

  static String verifiedWorkoutVideoCount(int count, String localeTag) {
    final canonical = _canonicalTag(localeTag) ?? 'en';
    final copy = _workoutVideoCounts[canonical] ?? _workoutVideoCounts['en']!;
    final template = Intl.pluralLogic<String>(
      count,
      zero: copy.zero,
      one: copy.one,
      two: copy.two,
      few: copy.few,
      many: copy.many,
      other: copy.other,
      locale: canonical.replaceAll('-', '_'),
    );
    final number = NumberFormat.decimalPattern(
      canonical.replaceAll('-', '_'),
    ).format(count);
    return template.replaceAll('{count}', number);
  }

  static String? resolve(String english, String localeTag) {
    final canonical = _canonicalTag(localeTag);
    if (canonical != null) return values[english]?[canonical];
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    final language = normalized.split('-').first;
    final matches = supported
        .where((candidate) => candidate.toLowerCase() == language)
        .toList(growable: false);
    return matches.length == 1 ? (values[english]?[matches.single]) : null;
  }

  static bool get balanced => values.values.every(
    (translations) =>
        translations.keys.toSet().containsAll(supported) &&
        supported.containsAll(translations.keys) &&
        translations.values.every((value) => value.trim().isNotEmpty),
  );

  static String? _canonicalTag(String localeTag) {
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final candidate in supported) {
      if (candidate.toLowerCase() == normalized) return candidate;
    }
    final language = normalized.split('-').first;
    final matches = supported
        .where((candidate) => candidate.toLowerCase() == language)
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }
}

final class _PluralCopy {
  const _PluralCopy({
    this.zero,
    this.one,
    this.two,
    this.few,
    this.many,
    required this.other,
  });

  final String? zero;
  final String? one;
  final String? two;
  final String? few;
  final String? many;
  final String other;
}
