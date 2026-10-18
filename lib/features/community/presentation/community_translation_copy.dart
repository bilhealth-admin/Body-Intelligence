import 'package:flutter/widgets.dart';

// Each application's language labels its own translation action. The source
// language comes from local detection, never the author's country/profile.
String translationCopy(BuildContext context, int index) {
  final language = Localizations.localeOf(context).languageCode;
  if (index == 5) return 'Google Translate';
  if (index == 7) return cloudTranslationDisclosure(context);
  if (language == 'zh' &&
      Localizations.localeOf(context).scriptCode == 'Hant') {
    return const [
      '查看翻譯',
      '查看原文',
      '正在準備…',
      '取消',
      '翻譯不可用。已保留原文。',
      '機器翻譯 · 在裝置上',
      '翻譯資訊',
      '翻譯可能不準確。請查看原文，不要依賴翻譯做醫療決定。可能需要下載語言模型。文字在此裝置上處理。',
      '已是應用程式語言',
    ][index];
  }
  return (_labels[language] ?? _labels['en']!)[index];
}

const _labels = <String, List<String>>{
  'en': [
    'View translation',
    'View original',
    'Preparing translation…',
    'Cancel',
    'Translation unavailable. Original text retained.',
    'Machine translation · on device',
    'Translation information',
    'Translation can be inaccurate. Consult the original text; do not rely on a translation for medical decisions. Language models may need downloading. Text is processed on this device.',
    'Already in your language',
  ],
  'ar': [
    'عرض الترجمة',
    'عرض الأصل',
    'جارٍ تجهيز الترجمة…',
    'إلغاء',
    'الترجمة غير متاحة. النص الأصلي محفوظ.',
    'ترجمة آلية · على الجهاز',
    'معلومات الترجمة',
    'قد تكون الترجمة غير دقيقة. راجع النص الأصلي ولا تعتمد عليها لاتخاذ قرار طبي. قد يلزم تنزيل نماذج اللغة. يُعالج النص على هذا الجهاز.',
    'النص بلغة تطبيقك بالفعل',
  ],
  'tr': [
    'Çeviriyi görüntüle',
    'Orijinali görüntüle',
    'Çeviri hazırlanıyor…',
    'İptal',
    'Çeviri kullanılamıyor. Orijinal metin korundu.',
    'Makine çevirisi · cihazda',
    'Çeviri bilgisi',
    'Çeviri hatalı olabilir. Orijinal metni kontrol edin; tıbbi kararlar için çeviriye güvenmeyin. Dil modelleri indirilebilir. Metin bu cihazda işlenir.',
    'Metin zaten uygulama dilinde',
  ],
  'fr': [
    'Voir la traduction',
    'Voir l’original',
    'Préparation…',
    'Annuler',
    'Traduction indisponible. Original conservé.',
    'Traduction automatique · sur l’appareil',
    'Informations',
    'La traduction peut être inexacte. Consultez l’original, sans vous fier à la traduction pour une décision médicale. Les modèles peuvent être téléchargés. Le texte est traité sur cet appareil.',
    'Déjà dans votre langue',
  ],
  'es': [
    'Ver traducción',
    'Ver original',
    'Preparando…',
    'Cancelar',
    'Traducción no disponible. Original conservado.',
    'Traducción automática · en el dispositivo',
    'Información',
    'La traducción puede ser inexacta. Consulte el original; no tome decisiones médicas basadas en ella. Puede ser necesario descargar modelos. El texto se procesa en este dispositivo.',
    'Ya está en tu idioma',
  ],
  'de': [
    'Übersetzung anzeigen',
    'Original anzeigen',
    'Wird vorbereitet…',
    'Abbrechen',
    'Übersetzung nicht verfügbar. Original bleibt erhalten.',
    'Maschinelle Übersetzung · auf dem Gerät',
    'Informationen',
    'Übersetzungen können fehlerhaft sein. Prüfen Sie das Original; treffen Sie keine medizinischen Entscheidungen anhand der Übersetzung. Sprachmodelle müssen eventuell heruntergeladen werden. Text wird auf diesem Gerät verarbeitet.',
    'Bereits in Ihrer Sprache',
  ],
  'it': [
    'Mostra traduzione',
    'Mostra originale',
    'Preparazione…',
    'Annulla',
    'Traduzione non disponibile. Originale conservato.',
    'Traduzione automatica · sul dispositivo',
    'Informazioni',
    'La traduzione può essere inesatta. Consulta l’originale; non basare decisioni mediche sulla traduzione. Potrebbe essere necessario scaricare modelli. Il testo è elaborato su questo dispositivo.',
    'Già nella tua lingua',
  ],
  'pt': [
    'Ver tradução',
    'Ver original',
    'Preparando…',
    'Cancelar',
    'Tradução indisponível. Original preservado.',
    'Tradução automática · no dispositivo',
    'Informações',
    'A tradução pode ser imprecisa. Consulte o original; não baseie decisões médicas nela. Pode ser necessário baixar modelos. O texto é processado neste dispositivo.',
    'Já está no seu idioma',
  ],
  'ur': [
    'ترجمہ دیکھیں',
    'اصل دیکھیں',
    'ترجمہ تیار ہو رہا ہے…',
    'منسوخ',
    'ترجمہ دستیاب نہیں۔ اصل متن محفوظ ہے۔',
    'مشینی ترجمہ · آلے پر',
    'ترجمے کی معلومات',
    'ترجمہ غلط ہو سکتا ہے۔ اصل متن دیکھیں؛ طبی فیصلے ترجمے پر نہ کریں۔ زبان کے ماڈلز ڈاؤن لوڈ ہو سکتے ہیں۔ متن اسی آلے پر پروسیس ہوتا ہے۔',
    'متن پہلے ہی آپ کی زبان میں ہے',
  ],
  'fa': [
    'نمایش ترجمه',
    'نمایش اصل',
    'آماده‌سازی ترجمه…',
    'لغو',
    'ترجمه در دسترس نیست. متن اصلی حفظ شد.',
    'ترجمه ماشینی · روی دستگاه',
    'اطلاعات ترجمه',
    'ترجمه ممکن است نادرست باشد. اصل را بررسی کنید؛ تصمیم پزشکی را بر ترجمه بنا نکنید. ممکن است مدل زبان دانلود شود. متن روی این دستگاه پردازش می‌شود.',
    'متن به زبان برنامه است',
  ],
  'hi': [
    'अनुवाद देखें',
    'मूल देखें',
    'तैयार हो रहा है…',
    'रद्द करें',
    'अनुवाद उपलब्ध नहीं। मूल सुरक्षित है।',
    'मशीनी अनुवाद · डिवाइस पर',
    'जानकारी',
    'अनुवाद गलत हो सकता है। मूल देखें; चिकित्सा निर्णय इसके आधार पर न लें। भाषा मॉडल डाउनलोड हो सकते हैं। पाठ इस डिवाइस पर संसाधित होता है।',
    'पहले से आपकी भाषा में',
  ],
  'id': [
    'Lihat terjemahan',
    'Lihat asli',
    'Menyiapkan…',
    'Batal',
    'Terjemahan tidak tersedia. Teks asli disimpan.',
    'Terjemahan mesin · di perangkat',
    'Informasi',
    'Terjemahan bisa keliru. Periksa teks asli; jangan mengandalkannya untuk keputusan medis. Model bahasa mungkin perlu diunduh. Teks diproses di perangkat ini.',
    'Sudah dalam bahasa Anda',
  ],
  'ms': [
    'Lihat terjemahan',
    'Lihat asal',
    'Menyediakan…',
    'Batal',
    'Terjemahan tidak tersedia. Teks asal dikekalkan.',
    'Terjemahan mesin · pada peranti',
    'Maklumat',
    'Terjemahan mungkin tidak tepat. Semak teks asal; jangan bergantung padanya untuk keputusan perubatan. Model bahasa mungkin dimuat turun. Teks diproses pada peranti ini.',
    'Sudah dalam bahasa anda',
  ],
  'ja': [
    '翻訳を表示',
    '原文を表示',
    '準備中…',
    'キャンセル',
    '翻訳できません。原文は保持されています。',
    '機械翻訳 · デバイス上',
    '翻訳について',
    '翻訳は不正確な場合があります。原文を確認し、医療判断を翻訳に頼らないでください。言語モデルのダウンロードが必要な場合があります。文章はこのデバイスで処理されます。',
    'すでにアプリの言語です',
  ],
  'ko': [
    '번역 보기',
    '원문 보기',
    '준비 중…',
    '취소',
    '번역 불가. 원문이 유지됩니다.',
    '기계 번역 · 기기에서',
    '번역 정보',
    '번역이 부정확할 수 있습니다. 원문을 확인하고 의료 판단에 의존하지 마세요. 언어 모델 다운로드가 필요할 수 있습니다. 텍스트는 이 기기에서 처리됩니다.',
    '이미 앱 언어입니다',
  ],
  'zh': [
    '查看翻译',
    '查看原文',
    '正在准备…',
    '取消',
    '翻译不可用。已保留原文。',
    '机器翻译 · 在设备上',
    '翻译信息',
    '翻译可能不准确。请查看原文，不要依赖翻译做医疗决定。可能需要下载语言模型。文本在此设备上处理。',
    '已是应用语言',
  ],
  'ru': [
    'Показать перевод',
    'Показать оригинал',
    'Подготовка…',
    'Отмена',
    'Перевод недоступен. Оригинал сохранён.',
    'Машинный перевод · на устройстве',
    'О переводе',
    'Перевод может быть неточным. Проверяйте оригинал; не принимайте медицинские решения по переводу. Может потребоваться загрузка моделей. Текст обрабатывается на этом устройстве.',
    'Уже на вашем языке',
  ],
  'bn': [
    'অনুবাদ দেখুন',
    'মূল দেখুন',
    'প্রস্তুত হচ্ছে…',
    'বাতিল',
    'অনুবাদ নেই। মূল পাঠ রাখা হয়েছে।',
    'যান্ত্রিক অনুবাদ · ডিভাইসে',
    'তথ্য',
    'অনুবাদ ভুল হতে পারে। মূল পাঠ দেখুন; চিকিৎসার সিদ্ধান্তে এর উপর নির্ভর করবেন না। ভাষার মডেল ডাউনলোড লাগতে পারে। পাঠ এই ডিভাইসে প্রক্রিয়াকৃত হয়।',
    'ইতিমধ্যে আপনার ভাষায়',
  ],
  'vi': [
    'Xem bản dịch',
    'Xem bản gốc',
    'Đang chuẩn bị…',
    'Hủy',
    'Không thể dịch. Giữ nguyên bản gốc.',
    'Dịch máy · trên thiết bị',
    'Thông tin',
    'Bản dịch có thể sai. Xem bản gốc; không dựa vào bản dịch để quyết định y tế. Có thể cần tải mô hình. Văn bản được xử lý trên thiết bị này.',
    'Đã ở ngôn ngữ ứng dụng',
  ],
  'th': [
    'ดูคำแปล',
    'ดูต้นฉบับ',
    'กำลังเตรียม…',
    'ยกเลิก',
    'แปลไม่ได้ เก็บต้นฉบับไว้แล้ว',
    'แปลโดยเครื่อง · บนอุปกรณ์',
    'ข้อมูล',
    'คำแปลอาจไม่ถูกต้อง โปรดดูต้นฉบับและอย่าใช้ตัดสินใจทางการแพทย์ อาจต้องดาวน์โหลดโมเดลภาษา ข้อความประมวลผลบนอุปกรณ์นี้',
    'เป็นภาษาของแอปแล้ว',
  ],
  'pl': [
    'Pokaż tłumaczenie',
    'Pokaż oryginał',
    'Przygotowanie…',
    'Anuluj',
    'Tłumaczenie niedostępne. Oryginał zachowany.',
    'Tłumaczenie maszynowe · na urządzeniu',
    'Informacje',
    'Tłumaczenie może być błędne. Sprawdź oryginał; nie opieraj decyzji medycznych na tłumaczeniu. Może być konieczne pobranie modeli. Tekst jest przetwarzany na tym urządzeniu.',
    'Już w języku aplikacji',
  ],
  'nl': [
    'Vertaling bekijken',
    'Origineel bekijken',
    'Voorbereiden…',
    'Annuleren',
    'Vertaling niet beschikbaar. Origineel behouden.',
    'Machinevertaling · op het apparaat',
    'Informatie',
    'Vertalingen kunnen onjuist zijn. Bekijk het origineel; baseer medische beslissingen niet op de vertaling. Modellen moeten mogelijk worden gedownload. Tekst wordt op dit apparaat verwerkt.',
    'Al in uw taal',
  ],
  'uk': [
    'Переглянути переклад',
    'Переглянути оригінал',
    'Підготовка…',
    'Скасувати',
    'Переклад недоступний. Оригінал збережено.',
    'Машинний переклад · на пристрої',
    'Інформація',
    'Переклад може бути неточним. Перевірте оригінал; не приймайте медичних рішень за перекладом. Може знадобитися завантаження моделей. Текст обробляється на цьому пристрої.',
    'Вже мовою застосунку',
  ],
};

String googleTranslationAction(BuildContext context) =>
    (_googleActions[Localizations.localeOf(context).languageCode] ??
    'Translate with Google');
const _googleActions = {
  'en': 'Translate with Google',
  'ar': 'ترجمة باستخدام Google',
  'tr': 'Google ile çevir',
  'fr': 'Traduire avec Google',
  'es': 'Traducir con Google',
  'de': 'Mit Google übersetzen',
  'it': 'Traduci con Google',
  'pt': 'Traduzir com o Google',
  'ur': 'Google سے ترجمہ کریں',
  'fa': 'ترجمه با Google',
  'hi': 'Google से अनुवाद करें',
  'id': 'Terjemahkan dengan Google',
  'ms': 'Terjemah dengan Google',
  'ja': 'Google で翻訳',
  'ko': 'Google로 번역',
  'zh': 'Google 翻譯',
  'ru': 'Перевести с Google',
  'bn': 'Google দিয়ে অনুবাদ',
  'vi': 'Dịch bằng Google',
  'th': 'แปลด้วย Google',
  'pl': 'Przetłumacz z Google',
  'nl': 'Vertalen met Google',
  'uk': 'Перекласти з Google',
};

// Shown before the explicit action, including on iOS: no device model download.
String cloudTranslationDisclosure(BuildContext context) =>
    _cloudDisclosure[Localizations.localeOf(context).languageCode] ??
    _cloudDisclosure['en']!;
const _cloudDisclosure = {
  'en':
      'Tapping translate sends only this text to BIL and Google Cloud Translation. Check the original for accuracy.',
  'ar':
      'عند الضغط على الترجمة يُرسل هذا النص فقط إلى BIL وترجمة Google السحابية. راجع الأصل للتأكد من الدقة.',
  'fr':
      'Traduire envoie uniquement ce texte à BIL et Google Cloud Translation. Vérifiez le texte original.',
  'es':
      'Al traducir, solo se envía este texto a BIL y Google Cloud Translation. Compruebe el original.',
  'tr':
      'Çevir düğmesi yalnızca bu metni BIL ve Google Cloud Translation’a gönderir. Asıl metni kontrol edin.',
  'de':
      'Beim Übersetzen wird nur dieser Text an BIL und Google Cloud Translation gesendet. Prüfen Sie das Original.',
  'it':
      'Traduci invia solo questo testo a BIL e Google Cloud Translation. Controlla il testo originale.',
  'pt':
      'Ao traduzir, apenas este texto é enviado ao BIL e ao Google Cloud Translation. Confira o original.',
  'ur':
      'ترجمہ دبانے پر صرف یہ متن BIL اور Google Cloud Translation کو بھیجا جاتا ہے۔ اصل متن چیک کریں۔',
  'fa':
      'با زدن ترجمه، فقط این متن به BIL و Google Cloud Translation فرستاده می‌شود. متن اصلی را بررسی کنید.',
  'hi':
      'अनुवाद दबाने पर केवल यह पाठ BIL और Google Cloud Translation को भेजा जाता है। मूल पाठ जाँचें।',
  'id':
      'Mengetuk terjemahkan hanya mengirim teks ini ke BIL dan Google Cloud Translation. Periksa teks asli.',
  'ms':
      'Menekan terjemah menghantar teks ini sahaja kepada BIL dan Google Cloud Translation. Semak teks asal.',
  'ja': '翻訳を押すと、このテキストのみがBILとGoogle Cloud Translationに送信されます。原文を確認してください。',
  'ko': '번역을 누르면 이 텍스트만 BIL 및 Google Cloud Translation으로 전송됩니다. 원문을 확인하세요.',
  'zh': '点击翻译仅将此文本发送给 BIL 和 Google Cloud Translation。请核对原文。',
  'ru':
      'При переводе только этот текст отправляется в BIL и Google Cloud Translation. Проверьте оригинал.',
  'bn':
      'অনুবাদ চাপলে শুধু এই লেখাটি BIL ও Google Cloud Translation-এ পাঠানো হয়। মূল লেখা যাচাই করুন।',
  'vi':
      'Nhấn dịch chỉ gửi văn bản này đến BIL và Google Cloud Translation. Hãy kiểm tra bản gốc.',
  'th':
      'เมื่อกดแปล ระบบส่งเฉพาะข้อความนี้ไปยัง BIL และ Google Cloud Translation โปรดตรวจสอบต้นฉบับ',
  'pl':
      'Tłumaczenie wysyła tylko ten tekst do BIL i Google Cloud Translation. Sprawdź oryginał.',
  'nl':
      'Bij vertalen wordt alleen deze tekst naar BIL en Google Cloud Translation gestuurd. Controleer het origineel.',
  'uk':
      'Під час перекладу лише цей текст надсилається до BIL і Google Cloud Translation. Перевірте оригінал.',
};
