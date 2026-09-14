part of '../food_page.dart';

String _foodSearchText(BuildContext context, String english) {
  final locale = Localizations.localeOf(context);
  return FoodSearchRuntimeCopy.resolve(english, locale.toLanguageTag()) ??
      FoodSearchRuntimeCopy.resolve(english, locale.languageCode) ??
      context.strings.text(english);
}

/// Small, reviewed UI-only vocabulary for the food-search surface.
///
/// Food identity remains source-authoritative; these strings localize search
/// affordances and empty-state guidance only. Keeping the 25-locale matrix
/// explicit prevents a supported locale from silently falling back to English.
abstract final class FoodSearchRuntimeCopy {
  static const supported = <String>{
    'en',
    'ar',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };

  static const sources = <String>[
    'English, Arabic, keyword, or barcode',
    'No local food matches this search',
    'BIL will not invent a match. Create a custom food from verified label evidence.',
  ];

  static const rows = <String, List<String>>{
    'en': <String>[
      'English, Arabic, keyword, or barcode',
      'No local food matches this search',
      'BIL will not invent a match. Create a custom food from verified label evidence.',
    ],
    'ar': <String>[
      'الإنجليزية أو العربية أو كلمة مفتاحية أو باركود',
      'لا يوجد طعام محلي يطابق هذا البحث',
      'لن يخترع BIL تطابقًا. أنشئ طعامًا مخصصًا من بيانات ملصق موثوقة.',
    ],
    'fr': <String>[
      'Anglais, arabe, mot-clé ou code-barres',
      'Aucun aliment local ne correspond à cette recherche',
      'BIL n’inventera pas de correspondance. Créez un aliment personnalisé à partir d’une étiquette vérifiée.',
    ],
    'es': <String>[
      'Inglés, árabe, palabra clave o código de barras',
      'Ningún alimento local coincide con esta búsqueda',
      'BIL no inventará una coincidencia. Crea un alimento personalizado a partir de una etiqueta verificada.',
    ],
    'tr': <String>[
      'İngilizce, Arapça, anahtar kelime veya barkod',
      'Bu aramayla eşleşen yerel yiyecek yok',
      'BIL eşleşme uydurmaz. Doğrulanmış etiket bilgileriyle özel bir yiyecek oluşturun.',
    ],
    'de': <String>[
      'Englisch, Arabisch, Stichwort oder Barcode',
      'Keine lokalen Lebensmittel entsprechen dieser Suche',
      'BIL erfindet keine Übereinstimmung. Erstelle ein eigenes Lebensmittel anhand verifizierter Etikettangaben.',
    ],
    'it': <String>[
      'Inglese, arabo, parola chiave o codice a barre',
      'Nessun alimento locale corrisponde a questa ricerca',
      'BIL non inventerà una corrispondenza. Crea un alimento personalizzato da dati verificati dell’etichetta.',
    ],
    'pt-BR': <String>[
      'Inglês, árabe, palavra-chave ou código de barras',
      'Nenhum alimento local corresponde a esta busca',
      'O BIL não inventará uma correspondência. Crie um alimento personalizado com dados verificados do rótulo.',
    ],
    'pt-PT': <String>[
      'Inglês, árabe, palavra-chave ou código de barras',
      'Nenhum alimento local corresponde a esta pesquisa',
      'O BIL não inventará uma correspondência. Crie um alimento personalizado com dados verificados do rótulo.',
    ],
    'ur': <String>[
      'انگریزی، عربی، کلیدی لفظ یا بار کوڈ',
      'اس تلاش سے کوئی مقامی غذا مماثل نہیں ہے',
      'BIL کوئی مماثلت خود سے نہیں بنائے گا۔ تصدیق شدہ لیبل معلومات سے اپنی غذا بنائیں۔',
    ],
    'fa': <String>[
      'انگلیسی، عربی، کلیدواژه یا بارکد',
      'هیچ غذای محلی با این جستجو مطابقت ندارد',
      'BIL تطابقی را از خود نمی‌سازد. یک غذای سفارشی بر اساس اطلاعات تأییدشدهٔ برچسب ایجاد کنید.',
    ],
    'hi': <String>[
      'अंग्रेज़ी, अरबी, कीवर्ड या बारकोड',
      'इस खोज से कोई स्थानीय भोजन मेल नहीं खाता',
      'BIL कोई मिलान गढ़ेगा नहीं। सत्यापित लेबल जानकारी से कस्टम भोजन बनाएँ।',
    ],
    'id': <String>[
      'Bahasa Inggris, Arab, kata kunci, atau kode batang',
      'Tidak ada makanan lokal yang cocok dengan pencarian ini',
      'BIL tidak akan mengarang kecocokan. Buat makanan khusus dari informasi label yang terverifikasi.',
    ],
    'ms': <String>[
      'Bahasa Inggeris, Arab, kata kunci atau kod bar',
      'Tiada makanan tempatan yang sepadan dengan carian ini',
      'BIL tidak akan mereka padanan. Cipta makanan tersuai daripada maklumat label yang disahkan.',
    ],
    'ja': <String>[
      '英語、アラビア語、キーワード、またはバーコード',
      'この検索に一致するローカル食品はありません',
      'BIL は一致する食品を作り上げません。確認済みのラベル情報からカスタム食品を作成してください。',
    ],
    'ko': <String>[
      '영어, 아랍어, 키워드 또는 바코드',
      '이 검색과 일치하는 로컬 음식이 없습니다',
      'BIL은 일치 항목을 임의로 만들지 않습니다. 검증된 라벨 정보로 사용자 지정 음식을 만드세요.',
    ],
    'zh-Hans': <String>[
      '英语、阿拉伯语、关键词或条形码',
      '没有本地食物与此搜索匹配',
      'BIL 不会编造匹配结果。请根据已验证的标签信息创建自定义食物。',
    ],
    'zh-Hant': <String>[
      '英文、阿拉伯文、關鍵字或條碼',
      '沒有本地食物符合此搜尋',
      'BIL 不會捏造符合項目。請根據已驗證的標籤資訊建立自訂食物。',
    ],
    'ru': <String>[
      'Английский, арабский, ключевое слово или штрихкод',
      'Локальные продукты по этому запросу не найдены',
      'BIL не будет придумывать совпадение. Создайте свой продукт по проверенным данным с этикетки.',
    ],
    'bn': <String>[
      'ইংরেজি, আরবি, কীওয়ার্ড বা বারকোড',
      'এই অনুসন্ধানের সঙ্গে কোনো স্থানীয় খাবার মেলেনি',
      'BIL কোনো মিল বানিয়ে দেখাবে না। যাচাইকৃত লেবেল তথ্য থেকে কাস্টম খাবার তৈরি করুন।',
    ],
    'vi': <String>[
      'Tiếng Anh, tiếng Ả Rập, từ khóa hoặc mã vạch',
      'Không có thực phẩm cục bộ nào khớp với tìm kiếm này',
      'BIL sẽ không tạo ra kết quả khớp giả. Hãy tạo thực phẩm tùy chỉnh từ thông tin nhãn đã được xác minh.',
    ],
    'th': <String>[
      'อังกฤษ อาหรับ คำสำคัญ หรือบาร์โค้ด',
      'ไม่มีอาหารในเครื่องที่ตรงกับการค้นหานี้',
      'BIL จะไม่สร้างผลลัพธ์ที่ตรงกันขึ้นมาเอง สร้างอาหารแบบกำหนดเองจากข้อมูลฉลากที่ตรวจสอบแล้ว',
    ],
    'pl': <String>[
      'Angielski, arabski, słowo kluczowe lub kod kreskowy',
      'Brak lokalnej żywności pasującej do tego wyszukiwania',
      'BIL nie wymyśli dopasowania. Utwórz własny produkt na podstawie zweryfikowanych danych z etykiety.',
    ],
    'nl': <String>[
      'Engels, Arabisch, trefwoord of barcode',
      'Geen lokale voedingsmiddelen komen overeen met deze zoekopdracht',
      'BIL verzint geen overeenkomst. Maak een aangepast voedingsmiddel op basis van geverifieerde etiketgegevens.',
    ],
    'uk': <String>[
      'Англійська, арабська, ключове слово або штрихкод',
      'Локальні продукти за цим пошуком не знайдені',
      'BIL не вигадуватиме збіг. Створіть власний продукт за перевіреними даними з етикетки.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final row = rows[localeTag];
    if (row == null || row.length != sources.length) return null;
    return row[index];
  }

  static bool get balanced =>
      supported.length == 25 &&
      rows.keys.toSet().containsAll(supported) &&
      supported.containsAll(rows.keys) &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((value) => value.trim().isNotEmpty),
      ) &&
      _sameValues(rows['en'], sources);

  static bool _sameValues(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < right.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
