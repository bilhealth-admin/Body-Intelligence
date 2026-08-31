import 'package:flutter/widgets.dart';

import 'bil_locale_policy.dart';

/// Reviewed parameterized copy for measured fitness connection status.
///
/// Values remain templates until [format] is called so runtime values never
/// become lookup keys and silently fall back to English.
abstract final class ConnectedHealthRuntimeCopy {
  static const importedRecords =
      '{count} new records were imported during the last synchronization.';
  static const devicesFound = '{count} fitness device(s) found.';
  static const measurementSyncFailed =
      'Fitness device paired, but measurement sync failed ({code}).';
  static const connectedWithoutBattery =
      'Fitness device connected. Battery was not reported. Last sync: {time}.';
  static const connectedWithBattery =
      'Fitness device connected. Battery {percent}%. Last sync: {time}.';

  static const sources = <String>[
    importedRecords,
    devicesFound,
    measurementSyncFailed,
    connectedWithoutBattery,
    connectedWithBattery,
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
    'ar': [
      'تم استيراد {count} سجل جديد خلال آخر مزامنة.',
      'تم العثور على {count} من أجهزة اللياقة.',
      'تم اقتران جهاز اللياقة، لكن فشلت مزامنة القياس ({code}).',
      'جهاز اللياقة متصل. لم يرسل الجهاز حالة البطارية. آخر مزامنة: {time}.',
      'جهاز اللياقة متصل. البطارية {percent}٪. آخر مزامنة: {time}.',
    ],
    'en': sources,
    'fr': [
      '{count} nouveaux enregistrements ont été importés lors de la dernière synchronisation.',
      '{count} appareils de fitness trouvés.',
      'Appareil de fitness associé, mais la synchronisation des mesures a échoué ({code}).',
      'Appareil de fitness connecté. La batterie n’a pas été communiquée. Dernière synchronisation : {time}.',
      'Appareil de fitness connecté. Batterie {percent} %. Dernière synchronisation : {time}.',
    ],
    'es': [
      'Se importaron {count} registros nuevos durante la última sincronización.',
      'Se encontraron {count} dispositivos de fitness.',
      'El dispositivo de fitness se vinculó, pero falló la sincronización de mediciones ({code}).',
      'Dispositivo de fitness conectado. No se informó la batería. Última sincronización: {time}.',
      'Dispositivo de fitness conectado. Batería {percent} %. Última sincronización: {time}.',
    ],
    'tr': [
      'Son eşitlemede {count} yeni kayıt içe aktarıldı.',
      '{count} fitness cihazı bulundu.',
      'Fitness cihazı eşleştirildi ancak ölçüm eşitlemesi başarısız oldu ({code}).',
      'Fitness cihazı bağlı. Pil bilgisi bildirilmedi. Son eşitleme: {time}.',
      'Fitness cihazı bağlı. Pil %{percent}. Son eşitleme: {time}.',
    ],
    'de': [
      'Bei der letzten Synchronisierung wurden {count} neue Datensätze importiert.',
      '{count} Fitnessgeräte gefunden.',
      'Fitnessgerät gekoppelt, aber die Messwertsynchronisierung ist fehlgeschlagen ({code}).',
      'Fitnessgerät verbunden. Der Akkustand wurde nicht gemeldet. Letzte Synchronisierung: {time}.',
      'Fitnessgerät verbunden. Akku {percent} %. Letzte Synchronisierung: {time}.',
    ],
    'it': [
      'Durante l’ultima sincronizzazione sono stati importati {count} nuovi record.',
      'Trovati {count} dispositivi fitness.',
      'Dispositivo fitness associato, ma la sincronizzazione delle misurazioni non è riuscita ({code}).',
      'Dispositivo fitness connesso. Batteria non comunicata. Ultima sincronizzazione: {time}.',
      'Dispositivo fitness connesso. Batteria {percent}%. Ultima sincronizzazione: {time}.',
    ],
    'pt-BR': [
      '{count} novos registros foram importados na última sincronização.',
      '{count} dispositivos fitness encontrados.',
      'Dispositivo fitness pareado, mas a sincronização das medições falhou ({code}).',
      'Dispositivo fitness conectado. A bateria não foi informada. Última sincronização: {time}.',
      'Dispositivo fitness conectado. Bateria {percent}%. Última sincronização: {time}.',
    ],
    'pt-PT': [
      'Foram importados {count} novos registos na última sincronização.',
      'Foram encontrados {count} dispositivos de fitness.',
      'Dispositivo de fitness emparelhado, mas a sincronização das medições falhou ({code}).',
      'Dispositivo de fitness ligado. A bateria não foi comunicada. Última sincronização: {time}.',
      'Dispositivo de fitness ligado. Bateria {percent}%. Última sincronização: {time}.',
    ],
    'ur': [
      'آخری ہم آہنگی میں {count} نئے ریکارڈ درآمد کیے گئے۔',
      '{count} فٹنس آلات ملے۔',
      'فٹنس آلہ جڑ گیا، لیکن پیمائش کی ہم آہنگی ناکام رہی ({code})۔',
      'فٹنس آلہ منسلک ہے۔ بیٹری کی اطلاع نہیں ملی۔ آخری ہم آہنگی: {time}۔',
      'فٹنس آلہ منسلک ہے۔ بیٹری {percent}٪۔ آخری ہم آہنگی: {time}۔',
    ],
    'fa': [
      'در آخرین همگام‌سازی {count} رکورد جدید وارد شد.',
      '{count} دستگاه تناسب اندام پیدا شد.',
      'دستگاه تناسب اندام جفت شد، اما همگام‌سازی اندازه‌گیری ناموفق بود ({code}).',
      'دستگاه تناسب اندام متصل است. وضعیت باتری ارسال نشد. آخرین همگام‌سازی: {time}.',
      'دستگاه تناسب اندام متصل است. باتری {percent}٪. آخرین همگام‌سازی: {time}.',
    ],
    'hi': [
      'पिछले सिंक में {count} नए रिकॉर्ड इंपोर्ट हुए।',
      '{count} फ़िटनेस डिवाइस मिले।',
      'फ़िटनेस डिवाइस पेयर हुआ, लेकिन माप सिंक नहीं हुआ ({code})।',
      'फ़िटनेस डिवाइस कनेक्टेड है। बैटरी की जानकारी नहीं मिली। पिछला सिंक: {time}।',
      'फ़िटनेस डिवाइस कनेक्टेड है। बैटरी {percent}%। पिछला सिंक: {time}।',
    ],
    'id': [
      '{count} catatan baru diimpor saat sinkronisasi terakhir.',
      '{count} perangkat kebugaran ditemukan.',
      'Perangkat kebugaran tersambung, tetapi sinkronisasi pengukuran gagal ({code}).',
      'Perangkat kebugaran terhubung. Status baterai tidak dilaporkan. Sinkronisasi terakhir: {time}.',
      'Perangkat kebugaran terhubung. Baterai {percent}%. Sinkronisasi terakhir: {time}.',
    ],
    'ms': [
      '{count} rekod baharu diimport semasa penyegerakan terakhir.',
      '{count} peranti kecergasan ditemui.',
      'Peranti kecergasan dipasangkan, tetapi penyegerakan ukuran gagal ({code}).',
      'Peranti kecergasan disambungkan. Bateri tidak dilaporkan. Penyegerakan terakhir: {time}.',
      'Peranti kecergasan disambungkan. Bateri {percent}%. Penyegerakan terakhir: {time}.',
    ],
    'ja': [
      '前回の同期で新しい記録 {count} 件を取り込みました。',
      'フィットネス機器が {count} 台見つかりました。',
      'フィットネス機器はペアリングされましたが、測定の同期に失敗しました（{code}）。',
      'フィットネス機器は接続済みです。バッテリー情報はありません。最終同期: {time}。',
      'フィットネス機器は接続済みです。バッテリー {percent}%。最終同期: {time}。',
    ],
    'ko': [
      '마지막 동기화에서 새 기록 {count}개를 가져왔습니다.',
      '피트니스 기기 {count}개를 찾았습니다.',
      '피트니스 기기가 페어링되었지만 측정값 동기화에 실패했습니다({code}).',
      '피트니스 기기가 연결되었습니다. 배터리 정보가 없습니다. 마지막 동기화: {time}.',
      '피트니스 기기가 연결되었습니다. 배터리 {percent}%. 마지막 동기화: {time}.',
    ],
    'zh-Hans': [
      '上次同步已导入 {count} 条新记录。',
      '找到 {count} 台健身设备。',
      '健身设备已配对，但测量同步失败（{code}）。',
      '健身设备已连接。设备未报告电量。上次同步：{time}。',
      '健身设备已连接。电量 {percent}%。上次同步：{time}。',
    ],
    'zh-Hant': [
      '上次同步已匯入 {count} 筆新記錄。',
      '找到 {count} 台健身裝置。',
      '健身裝置已配對，但測量同步失敗（{code}）。',
      '健身裝置已連線。裝置未回報電量。上次同步：{time}。',
      '健身裝置已連線。電量 {percent}%。上次同步：{time}。',
    ],
    'ru': [
      'При последней синхронизации импортировано новых записей: {count}.',
      'Найдено фитнес-устройств: {count}.',
      'Фитнес-устройство сопряжено, но синхронизация измерений не удалась ({code}).',
      'Фитнес-устройство подключено. Уровень заряда не сообщён. Последняя синхронизация: {time}.',
      'Фитнес-устройство подключено. Заряд {percent}%. Последняя синхронизация: {time}.',
    ],
    'bn': [
      'শেষ সিঙ্কে {count}টি নতুন রেকর্ড ইমপোর্ট হয়েছে।',
      '{count}টি ফিটনেস ডিভাইস পাওয়া গেছে।',
      'ফিটনেস ডিভাইস পেয়ার হয়েছে, কিন্তু পরিমাপ সিঙ্ক ব্যর্থ ({code})।',
      'ফিটনেস ডিভাইস সংযুক্ত। ব্যাটারির তথ্য পাওয়া যায়নি। শেষ সিঙ্ক: {time}।',
      'ফিটনেস ডিভাইস সংযুক্ত। ব্যাটারি {percent}%। শেষ সিঙ্ক: {time}।',
    ],
    'vi': [
      'Đã nhập {count} bản ghi mới trong lần đồng bộ gần nhất.',
      'Đã tìm thấy {count} thiết bị thể chất.',
      'Thiết bị thể chất đã ghép đôi, nhưng không thể đồng bộ số đo ({code}).',
      'Thiết bị thể chất đã kết nối. Thiết bị không báo pin. Lần đồng bộ gần nhất: {time}.',
      'Thiết bị thể chất đã kết nối. Pin {percent}%. Lần đồng bộ gần nhất: {time}.',
    ],
    'th': [
      'นำเข้าระเบียนใหม่ {count} รายการในการซิงค์ล่าสุดแล้ว',
      'พบอุปกรณ์ฟิตเนส {count} เครื่อง',
      'จับคู่อุปกรณ์ฟิตเนสแล้ว แต่ซิงค์ค่าที่วัดไม่สำเร็จ ({code})',
      'เชื่อมต่ออุปกรณ์ฟิตเนสแล้ว ไม่มีข้อมูลแบตเตอรี่ ซิงค์ล่าสุด: {time}',
      'เชื่อมต่ออุปกรณ์ฟิตเนสแล้ว แบตเตอรี่ {percent}% ซิงค์ล่าสุด: {time}',
    ],
    'pl': [
      'Podczas ostatniej synchronizacji zaimportowano {count} nowych rekordów.',
      'Znaleziono {count} urządzeń fitness.',
      'Urządzenie fitness sparowano, ale synchronizacja pomiarów nie powiodła się ({code}).',
      'Urządzenie fitness jest połączone. Nie zgłoszono stanu baterii. Ostatnia synchronizacja: {time}.',
      'Urządzenie fitness jest połączone. Bateria {percent}%. Ostatnia synchronizacja: {time}.',
    ],
    'nl': [
      'Bij de laatste synchronisatie zijn {count} nieuwe records geïmporteerd.',
      '{count} fitnessapparaten gevonden.',
      'Fitnessapparaat gekoppeld, maar het synchroniseren van metingen is mislukt ({code}).',
      'Fitnessapparaat verbonden. Batterijstatus niet gemeld. Laatste synchronisatie: {time}.',
      'Fitnessapparaat verbonden. Batterij {percent}%. Laatste synchronisatie: {time}.',
    ],
    'uk': [
      'Під час останньої синхронізації імпортовано {count} нових записів.',
      'Знайдено фітнес-пристроїв: {count}.',
      'Фітнес-пристрій спаровано, але синхронізація вимірювань не вдалася ({code}).',
      'Фітнес-пристрій підключено. Рівень заряду не повідомлено. Остання синхронізація: {time}.',
      'Фітнес-пристрій підключено. Заряд {percent}%. Остання синхронізація: {time}.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing connected-health runtime copy for $tag.');
    }
    return row[index];
  }

  static String format(
    BuildContext context,
    String source, {
    String? count,
    String? code,
    String? time,
    String? percent,
  }) {
    final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
    return formatForTag(
      tag,
      source,
      count: count,
      code: code,
      time: time,
      percent: percent,
    );
  }

  static String formatForTag(
    String localeTag,
    String source, {
    String? count,
    String? code,
    String? time,
    String? percent,
  }) {
    var value = resolve(source, localeTag) ?? source;
    if (count != null) value = value.replaceAll('{count}', count);
    if (code != null) value = value.replaceAll('{code}', code);
    if (time != null) value = value.replaceAll('{time}', time);
    if (percent != null) value = value.replaceAll('{percent}', percent);
    return value;
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
