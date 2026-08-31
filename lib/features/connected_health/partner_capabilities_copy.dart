import 'package:flutter/widgets.dart';

import '../../app/localization/bil_locale_policy.dart';

/// Reviewed copy for the truthful partner-capability registry surface.
final class PartnerCapabilitiesCopy {
  const PartnerCapabilitiesCopy._(this._values);

  static const sources = <String>[
    'Connection capabilities',
    'Choose a supported health source. Availability depends on your device and permissions.',
    'Bluetooth fitness devices',
    'Health platform',
    'Fitness device',
    'Partner account',
    'Available on supported devices after permission',
    'Available after Bluetooth permission',
    'Not available yet',
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

  static PartnerCapabilitiesCopy of(BuildContext context) =>
      forTag(BilLocalePolicy.canonicalTag(Localizations.localeOf(context)));

  static PartnerCapabilitiesCopy forTag(String localeTag) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return const PartnerCapabilitiesCopy._(sources);
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing partner-capabilities copy for $tag.');
    }
    return PartnerCapabilitiesCopy._(row);
  }

  final List<String> _values;

  String text(String key) {
    final index = sources.indexOf(key);
    if (index >= 0) return _values[index];
    return switch (key) {
      'health-connect' => 'Health Connect',
      'healthkit' => 'Apple Health',
      'garmin' => 'Garmin',
      'fitbit' => 'Fitbit',
      'samsung-health' => 'Samsung Health',
      _ => throw StateError('Unknown partner capability copy key: $key'),
    };
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

  static const rows = <String, List<String>>{
    'ar': <String>[
      'قدرات الاتصال',
      'اختر مصدرًا صحيًا مدعومًا. يعتمد التوفر على جهازك والأذونات.',
      'أجهزة لياقة عبر Bluetooth',
      'منصة صحية',
      'جهاز لياقة',
      'حساب شريك',
      'متاح على الأجهزة المدعومة بعد منح الإذن',
      'متاح بعد منح إذن Bluetooth',
      'غير متاح بعد',
    ],
    'en': sources,
    'fr': <String>[
      'Capacités de connexion',
      'Choisissez une source de santé compatible. La disponibilité dépend de votre appareil et des autorisations.',
      'Appareils de fitness Bluetooth',
      'Plateforme de santé',
      'Appareil de fitness',
      'Compte partenaire',
      'Disponible sur les appareils compatibles après autorisation',
      'Disponible après autorisation Bluetooth',
      'Pas encore disponible',
    ],
    'es': <String>[
      'Capacidades de conexión',
      'Elige una fuente de salud compatible. La disponibilidad depende del dispositivo y los permisos.',
      'Dispositivos de fitness Bluetooth',
      'Plataforma de salud',
      'Dispositivo de fitness',
      'Cuenta asociada',
      'Disponible en dispositivos compatibles después del permiso',
      'Disponible después del permiso de Bluetooth',
      'Aún no disponible',
    ],
    'tr': <String>[
      'Bağlantı özellikleri',
      'Desteklenen bir sağlık kaynağı seçin. Kullanılabilirlik cihazınıza ve izinlere bağlıdır.',
      'Bluetooth fitness cihazları',
      'Sağlık platformu',
      'Fitness cihazı',
      'İş ortağı hesabı',
      'İzin verildikten sonra desteklenen cihazlarda kullanılabilir',
      'Bluetooth izninden sonra kullanılabilir',
      'Henüz kullanılamıyor',
    ],
    'de': <String>[
      'Verbindungsmöglichkeiten',
      'Wählen Sie eine unterstützte Gesundheitsquelle. Die Verfügbarkeit hängt von Ihrem Gerät und den Berechtigungen ab.',
      'Bluetooth-Fitnessgeräte',
      'Gesundheitsplattform',
      'Fitnessgerät',
      'Partnerkonto',
      'Nach Erteilung der Berechtigung auf unterstützten Geräten verfügbar',
      'Nach Erteilung der Bluetooth-Berechtigung verfügbar',
      'Noch nicht verfügbar',
    ],
    'it': <String>[
      'Opzioni di connessione',
      'Scegli una fonte sanitaria supportata. La disponibilità dipende dal dispositivo e dalle autorizzazioni.',
      'Dispositivi fitness Bluetooth',
      'Piattaforma sanitaria',
      'Dispositivo fitness',
      'Account partner',
      'Disponibile sui dispositivi supportati dopo l’autorizzazione',
      'Disponibile dopo l’autorizzazione Bluetooth',
      'Non ancora disponibile',
    ],
    'pt-BR': <String>[
      'Recursos de conexão',
      'Escolha uma fonte de saúde compatível. A disponibilidade depende do dispositivo e das permissões.',
      'Dispositivos fitness Bluetooth',
      'Plataforma de saúde',
      'Dispositivo fitness',
      'Conta de parceiro',
      'Disponível em dispositivos compatíveis após a permissão',
      'Disponível após a permissão de Bluetooth',
      'Ainda não disponível',
    ],
    'pt-PT': <String>[
      'Capacidades de ligação',
      'Escolha uma fonte de saúde compatível. A disponibilidade depende do dispositivo e das permissões.',
      'Dispositivos de fitness Bluetooth',
      'Plataforma de saúde',
      'Dispositivo de fitness',
      'Conta de parceiro',
      'Disponível em dispositivos compatíveis após a autorização',
      'Disponível após a autorização de Bluetooth',
      'Ainda não disponível',
    ],
    'ur': <String>[
      'کنکشن کی صلاحیتیں',
      'ایک معاون صحت کا ماخذ منتخب کریں۔ دستیابی آپ کے آلے اور اجازتوں پر منحصر ہے۔',
      'Bluetooth فٹنس آلات',
      'صحت کا پلیٹ فارم',
      'فٹنس آلہ',
      'شراکت دار اکاؤنٹ',
      'اجازت کے بعد معاون آلات پر دستیاب',
      'Bluetooth کی اجازت کے بعد دستیاب',
      'ابھی دستیاب نہیں',
    ],
    'fa': <String>[
      'قابلیت‌های اتصال',
      'یک منبع سلامت پشتیبانی‌شده انتخاب کنید. دسترس‌پذیری به دستگاه و مجوزهای شما بستگی دارد.',
      'دستگاه‌های تناسب اندام Bluetooth',
      'پلتفرم سلامت',
      'دستگاه تناسب اندام',
      'حساب شریک',
      'پس از صدور مجوز روی دستگاه‌های پشتیبانی‌شده در دسترس است',
      'پس از صدور مجوز Bluetooth در دسترس است',
      'هنوز در دسترس نیست',
    ],
    'hi': <String>[
      'कनेक्शन क्षमताएँ',
      'समर्थित स्वास्थ्य स्रोत चुनें। उपलब्धता आपके डिवाइस और अनुमतियों पर निर्भर करती है।',
      'Bluetooth फ़िटनेस डिवाइस',
      'स्वास्थ्य प्लेटफ़ॉर्म',
      'फ़िटनेस डिवाइस',
      'पार्टनर खाता',
      'अनुमति मिलने के बाद समर्थित डिवाइस पर उपलब्ध',
      'Bluetooth अनुमति के बाद उपलब्ध',
      'अभी उपलब्ध नहीं',
    ],
    'id': <String>[
      'Kemampuan koneksi',
      'Pilih sumber kesehatan yang didukung. Ketersediaan bergantung pada perangkat dan izin Anda.',
      'Perangkat kebugaran Bluetooth',
      'Platform kesehatan',
      'Perangkat kebugaran',
      'Akun mitra',
      'Tersedia di perangkat yang didukung setelah izin diberikan',
      'Tersedia setelah izin Bluetooth diberikan',
      'Belum tersedia',
    ],
    'ms': <String>[
      'Keupayaan sambungan',
      'Pilih sumber kesihatan yang disokong. Ketersediaan bergantung pada peranti dan kebenaran anda.',
      'Peranti kecergasan Bluetooth',
      'Platform kesihatan',
      'Peranti kecergasan',
      'Akaun rakan kongsi',
      'Tersedia pada peranti yang disokong selepas kebenaran diberikan',
      'Tersedia selepas kebenaran Bluetooth diberikan',
      'Belum tersedia',
    ],
    'ja': <String>[
      '接続機能',
      '対応するヘルスソースを選択してください。利用可否は端末と権限によって異なります。',
      'Bluetoothフィットネス機器',
      'ヘルスプラットフォーム',
      'フィットネス機器',
      'パートナーアカウント',
      '対応端末で権限を許可すると利用できます',
      'Bluetooth権限を許可すると利用できます',
      'まだ利用できません',
    ],
    'ko': <String>[
      '연결 기능',
      '지원되는 건강 데이터 소스를 선택하세요. 사용 가능 여부는 기기와 권한에 따라 달라집니다.',
      'Bluetooth 피트니스 기기',
      '건강 플랫폼',
      '피트니스 기기',
      '파트너 계정',
      '지원 기기에서 권한을 허용하면 사용할 수 있습니다',
      'Bluetooth 권한을 허용하면 사용할 수 있습니다',
      '아직 사용할 수 없음',
    ],
    'zh-Hans': <String>[
      '连接功能',
      '请选择受支持的健康数据源。可用性取决于你的设备和权限。',
      'Bluetooth健身设备',
      '健康平台',
      '健身设备',
      '合作伙伴账户',
      '在受支持的设备上授权后可用',
      '授予Bluetooth权限后可用',
      '尚不可用',
    ],
    'zh-Hant': <String>[
      '連線功能',
      '請選擇支援的健康資料來源。可用性取決於你的裝置和權限。',
      'Bluetooth健身裝置',
      '健康平台',
      '健身裝置',
      '合作夥伴帳戶',
      '在支援的裝置上授權後即可使用',
      '授予Bluetooth權限後即可使用',
      '尚未提供',
    ],
    'ru': <String>[
      'Возможности подключения',
      'Выберите поддерживаемый источник данных о здоровье. Доступность зависит от устройства и разрешений.',
      'Фитнес-устройства Bluetooth',
      'Платформа здоровья',
      'Фитнес-устройство',
      'Учётная запись партнёра',
      'Доступно на поддерживаемых устройствах после предоставления разрешения',
      'Доступно после предоставления разрешения Bluetooth',
      'Пока недоступно',
    ],
    'bn': <String>[
      'সংযোগের সুবিধা',
      'সমর্থিত স্বাস্থ্য উৎস বেছে নিন। প্রাপ্যতা আপনার ডিভাইস ও অনুমতির ওপর নির্ভর করে।',
      'Bluetooth ফিটনেস ডিভাইস',
      'স্বাস্থ্য প্ল্যাটফর্ম',
      'ফিটনেস ডিভাইস',
      'অংশীদার অ্যাকাউন্ট',
      'অনুমতি দেওয়ার পর সমর্থিত ডিভাইসে ব্যবহারযোগ্য',
      'Bluetooth অনুমতির পর ব্যবহারযোগ্য',
      'এখনও পাওয়া যাচ্ছে না',
    ],
    'vi': <String>[
      'Khả năng kết nối',
      'Chọn nguồn dữ liệu sức khỏe được hỗ trợ. Khả dụng tùy thuộc vào thiết bị và quyền của bạn.',
      'Thiết bị thể dục Bluetooth',
      'Nền tảng sức khỏe',
      'Thiết bị thể dục',
      'Tài khoản đối tác',
      'Khả dụng trên thiết bị được hỗ trợ sau khi cấp quyền',
      'Khả dụng sau khi cấp quyền Bluetooth',
      'Chưa khả dụng',
    ],
    'th': <String>[
      'ความสามารถในการเชื่อมต่อ',
      'เลือกแหล่งข้อมูลสุขภาพที่รองรับ ความพร้อมใช้งานขึ้นอยู่กับอุปกรณ์และสิทธิ์ของคุณ',
      'อุปกรณ์ฟิตเนส Bluetooth',
      'แพลตฟอร์มสุขภาพ',
      'อุปกรณ์ฟิตเนส',
      'บัญชีพาร์ทเนอร์',
      'ใช้ได้บนอุปกรณ์ที่รองรับหลังจากให้สิทธิ์',
      'ใช้ได้หลังจากให้สิทธิ์ Bluetooth',
      'ยังไม่พร้อมใช้งาน',
    ],
    'pl': <String>[
      'Możliwości połączeń',
      'Wybierz obsługiwane źródło danych zdrowotnych. Dostępność zależy od urządzenia i uprawnień.',
      'Urządzenia fitness Bluetooth',
      'Platforma zdrowotna',
      'Urządzenie fitness',
      'Konto partnera',
      'Dostępne na obsługiwanych urządzeniach po udzieleniu zgody',
      'Dostępne po udzieleniu zgody na Bluetooth',
      'Jeszcze niedostępne',
    ],
    'nl': <String>[
      'Verbindingsmogelijkheden',
      'Kies een ondersteunde gezondheidsbron. Beschikbaarheid is afhankelijk van uw apparaat en machtigingen.',
      'Bluetooth-fitnessapparaten',
      'Gezondheidsplatform',
      'Fitnessapparaat',
      'Partneraccount',
      'Beschikbaar op ondersteunde apparaten na toestemming',
      'Beschikbaar na Bluetooth-toestemming',
      'Nog niet beschikbaar',
    ],
    'uk': <String>[
      'Можливості підключення',
      'Виберіть підтримуване джерело даних про здоров’я. Доступність залежить від пристрою та дозволів.',
      'Фітнес-пристрої Bluetooth',
      'Платформа здоров’я',
      'Фітнес-пристрій',
      'Обліковий запис партнера',
      'Доступно на підтримуваних пристроях після надання дозволу',
      'Доступно після надання дозволу Bluetooth',
      'Поки недоступно',
    ],
  };
}
