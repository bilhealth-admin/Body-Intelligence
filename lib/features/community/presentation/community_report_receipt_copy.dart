import '../../../app/localization/bil_locale_policy.dart';

abstract final class CommunityReportReceiptCopy {
  static const alreadyReported =
      'You already reported this item. Your new note was not added.';

  static const values = <String, String>{
    'en': alreadyReported,
    'ar': 'سبق أن أبلغت عن هذا العنصر. لم تُضف ملاحظتك الجديدة.',
    'fr':
        'Vous avez déjà signalé cet élément. Votre nouvelle note n’a pas été ajoutée.',
    'es': 'Ya denunciaste este elemento. Tu nueva nota no se añadió.',
    'tr': 'Bu öğeyi zaten bildirdiniz. Yeni notunuz eklenmedi.',
    'de':
        'Du hast diesen Inhalt bereits gemeldet. Deine neue Notiz wurde nicht hinzugefügt.',
    'it':
        'Hai già segnalato questo elemento. La nuova nota non è stata aggiunta.',
    'pt-BR':
        'Você já denunciou este item. Sua nova observação não foi adicionada.',
    'pt-PT': 'Já denunciou este item. A sua nova nota não foi adicionada.',
    'ur':
        'آپ اس آئٹم کی پہلے ہی رپورٹ کر چکے ہیں۔ آپ کا نیا نوٹ شامل نہیں ہوا۔',
    'fa': 'قبلاً این مورد را گزارش کرده‌اید. یادداشت جدید شما اضافه نشد.',
    'hi':
        'आप इस आइटम की रिपोर्ट पहले ही कर चुके हैं। आपका नया नोट नहीं जोड़ा गया।',
    'id':
        'Anda sudah melaporkan item ini. Catatan baru Anda tidak ditambahkan.',
    'ms': 'Anda sudah melaporkan item ini. Nota baharu anda tidak ditambahkan.',
    'ja': 'この項目はすでに報告済みです。新しいメモは追加されませんでした。',
    'ko': '이미 신고한 항목입니다. 새 메모는 추가되지 않았습니다.',
    'zh-Hans': '你已举报此内容。新备注未添加。',
    'zh-Hant': '你已檢舉此內容。新備註未新增。',
    'ru': 'Вы уже пожаловались на этот элемент. Новое примечание не добавлено.',
    'bn':
        'আপনি ইতিমধ্যে এই আইটেমটি রিপোর্ট করেছেন। আপনার নতুন নোট যোগ করা হয়নি।',
    'vi': 'Bạn đã báo cáo mục này. Ghi chú mới của bạn chưa được thêm.',
    'th': 'คุณรายงานรายการนี้แล้ว ระบบไม่ได้เพิ่มหมายเหตุใหม่ของคุณ',
    'pl':
        'Ten element został już przez Ciebie zgłoszony. Nowa notatka nie została dodana.',
    'nl': 'Je hebt dit item al gemeld. Je nieuwe notitie is niet toegevoegd.',
    'uk': 'Ви вже поскаржилися на цей елемент. Нову примітку не додано.',
  };

  static String? resolve(String source, String localeTag) {
    if (source != alreadyReported) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    return tag == null ? null : values[tag];
  }
}
