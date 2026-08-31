import 'bil_locale_policy.dart';

/// Reviewed safety copy for camera and barcode lookup journeys.
abstract final class FoodActionRuntimeCopy {
  static const enableCamera =
      'Enable camera access in system settings to scan a barcode. Manual barcode entry remains available.';
  static const selectedScanOnly =
      'BIL opens the camera only for the barcode scan you selected and never at startup.';
  static const verifiedCatalogUnavailable =
      'The verified catalog could not be reached. BIL will not invent nutrition values. You can create this product from its label, or try again later.';
  static const noVerifiedBarcodeMatch =
      'No verified product matched this barcode. BIL will not invent nutrition values. You can create a food from the product label and the barcode will be prefilled.';

  static const sources = <String>[
    enableCamera,
    selectedScanOnly,
    verifiedCatalogUnavailable,
    noVerifiedBarcodeMatch,
  ];

  static const supported = <String>{
    'ar',
    'en',
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

  static const rows = <String, List<String>>{
    'ar': <String>[
      'فعّل الوصول إلى الكاميرا من إعدادات النظام لمسح باركود. يظل إدخال الباركود يدويًا متاحًا.',
      'يفتح BIL الكاميرا فقط لمسح الباركود الذي اخترته، ولا يفتحها مطلقًا عند بدء التشغيل.',
      'تعذّر الوصول إلى الدليل الموثّق. لن يخمّن BIL القيم الغذائية. يمكنك إنشاء هذا المنتج من ملصقه أو المحاولة لاحقًا.',
      'لم يطابق أي منتج موثّق هذا الباركود. لن يخمّن BIL القيم الغذائية. يمكنك إنشاء طعام من ملصق المنتج وسيُملأ الباركود مسبقًا.',
    ],
    'en': sources,
    'fr': <String>[
      'Autorisez l’accès à l’appareil photo dans les réglages système pour scanner un code-barres. La saisie manuelle reste disponible.',
      'BIL ouvre l’appareil photo uniquement pour le scan de code-barres que vous avez choisi, jamais au démarrage.',
      'Le catalogue vérifié est inaccessible. BIL n’inventera pas de valeurs nutritionnelles. Créez ce produit à partir de son étiquette ou réessayez plus tard.',
      'Aucun produit vérifié ne correspond à ce code-barres. BIL n’inventera pas de valeurs nutritionnelles. Créez un aliment depuis l’étiquette; le code-barres sera prérempli.',
    ],
    'es': <String>[
      'Activa el acceso a la cámara en los ajustes del sistema para escanear un código de barras. La entrada manual seguirá disponible.',
      'BIL abre la cámara solo para el escaneo que seleccionaste y nunca al iniciar la aplicación.',
      'No se pudo acceder al catálogo verificado. BIL no inventará valores nutricionales. Crea el producto desde su etiqueta o inténtalo más tarde.',
      'Ningún producto verificado coincide con este código de barras. BIL no inventará valores nutricionales. Crea un alimento desde la etiqueta; el código quedará rellenado.',
    ],
    'tr': <String>[
      'Barkod taramak için sistem ayarlarından kamera erişimini açın. Barkodu elle girme seçeneği kullanılabilir durumda kalır.',
      'BIL kamerayı yalnızca seçtiğiniz barkod taraması için açar; başlangıçta asla açmaz.',
      'Doğrulanmış kataloga ulaşılamadı. BIL besin değerlerini tahmin etmez. Ürünü etiketinden oluşturabilir veya daha sonra tekrar deneyebilirsiniz.',
      'Bu barkodla eşleşen doğrulanmış ürün bulunamadı. BIL besin değerlerini tahmin etmez. Etiketten bir yiyecek oluşturabilirsiniz; barkod önceden doldurulur.',
    ],
    'de': <String>[
      'Aktiviere den Kamerazugriff in den Systemeinstellungen, um einen Barcode zu scannen. Die manuelle Eingabe bleibt verfügbar.',
      'BIL öffnet die Kamera nur für den von dir gewählten Barcode-Scan und niemals beim Start.',
      'Der verifizierte Katalog war nicht erreichbar. BIL erfindet keine Nährwerte. Erstelle das Produkt anhand des Etiketts oder versuche es später erneut.',
      'Kein verifiziertes Produkt stimmt mit diesem Barcode überein. BIL erfindet keine Nährwerte. Erstelle ein Lebensmittel anhand des Etiketts; der Barcode wird vorausgefüllt.',
    ],
    'it': <String>[
      'Abilita l’accesso alla fotocamera nelle impostazioni di sistema per scansionare un codice a barre. L’inserimento manuale resta disponibile.',
      'BIL apre la fotocamera solo per la scansione scelta e mai all’avvio.',
      'Impossibile raggiungere il catalogo verificato. BIL non inventerà valori nutrizionali. Crea il prodotto dall’etichetta o riprova più tardi.',
      'Nessun prodotto verificato corrisponde a questo codice a barre. BIL non inventerà valori nutrizionali. Crea un alimento dall’etichetta; il codice sarà precompilato.',
    ],
    'pt-BR': <String>[
      'Ative o acesso à câmera nas configurações do sistema para ler um código de barras. A entrada manual continua disponível.',
      'O BIL abre a câmera somente para a leitura escolhida e nunca ao iniciar.',
      'Não foi possível acessar o catálogo verificado. O BIL não inventa valores nutricionais. Crie o produto pelo rótulo ou tente novamente mais tarde.',
      'Nenhum produto verificado corresponde a este código de barras. O BIL não inventa valores nutricionais. Crie um alimento pelo rótulo; o código será preenchido.',
    ],
    'pt-PT': <String>[
      'Ative o acesso à câmara nas definições do sistema para ler um código de barras. A introdução manual continua disponível.',
      'O BIL abre a câmara apenas para a leitura escolhida e nunca ao iniciar.',
      'Não foi possível aceder ao catálogo verificado. O BIL não inventa valores nutricionais. Crie o produto pelo rótulo ou tente mais tarde.',
      'Nenhum produto verificado corresponde a este código de barras. O BIL não inventa valores nutricionais. Crie um alimento pelo rótulo; o código será pré-preenchido.',
    ],
    'ur': <String>[
      'بار کوڈ اسکین کرنے کے لیے سسٹم سیٹنگز میں کیمرے کی اجازت فعال کریں۔ دستی اندراج دستیاب رہے گا۔',
      'BIL کیمرا صرف آپ کے منتخب کردہ بار کوڈ اسکین کے لیے کھولتا ہے، آغاز پر کبھی نہیں۔',
      'تصدیق شدہ کیٹلاگ تک رسائی نہیں ہو سکی۔ BIL غذائی اقدار نہیں گھڑے گا۔ لیبل سے پروڈکٹ بنائیں یا بعد میں دوبارہ کوشش کریں۔',
      'اس بار کوڈ سے کوئی تصدیق شدہ پروڈکٹ نہیں ملی۔ BIL غذائی اقدار نہیں گھڑے گا۔ لیبل سے غذا بنائیں؛ بار کوڈ پہلے سے درج ہوگا۔',
    ],
    'fa': <String>[
      'برای اسکن بارکد، دسترسی دوربین را در تنظیمات سیستم فعال کنید. ورود دستی بارکد همچنان در دسترس است.',
      'BIL دوربین را فقط برای اسکن بارکدی که انتخاب کرده‌اید باز می‌کند و هرگز هنگام شروع برنامه باز نمی‌کند.',
      'دسترسی به فهرست تأییدشده ممکن نشد. BIL مقادیر تغذیه‌ای را حدس نمی‌زند. محصول را از روی برچسب بسازید یا بعداً دوباره تلاش کنید.',
      'هیچ محصول تأییدشده‌ای با این بارکد تطابق نداشت. BIL مقادیر تغذیه‌ای را حدس نمی‌زند. غذا را از روی برچسب بسازید؛ بارکد از پیش پر می‌شود.',
    ],
    'hi': <String>[
      'बारकोड स्कैन करने के लिए सिस्टम सेटिंग में कैमरा एक्सेस चालू करें। बारकोड को हाथ से दर्ज करने का विकल्प उपलब्ध रहेगा।',
      'BIL कैमरा केवल आपके चुने हुए बारकोड स्कैन के लिए खोलता है, ऐप शुरू होने पर कभी नहीं।',
      'सत्यापित कैटलॉग उपलब्ध नहीं था। BIL पोषण मान नहीं गढ़ेगा। लेबल से यह उत्पाद बनाएँ या बाद में फिर कोशिश करें।',
      'इस बारकोड से कोई सत्यापित उत्पाद नहीं मिला। BIL पोषण मान नहीं गढ़ेगा। लेबल से खाद्य बनाएँ; बारकोड पहले से भरा होगा।',
    ],
    'id': <String>[
      'Aktifkan akses kamera di pengaturan sistem untuk memindai kode batang. Entri manual tetap tersedia.',
      'BIL membuka kamera hanya untuk pemindaian yang Anda pilih dan tidak pernah saat aplikasi dimulai.',
      'Katalog terverifikasi tidak dapat dijangkau. BIL tidak akan mengarang nilai gizi. Buat produk dari labelnya atau coba lagi nanti.',
      'Tidak ada produk terverifikasi yang cocok dengan kode batang ini. BIL tidak akan mengarang nilai gizi. Buat makanan dari label; kode akan terisi otomatis.',
    ],
    'ms': <String>[
      'Aktifkan akses kamera dalam tetapan sistem untuk mengimbas kod bar. Kemasukan manual tetap tersedia.',
      'BIL membuka kamera hanya untuk imbasan kod bar yang anda pilih dan tidak pernah semasa aplikasi bermula.',
      'Katalog yang disahkan tidak dapat dicapai. BIL tidak akan mereka nilai pemakanan. Cipta produk daripada labelnya atau cuba lagi kemudian.',
      'Tiada produk disahkan sepadan dengan kod bar ini. BIL tidak akan mereka nilai pemakanan. Cipta makanan daripada label; kod bar akan diisi awal.',
    ],
    'ja': <String>[
      'バーコードをスキャンするには、システム設定でカメラへのアクセスを許可してください。手入力は引き続き利用できます。',
      'BILがカメラを開くのは選択したバーコードスキャン時だけで、起動時には開きません。',
      '検証済みカタログに接続できませんでした。BILが栄養値を推測することはありません。ラベルから商品を作成するか、後でもう一度お試しください。',
      'このバーコードに一致する検証済み商品はありません。BILが栄養値を推測することはありません。ラベルから食品を作成すると、バーコードは入力済みになります。',
    ],
    'ko': <String>[
      '바코드를 스캔하려면 시스템 설정에서 카메라 접근을 허용하세요. 수동 입력은 계속 사용할 수 있습니다.',
      'BIL은 선택한 바코드 스캔 때만 카메라를 열며 시작할 때는 열지 않습니다.',
      '검증된 카탈로그에 연결할 수 없습니다. BIL은 영양값을 만들어 내지 않습니다. 라벨에서 제품을 만들거나 나중에 다시 시도하세요.',
      '이 바코드와 일치하는 검증된 제품이 없습니다. BIL은 영양값을 만들어 내지 않습니다. 라벨에서 식품을 만들면 바코드가 미리 입력됩니다.',
    ],
    'zh-Hans': <String>[
      '请在系统设置中启用相机权限以扫描条形码。仍可手动输入条形码。',
      'BIL 只会在您选择扫描条形码时打开相机，绝不会在启动时打开。',
      '无法访问已验证目录。BIL 不会编造营养值。您可以根据标签创建此产品，或稍后重试。',
      '没有已验证产品与此条形码匹配。BIL 不会编造营养值。您可以根据产品标签创建食物，条形码会自动填入。',
    ],
    'zh-Hant': <String>[
      '請在系統設定中啟用相機權限以掃描條碼。仍可手動輸入條碼。',
      'BIL 只會在您選擇掃描條碼時開啟相機，絕不會在啟動時開啟。',
      '無法存取已驗證目錄。BIL 不會編造營養值。您可以依標籤建立此產品，或稍後重試。',
      '沒有已驗證產品與此條碼相符。BIL 不會編造營養值。您可以依產品標籤建立食物，條碼會自動填入。',
    ],
    'ru': <String>[
      'Разрешите доступ к камере в системных настройках, чтобы сканировать штрихкод. Ручной ввод останется доступен.',
      'BIL открывает камеру только для выбранного вами сканирования и никогда при запуске.',
      'Не удалось связаться с проверенным каталогом. BIL не придумывает пищевую ценность. Создайте продукт по этикетке или повторите попытку позже.',
      'Для этого штрихкода нет проверенного продукта. BIL не придумывает пищевую ценность. Создайте продукт по этикетке; штрихкод будет заполнен.',
    ],
    'bn': <String>[
      'বারকোড স্ক্যান করতে সিস্টেম সেটিংসে ক্যামেরা অ্যাক্সেস চালু করুন। হাতে বারকোড লেখা যাবে।',
      'BIL কেবল আপনার বেছে নেওয়া বারকোড স্ক্যানের সময় ক্যামেরা খোলে, অ্যাপ চালুর সময় কখনো নয়।',
      'যাচাইকৃত ক্যাটালগে পৌঁছানো যায়নি। BIL পুষ্টিমান বানিয়ে বলবে না। লেবেল থেকে পণ্য তৈরি করুন বা পরে আবার চেষ্টা করুন।',
      'এই বারকোডের সঙ্গে কোনো যাচাইকৃত পণ্য মেলেনি। BIL পুষ্টিমান বানিয়ে বলবে না। লেবেল থেকে খাবার তৈরি করলে বারকোড আগে থেকেই পূরণ থাকবে।',
    ],
    'vi': <String>[
      'Bật quyền truy cập máy ảnh trong cài đặt hệ thống để quét mã vạch. Bạn vẫn có thể nhập mã thủ công.',
      'BIL chỉ mở máy ảnh cho lần quét mã vạch bạn chọn và không bao giờ mở khi khởi động.',
      'Không thể truy cập danh mục đã xác minh. BIL sẽ không tự đặt ra giá trị dinh dưỡng. Hãy tạo sản phẩm từ nhãn hoặc thử lại sau.',
      'Không có sản phẩm đã xác minh khớp mã vạch này. BIL sẽ không tự đặt ra giá trị dinh dưỡng. Hãy tạo món từ nhãn; mã vạch sẽ được điền sẵn.',
    ],
    'th': <String>[
      'เปิดสิทธิ์เข้าถึงกล้องในการตั้งค่าระบบเพื่อสแกนบาร์โค้ด โดยยังป้อนบาร์โค้ดด้วยตนเองได้',
      'BIL เปิดกล้องเฉพาะเมื่อคุณเลือกสแกนบาร์โค้ด และจะไม่เปิดเมื่อเริ่มแอป',
      'ไม่สามารถเข้าถึงแคตตาล็อกที่ยืนยันแล้วได้ BIL จะไม่สร้างค่าทางโภชนาการขึ้นเอง คุณสร้างผลิตภัณฑ์จากฉลากหรือลองใหม่ภายหลังได้',
      'ไม่พบผลิตภัณฑ์ที่ยืนยันแล้วตรงกับบาร์โค้ดนี้ BIL จะไม่สร้างค่าทางโภชนาการขึ้นเอง คุณสร้างอาหารจากฉลากได้ โดยระบบจะกรอกบาร์โค้ดไว้ให้',
    ],
    'pl': <String>[
      'Włącz dostęp do aparatu w ustawieniach systemu, aby skanować kod kreskowy. Ręczne wpisywanie nadal będzie dostępne.',
      'BIL otwiera aparat tylko podczas wybranego skanowania kodu, nigdy przy uruchamianiu.',
      'Nie udało się połączyć ze zweryfikowanym katalogiem. BIL nie wymyśla wartości odżywczych. Utwórz produkt z etykiety lub spróbuj później.',
      'Żaden zweryfikowany produkt nie pasuje do tego kodu. BIL nie wymyśla wartości odżywczych. Utwórz produkt z etykiety; kod zostanie wypełniony.',
    ],
    'nl': <String>[
      'Schakel cameratoegang in bij de systeeminstellingen om een barcode te scannen. Handmatig invoeren blijft beschikbaar.',
      'BIL opent de camera alleen voor de door jou gekozen barcodescan en nooit bij het opstarten.',
      'De geverifieerde catalogus was niet bereikbaar. BIL verzint geen voedingswaarden. Maak het product aan vanaf het etiket of probeer het later opnieuw.',
      'Geen geverifieerd product kwam overeen met deze barcode. BIL verzint geen voedingswaarden. Maak een voedingsmiddel vanaf het etiket; de barcode wordt ingevuld.',
    ],
    'uk': <String>[
      'Увімкніть доступ до камери в системних налаштуваннях, щоб сканувати штрихкод. Ручне введення залишиться доступним.',
      'BIL відкриває камеру лише для вибраного вами сканування і ніколи під час запуску.',
      'Не вдалося зв’язатися з перевіреним каталогом. BIL не вигадує поживні значення. Створіть продукт за етикеткою або повторіть спробу пізніше.',
      'Жоден перевірений продукт не відповідає цьому штрихкоду. BIL не вигадує поживні значення. Створіть продукт за етикеткою; штрихкод буде заповнено.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing food-action copy for $tag.');
    }
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
