import 'package:flutter/material.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_voice_status.dart';

/// An authorized cached page stays visible when its independent refresh fails.
class CommunityFeedRefreshNotice extends StatelessWidget {
  const CommunityFeedRefreshNotice({super.key, required this.onRetry});
  final VoidCallback onRetry;
  static const messages = <String, String>{
    'en': 'Refresh failed. Showing the last authorized posts.',
    'ar': 'تعذّر التحديث. تُعرض آخر منشورات مسموح بها.',
    'fr':
        'Échec de l’actualisation. Les dernières publications autorisées restent affichées.',
    'es':
        'Error al actualizar. Se muestran las últimas publicaciones autorizadas.',
    'tr': 'Yenileme başarısız. Son izin verilen gönderiler gösteriliyor.',
    'de':
        'Aktualisierung fehlgeschlagen. Die letzten freigegebenen Beiträge bleiben sichtbar.',
    'it':
        'Aggiornamento non riuscito. Sono visibili gli ultimi post autorizzati.',
    'pt-BR':
        'Falha na atualização. Exibindo as últimas publicações autorizadas.',
    'pt-PT':
        'Falha na atualização. São apresentadas as últimas publicações autorizadas.',
    'ur': 'تازہ کاری ناکام ہوئی۔ آخری مجاز پوسٹس دکھائی جا رہی ہیں۔',
    'fa': 'به‌روزرسانی ناموفق بود. آخرین پست‌های مجاز نمایش داده می‌شوند.',
    'hi': 'रिफ़्रेश विफल हुआ। अंतिम अधिकृत पोस्ट दिखाई जा रही हैं।',
    'id': 'Pembaruan gagal. Menampilkan postingan terakhir yang diizinkan.',
    'ms': 'Penyegaran gagal. Memaparkan siaran terakhir yang dibenarkan.',
    'ja': '更新に失敗しました。最後に閲覧が許可された投稿を表示しています。',
    'ko': '새로고침에 실패했습니다. 마지막으로 허용된 게시물을 표시합니다.',
    'zh-Hans': '刷新失败。显示最近获准访问的帖子。',
    'zh-Hant': '重新整理失敗。顯示最近獲准存取的貼文。',
    'ru': 'Не удалось обновить. Показаны последние разрешённые публикации.',
    'bn': 'রিফ্রেশ ব্যর্থ হয়েছে। সর্বশেষ অনুমোদিত পোস্ট দেখানো হচ্ছে।',
    'vi': 'Làm mới thất bại. Đang hiển thị các bài đăng được phép gần nhất.',
    'th': 'รีเฟรชไม่สำเร็จ กำลังแสดงโพสต์ล่าสุดที่ได้รับอนุญาต',
    'pl': 'Odświeżanie nie powiodło się. Widoczne są ostatnie dozwolone posty.',
    'nl':
        'Vernieuwen mislukt. De laatst toegestane berichten blijven zichtbaar.',
    'uk': 'Не вдалося оновити. Показано останні дозволені дописи.',
  };
  @override
  Widget build(BuildContext context) {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          key: const Key('community-feed-cache-refresh-error'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline_rounded, size: 20),
          title: Text(messages[locale] ?? messages['en']!),
          trailing: IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: VoiceStatusRuntimeCopy.resolve(
              VoiceStatusCopyKey.retry,
              locale,
            ),
          ),
        ),
      ),
    );
  }
}
