import '../../../app/localization/bil_locale_policy.dart';

abstract final class CommunityChatGuardCopy {
  static const sources = <String>[
    'Keep the message within 2000 characters. Your text is kept.',
    'Load older messages',
    'Keep the subject within 120 characters. Your text is kept.',
  ];
  static const values = <String, List<String>>{
    'en': [
      'Keep the message within 2000 characters. Your text is kept.',
      'Load older messages',
      'Keep the subject within 120 characters. Your text is kept.',
    ],
    'ar': [
      'اجعل الرسالة في حدود 2000 حرف. احتفظنا بالنص كاملًا.',
      'تحميل الرسائل الأقدم',
      'اجعل العنوان في حدود 120 حرفًا. احتفظنا بالنص كاملًا.',
    ],
    'fr': [
      'Limitez le message à 2000 caractères. Votre texte est conservé.',
      'Charger les messages précédents',
      'Limitez l’objet à 120 caractères. Votre texte est conservé.',
    ],
    'es': [
      'Limita el mensaje a 2000 caracteres. Conservamos tu texto.',
      'Cargar mensajes anteriores',
      'Limita el asunto a 120 caracteres. Conservamos tu texto.',
    ],
    'tr': [
      'Mesajı 2000 karakterle sınırlayın. Metniniz korunuyor.',
      'Eski mesajları yükle',
      'Konuyu 120 karakterle sınırlayın. Metniniz korunuyor.',
    ],
    'de': [
      'Begrenze die Nachricht auf 2000 Zeichen. Dein Text bleibt erhalten.',
      'Ältere Nachrichten laden',
      'Begrenze den Betreff auf 120 Zeichen. Dein Text bleibt erhalten.',
    ],
    'it': [
      'Limita il messaggio a 2000 caratteri. Il testo viene conservato.',
      'Carica messaggi precedenti',
      'Limita l’oggetto a 120 caratteri. Il testo viene conservato.',
    ],
    'pt-BR': [
      'Limite a mensagem a 2000 caracteres. Seu texto foi mantido.',
      'Carregar mensagens anteriores',
      'Limite o assunto a 120 caracteres. Seu texto foi mantido.',
    ],
    'pt-PT': [
      'Limite a mensagem a 2000 caracteres. O seu texto foi mantido.',
      'Carregar mensagens anteriores',
      'Limite o assunto a 120 caracteres. O seu texto foi mantido.',
    ],
    'ur': [
      'پیغام کو 2000 حروف تک محدود رکھیں۔ آپ کا متن محفوظ ہے۔',
      'پرانے پیغامات لوڈ کریں',
      'عنوان کو 120 حروف تک محدود رکھیں۔ آپ کا متن محفوظ ہے۔',
    ],
    'fa': [
      'پیام را به 2000 نویسه محدود کنید. متن شما حفظ شده است.',
      'بارگیری پیام‌های قدیمی‌تر',
      'موضوع را به 120 نویسه محدود کنید. متن شما حفظ شده است.',
    ],
    'hi': [
      'संदेश को 2000 अक्षरों तक रखें। आपका पाठ सुरक्षित है।',
      'पुराने संदेश लोड करें',
      'विषय को 120 अक्षरों तक रखें। आपका पाठ सुरक्षित है।',
    ],
    'id': [
      'Batasi pesan hingga 2000 karakter. Teks Anda tetap tersimpan.',
      'Muat pesan lebih lama',
      'Batasi subjek hingga 120 karakter. Teks Anda tetap tersimpan.',
    ],
    'ms': [
      'Hadkan mesej kepada 2000 aksara. Teks anda masih disimpan.',
      'Muatkan mesej lama',
      'Hadkan subjek kepada 120 aksara. Teks anda masih disimpan.',
    ],
    'ja': [
      'メッセージは2000文字以内にしてください。入力した文章は保持されています。',
      '以前のメッセージを読み込む',
      '件名は120文字以内にしてください。入力した文章は保持されています。',
    ],
    'ko': [
      '메시지를 2000자 이내로 줄여 주세요. 입력한 내용은 보관됩니다.',
      '이전 메시지 불러오기',
      '제목을 120자 이내로 줄여 주세요. 입력한 내용은 보관됩니다.',
    ],
    'zh-Hans': [
      '请将消息控制在2000个字符以内。您输入的文字已保留。',
      '加载更早的消息',
      '请将主题控制在120个字符以内。您输入的文字已保留。',
    ],
    'zh-Hant': [
      '請將訊息控制在2000個字元以內。您輸入的文字已保留。',
      '載入較早的訊息',
      '請將主旨控制在120個字元以內。您輸入的文字已保留。',
    ],
    'ru': [
      'Сократите сообщение до 2000 символов. Ваш текст сохранён.',
      'Загрузить более ранние сообщения',
      'Сократите тему до 120 символов. Ваш текст сохранён.',
    ],
    'bn': [
      'বার্তাটি 2000 অক্ষরের মধ্যে রাখুন। আপনার লেখা সংরক্ষিত আছে।',
      'পুরোনো বার্তা লোড করুন',
      'বিষয়টি 120 অক্ষরের মধ্যে রাখুন। আপনার লেখা সংরক্ষিত আছে।',
    ],
    'vi': [
      'Giới hạn tin nhắn trong 2000 ký tự. Văn bản của bạn được giữ lại.',
      'Tải tin nhắn cũ hơn',
      'Giới hạn tiêu đề trong 120 ký tự. Văn bản của bạn được giữ lại.',
    ],
    'th': [
      'จำกัดข้อความไม่เกิน 2000 อักขระ ข้อความที่พิมพ์ไว้ยังคงอยู่',
      'โหลดข้อความเก่า',
      'จำกัดหัวข้อไม่เกิน 120 อักขระ ข้อความที่พิมพ์ไว้ยังคงอยู่',
    ],
    'pl': [
      'Skróć wiadomość do 2000 znaków. Twój tekst został zachowany.',
      'Wczytaj starsze wiadomości',
      'Skróć temat do 120 znaków. Twój tekst został zachowany.',
    ],
    'nl': [
      'Beperk het bericht tot 2000 tekens. Je tekst is bewaard.',
      'Oudere berichten laden',
      'Beperk het onderwerp tot 120 tekens. Je tekst is bewaard.',
    ],
    'uk': [
      'Скоротіть повідомлення до 2000 символів. Ваш текст збережено.',
      'Завантажити давніші повідомлення',
      'Скоротіть тему до 120 символів. Ваш текст збережено.',
    ],
  };
  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    return tag == null ? null : values[tag]?[index];
  }
}
