import '../../../app/localization/bil_locale_policy.dart';

/// Reviewed, Coach-owned tools-sheet labels for every BIL release locale.
///
/// These strings are intentionally local to AI Coach: the shared runtime
/// catalogue is owned by the integration stream and must not be edited by
/// an isolated Coach worker.
abstract final class CoachToolsLocaleCopy {
  static const keys = <String>[
    'Coach tools',
    'Food diary',
    'Nutrition analysis',
  ];

  // Every row follows the exact order of [keys]. Region/script variants are
  // authored explicitly rather than silently falling back to English.
  static const rows = <String, List<String>>{
    'en': keys,
    'ar': ['أدوات المدرب', 'سجل الطعام', 'تحليل التغذية'],
    'fr': ['Outils du coach', 'Journal alimentaire', 'Analyse nutritionnelle'],
    'es': [
      'Herramientas del entrenador',
      'Diario de alimentos',
      'Análisis nutricional',
    ],
    'tr': ['Koç araçları', 'Yemek günlüğü', 'Beslenme analizi'],
    'de': ['Coach-Werkzeuge', 'Ernährungstagebuch', 'Ernährungsanalyse'],
    'it': ['Strumenti del coach', 'Diario alimentare', 'Analisi nutrizionale'],
    'pt-BR': [
      'Ferramentas do treinador',
      'Diário alimentar',
      'Análise nutricional',
    ],
    'pt-PT': [
      'Ferramentas do treinador',
      'Diário alimentar',
      'Análise nutricional',
    ],
    'ur': ['کوچ کے اوزار', 'غذا کی ڈائری', 'غذائیت کا تجزیہ'],
    'fa': ['ابزارهای مربی', 'دفترچهٔ غذا', 'تحلیل تغذیه'],
    'hi': ['कोच के उपकरण', 'भोजन डायरी', 'पोषण विश्लेषण'],
    'id': ['Alat pelatih', 'Catatan makanan', 'Analisis gizi'],
    'ms': ['Alat jurulatih', 'Diari makanan', 'Analisis pemakanan'],
    'ja': ['コーチのツール', '食事日記', '栄養分析'],
    'ko': ['코치 도구', '식사 일지', '영양 분석'],
    'zh-Hans': ['教练工具', '饮食日记', '营养分析'],
    'zh-Hant': ['教練工具', '飲食日記', '營養分析'],
    'ru': ['Инструменты тренера', 'Дневник питания', 'Анализ питания'],
    'bn': ['কোচের সরঞ্জাম', 'খাদ্য ডায়েরি', 'পুষ্টি বিশ্লেষণ'],
    'vi': [
      'Công cụ huấn luyện viên',
      'Nhật ký ăn uống',
      'Phân tích dinh dưỡng',
    ],
    'th': ['เครื่องมือโค้ช', 'บันทึกอาหาร', 'วิเคราะห์โภชนาการ'],
    'pl': ['Narzędzia trenera', 'Dziennik żywieniowy', 'Analiza żywienia'],
    'nl': ['Coachhulpmiddelen', 'Voedingsdagboek', 'Voedingsanalyse'],
    'uk': ['Інструменти тренера', 'Щоденник харчування', 'Аналіз харчування'],
  };

  static bool get complete {
    final expected = BilLocalePolicy.productionTags.toSet();
    final actual = rows.keys.toSet();
    if (actual.length != expected.length ||
        !actual.containsAll(expected) ||
        !expected.containsAll(actual)) {
      return false;
    }
    for (final tag in expected) {
      final row = rows[tag]!;
      if (row.length != keys.length) return false;
      for (var index = 0; index < keys.length; index++) {
        if (row[index].trim().isEmpty ||
            (tag != 'en' && row[index] == keys[index])) {
          return false;
        }
      }
    }
    return true;
  }

  static String resolve(String english, String localeTag) {
    final index = keys.indexOf(english);
    if (index < 0) {
      throw ArgumentError.value(
        english,
        'english',
        'Unregistered Coach tools label',
      );
    }
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag) ?? 'en';
    return rows[tag]![index];
  }
}
