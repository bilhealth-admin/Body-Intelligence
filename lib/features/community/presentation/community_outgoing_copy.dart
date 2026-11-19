import 'package:flutter/widgets.dart';

import '../../../app/localization/bil_locale_policy.dart';

abstract final class CommunityOutgoingCopy {
  static const sentLabels = <String, String>{
    'en': 'Sent',
    'ar': 'المرسلة',
    'fr': 'Envoyées',
    'es': 'Enviadas',
    'tr': 'Gönderilenler',
    'de': 'Gesendet',
    'it': 'Inviate',
    'pt-BR': 'Enviadas',
    'pt-PT': 'Enviados',
    'ur': 'بھیجی گئی',
    'fa': 'ارسال‌شده',
    'hi': 'भेजे गए',
    'id': 'Terkirim',
    'ms': 'Dihantar',
    'ja': '送信済み',
    'ko': '보낸 요청',
    'zh-Hans': '已发送',
    'zh-Hant': '已傳送',
    'ru': 'Отправленные',
    'bn': 'পাঠানো',
    'vi': 'Đã gửi',
    'th': 'ส่งแล้ว',
    'pl': 'Wysłane',
    'nl': 'Verzonden',
    'uk': 'Надіслані',
  };

  static String sent(BuildContext context) =>
      sentLabels[BilLocalePolicy.canonicalTag(
        Localizations.localeOf(context),
      )] ??
      sentLabels['en']!;
}
