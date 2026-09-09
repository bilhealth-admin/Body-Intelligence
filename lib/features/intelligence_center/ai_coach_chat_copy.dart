import '../../app/localization/bil_locale_policy.dart';

/// Small, feature-owned catalog for AI Coach action state.
///
/// These strings deliberately do not use the Community runtime catalog. They
/// are complete for every BIL production locale so an action failure never
/// falls back to an unrelated interface language.
abstract final class AiCoachChatCopy {
  static const navigationReady = 'navigationReady';
  static const opening = 'opening';
  static const navigationFailed = 'navigationFailed';
  static const retry = 'retry';

  static const keys = <String>{
    navigationReady,
    opening,
    navigationFailed,
    retry,
  };

  static String resolve(String locale, String key) {
    final tag = BilLocalePolicy.canonicalSupportedTag(locale) ?? 'en';
    return _values[tag]?[key] ?? _values['en']![key]!;
  }

  static Map<String, Map<String, String>> get values => _values;

  static const _values = <String, Map<String, String>>{
    'ar': {
      navigationReady: 'استخدم الإجراء أدناه لفتح الشاشة المطلوبة.',
      opening: 'جارٍ الفتح…',
      navigationFailed: 'تعذر فتح هذه الشاشة.',
      retry: 'إعادة المحاولة',
    },
    'en': {
      navigationReady: 'Use the action below to open the requested screen.',
      opening: 'Opening…',
      navigationFailed: 'Couldn’t open this screen.',
      retry: 'Try again',
    },
    'fr': {
      navigationReady:
          'Utilisez l’action ci-dessous pour ouvrir l’écran demandé.',
      opening: 'Ouverture…',
      navigationFailed: 'Impossible d’ouvrir cet écran.',
      retry: 'Réessayer',
    },
    'es': {
      navigationReady:
          'Usa la acción de abajo para abrir la pantalla solicitada.',
      opening: 'Abriendo…',
      navigationFailed: 'No se pudo abrir esta pantalla.',
      retry: 'Reintentar',
    },
    'tr': {
      navigationReady: 'İstenen ekranı açmak için aşağıdaki işlemi kullanın.',
      opening: 'Açılıyor…',
      navigationFailed: 'Bu ekran açılamadı.',
      retry: 'Tekrar dene',
    },
    'de': {
      navigationReady: 'Öffne den gewünschten Bildschirm mit der Aktion unten.',
      opening: 'Wird geöffnet…',
      navigationFailed: 'Dieser Bildschirm konnte nicht geöffnet werden.',
      retry: 'Erneut versuchen',
    },
    'it': {
      navigationReady:
          'Usa l’azione qui sotto per aprire la schermata richiesta.',
      opening: 'Apertura…',
      navigationFailed: 'Impossibile aprire questa schermata.',
      retry: 'Riprova',
    },
    'pt-BR': {
      navigationReady: 'Use a ação abaixo para abrir a tela solicitada.',
      opening: 'Abrindo…',
      navigationFailed: 'Não foi possível abrir esta tela.',
      retry: 'Tentar novamente',
    },
    'pt-PT': {
      navigationReady: 'Use a ação abaixo para abrir o ecrã solicitado.',
      opening: 'A abrir…',
      navigationFailed: 'Não foi possível abrir este ecrã.',
      retry: 'Tentar novamente',
    },
    'ur': {
      navigationReady:
          'مطلوبہ اسکرین کھولنے کے لیے نیچے دی گئی کارروائی استعمال کریں۔',
      opening: 'کھولا جا رہا ہے…',
      navigationFailed: 'یہ اسکرین نہیں کھل سکی۔',
      retry: 'دوبارہ کوشش کریں',
    },
    'fa': {
      navigationReady:
          'برای باز کردن صفحهٔ درخواستی از اقدام زیر استفاده کنید.',
      opening: 'در حال باز کردن…',
      navigationFailed: 'این صفحه باز نشد.',
      retry: 'تلاش دوباره',
    },
    'hi': {
      navigationReady:
          'माँगी गई स्क्रीन खोलने के लिए नीचे दी गई कार्रवाई का उपयोग करें।',
      opening: 'खोला जा रहा है…',
      navigationFailed: 'यह स्क्रीन नहीं खुल सकी।',
      retry: 'फिर कोशिश करें',
    },
    'id': {
      navigationReady:
          'Gunakan tindakan di bawah untuk membuka layar yang diminta.',
      opening: 'Membuka…',
      navigationFailed: 'Layar ini tidak dapat dibuka.',
      retry: 'Coba lagi',
    },
    'ms': {
      navigationReady:
          'Gunakan tindakan di bawah untuk membuka skrin yang diminta.',
      opening: 'Membuka…',
      navigationFailed: 'Skrin ini tidak dapat dibuka.',
      retry: 'Cuba lagi',
    },
    'ja': {
      navigationReady: '下の操作を使って、リクエストした画面を開いてください。',
      opening: '開いています…',
      navigationFailed: 'この画面を開けませんでした。',
      retry: 'もう一度試す',
    },
    'ko': {
      navigationReady: '아래 작업을 사용해 요청한 화면을 여세요.',
      opening: '여는 중…',
      navigationFailed: '이 화면을 열 수 없습니다.',
      retry: '다시 시도',
    },
    'zh-Hans': {
      navigationReady: '使用下方操作打开所请求的页面。',
      opening: '正在打开…',
      navigationFailed: '无法打开此页面。',
      retry: '重试',
    },
    'zh-Hant': {
      navigationReady: '使用下方操作開啟所要求的頁面。',
      opening: '正在開啟…',
      navigationFailed: '無法開啟此頁面。',
      retry: '重試',
    },
    'ru': {
      navigationReady: 'Используйте действие ниже, чтобы открыть нужный экран.',
      opening: 'Открытие…',
      navigationFailed: 'Не удалось открыть этот экран.',
      retry: 'Повторить',
    },
    'bn': {
      navigationReady: 'অনুরোধ করা স্ক্রিন খুলতে নিচের অ্যাকশনটি ব্যবহার করুন।',
      opening: 'খোলা হচ্ছে…',
      navigationFailed: 'এই স্ক্রিনটি খোলা যায়নি।',
      retry: 'আবার চেষ্টা করুন',
    },
    'vi': {
      navigationReady: 'Dùng thao tác bên dưới để mở màn hình được yêu cầu.',
      opening: 'Đang mở…',
      navigationFailed: 'Không thể mở màn hình này.',
      retry: 'Thử lại',
    },
    'th': {
      navigationReady: 'ใช้การดำเนินการด้านล่างเพื่อเปิดหน้าที่ขอ',
      opening: 'กำลังเปิด…',
      navigationFailed: 'ไม่สามารถเปิดหน้านี้ได้',
      retry: 'ลองอีกครั้ง',
    },
    'pl': {
      navigationReady: 'Użyj działania poniżej, aby otworzyć żądany ekran.',
      opening: 'Otwieranie…',
      navigationFailed: 'Nie udało się otworzyć tego ekranu.',
      retry: 'Spróbuj ponownie',
    },
    'nl': {
      navigationReady:
          'Gebruik de actie hieronder om het gevraagde scherm te openen.',
      opening: 'Openen…',
      navigationFailed: 'Dit scherm kon niet worden geopend.',
      retry: 'Opnieuw proberen',
    },
    'uk': {
      navigationReady:
          'Скористайтеся дією нижче, щоб відкрити потрібний екран.',
      opening: 'Відкриття…',
      navigationFailed: 'Не вдалося відкрити цей екран.',
      retry: 'Спробувати ще раз',
    },
  };
}
