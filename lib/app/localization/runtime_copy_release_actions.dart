import 'package:flutter/widgets.dart';

import 'bil_locale_policy.dart';

/// Reviewed copy for small release-critical actions and validation messages.
///
/// Every shipped locale owns an explicit row. A missing row is a programming
/// error rather than permission to expose an English fallback in production.
abstract final class ReleaseActionRuntimeCopy {
  static const noThanks = 'No thanks';
  static const logFoodInSeconds = 'Log food in seconds';
  static const fastestBilTools =
      'Use the fastest BIL tools whenever typing is not convenient.';
  static const scanBarcode = 'Scan a barcode';
  static const identifyPackagedProducts =
      'Identify packaged products and review their nutrition before saving.';
  static const logWithVoice = 'Log with your voice';
  static const describeMeal =
      'Describe a meal naturally, then confirm every item before it is added.';
  static const analyzeMealPhoto = 'Analyze a meal photo';
  static const photoStartingPoint =
      'Use a photo as a starting point and review portions and evidence.';
  static const nonNegativeNumber = 'Enter a non-negative number.';
  static const saveEntryFailed = 'Could not save this entry. Try again.';
  static const lookUp = 'Look up';
  static const compatibleFitnessMeasurements =
      'Weight, body composition, and heart rate from compatible fitness devices.';

  static const sources = <String>[
    noThanks,
    logFoodInSeconds,
    fastestBilTools,
    scanBarcode,
    identifyPackagedProducts,
    logWithVoice,
    describeMeal,
    analyzeMealPhoto,
    photoStartingPoint,
    nonNegativeNumber,
    saveEntryFailed,
    lookUp,
    compatibleFitnessMeasurements,
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
      'لا شكرًا',
      'سجّل طعامك خلال ثوانٍ',
      'استخدم أسرع أدوات BIL عندما لا تكون الكتابة مناسبة.',
      'امسح الباركود',
      'تعرّف على المنتجات المعبأة وراجع قيمها الغذائية قبل الحفظ.',
      'سجّل بصوتك',
      'صِف وجبتك بطبيعية، ثم أكّد كل عنصر قبل إضافته.',
      'حلّل صورة الوجبة',
      'استخدم الصورة كنقطة بداية وراجع الحصص والأدلة.',
      'أدخل رقمًا غير سالب.',
      'تعذّر حفظ هذا الإدخال. حاول مرة أخرى.',
      'بحث',
      'الوزن وتركيب الجسم ومعدل ضربات القلب من أجهزة اللياقة المتوافقة.',
    ],
    'en': sources,
    'fr': <String>[
      'Non merci',
      'Enregistrez vos aliments en quelques secondes',
      'Utilisez les outils BIL les plus rapides lorsque la saisie est peu pratique.',
      'Scanner un code-barres',
      'Identifiez les produits emballés et vérifiez leurs valeurs nutritionnelles avant de les enregistrer.',
      'Enregistrer avec votre voix',
      'Décrivez naturellement un repas, puis confirmez chaque élément avant son ajout.',
      'Analyser une photo de repas',
      'Utilisez une photo comme point de départ, puis vérifiez les portions et les preuves.',
      'Saisissez un nombre positif ou nul.',
      'Impossible d’enregistrer cette entrée. Réessayez.',
      'Rechercher',
      'Poids, composition corporelle et fréquence cardiaque provenant d’appareils de fitness compatibles.',
    ],
    'es': <String>[
      'No, gracias',
      'Registra alimentos en segundos',
      'Usa las herramientas más rápidas de BIL cuando escribir no resulte práctico.',
      'Escanear un código de barras',
      'Identifica productos envasados y revisa su información nutricional antes de guardarlos.',
      'Registrar con tu voz',
      'Describe una comida con naturalidad y confirma cada elemento antes de añadirlo.',
      'Analizar una foto de la comida',
      'Usa una foto como punto de partida y revisa las porciones y las pruebas.',
      'Introduce un número no negativo.',
      'No se pudo guardar esta entrada. Inténtalo de nuevo.',
      'Buscar',
      'Peso, composición corporal y frecuencia cardíaca de dispositivos de fitness compatibles.',
    ],
    'tr': <String>[
      'Hayır, teşekkürler',
      'Yiyecekleri saniyeler içinde kaydet',
      'Yazmanın uygun olmadığı durumlarda BIL’in en hızlı araçlarını kullan.',
      'Barkod tara',
      'Paketli ürünleri tanı ve kaydetmeden önce besin değerlerini incele.',
      'Sesinle kaydet',
      'Öğünü doğal biçimde anlat, ardından eklenmeden önce her öğeyi onayla.',
      'Öğün fotoğrafını analiz et',
      'Fotoğrafı başlangıç noktası olarak kullan; porsiyonları ve kanıtları incele.',
      'Negatif olmayan bir sayı girin.',
      'Bu kayıt kaydedilemedi. Tekrar deneyin.',
      'Ara',
      'Uyumlu fitness cihazlarından ağırlık, vücut kompozisyonu ve kalp hızı.',
    ],
    'de': <String>[
      'Nein, danke',
      'Lebensmittel in Sekunden protokollieren',
      'Nutze die schnellsten BIL-Werkzeuge, wenn Tippen unpraktisch ist.',
      'Barcode scannen',
      'Erkenne verpackte Produkte und prüfe ihre Nährwerte vor dem Speichern.',
      'Per Sprache protokollieren',
      'Beschreibe eine Mahlzeit ganz natürlich und bestätige jeden Eintrag vor dem Hinzufügen.',
      'Mahlzeitenfoto analysieren',
      'Nutze ein Foto als Ausgangspunkt und prüfe Portionen und Nachweise.',
      'Gib eine nicht negative Zahl ein.',
      'Dieser Eintrag konnte nicht gespeichert werden. Versuche es erneut.',
      'Nachschlagen',
      'Gewicht, Körperzusammensetzung und Herzfrequenz von kompatiblen Fitnessgeräten.',
    ],
    'it': <String>[
      'No, grazie',
      'Registra gli alimenti in pochi secondi',
      'Usa gli strumenti BIL più rapidi quando digitare non è comodo.',
      'Scansiona un codice a barre',
      'Identifica i prodotti confezionati e controlla i valori nutrizionali prima di salvarli.',
      'Registra con la voce',
      'Descrivi un pasto in modo naturale, poi conferma ogni elemento prima di aggiungerlo.',
      'Analizza la foto di un pasto',
      'Usa una foto come punto di partenza e controlla porzioni e prove.',
      'Inserisci un numero non negativo.',
      'Impossibile salvare questa voce. Riprova.',
      'Cerca',
      'Peso, composizione corporea e frequenza cardiaca da dispositivi fitness compatibili.',
    ],
    'pt-BR': <String>[
      'Não, obrigado',
      'Registre alimentos em segundos',
      'Use as ferramentas mais rápidas do BIL quando digitar não for conveniente.',
      'Ler código de barras',
      'Identifique produtos embalados e revise os dados nutricionais antes de salvar.',
      'Registrar por voz',
      'Descreva uma refeição naturalmente e confirme cada item antes de adicioná-lo.',
      'Analisar foto da refeição',
      'Use uma foto como ponto de partida e revise porções e evidências.',
      'Digite um número não negativo.',
      'Não foi possível salvar esta entrada. Tente novamente.',
      'Consultar',
      'Peso, composição corporal e frequência cardíaca de dispositivos fitness compatíveis.',
    ],
    'pt-PT': <String>[
      'Não, obrigado',
      'Registe alimentos em segundos',
      'Use as ferramentas mais rápidas do BIL quando não for conveniente escrever.',
      'Ler código de barras',
      'Identifique produtos embalados e reveja os dados nutricionais antes de guardar.',
      'Registar por voz',
      'Descreva uma refeição naturalmente e confirme cada item antes de o adicionar.',
      'Analisar fotografia da refeição',
      'Use uma fotografia como ponto de partida e reveja porções e provas.',
      'Introduza um número não negativo.',
      'Não foi possível guardar esta entrada. Tente novamente.',
      'Consultar',
      'Peso, composição corporal e frequência cardíaca de dispositivos de fitness compatíveis.',
    ],
    'ur': <String>[
      'نہیں، شکریہ',
      'چند سیکنڈ میں کھانا درج کریں',
      'جب ٹائپ کرنا آسان نہ ہو تو BIL کے تیز ترین ٹولز استعمال کریں۔',
      'بار کوڈ اسکین کریں',
      'پیک شدہ مصنوعات پہچانیں اور محفوظ کرنے سے پہلے غذائیت کا جائزہ لیں۔',
      'اپنی آواز سے درج کریں',
      'کھانے کی قدرتی انداز میں وضاحت کریں، پھر شامل کرنے سے پہلے ہر چیز کی تصدیق کریں۔',
      'کھانے کی تصویر کا تجزیہ کریں',
      'تصویر کو نقطۂ آغاز بنائیں اور مقداروں اور شواہد کا جائزہ لیں۔',
      'صفر یا اس سے بڑا عدد درج کریں۔',
      'یہ اندراج محفوظ نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
      'تلاش کریں',
      'ہم آہنگ فٹنس آلات سے وزن، جسمانی ساخت اور دل کی دھڑکن۔',
    ],
    'fa': <String>[
      'نه، ممنون',
      'ثبت غذا در چند ثانیه',
      'هر زمان تایپ‌کردن مناسب نیست، از سریع‌ترین ابزارهای BIL استفاده کنید.',
      'اسکن بارکد',
      'محصولات بسته‌بندی‌شده را شناسایی کنید و پیش از ذخیره، اطلاعات تغذیه‌ای را بررسی کنید.',
      'ثبت با صدا',
      'وعده را طبیعی توضیح دهید و پیش از افزودن، هر مورد را تأیید کنید.',
      'تحلیل عکس وعده',
      'عکس را نقطه شروع قرار دهید و مقدارها و شواهد را بررسی کنید.',
      'عددی نامنفی وارد کنید.',
      'این ورودی ذخیره نشد. دوباره تلاش کنید.',
      'جست‌وجو',
      'وزن، ترکیب بدن و ضربان قلب از دستگاه‌های تناسب اندام سازگار.',
    ],
    'hi': <String>[
      'नहीं, धन्यवाद',
      'कुछ सेकंड में भोजन दर्ज करें',
      'जब टाइप करना सुविधाजनक न हो, तब BIL के सबसे तेज़ टूल इस्तेमाल करें।',
      'बारकोड स्कैन करें',
      'पैक किए गए उत्पाद पहचानें और सहेजने से पहले उनकी पोषण जानकारी जाँचें।',
      'आवाज़ से दर्ज करें',
      'भोजन का स्वाभाविक रूप से वर्णन करें, फिर जोड़ने से पहले हर आइटम की पुष्टि करें।',
      'भोजन की फ़ोटो का विश्लेषण करें',
      'फ़ोटो को शुरुआती बिंदु मानें और मात्रा तथा प्रमाण की समीक्षा करें।',
      'शून्य या उससे बड़ी संख्या दर्ज करें।',
      'यह प्रविष्टि सहेजी नहीं जा सकी। फिर से कोशिश करें।',
      'खोजें',
      'संगत फ़िटनेस डिवाइसों से वज़न, शरीर संरचना और हृदय गति।',
    ],
    'id': <String>[
      'Tidak, terima kasih',
      'Catat makanan dalam hitungan detik',
      'Gunakan alat BIL tercepat saat mengetik tidak praktis.',
      'Pindai kode batang',
      'Kenali produk kemasan dan tinjau informasi gizinya sebelum menyimpan.',
      'Catat dengan suara',
      'Jelaskan makanan secara alami, lalu konfirmasi setiap item sebelum ditambahkan.',
      'Analisis foto makanan',
      'Gunakan foto sebagai titik awal dan tinjau porsi serta buktinya.',
      'Masukkan angka yang tidak negatif.',
      'Entri ini tidak dapat disimpan. Coba lagi.',
      'Cari',
      'Berat, komposisi tubuh, dan detak jantung dari perangkat kebugaran yang kompatibel.',
    ],
    'ms': <String>[
      'Tidak, terima kasih',
      'Catat makanan dalam beberapa saat',
      'Gunakan alat BIL terpantas apabila menaip tidak sesuai.',
      'Imbas kod bar',
      'Kenal pasti produk berbungkus dan semak maklumat pemakanan sebelum menyimpan.',
      'Catat dengan suara',
      'Terangkan hidangan secara semula jadi, kemudian sahkan setiap item sebelum ditambah.',
      'Analisis foto hidangan',
      'Gunakan foto sebagai titik mula dan semak saiz hidangan serta bukti.',
      'Masukkan nombor bukan negatif.',
      'Entri ini tidak dapat disimpan. Cuba lagi.',
      'Cari',
      'Berat, komposisi badan dan kadar denyutan jantung daripada peranti kecergasan yang serasi.',
    ],
    'ja': <String>[
      '結構です',
      '数秒で食事を記録',
      '入力しにくいときは、BILのすばやいツールを使えます。',
      'バーコードをスキャン',
      '包装食品を特定し、保存前に栄養情報を確認します。',
      '音声で記録',
      '食事を自然に説明し、追加前に各項目を確認します。',
      '食事写真を分析',
      '写真を出発点にして、分量と根拠を確認します。',
      '0以上の数値を入力してください。',
      'この項目を保存できませんでした。もう一度お試しください。',
      '検索',
      '対応するフィットネス機器からの体重、体組成、心拍数。',
    ],
    'ko': <String>[
      '괜찮습니다',
      '몇 초 만에 음식 기록',
      '입력하기 어려울 때 BIL의 빠른 도구를 사용하세요.',
      '바코드 스캔',
      '포장 제품을 식별하고 저장 전에 영양 정보를 확인하세요.',
      '음성으로 기록',
      '식사를 자연스럽게 설명한 뒤 추가 전에 각 항목을 확인하세요.',
      '식사 사진 분석',
      '사진을 시작점으로 사용하고 분량과 근거를 검토하세요.',
      '0 이상의 숫자를 입력하세요.',
      '이 항목을 저장하지 못했습니다. 다시 시도하세요.',
      '조회',
      '호환되는 피트니스 기기의 체중, 체성분 및 심박수.',
    ],
    'zh-Hans': <String>[
      '不用，谢谢',
      '数秒内记录食物',
      '不方便打字时，可使用 BIL 的快捷工具。',
      '扫描条形码',
      '识别包装产品，并在保存前查看其营养信息。',
      '用语音记录',
      '自然描述一餐，然后在添加前确认每个项目。',
      '分析餐食照片',
      '以照片为起点，并检查份量和依据。',
      '请输入非负数。',
      '无法保存此条目。请重试。',
      '查找',
      '来自兼容健身设备的体重、身体成分和心率。',
    ],
    'zh-Hant': <String>[
      '不用，謝謝',
      '數秒內記錄食物',
      '不方便輸入時，可使用 BIL 的快捷工具。',
      '掃描條碼',
      '辨識包裝產品，並在儲存前查看其營養資訊。',
      '用語音記錄',
      '自然描述一餐，然後在加入前確認每個項目。',
      '分析餐點照片',
      '以照片為起點，並檢查份量與依據。',
      '請輸入非負數。',
      '無法儲存此項目。請再試一次。',
      '查找',
      '來自相容健身裝置的體重、身體組成與心率。',
    ],
    'ru': <String>[
      'Нет, спасибо',
      'Записывайте еду за считанные секунды',
      'Используйте самые быстрые инструменты BIL, когда неудобно печатать.',
      'Сканировать штрихкод',
      'Распознавайте упакованные продукты и проверяйте пищевую ценность перед сохранением.',
      'Записать голосом',
      'Опишите приём пищи естественными словами, затем подтвердите каждый пункт перед добавлением.',
      'Анализировать фото блюда',
      'Используйте фото как отправную точку и проверьте порции и подтверждения.',
      'Введите неотрицательное число.',
      'Не удалось сохранить эту запись. Повторите попытку.',
      'Найти',
      'Вес, состав тела и частота пульса с совместимых фитнес-устройств.',
    ],
    'bn': <String>[
      'না, ধন্যবাদ',
      'কয়েক সেকেন্ডে খাবার লিখুন',
      'টাইপ করা সুবিধাজনক না হলে BIL-এর দ্রুততম টুল ব্যবহার করুন।',
      'বারকোড স্ক্যান করুন',
      'প্যাকেটজাত পণ্য শনাক্ত করুন এবং সংরক্ষণের আগে পুষ্টি তথ্য পর্যালোচনা করুন।',
      'কণ্ঠে লিখুন',
      'স্বাভাবিকভাবে খাবারের বর্ণনা দিন, তারপর যোগ করার আগে প্রতিটি আইটেম নিশ্চিত করুন।',
      'খাবারের ছবি বিশ্লেষণ করুন',
      'ছবিকে শুরুর বিন্দু হিসেবে ব্যবহার করুন এবং পরিমাণ ও প্রমাণ পর্যালোচনা করুন।',
      'শূন্য বা তার বেশি সংখ্যা লিখুন।',
      'এই এন্ট্রি সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।',
      'খুঁজুন',
      'সামঞ্জস্যপূর্ণ ফিটনেস ডিভাইস থেকে ওজন, শরীরের গঠন ও হৃদ্‌স্পন্দন।',
    ],
    'vi': <String>[
      'Không, cảm ơn',
      'Ghi món ăn trong vài giây',
      'Dùng các công cụ BIL nhanh nhất khi việc nhập liệu không thuận tiện.',
      'Quét mã vạch',
      'Nhận diện sản phẩm đóng gói và xem lại thông tin dinh dưỡng trước khi lưu.',
      'Ghi bằng giọng nói',
      'Mô tả bữa ăn tự nhiên, rồi xác nhận từng món trước khi thêm.',
      'Phân tích ảnh bữa ăn',
      'Dùng ảnh làm điểm bắt đầu và xem lại khẩu phần cùng bằng chứng.',
      'Nhập một số không âm.',
      'Không thể lưu mục này. Hãy thử lại.',
      'Tra cứu',
      'Cân nặng, thành phần cơ thể và nhịp tim từ thiết bị thể chất tương thích.',
    ],
    'th': <String>[
      'ไม่ ขอบคุณ',
      'บันทึกอาหารในไม่กี่วินาที',
      'ใช้เครื่องมือ BIL ที่รวดเร็วเมื่อไม่สะดวกพิมพ์',
      'สแกนบาร์โค้ด',
      'ระบุผลิตภัณฑ์บรรจุหีบห่อและตรวจสอบโภชนาการก่อนบันทึก',
      'บันทึกด้วยเสียง',
      'อธิบายมื้ออาหารอย่างเป็นธรรมชาติ แล้วยืนยันแต่ละรายการก่อนเพิ่ม',
      'วิเคราะห์ภาพมื้ออาหาร',
      'ใช้ภาพเป็นจุดเริ่มต้นและตรวจสอบปริมาณกับหลักฐาน',
      'ป้อนตัวเลขที่ไม่ติดลบ',
      'บันทึกรายการนี้ไม่ได้ โปรดลองอีกครั้ง',
      'ค้นหา',
      'น้ำหนัก องค์ประกอบร่างกาย และอัตราการเต้นหัวใจจากอุปกรณ์ฟิตเนสที่รองรับ',
    ],
    'pl': <String>[
      'Nie, dziękuję',
      'Zapisuj jedzenie w kilka sekund',
      'Używaj najszybszych narzędzi BIL, gdy pisanie jest niewygodne.',
      'Zeskanuj kod kreskowy',
      'Rozpoznaj produkty pakowane i sprawdź ich wartości odżywcze przed zapisaniem.',
      'Zapisz głosem',
      'Opisz posiłek w naturalny sposób, a następnie potwierdź każdy element przed dodaniem.',
      'Przeanalizuj zdjęcie posiłku',
      'Użyj zdjęcia jako punktu wyjścia i sprawdź porcje oraz dowody.',
      'Wpisz liczbę nieujemną.',
      'Nie udało się zapisać tego wpisu. Spróbuj ponownie.',
      'Wyszukaj',
      'Masa ciała, skład ciała i tętno ze zgodnych urządzeń fitness.',
    ],
    'nl': <String>[
      'Nee, bedankt',
      'Voeding in seconden registreren',
      'Gebruik de snelste BIL-tools wanneer typen niet handig is.',
      'Barcode scannen',
      'Herken verpakte producten en controleer de voedingsinformatie voordat je opslaat.',
      'Met je stem registreren',
      'Beschrijf een maaltijd op natuurlijke wijze en bevestig elk item voordat het wordt toegevoegd.',
      'Een maaltijdfoto analyseren',
      'Gebruik een foto als uitgangspunt en controleer porties en bewijs.',
      'Voer een niet-negatief getal in.',
      'Dit item kon niet worden opgeslagen. Probeer het opnieuw.',
      'Opzoeken',
      'Gewicht, lichaamssamenstelling en hartslag van compatibele fitnessapparaten.',
    ],
    'uk': <String>[
      'Ні, дякую',
      'Записуйте їжу за кілька секунд',
      'Використовуйте найшвидші інструменти BIL, коли вводити текст незручно.',
      'Сканувати штрихкод',
      'Розпізнавайте упаковані продукти та перевіряйте поживність перед збереженням.',
      'Записати голосом',
      'Опишіть прийом їжі природно, а потім підтвердьте кожен пункт перед додаванням.',
      'Проаналізувати фото страви',
      'Використайте фото як відправну точку та перевірте порції й підтвердження.',
      'Введіть невід’ємне число.',
      'Не вдалося зберегти цей запис. Спробуйте ще раз.',
      'Знайти',
      'Вага, склад тіла та частота пульсу із сумісних фітнес-пристроїв.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing release-action copy for $tag.');
    }
    return row[index];
  }

  static String textForLocale(String source, Locale locale) =>
      resolve(source, BilLocalePolicy.canonicalTag(locale)) ?? source;

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
