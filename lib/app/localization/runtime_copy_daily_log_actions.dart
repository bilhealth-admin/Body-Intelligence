import 'bil_locale_policy.dart';

/// Reviewed copy for date-copy actions in the daily diary.
abstract final class DailyLogActionRuntimeCopy {
  static const copyYesterday = 'Copy all meals from yesterday.';
  static const chooseDays = 'Choose days';
  static const copyToDates = 'Copy this diary to one or more dates.';

  static const sources = <String>[copyYesterday, chooseDays, copyToDates];
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
      'انسخ جميع وجبات الأمس.',
      'اختر الأيام',
      'انسخ سجل الطعام هذا إلى تاريخ واحد أو أكثر.',
    ],
    'en': sources,
    'fr': <String>[
      'Copier tous les repas d’hier.',
      'Choisir des jours',
      'Copier ce journal vers une ou plusieurs dates.',
    ],
    'es': <String>[
      'Copiar todas las comidas de ayer.',
      'Elegir días',
      'Copiar este diario a una o varias fechas.',
    ],
    'tr': <String>[
      'Dünün tüm öğünlerini kopyala.',
      'Günleri seç',
      'Bu günlüğü bir veya daha fazla tarihe kopyala.',
    ],
    'de': <String>[
      'Alle Mahlzeiten von gestern kopieren.',
      'Tage auswählen',
      'Dieses Tagebuch auf ein oder mehrere Daten kopieren.',
    ],
    'it': <String>[
      'Copia tutti i pasti di ieri.',
      'Scegli i giorni',
      'Copia questo diario in una o più date.',
    ],
    'pt-BR': <String>[
      'Copiar todas as refeições de ontem.',
      'Escolher dias',
      'Copiar este diário para uma ou mais datas.',
    ],
    'pt-PT': <String>[
      'Copiar todas as refeições de ontem.',
      'Escolher dias',
      'Copiar este diário para uma ou mais datas.',
    ],
    'ur': <String>[
      'کل کے تمام کھانے نقل کریں۔',
      'دن منتخب کریں',
      'اس ڈائری کو ایک یا زیادہ تاریخوں میں نقل کریں۔',
    ],
    'fa': <String>[
      'همه وعده‌های دیروز را کپی کنید.',
      'روزها را انتخاب کنید',
      'این دفترچه را در یک یا چند تاریخ کپی کنید.',
    ],
    'hi': <String>[
      'कल के सभी भोजन कॉपी करें।',
      'दिन चुनें',
      'इस डायरी को एक या अधिक तारीखों पर कॉपी करें।',
    ],
    'id': <String>[
      'Salin semua makanan kemarin.',
      'Pilih hari',
      'Salin diari ini ke satu atau beberapa tanggal.',
    ],
    'ms': <String>[
      'Salin semua hidangan semalam.',
      'Pilih hari',
      'Salin diari ini ke satu atau beberapa tarikh.',
    ],
    'ja': <String>['昨日の食事をすべてコピーします。', '日付を選択', 'この食事記録を1つ以上の日付にコピーします。'],
    'ko': <String>['어제의 모든 식사를 복사합니다.', '날짜 선택', '이 식사 일지를 하나 이상의 날짜로 복사합니다.'],
    'zh-Hans': <String>['复制昨天的所有餐食。', '选择日期', '将此饮食日志复制到一个或多个日期。'],
    'zh-Hant': <String>['複製昨天的所有餐點。', '選擇日期', '將此飲食日誌複製到一個或多個日期。'],
    'ru': <String>[
      'Скопировать все приёмы пищи за вчера.',
      'Выбрать дни',
      'Скопировать этот дневник на одну или несколько дат.',
    ],
    'bn': <String>[
      'গতকালের সব খাবার কপি করুন।',
      'দিন বেছে নিন',
      'এই ডায়েরি এক বা একাধিক তারিখে কপি করুন।',
    ],
    'vi': <String>[
      'Sao chép tất cả bữa ăn của hôm qua.',
      'Chọn ngày',
      'Sao chép nhật ký này sang một hoặc nhiều ngày.',
    ],
    'th': <String>[
      'คัดลอกมื้ออาหารทั้งหมดจากเมื่อวาน',
      'เลือกวัน',
      'คัดลอกไดอารี่นี้ไปยังหนึ่งวันหรือหลายวัน',
    ],
    'pl': <String>[
      'Skopiuj wszystkie wczorajsze posiłki.',
      'Wybierz dni',
      'Skopiuj ten dziennik do jednej lub kilku dat.',
    ],
    'nl': <String>[
      'Alle maaltijden van gisteren kopiëren.',
      'Dagen kiezen',
      'Dit dagboek naar één of meer datums kopiëren.',
    ],
    'uk': <String>[
      'Скопіювати всі вчорашні прийоми їжі.',
      'Вибрати дні',
      'Скопіювати цей щоденник на одну або кілька дат.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing daily-log action copy for $tag.');
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
