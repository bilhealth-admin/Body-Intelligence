part of 'wellness_copy.dart';

/// Copy that is visible on the sleep and fasting engines but is not part of
/// the older general runtime catalog. Every shipped non-core language must be
/// present: silently showing English here would make a health workflow look
/// partially translated.
const _wellnessEngineExtended = <String, Map<String, String>>{
  'N/A': {
    'de': '—',
    'it': '—',
    'pt': '—',
    'ur': '—',
    'fa': '—',
    'hi': '—',
    'id': '—',
    'ms': '—',
    'ja': '—',
    'ko': '—',
    'zh': '—',
    'ru': '—',
    'bn': '—',
    'vi': '—',
    'th': '—',
    'pl': '—',
    'nl': '—',
    'uk': '—',
  },
  'Reminder': {
    'de': 'Erinnerung',
    'it': 'Promemoria',
    'pt': 'Lembrete',
    'ur': 'یاد دہانی',
    'fa': 'یادآوری',
    'hi': 'रिमाइंडर',
    'id': 'Pengingat',
    'ms': 'Peringatan',
    'ja': 'リマインダー',
    'ko': '알림',
    'zh': '提醒',
    'ru': 'Напоминание',
    'bn': 'অনুস্মারক',
    'vi': 'Nhắc nhở',
    'th': 'การแจ้งเตือน',
    'pl': 'Przypomnienie',
    'nl': 'Herinnering',
    'uk': 'Нагадування',
  },
  "Find out what's keeping you awake": {
    'de': 'Finde heraus, was dich wach hält',
    'it': 'Scopri cosa ti tiene sveglio',
    'pt': 'Descubra o que mantém você acordado',
    'ur': 'جانیں کہ آپ کو کیا بیدار رکھتا ہے',
    'fa': 'ببینید چه چیزی شما را بیدار نگه می‌دارد',
    'hi': 'जानें कि आपको क्या जगाए रखता है',
    'id': 'Cari tahu apa yang membuat Anda tetap terjaga',
    'ms': 'Ketahui perkara yang membuat anda berjaga',
    'ja': '眠れない原因を見つけましょう',
    'ko': '잠을 방해하는 요인을 알아보세요',
    'zh': '找出让您保持清醒的原因',
    'ru': 'Узнайте, что мешает вам уснуть',
    'bn': 'কী আপনাকে জাগিয়ে রাখছে তা জানুন',
    'vi': 'Tìm hiểu điều gì khiến bạn thức giấc',
    'th': 'ค้นหาสิ่งที่ทำให้คุณตื่นอยู่',
    'pl': 'Sprawdź, co nie pozwala Ci zasnąć',
    'nl': 'Ontdek wat je wakker houdt',
    'uk': 'Дізнайтеся, що заважає вам заснути',
  },
  'Choose a standard or custom intermittent fasting window': {
    'de': 'Wähle ein Standard- oder eigenes Intervallfasten-Fenster',
    'it': 'Scegli una finestra di digiuno standard o personalizzata',
    'pt': 'Escolha uma janela de jejum padrão ou personalizada',
    'ur': 'معیاری یا حسبِ ضرورت وقفے کے روزے کا دورانیہ منتخب کریں',
    'fa': 'یک بازه روزه‌داری متناوب استاندارد یا سفارشی انتخاب کنید',
    'hi': 'मानक या कस्टम इंटरमिटेंट फास्टिंग विंडो चुनें',
    'id': 'Pilih jendela puasa intermiten standar atau khusus',
    'ms': 'Pilih tempoh puasa berselang standard atau tersuai',
    'ja': '標準またはカスタムの断続的断食時間を選択',
    'ko': '표준 또는 사용자 지정 간헐적 단식 시간을 선택하세요',
    'zh': '选择标准或自定义间歇性禁食时段',
    'ru': 'Выберите стандартное или своё окно интервального голодания',
    'bn': 'মানক বা কাস্টম ইন্টারমিটেন্ট ফাস্টিং সময় বেছে নিন',
    'vi': 'Chọn khung nhịn ăn gián đoạn tiêu chuẩn hoặc tùy chỉnh',
    'th': 'เลือกช่วงอดอาหารแบบมาตรฐานหรือกำหนดเอง',
    'pl': 'Wybierz standardowe lub własne okno postu przerywanego',
    'nl': 'Kies een standaard of aangepast vastenvenster',
    'uk': 'Виберіть стандартне або власне вікно інтервального голодування',
  },
  'Notification permission is not active': {
    'de': 'Benachrichtigungen sind nicht erlaubt',
    'it': 'Il permesso per le notifiche non è attivo',
    'pt': 'A permissão de notificações não está ativa',
    'ur': 'اطلاعات کی اجازت فعال نہیں ہے',
    'fa': 'مجوز اعلان‌ها فعال نیست',
    'hi': 'नोटिफिकेशन की अनुमति सक्रिय नहीं है',
    'id': 'Izin notifikasi tidak aktif',
    'ms': 'Kebenaran pemberitahuan tidak aktif',
    'ja': '通知の許可が有効ではありません',
    'ko': '알림 권한이 활성화되어 있지 않습니다',
    'zh': '通知权限未启用',
    'ru': 'Разрешение на уведомления не включено',
    'bn': 'নোটিফিকেশনের অনুমতি সক্রিয় নয়',
    'vi': 'Quyền thông báo chưa được bật',
    'th': 'ยังไม่ได้เปิดสิทธิ์การแจ้งเตือน',
    'pl': 'Uprawnienie do powiadomień nie jest aktywne',
    'nl': 'Meldingsrechten zijn niet actief',
    'uk': 'Дозвіл на сповіщення не ввімкнено',
  },
};

/// The original reviewed five-language wellness catalog predates these engine
/// controls. Patch its three secondary locales explicitly instead of passing
/// missing keys into the global fallback resolver.
const _wellnessEngineCorePatch = <String, Map<String, String>>{
  'N/A': {'fr': '—', 'es': '—', 'tr': '—'},
  'Goal': {'fr': 'Objectif', 'es': 'Objetivo', 'tr': 'Hedef'},
  'Reminder': {'fr': 'Rappel', 'es': 'Recordatorio', 'tr': 'Hatırlatıcı'},
  "Find out what's keeping you awake": {
    'fr': 'Découvrez ce qui vous empêche de dormir',
    'es': 'Descubre qué te mantiene despierto',
    'tr': 'Sizi uyanık tutan şeyi keşfedin',
  },
  'Time': {'fr': 'Heure', 'es': 'Hora', 'tr': 'Saat'},
  'Choose a standard or custom intermittent fasting window': {
    'fr': 'Choisissez une fenêtre de jeûne standard ou personnalisée',
    'es': 'Elige una ventana de ayuno estándar o personalizada',
    'tr': 'Standart veya özel aralıklı oruç penceresi seçin',
  },
  'The local timer survives app restarts': {
    'fr': "Le minuteur local reste actif après le redémarrage de l’application",
    'es': 'El temporizador local continúa tras reiniciar la aplicación',
    'tr': 'Yerel zamanlayıcı uygulama yeniden başlatıldığında devam eder',
  },
  'Review completed intermittent fasting sessions here': {
    'fr': 'Consultez ici vos jeûnes intermittents terminés',
    'es': 'Consulta aquí los ayunos intermitentes completados',
    'tr': 'Tamamlanan aralıklı oruçları burada inceleyin',
  },
  'A local intermittent fasting timer. You remain in control.': {
    'fr': 'Un minuteur local de jeûne intermittent. Vous gardez le contrôle.',
    'es':
        'Un temporizador local de ayuno intermitente. Tú mantienes el control.',
    'tr': 'Yerel bir aralıklı oruç zamanlayıcısı. Kontrol sizde kalır.',
  },
  'No active fast': {
    'fr': 'Aucun jeûne actif',
    'es': 'No hay un ayuno activo',
    'tr': 'Aktif oruç yok',
  },
  'Target': {'fr': 'Objectif', 'es': 'Objetivo', 'tr': 'Hedef'},
  'Custom': {'fr': 'Personnalisé', 'es': 'Personalizado', 'tr': 'Özel'},
  'Notify me at my target': {
    'fr': 'Me prévenir lorsque mon objectif est atteint',
    'es': 'Avísame al alcanzar mi objetivo',
    'tr': 'Hedefime ulaştığımda bildir',
  },
  'Notification permission is not active': {
    'fr': "L’autorisation des notifications n’est pas active",
    'es': 'El permiso de notificaciones no está activo',
    'tr': 'Bildirim izni etkin değil',
  },
};

const _wellnessEngineExtendedLanguageCodes = <String>{
  'de',
  'it',
  'pt',
  'ur',
  'fa',
  'hi',
  'id',
  'ms',
  'ja',
  'ko',
  'zh',
  'ru',
  'bn',
  'vi',
  'th',
  'pl',
  'nl',
  'uk',
};

bool get wellnessEngineExtendedCopyIsComplete =>
    _wellnessEngineExtended.values.every(
      (translations) =>
          translations.keys.toSet().containsAll(
            _wellnessEngineExtendedLanguageCodes,
          ) &&
          _wellnessEngineExtendedLanguageCodes.containsAll(translations.keys) &&
          translations.values.every((value) => value.trim().isNotEmpty),
    ) &&
    _wellnessEngineCorePatch.values.every(
      (translations) =>
          translations.keys.toSet().containsAll(const {'fr', 'es', 'tr'}) &&
          const {'fr', 'es', 'tr'}.containsAll(translations.keys) &&
          translations.values.every((value) => value.trim().isNotEmpty),
    );

String? wellnessEngineExtendedCopyForTesting(String english, String localeTag) {
  final language = localeTag
      .replaceAll('_', '-')
      .toLowerCase()
      .split('-')
      .first;
  return _wellnessEngineCorePatch[english]?[language] ??
      _wellnessEngineExtended[english]?[language];
}
