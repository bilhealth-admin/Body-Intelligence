import '../domain/product_identity.dart';

String productKindLabel(
  ProductKind kind, {
  required bool arabic,
  String? languageCode,
}) {
  final code = _resolvedLanguage(languageCode, arabic);
  final labels = _productLabels[kind]!;
  return labels[code] ?? _deepProductLabels[code]?[kind.index] ?? labels['en']!;
}

String productIdentityExplanation(
  ProductIdentity product, {
  required bool arabic,
  String? languageCode,
}) {
  final code = _resolvedLanguage(languageCode, arabic);
  final type = productKindLabel(
    product.kind,
    arabic: arabic,
    languageCode: code,
  );
  final name = code == 'ar' && product.arabicName?.trim().isNotEmpty == true
      ? product.arabicName!
      : product.name;
  final explanation =
      _identityExplanation[code] ??
      _deepIdentityExplanation[code] ??
      _identityExplanation['en']!;
  return '$type: $name. $explanation';
}

String _resolvedLanguage(String? languageCode, bool arabic) {
  if (languageCode != null) return languageCode.toLowerCase();
  if (arabic) return 'ar';
  return 'en';
}

const _productLabels = <ProductKind, Map<String, String>>{
  ProductKind.food: {
    'en': 'Food product',
    'ar': 'منتج غذائي',
    'fr': 'Produit alimentaire',
    'es': 'Producto alimenticio',
    'tr': 'Gıda ürünü',
  },
  ProductKind.beverage: {
    'en': 'Beverage',
    'ar': 'مشروب',
    'fr': 'Boisson',
    'es': 'Bebida',
    'tr': 'İçecek',
  },
  ProductKind.alcohol: {
    'en': 'Alcoholic beverage',
    'ar': 'مشروب كحولي',
    'fr': 'Boisson alcoolisée',
    'es': 'Bebida alcohólica',
    'tr': 'Alkollü içecek',
  },
  ProductKind.supplement: {
    'en': 'Dietary supplement',
    'ar': 'مكمل غذائي',
    'fr': 'Complément alimentaire',
    'es': 'Suplemento alimenticio',
    'tr': 'Besin takviyesi',
  },
  ProductKind.medicine: {
    'en': 'Medicine or pharmaceutical product',
    'ar': 'دواء أو منتج صيدلاني',
    'fr': 'Médicament ou produit pharmaceutique',
    'es': 'Medicamento o producto farmacéutico',
    'tr': 'İlaç veya farmasötik ürün',
  },
  ProductKind.tobacco: {
    'en': 'Tobacco or nicotine product',
    'ar': 'منتج تبغ أو نيكوتين',
    'fr': 'Produit du tabac ou à base de nicotine',
    'es': 'Producto de tabaco o nicotina',
    'tr': 'Tütün veya nikotin ürünü',
  },
  ProductKind.personalCare: {
    'en': 'Personal-care product',
    'ar': 'منتج عناية شخصية',
    'fr': 'Produit de soins personnels',
    'es': 'Producto de cuidado personal',
    'tr': 'Kişisel bakım ürünü',
  },
  ProductKind.petFood: {
    'en': 'Pet food',
    'ar': 'غذاء حيوانات',
    'fr': 'Aliment pour animaux',
    'es': 'Alimento para mascotas',
    'tr': 'Evcil hayvan maması',
  },
  ProductKind.household: {
    'en': 'Household product',
    'ar': 'منتج منزلي',
    'fr': 'Produit ménager',
    'es': 'Producto doméstico',
    'tr': 'Ev ürünü',
  },
  ProductKind.generalProduct: {
    'en': 'Non-food product',
    'ar': 'منتج غير غذائي',
    'fr': 'Produit non alimentaire',
    'es': 'Producto no alimenticio',
    'tr': 'Gıda dışı ürün',
  },
  ProductKind.unknown: {
    'en': 'Unclassified product',
    'ar': 'نوع منتج غير محدد',
    'fr': 'Produit non classé',
    'es': 'Producto sin clasificar',
    'tr': 'Sınıflandırılmamış ürün',
  },
};

const _identityExplanation = <String, String>{
  'en':
      'The product was identified, but complete trusted nutrition data is unavailable. BIL will not create estimated values.',
  'ar':
      'تم التعرّف على المنتج، لكن لا تتوفر بيانات غذائية موثوقة وكاملة لإضافته كطعام. لن ينشئ BIL قيمًا تقديرية.',
  'fr':
      'Le produit a été identifié, mais ses données nutritionnelles fiables et complètes ne sont pas disponibles. BIL ne créera aucune valeur estimée.',
  'es':
      'El producto fue identificado, pero no hay datos nutricionales completos y fiables. BIL no creará valores estimados.',
  'tr':
      'Ürün tanımlandı ancak eksiksiz ve güvenilir besin verileri mevcut değil. BIL tahmini değerler oluşturmayacaktır.',
};

// Order follows ProductKind.values. Keeping deep-locale labels in rows makes
// completeness auditable without duplicating a map for every product kind.
const _deepProductLabels = <String, List<String>>{
  'de': [
    'Lebensmittel',
    'Getränk',
    'Alkoholisches Getränk',
    'Nahrungsergänzung',
    'Arzneimittel',
    'Tabak- oder Nikotinprodukt',
    'Körperpflegeprodukt',
    'Tiernahrung',
    'Haushaltsprodukt',
    'Nicht-Lebensmittel',
    'Nicht klassifiziertes Produkt',
  ],
  'it': [
    'Prodotto alimentare',
    'Bevanda',
    'Bevanda alcolica',
    'Integratore alimentare',
    'Medicinale',
    'Prodotto del tabacco o nicotina',
    'Prodotto per la cura personale',
    'Alimento per animali',
    'Prodotto per la casa',
    'Prodotto non alimentare',
    'Prodotto non classificato',
  ],
  'pt': [
    'Produto alimentar',
    'Bebida',
    'Bebida alcoólica',
    'Suplemento alimentar',
    'Medicamento',
    'Produto de tabaco ou nicotina',
    'Produto de cuidado pessoal',
    'Alimento para animais',
    'Produto doméstico',
    'Produto não alimentar',
    'Produto não classificado',
  ],
  'ur': [
    'غذائی پروڈکٹ',
    'مشروب',
    'الکحل والا مشروب',
    'غذائی سپلیمنٹ',
    'دوا',
    'تمباکو یا نکوٹین پروڈکٹ',
    'ذاتی نگہداشت کی پروڈکٹ',
    'پالتو جانوروں کی خوراک',
    'گھریلو پروڈکٹ',
    'غیر غذائی پروڈکٹ',
    'غیر درجہ بند پروڈکٹ',
  ],
  'fa': [
    'محصول غذایی',
    'نوشیدنی',
    'نوشیدنی الکلی',
    'مکمل غذایی',
    'دارو',
    'محصول دخانی یا نیکوتینی',
    'محصول مراقبت شخصی',
    'غذای حیوانات',
    'محصول خانگی',
    'محصول غیرغذایی',
    'محصول طبقه‌بندی‌نشده',
  ],
  'hi': [
    'खाद्य उत्पाद',
    'पेय',
    'मादक पेय',
    'आहार अनुपूरक',
    'दवा',
    'तंबाकू या निकोटीन उत्पाद',
    'व्यक्तिगत देखभाल उत्पाद',
    'पालतू पशु आहार',
    'घरेलू उत्पाद',
    'गैर-खाद्य उत्पाद',
    'अवर्गीकृत उत्पाद',
  ],
  'id': [
    'Produk makanan',
    'Minuman',
    'Minuman beralkohol',
    'Suplemen makanan',
    'Obat',
    'Produk tembakau atau nikotin',
    'Produk perawatan pribadi',
    'Makanan hewan',
    'Produk rumah tangga',
    'Produk nonmakanan',
    'Produk belum terklasifikasi',
  ],
  'ms': [
    'Produk makanan',
    'Minuman',
    'Minuman beralkohol',
    'Suplemen pemakanan',
    'Ubat',
    'Produk tembakau atau nikotin',
    'Produk penjagaan diri',
    'Makanan haiwan',
    'Produk isi rumah',
    'Produk bukan makanan',
    'Produk tidak dikelaskan',
  ],
  'ja': [
    '食品',
    '飲料',
    'アルコール飲料',
    '栄養補助食品',
    '医薬品',
    'たばこ・ニコチン製品',
    'パーソナルケア製品',
    'ペットフード',
    '家庭用品',
    '非食品',
    '未分類の製品',
  ],
  'ko': [
    '식품',
    '음료',
    '주류',
    '건강 보조 식품',
    '의약품',
    '담배 또는 니코틴 제품',
    '개인 관리 제품',
    '반려동물 사료',
    '가정용품',
    '비식품',
    '분류되지 않은 제품',
  ],
  'zh': [
    '食品',
    '饮料',
    '酒精饮料',
    '膳食补充剂',
    '药品',
    '烟草或尼古丁产品',
    '个人护理产品',
    '宠物食品',
    '家居用品',
    '非食品',
    '未分类产品',
  ],
  'ru': [
    'Пищевой продукт',
    'Напиток',
    'Алкогольный напиток',
    'Пищевая добавка',
    'Лекарство',
    'Табачное или никотиновое изделие',
    'Средство личной гигиены',
    'Корм для животных',
    'Бытовой товар',
    'Непищевой товар',
    'Неклассифицированный товар',
  ],
  'bn': [
    'খাদ্যপণ্য',
    'পানীয়',
    'অ্যালকোহলযুক্ত পানীয়',
    'খাদ্য সম্পূরক',
    'ওষুধ',
    'তামাক বা নিকোটিন পণ্য',
    'ব্যক্তিগত যত্ন পণ্য',
    'পোষা প্রাণীর খাবার',
    'গৃহস্থালি পণ্য',
    'খাদ্য নয় এমন পণ্য',
    'শ্রেণিবিহীন পণ্য',
  ],
  'vi': [
    'Thực phẩm',
    'Đồ uống',
    'Đồ uống có cồn',
    'Thực phẩm bổ sung',
    'Thuốc',
    'Sản phẩm thuốc lá hoặc nicotine',
    'Sản phẩm chăm sóc cá nhân',
    'Thức ăn thú cưng',
    'Sản phẩm gia dụng',
    'Sản phẩm phi thực phẩm',
    'Sản phẩm chưa phân loại',
  ],
  'th': [
    'ผลิตภัณฑ์อาหาร',
    'เครื่องดื่ม',
    'เครื่องดื่มแอลกอฮอล์',
    'อาหารเสริม',
    'ยา',
    'ผลิตภัณฑ์ยาสูบหรือนิโคติน',
    'ผลิตภัณฑ์ดูแลส่วนบุคคล',
    'อาหารสัตว์เลี้ยง',
    'ผลิตภัณฑ์ในครัวเรือน',
    'ผลิตภัณฑ์ที่ไม่ใช่อาหาร',
    'ผลิตภัณฑ์ที่ยังไม่จัดประเภท',
  ],
  'pl': [
    'Produkt spożywczy',
    'Napój',
    'Napój alkoholowy',
    'Suplement diety',
    'Lek',
    'Produkt tytoniowy lub nikotynowy',
    'Produkt do higieny osobistej',
    'Karma dla zwierząt',
    'Produkt gospodarstwa domowego',
    'Produkt niespożywczy',
    'Produkt niesklasyfikowany',
  ],
  'nl': [
    'Voedingsmiddel',
    'Drank',
    'Alcoholische drank',
    'Voedingssupplement',
    'Geneesmiddel',
    'Tabaks- of nicotineproduct',
    'Persoonlijke verzorging',
    'Dierenvoeding',
    'Huishoudelijk product',
    'Niet-voedingsproduct',
    'Niet-geclassificeerd product',
  ],
  'uk': [
    'Харчовий продукт',
    'Напій',
    'Алкогольний напій',
    'Дієтична добавка',
    'Ліки',
    'Тютюновий або нікотиновий виріб',
    'Засіб особистого догляду',
    'Корм для тварин',
    'Побутовий товар',
    'Нехарчовий товар',
    'Некласифікований товар',
  ],
};

const _deepIdentityExplanation = <String, String>{
  'de':
      'Das Produkt wurde erkannt, aber vollständige verlässliche Nährwertdaten fehlen. BIL erfindet keine Schätzwerte.',
  'it':
      'Il prodotto è stato identificato, ma non sono disponibili dati nutrizionali completi e affidabili. BIL non creerà valori stimati.',
  'pt':
      'O produto foi identificado, mas não há dados nutricionais completos e confiáveis. O BIL não criará valores estimados.',
  'ur':
      'پروڈکٹ کی شناخت ہوگئی، مگر مکمل اور قابل اعتماد غذائی معلومات دستیاب نہیں۔ BIL اندازاً قدریں نہیں بنائے گا۔',
  'fa':
      'محصول شناسایی شد، اما داده‌های تغذیه‌ای کامل و قابل اعتماد موجود نیست. BIL مقدار تخمینی نمی‌سازد.',
  'hi':
      'उत्पाद की पहचान हो गई है, लेकिन पूर्ण और विश्वसनीय पोषण डेटा उपलब्ध नहीं है। BIL अनुमानित मान नहीं बनाएगा।',
  'id':
      'Produk teridentifikasi, tetapi data gizi lengkap dan tepercaya tidak tersedia. BIL tidak akan membuat nilai perkiraan.',
  'ms':
      'Produk dikenal pasti, tetapi data pemakanan lengkap dan dipercayai tidak tersedia. BIL tidak akan mencipta nilai anggaran.',
  'ja': '製品は識別されましたが、完全で信頼できる栄養データがありません。BILは推定値を作成しません。',
  'ko': '제품은 식별되었지만 완전하고 신뢰할 수 있는 영양 데이터가 없습니다. BIL은 추정값을 만들지 않습니다.',
  'zh': '已识别该产品，但缺少完整可靠的营养数据。BIL 不会生成估算值。',
  'ru':
      'Товар распознан, но полные и надёжные данные о питании отсутствуют. BIL не создаёт приблизительные значения.',
  'bn':
      'পণ্যটি শনাক্ত হয়েছে, কিন্তু সম্পূর্ণ ও নির্ভরযোগ্য পুষ্টি তথ্য নেই। BIL আনুমানিক মান তৈরি করবে না।',
  'vi':
      'Đã nhận diện sản phẩm nhưng chưa có dữ liệu dinh dưỡng đầy đủ và đáng tin cậy. BIL sẽ không tạo giá trị ước tính.',
  'th':
      'ระบุผลิตภัณฑ์แล้ว แต่ไม่มีข้อมูลโภชนาการที่ครบถ้วนและเชื่อถือได้ BIL จะไม่สร้างค่าประมาณ',
  'pl':
      'Produkt rozpoznano, ale brak pełnych i wiarygodnych danych żywieniowych. BIL nie utworzy wartości szacunkowych.',
  'nl':
      'Het product is herkend, maar volledige en betrouwbare voedingsgegevens ontbreken. BIL maakt geen schattingen.',
  'uk':
      'Товар розпізнано, але повні й надійні харчові дані відсутні. BIL не створює приблизних значень.',
};
