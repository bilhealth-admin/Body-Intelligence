import 'bil_locale_policy.dart';

/// Stable status copy for in-flight publishing and cached Coach settings.
/// The state may be restored offline; never substitute English in a
/// production locale while verified user data remains visible.
abstract final class QualityFeedbackRuntimeCopy {
  static const publishing = 'Publishing…';
  static const refreshFailure =
      'Refresh failed. Showing last verified settings.';

  static const sources = <String>[publishing, refreshFailure];

  static const translations = <String, (String, String)>{
    'en': ('Publishing…', 'Refresh failed. Showing last verified settings.'),
    'ar': ('جارٍ النشر…', 'فشل التحديث. تُعرض آخر إعدادات تم التحقق منها.'),
    'fr': (
      'Publication en cours…',
      'Échec de l’actualisation. Derniers réglages vérifiés affichés.',
    ),
    'es': (
      'Publicando…',
      'Error al actualizar. Se muestran los últimos ajustes verificados.',
    ),
    'tr': (
      'Yayınlanıyor…',
      'Yenileme başarısız. Son doğrulanan ayarlar gösteriliyor.',
    ),
    'de': (
      'Wird veröffentlicht…',
      'Aktualisierung fehlgeschlagen. Letzte bestätigte Einstellungen angezeigt.',
    ),
    'it': (
      'Pubblicazione in corso…',
      'Aggiornamento non riuscito. Visualizzate le ultime impostazioni verificate.',
    ),
    'pt-BR': (
      'Publicando…',
      'Falha ao atualizar. Exibindo as últimas configurações verificadas.',
    ),
    'pt-PT': (
      'A publicar…',
      'Falha ao atualizar. A mostrar as últimas definições verificadas.',
    ),
    'ur': (
      'شائع کیا جا رہا ہے…',
      'تازہ کاری ناکام رہی۔ آخری تصدیق شدہ ترتیبات دکھائی جا رہی ہیں۔',
    ),
    'fa': (
      'در حال انتشار…',
      'به‌روزرسانی ناموفق بود. آخرین تنظیمات تأییدشده نمایش داده می‌شود.',
    ),
    'hi': (
      'प्रकाशित हो रहा है…',
      'रीफ़्रेश विफल रहा। अंतिम सत्यापित सेटिंग दिखाई जा रही हैं।',
    ),
    'id': (
      'Menerbitkan…',
      'Penyegaran gagal. Pengaturan terakhir yang terverifikasi ditampilkan.',
    ),
    'ms': (
      'Sedang menerbitkan…',
      'Muat semula gagal. Tetapan terakhir yang disahkan dipaparkan.',
    ),
    'ja': ('投稿しています…', '更新できませんでした。最後に確認された設定を表示しています。'),
    'ko': ('게시 중…', '새로 고침에 실패했습니다. 마지막으로 확인된 설정을 표시합니다.'),
    'zh-Hans': ('正在发布…', '刷新失败。正在显示最近一次验证的设置。'),
    'zh-Hant': ('正在發布…', '重新整理失敗。顯示上次驗證的設定。'),
    'ru': (
      'Публикация…',
      'Не удалось обновить. Показаны последние проверенные настройки.',
    ),
    'bn': (
      'প্রকাশ করা হচ্ছে…',
      'রিফ্রেশ ব্যর্থ হয়েছে। সর্বশেষ যাচাইকৃত সেটিংস দেখানো হচ্ছে।',
    ),
    'vi': (
      'Đang đăng…',
      'Làm mới thất bại. Đang hiển thị cài đặt đã xác minh gần nhất.',
    ),
    'th': (
      'กำลังเผยแพร่…',
      'รีเฟรชไม่สำเร็จ กำลังแสดงการตั้งค่าที่ตรวจสอบล่าสุด',
    ),
    'pl': (
      'Publikowanie…',
      'Nie udało się odświeżyć. Pokazano ostatnio zweryfikowane ustawienia.',
    ),
    'nl': (
      'Publiceren…',
      'Vernieuwen mislukt. De laatst bevestigde instellingen worden getoond.',
    ),
    'uk': (
      'Публікація…',
      'Не вдалося оновити. Показано останні підтверджені налаштування.',
    ),
  };

  static String? resolve(String english, String localeTag) {
    if (!sources.contains(english)) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    final pair = translations[tag];
    if (pair == null) return null;
    return english == publishing ? pair.$1 : pair.$2;
  }

  static bool get balanced {
    final required = BilLocalePolicy.productionTags.toSet();
    return translations.keys.toSet().containsAll(required) &&
        required.containsAll(translations.keys) &&
        translations.values.every(
          (pair) => pair.$1.trim().isNotEmpty && pair.$2.trim().isNotEmpty,
        );
  }
}
