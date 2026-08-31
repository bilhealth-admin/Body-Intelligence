import 'bil_locale_policy.dart';

/// Reviewed labels for the compact Dashboard fitness watch and its CTA.
abstract final class FitnessWatchRuntimeCopy {
  static const snapshot = 'Fitness snapshot';
  static const manageSources = 'Manage fitness sources';
  static const linkSource = 'Link a fitness source';
  static const linkFitness = 'Link fitness';
  static const connectFitness = 'Connect fitness';
  static const lastSync = 'Last sync';

  static const sources = <String>[
    snapshot,
    manageSources,
    linkSource,
    linkFitness,
    connectFitness,
    lastSync,
  ];
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

  static const rows = <String, List<String>>{
    'ar': <String>[
      'ملخص اللياقة',
      'إدارة مصادر اللياقة',
      'ربط مصدر لياقة',
      'ربط اللياقة',
      'ربط اللياقة',
      'آخر مزامنة',
    ],
    'en': sources,
    'fr': <String>[
      'Aperçu fitness',
      'Gérer les sources fitness',
      'Associer une source fitness',
      'Associer le fitness',
      'Connecter le fitness',
      'Dernière synchronisation',
    ],
    'es': <String>[
      'Resumen de fitness',
      'Gestionar fuentes de fitness',
      'Vincular una fuente de fitness',
      'Vincular fitness',
      'Conectar fitness',
      'Última sincronización',
    ],
    'tr': <String>[
      'Fitness özeti',
      'Fitness kaynaklarını yönet',
      'Fitness kaynağı bağla',
      'Fitness bağlantısı kur',
      'Fitness bağlantısı kur',
      'Son eşitleme',
    ],
    'de': <String>[
      'Fitnessübersicht',
      'Fitnessquellen verwalten',
      'Fitnessquelle verknüpfen',
      'Fitness verknüpfen',
      'Fitness verbinden',
      'Letzte Synchronisierung',
    ],
    'it': <String>[
      'Riepilogo fitness',
      'Gestisci fonti fitness',
      'Collega una fonte fitness',
      'Collega fitness',
      'Connetti fitness',
      'Ultima sincronizzazione',
    ],
    'pt-BR': <String>[
      'Resumo fitness',
      'Gerenciar fontes fitness',
      'Vincular uma fonte fitness',
      'Vincular fitness',
      'Conectar fitness',
      'Última sincronização',
    ],
    'pt-PT': <String>[
      'Resumo de fitness',
      'Gerir fontes de fitness',
      'Associar uma fonte de fitness',
      'Associar fitness',
      'Ligar fitness',
      'Última sincronização',
    ],
    'ur': <String>[
      'فٹنس خلاصہ',
      'فٹنس ذرائع کا نظم کریں',
      'فٹنس ذریعہ منسلک کریں',
      'فٹنس منسلک کریں',
      'فٹنس جوڑیں',
      'آخری ہم آہنگی',
    ],
    'fa': <String>[
      'خلاصه تناسب اندام',
      'مدیریت منابع تناسب اندام',
      'پیوند منبع تناسب اندام',
      'پیوند تناسب اندام',
      'اتصال تناسب اندام',
      'آخرین همگام‌سازی',
    ],
    'hi': <String>[
      'फ़िटनेस सारांश',
      'फ़िटनेस स्रोत प्रबंधित करें',
      'फ़िटनेस स्रोत जोड़ें',
      'फ़िटनेस जोड़ें',
      'फ़िटनेस कनेक्ट करें',
      'पिछला सिंक',
    ],
    'id': <String>[
      'Ringkasan kebugaran',
      'Kelola sumber kebugaran',
      'Tautkan sumber kebugaran',
      'Tautkan kebugaran',
      'Hubungkan kebugaran',
      'Sinkronisasi terakhir',
    ],
    'ms': <String>[
      'Ringkasan kecergasan',
      'Urus sumber kecergasan',
      'Pautkan sumber kecergasan',
      'Pautkan kecergasan',
      'Sambungkan kecergasan',
      'Penyegerakan terakhir',
    ],
    'ja': <String>[
      'フィットネス概要',
      'フィットネス情報源を管理',
      'フィットネス情報源を連携',
      'フィットネスを連携',
      'フィットネスを接続',
      '最終同期',
    ],
    'ko': <String>[
      '피트니스 요약',
      '피트니스 소스 관리',
      '피트니스 소스 연결',
      '피트니스 연결',
      '피트니스 연결하기',
      '마지막 동기화',
    ],
    'zh-Hans': <String>['健身概览', '管理健身来源', '关联健身来源', '关联健身', '连接健身', '上次同步'],
    'zh-Hant': <String>['健身概覽', '管理健身來源', '連結健身來源', '連結健身', '連接健身', '上次同步'],
    'ru': <String>[
      'Сводка фитнеса',
      'Управлять источниками фитнеса',
      'Подключить источник фитнеса',
      'Связать фитнес',
      'Подключить фитнес',
      'Последняя синхронизация',
    ],
    'bn': <String>[
      'ফিটনেস সারাংশ',
      'ফিটনেস উৎস পরিচালনা করুন',
      'ফিটনেস উৎস যুক্ত করুন',
      'ফিটনেস যুক্ত করুন',
      'ফিটনেস সংযোগ করুন',
      'সর্বশেষ সিঙ্ক',
    ],
    'vi': <String>[
      'Tóm tắt thể chất',
      'Quản lý nguồn thể chất',
      'Liên kết nguồn thể chất',
      'Liên kết thể chất',
      'Kết nối thể chất',
      'Lần đồng bộ gần nhất',
    ],
    'th': <String>[
      'สรุปฟิตเนส',
      'จัดการแหล่งข้อมูลฟิตเนส',
      'เชื่อมโยงแหล่งข้อมูลฟิตเนส',
      'เชื่อมโยงฟิตเนส',
      'เชื่อมต่อฟิตเนส',
      'ซิงค์ล่าสุด',
    ],
    'pl': <String>[
      'Podsumowanie fitness',
      'Zarządzaj źródłami fitness',
      'Połącz źródło fitness',
      'Połącz fitness',
      'Podłącz fitness',
      'Ostatnia synchronizacja',
    ],
    'nl': <String>[
      'Fitnessoverzicht',
      'Fitnessbronnen beheren',
      'Fitnessbron koppelen',
      'Fitness koppelen',
      'Fitness verbinden',
      'Laatste synchronisatie',
    ],
    'uk': <String>[
      'Огляд фітнесу',
      'Керувати джерелами фітнесу',
      'Під’єднати джерело фітнесу',
      'Під’єднати фітнес',
      'Підключити фітнес',
      'Остання синхронізація',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing fitness-watch copy for $tag.');
    }
    return row[index];
  }

  static bool get balanced =>
      supported.length == 25 &&
      rows.keys.toSet().containsAll(supported) &&
      supported.containsAll(rows.keys) &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((value) => value.trim().isNotEmpty),
      ) &&
      _sameValues(rows['en'], sources);

  static bool _sameValues(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < right.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
