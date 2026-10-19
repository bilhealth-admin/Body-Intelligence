import 'package:flutter/widgets.dart';

/// The remote fallback sends a search phrase, never the whole private diary.
String foodSearchPrivacyDisclosure(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final key = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
      ? 'zh-Hant'
      : locale.languageCode;
  return _copy[key] ?? _copy['en']!;
}

const _copy = <String, String>{
  'en':
      'For online food search, BIL sends the search phrase and language through its authenticated service to USDA. Google Cloud Translation may translate the phrase and food names. This does not automatically include your private diary or AI Coach conversations.',
  'ar':
      'للبحث عن الطعام عبر الإنترنت، يرسل BIL عبارة البحث واللغة عبر خدمته الموثقة إلى USDA. قد تترجم Google Cloud Translation العبارة وأسماء الأطعمة. لا تُضمّن يومياتك الخاصة أو محادثات المدرب الذكي تلقائيًا.',
  'fr':
      'Pour rechercher des aliments en ligne, BIL transmet la recherche et la langue à USDA via son service authentifié. Google Cloud Translation peut traduire la recherche et les noms des aliments. Votre journal privé et vos conversations avec le coach IA ne sont pas inclus automatiquement.',
  'es':
      'Para buscar alimentos en línea, BIL envía la consulta y el idioma a USDA mediante su servicio autenticado. Google Cloud Translation puede traducir la consulta y los nombres de alimentos. Tu diario privado y tus conversaciones con el entrenador IA no se incluyen automáticamente.',
  'tr':
      'Çevrimiçi yiyecek aramasında BIL, arama ifadesini ve dili kimliği doğrulanmış hizmeti üzerinden USDA’ya gönderir. Google Cloud Translation ifadeyi ve yiyecek adlarını çevirebilir. Özel günlüğünüz ve yapay zekâ koçu konuşmalarınız otomatik olarak eklenmez.',
  'de':
      'Bei der Online-Lebensmittelsuche sendet BIL Suchtext und Sprache über seinen authentifizierten Dienst an USDA. Google Cloud Translation kann Suchtext und Lebensmittelnamen übersetzen. Ihr privates Tagebuch und Ihre KI-Coach-Gespräche werden nicht automatisch einbezogen.',
  'it':
      'Per cercare alimenti online, BIL invia la ricerca e la lingua a USDA tramite il proprio servizio autenticato. Google Cloud Translation può tradurre la ricerca e i nomi degli alimenti. Il diario privato e le conversazioni con il coach IA non vengono inclusi automaticamente.',
  'pt':
      'Na pesquisa de alimentos online, o BIL envia a pesquisa e o idioma ao USDA através do seu serviço autenticado. O Google Cloud Translation pode traduzir a pesquisa e os nomes dos alimentos. O diário privado e as conversas com o treinador de IA não são incluídos automaticamente.',
  'ur':
      'آن لائن کھانا تلاش کرتے وقت BIL تلاش کی عبارت اور زبان اپنی تصدیق شدہ سروس کے ذریعے USDA کو بھیجتا ہے۔ Google Cloud Translation عبارت اور کھانوں کے نام ترجمہ کر سکتا ہے۔ آپ کی نجی ڈائری یا AI کوچ کی گفتگو خود بخود شامل نہیں ہوتی۔',
  'fa':
      'برای جستجوی آنلاین غذا، BIL عبارت جستجو و زبان را از طریق سرویس احراز هویت‌شده خود به USDA می‌فرستد. Google Cloud Translation ممکن است عبارت و نام غذاها را ترجمه کند. دفتر خصوصی و گفتگوهای مربی هوش مصنوعی شما خودکار ارسال نمی‌شوند.',
  'hi':
      'ऑनलाइन भोजन खोज के लिए BIL अपने प्रमाणित सेवा मार्ग से खोज वाक्यांश और भाषा USDA को भेजता है। Google Cloud Translation वाक्यांश और भोजन के नामों का अनुवाद कर सकता है। आपकी निजी डायरी या AI कोच की बातचीत अपने आप शामिल नहीं होती।',
  'id':
      'Untuk pencarian makanan daring, BIL mengirim frasa pencarian dan bahasa ke USDA melalui layanan terautentikasi. Google Cloud Translation dapat menerjemahkan frasa dan nama makanan. Jurnal pribadi dan percakapan pelatih AI tidak disertakan otomatis.',
  'ms':
      'Untuk carian makanan dalam talian, BIL menghantar frasa carian dan bahasa kepada USDA melalui perkhidmatan yang disahkan. Google Cloud Translation boleh menterjemah frasa dan nama makanan. Diari peribadi dan perbualan jurulatih AI tidak disertakan secara automatik.',
  'ja':
      'オンラインの食品検索では、BILは認証されたサービスを通じて検索語と使用言語をUSDAへ送信します。Google Cloud Translationで検索語や食品名を翻訳する場合があります。非公開の日記やAIコーチとの会話は自動的には含まれません。',
  'ko':
      '온라인 식품 검색 시 BIL은 인증된 서비스를 통해 검색어와 언어를 USDA에 전송합니다. Google Cloud Translation이 검색어와 식품명을 번역할 수 있습니다. 비공개 일지나 AI 코치 대화는 자동으로 포함되지 않습니다.',
  'zh':
      '在线搜索食物时，BIL通过其认证服务向USDA发送搜索词和语言。Google Cloud Translation可能会翻译搜索词和食物名称。不会自动包含您的私人日记或AI教练对话。',
  'zh-Hant':
      '線上搜尋食物時，BIL透過其驗證服務向USDA傳送搜尋詞和語言。Google Cloud Translation可能會翻譯搜尋詞和食物名稱。不會自動包含您的私人日記或AI教練對話。',
  'ru':
      'Для поиска продуктов в интернете BIL отправляет запрос и язык в USDA через свой аутентифицированный сервис. Google Cloud Translation может переводить запрос и названия продуктов. Личный дневник и беседы с ИИ-тренером автоматически не включаются.',
  'bn':
      'অনলাইনে খাবার খোঁজার জন্য BIL তার যাচাইকৃত পরিষেবার মাধ্যমে খোঁজার বাক্য ও ভাষা USDA-তে পাঠায়। Google Cloud Translation বাক্য ও খাবারের নাম অনুবাদ করতে পারে। আপনার ব্যক্তিগত ডায়েরি বা AI কোচের কথোপকথন স্বয়ংক্রিয়ভাবে অন্তর্ভুক্ত হয় না।',
  'vi':
      'Để tìm thực phẩm trực tuyến, BIL gửi cụm từ tìm kiếm và ngôn ngữ đến USDA qua dịch vụ đã xác thực. Google Cloud Translation có thể dịch cụm từ và tên thực phẩm. Nhật ký riêng tư và cuộc trò chuyện với huấn luyện viên AI không tự động được gửi kèm.',
  'th':
      'เมื่อค้นหาอาหารออนไลน์ BIL จะส่งคำค้นและภาษาไปยัง USDA ผ่านบริการที่ยืนยันตัวตนแล้ว Google Cloud Translation อาจแปลคำค้นและชื่ออาหาร โดยไม่รวมบันทึกส่วนตัวหรือบทสนทนากับโค้ช AI โดยอัตโนมัติ',
  'pl':
      'Podczas wyszukiwania żywności online BIL wysyła zapytanie i język do USDA przez uwierzytelnioną usługę. Google Cloud Translation może tłumaczyć zapytanie i nazwy żywności. Prywatny dziennik i rozmowy z trenerem AI nie są dołączane automatycznie.',
  'nl':
      'Bij online zoeken naar voeding stuurt BIL de zoekterm en taal via zijn geauthenticeerde dienst naar USDA. Google Cloud Translation kan de zoekterm en voedingsnamen vertalen. Uw privédagboek en gesprekken met de AI-coach worden niet automatisch meegestuurd.',
  'uk':
      'Для пошуку їжі онлайн BIL надсилає запит і мову до USDA через автентифікований сервіс. Google Cloud Translation може перекладати запит і назви продуктів. Приватний щоденник і розмови з ШІ-тренером автоматично не додаються.',
};
