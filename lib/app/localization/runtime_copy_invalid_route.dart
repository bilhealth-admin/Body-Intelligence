import 'bil_locale_policy.dart';

/// Explicit 25-locale copy for invalid/deep-link safety routing.
abstract final class InvalidRouteRuntimeCopy {
  static const source =
      'This link cannot be opened safely. Return to Home and try again.';

  static const values = <String, String>{
    'ar': 'لا يمكن فتح هذا الرابط بأمان. ارجع إلى الرئيسية وحاول مرة أخرى.',
    'en': 'This link cannot be opened safely. Return to Home and try again.',
    'fr':
        'Ce lien ne peut pas être ouvert en toute sécurité. Revenez à l’accueil et réessayez.',
    'es':
        'Este enlace no se puede abrir de forma segura. Vuelve al inicio e inténtalo de nuevo.',
    'tr':
        'Bu bağlantı güvenli bir şekilde açılamıyor. Ana sayfaya dönüp tekrar deneyin.',
    'de':
        'Dieser Link kann nicht sicher geöffnet werden. Kehren Sie zur Startseite zurück und versuchen Sie es erneut.',
    'it':
        'Questo link non può essere aperto in sicurezza. Torna alla Home e riprova.',
    'pt-BR':
        'Não é possível abrir este link com segurança. Volte para o Início e tente novamente.',
    'pt-PT':
        'Não é possível abrir esta ligação em segurança. Volte ao Início e tente novamente.',
    'ur':
        'یہ لنک محفوظ طریقے سے نہیں کھولا جا سکتا۔ ہوم پر واپس جائیں اور دوبارہ کوشش کریں۔',
    'fa':
        'این پیوند را نمی‌توان با اطمینان باز کرد. به صفحه اصلی برگردید و دوباره تلاش کنید.',
    'hi':
        'यह लिंक सुरक्षित रूप से नहीं खोला जा सकता। होम पर वापस जाएँ और फिर से कोशिश करें।',
    'id':
        'Tautan ini tidak dapat dibuka dengan aman. Kembali ke Beranda lalu coba lagi.',
    'ms':
        'Pautan ini tidak dapat dibuka dengan selamat. Kembali ke Laman Utama dan cuba lagi.',
    'ja': 'このリンクは安全に開けません。ホームに戻ってもう一度お試しください。',
    'ko': '이 링크를 안전하게 열 수 없습니다. 홈으로 돌아가 다시 시도하세요.',
    'zh-Hans': '无法安全打开此链接。请返回首页后重试。',
    'zh-Hant': '無法安全開啟此連結。請返回首頁後再試一次。',
    'ru':
        'Эту ссылку нельзя безопасно открыть. Вернитесь на главную и попробуйте снова.',
    'bn': 'এই লিংকটি নিরাপদে খোলা যাচ্ছে না। হোমে ফিরে আবার চেষ্টা করুন।',
    'vi':
        'Không thể mở liên kết này một cách an toàn. Hãy quay về Trang chủ và thử lại.',
    'th':
        'ไม่สามารถเปิดลิงก์นี้ได้อย่างปลอดภัย กลับไปที่หน้าหลักแล้วลองอีกครั้ง',
    'pl':
        'Nie można bezpiecznie otworzyć tego linku. Wróć na stronę główną i spróbuj ponownie.',
    'nl':
        'Deze link kan niet veilig worden geopend. Ga terug naar Home en probeer het opnieuw.',
    'uk':
        'Це посилання неможливо безпечно відкрити. Поверніться на головну й спробуйте ще раз.',
  };

  static String? resolve(String text, String localeTag) {
    if (text != source) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    return tag == null ? null : values[tag];
  }
}
