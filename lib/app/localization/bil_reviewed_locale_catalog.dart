import 'bil_health_glossary.dart';

class BilLocaleCatalogReview {
  const BilLocaleCatalogReview({
    required this.localeTag,
    required this.values,
    required this.humanReviewed,
    required this.smokePassed,
  });

  final String localeTag;
  final Map<String, String> values;
  final bool humanReviewed;
  final bool smokePassed;

  bool get glossaryComplete {
    final requiredKeys = BilHealthGlossary.terms
        .map((term) => term.key)
        .toSet();
    return values.keys.toSet().containsAll(requiredKeys) &&
        requiredKeys.every((key) => values[key]?.trim().isNotEmpty == true);
  }

  bool get eligibleForProduction =>
      glossaryComplete && humanReviewed && smokePassed;
}

/// Phase-1 translator-review drafts. These are deliberately separate from
/// AppLocalizations and cannot be selected until review + smoke gates pass.
abstract final class BilPhaseOneLocaleCatalogs {
  static const catalogs = <BilLocaleCatalogReview>[
    BilLocaleCatalogReview(
      localeTag: 'de',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Kalorien',
        'protein': 'Protein',
        'carbohydrates': 'Kohlenhydrate',
        'fat': 'Fett',
        'sodium': 'Natrium',
        'serving': 'Portion',
        'weight': 'Gewicht',
        'waist': 'Taillenumfang',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Unsicheres Ergebnis',
        'not_medical_diagnosis': 'Keine medizinische Diagnose',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'it',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Calorie',
        'protein': 'Proteine',
        'carbohydrates': 'Carboidrati',
        'fat': 'Grassi',
        'sodium': 'Sodio',
        'serving': 'Porzione',
        'weight': 'Peso',
        'waist': 'Circonferenza vita',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Risultato incerto',
        'not_medical_diagnosis': 'Non è una diagnosi medica',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'pt-BR',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Calorias',
        'protein': 'Proteína',
        'carbohydrates': 'Carboidratos',
        'fat': 'Gorduras',
        'sodium': 'Sódio',
        'serving': 'Porção',
        'weight': 'Peso',
        'waist': 'Circunferência da cintura',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Resultado incerto',
        'not_medical_diagnosis': 'Não é um diagnóstico médico',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'pt-PT',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Calorias',
        'protein': 'Proteína',
        'carbohydrates': 'Hidratos de carbono',
        'fat': 'Gordura',
        'sodium': 'Sódio',
        'serving': 'Porção',
        'weight': 'Peso',
        'waist': 'Perímetro da cintura',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Resultado incerto',
        'not_medical_diagnosis': 'Não é um diagnóstico médico',
      },
    ),
  ];

  static BilLocaleCatalogReview? forTag(String tag) {
    final normalized = tag.replaceAll('_', '-').toLowerCase();
    for (final catalog in catalogs) {
      if (catalog.localeTag.toLowerCase() == normalized) return catalog;
    }
    return null;
  }

  /// Runtime-safe access. Draft copy is never returned until both independent
  /// release gates have been recorded on that exact regional catalog.
  static Map<String, String>? productionValuesForTag(String tag) {
    final catalog = forTag(tag);
    if (catalog == null || !catalog.eligibleForProduction) return null;
    return Map<String, String>.unmodifiable(catalog.values);
  }
}

/// Mandatory script-expansion review drafts. They have production-shaped key
/// coverage, but remain unreachable at runtime until professional review and
/// device smoke are explicitly recorded for each exact script tag.
abstract final class BilMandatoryScriptLocaleCatalogs {
  static const catalogs = <BilLocaleCatalogReview>[
    BilLocaleCatalogReview(
      localeTag: 'ru',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Калории',
        'protein': 'Белки',
        'carbohydrates': 'Углеводы',
        'fat': 'Жиры',
        'sodium': 'Натрий',
        'serving': 'Порция',
        'weight': 'Вес',
        'waist': 'Окружность талии',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Неопределённый результат',
        'not_medical_diagnosis': 'Не является медицинским диагнозом',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'ur',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'کیلوریز',
        'protein': 'پروٹین',
        'carbohydrates': 'کاربوہائیڈریٹس',
        'fat': 'چکنائی',
        'sodium': 'سوڈیم',
        'serving': 'خوراک کی مقدار',
        'weight': 'وزن',
        'waist': 'کمر کا گھیر',
        'premium': 'پریمیم',
        'premium_ai_coach': 'پریمیم AI کوچ',
        'ai_boost': 'BIL AI بوسٹ',
        'uncertain': 'غیر یقینی نتیجہ',
        'not_medical_diagnosis': 'یہ طبی تشخیص نہیں ہے',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'fa',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'کالری',
        'protein': 'پروتئین',
        'carbohydrates': 'کربوهیدرات',
        'fat': 'چربی',
        'sodium': 'سدیم',
        'serving': 'وعده',
        'weight': 'وزن',
        'waist': 'دور کمر',
        'premium': 'پریمیوم',
        'premium_ai_coach': 'مربی هوش مصنوعی پریمیوم',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'نتیجه نامطمئن',
        'not_medical_diagnosis': 'تشخیص پزشکی نیست',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'hi',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'कैलोरी',
        'protein': 'प्रोटीन',
        'carbohydrates': 'कार्बोहाइड्रेट',
        'fat': 'वसा',
        'sodium': 'सोडियम',
        'serving': 'परोसने की मात्रा',
        'weight': 'वज़न',
        'waist': 'कमर की परिधि',
        'premium': 'प्रीमियम',
        'premium_ai_coach': 'प्रीमियम AI कोच',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'अनिश्चित परिणाम',
        'not_medical_diagnosis': 'यह चिकित्सीय निदान नहीं है',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'ja',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'カロリー',
        'protein': 'たんぱく質',
        'carbohydrates': '炭水化物',
        'fat': '脂質',
        'sodium': 'ナトリウム',
        'serving': '1食分',
        'weight': '体重',
        'waist': '腹囲',
        'premium': 'プレミアム',
        'premium_ai_coach': 'プレミアムAIコーチ',
        'ai_boost': 'BIL AI Boost',
        'uncertain': '不確かな結果',
        'not_medical_diagnosis': '医療診断ではありません',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'ko',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': '칼로리',
        'protein': '단백질',
        'carbohydrates': '탄수화물',
        'fat': '지방',
        'sodium': '나트륨',
        'serving': '1회 제공량',
        'weight': '체중',
        'waist': '허리둘레',
        'premium': '프리미엄',
        'premium_ai_coach': '프리미엄 AI 코치',
        'ai_boost': 'BIL AI Boost',
        'uncertain': '불확실한 결과',
        'not_medical_diagnosis': '의학적 진단이 아닙니다',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'zh-Hans',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': '卡路里',
        'protein': '蛋白质',
        'carbohydrates': '碳水化合物',
        'fat': '脂肪',
        'sodium': '钠',
        'serving': '每份',
        'weight': '体重',
        'waist': '腰围',
        'premium': '高级版',
        'premium_ai_coach': '高级版 AI 教练',
        'ai_boost': 'BIL AI Boost',
        'uncertain': '结果不确定',
        'not_medical_diagnosis': '不构成医疗诊断',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'zh-Hant',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': '卡路里',
        'protein': '蛋白質',
        'carbohydrates': '碳水化合物',
        'fat': '脂肪',
        'sodium': '鈉',
        'serving': '每份',
        'weight': '體重',
        'waist': '腰圍',
        'premium': '進階版',
        'premium_ai_coach': '進階版 AI 教練',
        'ai_boost': 'BIL AI Boost',
        'uncertain': '結果不確定',
        'not_medical_diagnosis': '不構成醫療診斷',
      },
    ),
  ];

  static BilLocaleCatalogReview? forTag(String tag) {
    final normalized = tag.replaceAll('_', '-').toLowerCase();
    for (final catalog in catalogs) {
      if (catalog.localeTag.toLowerCase() == normalized) return catalog;
    }
    return null;
  }

  static Map<String, String>? productionValuesForTag(String tag) {
    final catalog = forTag(tag);
    if (catalog == null || !catalog.eligibleForProduction) return null;
    return Map<String, String>.unmodifiable(catalog.values);
  }
}

abstract final class BilMandatorySoutheastAsiaLocaleCatalogs {
  static const catalogs = <BilLocaleCatalogReview>[
    BilLocaleCatalogReview(
      localeTag: 'id',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Kalori',
        'protein': 'Protein',
        'carbohydrates': 'Karbohidrat',
        'fat': 'Lemak',
        'sodium': 'Natrium',
        'serving': 'Porsi',
        'weight': 'Berat badan',
        'waist': 'Lingkar pinggang',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Hasil belum pasti',
        'not_medical_diagnosis': 'Bukan diagnosis medis',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'ms',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Kalori',
        'protein': 'Protein',
        'carbohydrates': 'Karbohidrat',
        'fat': 'Lemak',
        'sodium': 'Natrium',
        'serving': 'Hidangan',
        'weight': 'Berat badan',
        'waist': 'Lilitan pinggang',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Keputusan tidak pasti',
        'not_medical_diagnosis': 'Bukan diagnosis perubatan',
      },
    ),
  ];

  static BilLocaleCatalogReview? forTag(String tag) {
    final normalized = tag.replaceAll('_', '-').toLowerCase();
    for (final catalog in catalogs) {
      if (catalog.localeTag.toLowerCase() == normalized) return catalog;
    }
    return null;
  }

  static Map<String, String>? productionValuesForTag(String tag) {
    final catalog = forTag(tag);
    if (catalog == null || !catalog.eligibleForProduction) return null;
    return Map<String, String>.unmodifiable(catalog.values);
  }
}

abstract final class BilDraftLocaleCatalogs {
  static List<BilLocaleCatalogReview> get mandatory =>
      List<BilLocaleCatalogReview>.unmodifiable([
        ...BilPhaseOneLocaleCatalogs.catalogs,
        ...BilMandatoryScriptLocaleCatalogs.catalogs,
        ...BilMandatorySoutheastAsiaLocaleCatalogs.catalogs,
      ]);

  static List<BilLocaleCatalogReview> get all =>
      List<BilLocaleCatalogReview>.unmodifiable([
        ...mandatory,
        ...BilHighValueCandidateLocaleCatalogs.catalogs,
      ]);
}

/// Candidate locales stay outside the mandatory and production allow-lists.
/// Drafting them early makes terminology review measurable without claiming
/// support or increasing the release-critical surface.
abstract final class BilHighValueCandidateLocaleCatalogs {
  static const catalogs = <BilLocaleCatalogReview>[
    BilLocaleCatalogReview(
      localeTag: 'pl',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Kalorie',
        'protein': 'Białko',
        'carbohydrates': 'Węglowodany',
        'fat': 'Tłuszcz',
        'sodium': 'Sód',
        'serving': 'Porcja',
        'weight': 'Masa ciała',
        'waist': 'Obwód talii',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Niepewny wynik',
        'not_medical_diagnosis': 'To nie jest diagnoza medyczna',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'nl',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Calorieën',
        'protein': 'Eiwit',
        'carbohydrates': 'Koolhydraten',
        'fat': 'Vet',
        'sodium': 'Natrium',
        'serving': 'Portie',
        'weight': 'Gewicht',
        'waist': 'Tailleomtrek',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Onzeker resultaat',
        'not_medical_diagnosis': 'Geen medische diagnose',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'bn',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'ক্যালোরি',
        'protein': 'প্রোটিন',
        'carbohydrates': 'কার্বোহাইড্রেট',
        'fat': 'চর্বি',
        'sodium': 'সোডিয়াম',
        'serving': 'পরিবেশনের পরিমাণ',
        'weight': 'ওজন',
        'waist': 'কোমরের পরিধি',
        'premium': 'প্রিমিয়াম',
        'premium_ai_coach': 'প্রিমিয়াম AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'অনিশ্চিত ফলাফল',
        'not_medical_diagnosis': 'এটি কোনো চিকিৎসা নির্ণয় নয়',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'vi',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Calo',
        'protein': 'Chất đạm',
        'carbohydrates': 'Carbohydrate',
        'fat': 'Chất béo',
        'sodium': 'Natri',
        'serving': 'Khẩu phần',
        'weight': 'Cân nặng',
        'waist': 'Vòng eo',
        'premium': 'Cao cấp',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Kết quả chưa chắc chắn',
        'not_medical_diagnosis': 'Không phải chẩn đoán y khoa',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'th',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'แคลอรี',
        'protein': 'โปรตีน',
        'carbohydrates': 'คาร์โบไฮเดรต',
        'fat': 'ไขมัน',
        'sodium': 'โซเดียม',
        'serving': 'หนึ่งหน่วยบริโภค',
        'weight': 'น้ำหนัก',
        'waist': 'รอบเอว',
        'premium': 'พรีเมียม',
        'premium_ai_coach': 'พรีเมียม AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'ผลลัพธ์ไม่แน่นอน',
        'not_medical_diagnosis': 'ไม่ใช่การวินิจฉัยทางการแพทย์',
      },
    ),
    BilLocaleCatalogReview(
      localeTag: 'uk',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Калорії',
        'protein': 'Білки',
        'carbohydrates': 'Вуглеводи',
        'fat': 'Жири',
        'sodium': 'Натрій',
        'serving': 'Порція',
        'weight': 'Вага',
        'waist': 'Обхват талії',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'BIL AI Boost',
        'uncertain': 'Непевний результат',
        'not_medical_diagnosis': 'Це не медичний діагноз',
      },
    ),
  ];
}
