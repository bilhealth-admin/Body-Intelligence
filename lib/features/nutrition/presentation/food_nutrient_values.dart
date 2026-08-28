part of '../food_page.dart';

class _FoodNutrientValue {
  const _FoodNutrientValue({
    required this.nutrient,
    required this.value,
    required this.unit,
  });

  final FoodNutrient nutrient;
  final double value;
  final String unit;
}

class _FoodNutrientSummary extends StatelessWidget {
  const _FoodNutrientSummary({required this.food, this.expanded = false});

  final Food food;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) return _CompactFoodNutrientSummary(food: food);
    final values = _allFoodNutrients(food);
    final calories = values
        .where((value) => value.nutrient == FoodNutrient.calories)
        .toList(growable: false);
    final premiumValues = values
        .where((value) => value.nutrient != FoodNutrient.calories)
        .toList(growable: false);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in calories)
          _NutrientValuePill(
            food: food,
            nutrientValue: value,
            expanded: expanded,
          ),
        if (premiumValues.isNotEmpty)
          PremiumNutritionGlass(
            key: Key(
              expanded
                  ? 'food-catalog-nutrition-facts-glass'
                  : 'food-catalog-macros-glass',
            ),
            compact: !expanded,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: premiumValues
                  .map(
                    (value) => _NutrientValuePill(
                      food: food,
                      nutrientValue: value,
                      expanded: expanded,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class _CompactFoodNutrientSummary extends StatelessWidget {
  const _CompactFoodNutrientSummary({required this.food});

  final Food food;

  @override
  Widget build(BuildContext context) {
    final summary = _summaryNutrients(food);
    final calories = summary.first;
    final macros = summary
        .where(
          (value) => const {
            FoodNutrient.protein,
            FoodNutrient.carbohydrates,
            FoodNutrient.fat,
          }.contains(value.nutrient),
        )
        .toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: _CompactNutrientMetric(food: food, nutrientValue: calories),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PremiumNutritionGlass(
            key: const Key('food-catalog-macros-glass'),
            compact: true,
            borderRadius: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: .56),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    for (final macro in macros)
                      Expanded(
                        child: _CompactNutrientMetric(
                          food: food,
                          nutrientValue: macro,
                          bare: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactNutrientMetric extends StatelessWidget {
  const _CompactNutrientMetric({
    required this.food,
    required this.nutrientValue,
    this.bare = false,
  });

  final Food food;
  final _FoodNutrientValue nutrientValue;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = _foodNutrientKnown(food, nutrientValue.nutrient);
    final label = _foodNutrientLabel(context, nutrientValue.nutrient);
    final value = known
        ? '${_localizedNutrientNumber(context, nutrientValue.value)} ${nutrientValue.unit}'
        : '—';
    final metric = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textDirection: TextDirection.ltr,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: '$label, $value',
      child: bare
          ? metric
          : DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: .42),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: .16),
                ),
              ),
              child: metric,
            ),
    );
  }
}

class _NutrientValuePill extends StatelessWidget {
  const _NutrientValuePill({
    required this.food,
    required this.nutrientValue,
    required this.expanded,
  });

  final Food food;
  final _FoodNutrientValue nutrientValue;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = _foodNutrientKnown(food, nutrientValue.nutrient);
    final label = _foodNutrientLabel(context, nutrientValue.nutrient);
    final value = known
        ? '${_localizedNutrientNumber(context, nutrientValue.value)} ${nutrientValue.unit}'
        : _foodValueCopy(context, 'Not available');
    return Semantics(
      label: '$label, $value',
      child: Container(
        constraints: BoxConstraints(minWidth: expanded ? 126 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: known
              ? scheme.primaryContainer.withValues(alpha: 0.42)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: known
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.outlineVariant,
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            children: [
              TextSpan(text: '$label  '),
              TextSpan(
                text: value,
                style: TextStyle(
                  color: known ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<_FoodNutrientValue> _summaryNutrients(Food food) => [
  _FoodNutrientValue(
    nutrient: FoodNutrient.calories,
    value: food.calories,
    unit: 'kcal',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.protein,
    value: food.protein,
    unit: 'g',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.carbohydrates,
    value: food.carbs,
    unit: 'g',
  ),
  _FoodNutrientValue(nutrient: FoodNutrient.fat, value: food.fats, unit: 'g'),
];

List<_FoodNutrientValue> _allFoodNutrients(Food food) => [
  ..._summaryNutrients(food),
  _FoodNutrientValue(
    nutrient: FoodNutrient.sodium,
    value: food.sodium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.potassium,
    value: food.potassium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.fiber,
    value: food.fiber,
    unit: 'g',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.sugar,
    value: food.sugar,
    unit: 'g',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.calcium,
    value: food.calcium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.magnesium,
    value: food.magnesium,
    unit: 'mg',
  ),
  _FoodNutrientValue(
    nutrient: FoodNutrient.phosphorus,
    value: food.phosphorus,
    unit: 'mg',
  ),
  _FoodNutrientValue(nutrient: FoodNutrient.iron, value: food.iron, unit: 'mg'),
  _FoodNutrientValue(
    nutrient: FoodNutrient.vitaminC,
    value: food.vitaminC,
    unit: 'mg',
  ),
];

bool _foodNutrientKnown(Food food, FoodNutrient nutrient) {
  final value = switch (nutrient) {
    FoodNutrient.calories => food.calories,
    FoodNutrient.protein => food.protein,
    FoodNutrient.carbohydrates => food.carbs,
    FoodNutrient.fat => food.fats,
    FoodNutrient.fiber => food.fiber,
    FoodNutrient.sugar => food.sugar,
    FoodNutrient.sodium => food.sodium,
    FoodNutrient.potassium => food.potassium,
    FoodNutrient.calcium => food.calcium,
    FoodNutrient.magnesium => food.magnesium,
    FoodNutrient.phosphorus => food.phosphorus,
    FoodNutrient.iron => food.iron,
    FoodNutrient.vitaminC => food.vitaminC,
  };
  final maskTracksNutrient =
      nutrient != FoodNutrient.iron && nutrient != FoodNutrient.vitaminC;
  if (maskTracksNutrient &&
      UnifiedFood.evidenceFromMask(food.nutrientEvidenceMask, nutrient)) {
    return true;
  }
  // Old pre-evidence rows can still prove a non-zero value. Zero without a bit
  // is ambiguous and must never be presented as a measured nutrient value.
  return value != 0;
}

String _localizedNutrientNumber(BuildContext context, double value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final pattern = value.abs() >= 100 ? '0' : '0.#';
  return NumberFormat(pattern, locale).format(value);
}

String _foodNutrientLabel(BuildContext context, FoodNutrient nutrient) {
  final key = switch (nutrient) {
    FoodNutrient.calories => 'Calories',
    FoodNutrient.protein => 'Protein',
    FoodNutrient.carbohydrates => 'Carbs',
    FoodNutrient.fat => 'Fat',
    FoodNutrient.fiber => 'Fiber',
    FoodNutrient.sugar => 'Sugar',
    FoodNutrient.sodium => 'Sodium',
    FoodNutrient.potassium => 'Potassium',
    FoodNutrient.calcium => 'Calcium',
    FoodNutrient.magnesium => 'Magnesium',
    FoodNutrient.phosphorus => 'Phosphorus',
    FoodNutrient.iron => 'Iron',
    FoodNutrient.vitaminC => 'Vitamin C',
  };
  return _foodValueCopy(context, key);
}

String _foodValueCopy(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _foodValueTranslations[code]?[key] ??
      _foodValueTranslations['en']![key]!;
}

const Map<String, Map<String, String>> _foodValueTranslations = {
  'en': {
    'Calories': 'Calories',
    'Protein': 'Protein',
    'Carbs': 'Carbs',
    'Fat': 'Fat',
    'Fiber': 'Fiber',
    'Sugar': 'Sugar',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnesium',
    'Phosphorus': 'Phosphorus',
    'Iron': 'Iron',
    'Vitamin C': 'Vitamin C',
    'Not available': 'Not available',
  },
  'ar': {
    'Calories': 'السعرات',
    'Protein': 'البروتين',
    'Carbs': 'الكربوهيدرات',
    'Fat': 'الدهون',
    'Fiber': 'الألياف',
    'Sugar': 'السكر',
    'Sodium': 'الصوديوم',
    'Potassium': 'البوتاسيوم',
    'Calcium': 'الكالسيوم',
    'Magnesium': 'المغنيسيوم',
    'Phosphorus': 'الفوسفور',
    'Iron': 'الحديد',
    'Vitamin C': 'فيتامين C',
    'Not available': 'غير متوفر',
  },
  'fr': {
    'Calories': 'Calories',
    'Protein': 'Protéines',
    'Carbs': 'Glucides',
    'Fat': 'Lipides',
    'Fiber': 'Fibres',
    'Sugar': 'Sucres',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnésium',
    'Phosphorus': 'Phosphore',
    'Iron': 'Fer',
    'Vitamin C': 'Vitamine C',
    'Not available': 'Non disponible',
  },
  'es': {
    'Calories': 'Calorías',
    'Protein': 'Proteína',
    'Carbs': 'Carbohidratos',
    'Fat': 'Grasa',
    'Fiber': 'Fibra',
    'Sugar': 'Azúcar',
    'Sodium': 'Sodio',
    'Potassium': 'Potasio',
    'Calcium': 'Calcio',
    'Magnesium': 'Magnesio',
    'Phosphorus': 'Fósforo',
    'Iron': 'Hierro',
    'Vitamin C': 'Vitamina C',
    'Not available': 'No disponible',
  },
  'tr': {
    'Calories': 'Kalori',
    'Protein': 'Protein',
    'Carbs': 'Karbonhidrat',
    'Fat': 'Yağ',
    'Fiber': 'Lif',
    'Sugar': 'Şeker',
    'Sodium': 'Sodyum',
    'Potassium': 'Potasyum',
    'Calcium': 'Kalsiyum',
    'Magnesium': 'Magnezyum',
    'Phosphorus': 'Fosfor',
    'Iron': 'Demir',
    'Vitamin C': 'C vitamini',
    'Not available': 'Mevcut değil',
  },
  'de': {
    'Calories': 'Kalorien',
    'Protein': 'Eiweiß',
    'Carbs': 'Kohlenhydrate',
    'Fat': 'Fett',
    'Fiber': 'Ballaststoffe',
    'Sugar': 'Zucker',
    'Sodium': 'Natrium',
    'Potassium': 'Kalium',
    'Calcium': 'Kalzium',
    'Magnesium': 'Magnesium',
    'Phosphorus': 'Phosphor',
    'Iron': 'Eisen',
    'Vitamin C': 'Vitamin C',
    'Not available': 'Nicht verfügbar',
  },
  'it': {
    'Calories': 'Calorie',
    'Protein': 'Proteine',
    'Carbs': 'Carboidrati',
    'Fat': 'Grassi',
    'Fiber': 'Fibre',
    'Sugar': 'Zuccheri',
    'Sodium': 'Sodio',
    'Potassium': 'Potassio',
    'Calcium': 'Calcio',
    'Magnesium': 'Magnesio',
    'Phosphorus': 'Fosforo',
    'Iron': 'Ferro',
    'Vitamin C': 'Vitamina C',
    'Not available': 'Non disponibile',
  },
  'pt': {
    'Calories': 'Calorias',
    'Protein': 'Proteína',
    'Carbs': 'Carboidratos',
    'Fat': 'Gordura',
    'Fiber': 'Fibra',
    'Sugar': 'Açúcar',
    'Sodium': 'Sódio',
    'Potassium': 'Potássio',
    'Calcium': 'Cálcio',
    'Magnesium': 'Magnésio',
    'Phosphorus': 'Fósforo',
    'Iron': 'Ferro',
    'Vitamin C': 'Vitamina C',
    'Not available': 'Não disponível',
  },
  'ru': {
    'Calories': 'Калории',
    'Protein': 'Белок',
    'Carbs': 'Углеводы',
    'Fat': 'Жиры',
    'Fiber': 'Клетчатка',
    'Sugar': 'Сахар',
    'Sodium': 'Натрий',
    'Potassium': 'Калий',
    'Calcium': 'Кальций',
    'Magnesium': 'Магний',
    'Phosphorus': 'Фосфор',
    'Iron': 'Железо',
    'Vitamin C': 'Витамин C',
    'Not available': 'Нет данных',
  },
  'uk': {
    'Calories': 'Калорії',
    'Protein': 'Білок',
    'Carbs': 'Вуглеводи',
    'Fat': 'Жири',
    'Fiber': 'Клітковина',
    'Sugar': 'Цукор',
    'Sodium': 'Натрій',
    'Potassium': 'Калій',
    'Calcium': 'Кальцій',
    'Magnesium': 'Магній',
    'Phosphorus': 'Фосфор',
    'Iron': 'Залізо',
    'Vitamin C': 'Вітамін C',
    'Not available': 'Немає даних',
  },
  'ja': {
    'Calories': 'カロリー',
    'Protein': 'たんぱく質',
    'Carbs': '炭水化物',
    'Fat': '脂質',
    'Fiber': '食物繊維',
    'Sugar': '糖類',
    'Sodium': 'ナトリウム',
    'Potassium': 'カリウム',
    'Calcium': 'カルシウム',
    'Magnesium': 'マグネシウム',
    'Phosphorus': 'リン',
    'Iron': '鉄',
    'Vitamin C': 'ビタミンC',
    'Not available': 'データなし',
  },
  'ko': {
    'Calories': '칼로리',
    'Protein': '단백질',
    'Carbs': '탄수화물',
    'Fat': '지방',
    'Fiber': '식이섬유',
    'Sugar': '당류',
    'Sodium': '나트륨',
    'Potassium': '칼륨',
    'Calcium': '칼슘',
    'Magnesium': '마그네슘',
    'Phosphorus': '인',
    'Iron': '철',
    'Vitamin C': '비타민 C',
    'Not available': '데이터 없음',
  },
  'zh': {
    'Calories': '热量',
    'Protein': '蛋白质',
    'Carbs': '碳水化合物',
    'Fat': '脂肪',
    'Fiber': '膳食纤维',
    'Sugar': '糖',
    'Sodium': '钠',
    'Potassium': '钾',
    'Calcium': '钙',
    'Magnesium': '镁',
    'Phosphorus': '磷',
    'Iron': '铁',
    'Vitamin C': '维生素C',
    'Not available': '暂无数据',
  },
  'hi': {
    'Calories': 'कैलोरी',
    'Protein': 'प्रोटीन',
    'Carbs': 'कार्बोहाइड्रेट',
    'Fat': 'वसा',
    'Fiber': 'फाइबर',
    'Sugar': 'चीनी',
    'Sodium': 'सोडियम',
    'Potassium': 'पोटैशियम',
    'Calcium': 'कैल्शियम',
    'Magnesium': 'मैग्नीशियम',
    'Phosphorus': 'फॉस्फोरस',
    'Iron': 'आयरन',
    'Vitamin C': 'विटामिन C',
    'Not available': 'डेटा उपलब्ध नहीं',
  },
  'id': {
    'Calories': 'Kalori',
    'Protein': 'Protein',
    'Carbs': 'Karbohidrat',
    'Fat': 'Lemak',
    'Fiber': 'Serat',
    'Sugar': 'Gula',
    'Sodium': 'Natrium',
    'Potassium': 'Kalium',
    'Calcium': 'Kalsium',
    'Magnesium': 'Magnesium',
    'Phosphorus': 'Fosfor',
    'Iron': 'Zat besi',
    'Vitamin C': 'Vitamin C',
    'Not available': 'Tidak tersedia',
  },
  'ms': {
    'Calories': 'Kalori',
    'Protein': 'Protein',
    'Carbs': 'Karbohidrat',
    'Fat': 'Lemak',
    'Fiber': 'Serat',
    'Sugar': 'Gula',
    'Sodium': 'Natrium',
    'Potassium': 'Kalium',
    'Calcium': 'Kalsium',
    'Magnesium': 'Magnesium',
    'Phosphorus': 'Fosfor',
    'Iron': 'Zat besi',
    'Vitamin C': 'Vitamin C',
    'Not available': 'Tidak tersedia',
  },
  'nl': {
    'Calories': 'Calorieën',
    'Protein': 'Eiwit',
    'Carbs': 'Koolhydraten',
    'Fat': 'Vet',
    'Fiber': 'Vezels',
    'Sugar': 'Suiker',
    'Sodium': 'Natrium',
    'Potassium': 'Kalium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnesium',
    'Phosphorus': 'Fosfor',
    'Iron': 'IJzer',
    'Vitamin C': 'Vitamine C',
    'Not available': 'Niet beschikbaar',
  },
  'pl': {
    'Calories': 'Kalorie',
    'Protein': 'Białko',
    'Carbs': 'Węglowodany',
    'Fat': 'Tłuszcz',
    'Fiber': 'Błonnik',
    'Sugar': 'Cukier',
    'Sodium': 'Sód',
    'Potassium': 'Potas',
    'Calcium': 'Wapń',
    'Magnesium': 'Magnez',
    'Phosphorus': 'Fosfor',
    'Iron': 'Żelazo',
    'Vitamin C': 'Witamina C',
    'Not available': 'Brak danych',
  },
  'vi': {
    'Calories': 'Calo',
    'Protein': 'Chất đạm',
    'Carbs': 'Carb',
    'Fat': 'Chất béo',
    'Fiber': 'Chất xơ',
    'Sugar': 'Đường',
    'Sodium': 'Natri',
    'Potassium': 'Kali',
    'Calcium': 'Canxi',
    'Magnesium': 'Magiê',
    'Phosphorus': 'Phốt pho',
    'Iron': 'Sắt',
    'Vitamin C': 'Vitamin C',
    'Not available': 'Không có dữ liệu',
  },
  'th': {
    'Calories': 'แคลอรี',
    'Protein': 'โปรตีน',
    'Carbs': 'คาร์โบไฮเดรต',
    'Fat': 'ไขมัน',
    'Fiber': 'ใยอาหาร',
    'Sugar': 'น้ำตาล',
    'Sodium': 'โซเดียม',
    'Potassium': 'โพแทสเซียม',
    'Calcium': 'แคลเซียม',
    'Magnesium': 'แมกนีเซียม',
    'Phosphorus': 'ฟอสฟอรัส',
    'Iron': 'ธาตุเหล็ก',
    'Vitamin C': 'วิตามินซี',
    'Not available': 'ไม่มีข้อมูล',
  },
  'fa': {
    'Calories': 'کالری',
    'Protein': 'پروتئین',
    'Carbs': 'کربوهیدرات',
    'Fat': 'چربی',
    'Fiber': 'فیبر',
    'Sugar': 'قند',
    'Sodium': 'سدیم',
    'Potassium': 'پتاسیم',
    'Calcium': 'کلسیم',
    'Magnesium': 'منیزیم',
    'Phosphorus': 'فسفر',
    'Iron': 'آهن',
    'Vitamin C': 'ویتامین C',
    'Not available': 'داده‌ای موجود نیست',
  },
  'ur': {
    'Calories': 'کیلوریز',
    'Protein': 'پروٹین',
    'Carbs': 'کاربوہائیڈریٹس',
    'Fat': 'چکنائی',
    'Fiber': 'فائبر',
    'Sugar': 'شکر',
    'Sodium': 'سوڈیم',
    'Potassium': 'پوٹاشیم',
    'Calcium': 'کیلشیم',
    'Magnesium': 'میگنیشیم',
    'Phosphorus': 'فاسفورس',
    'Iron': 'آئرن',
    'Vitamin C': 'وٹامن C',
    'Not available': 'ڈیٹا دستیاب نہیں',
  },
  'bn': {
    'Calories': 'ক্যালোরি',
    'Protein': 'প্রোটিন',
    'Carbs': 'কার্বোহাইড্রেট',
    'Fat': 'চর্বি',
    'Fiber': 'আঁশ',
    'Sugar': 'চিনি',
    'Sodium': 'সোডিয়াম',
    'Potassium': 'পটাশিয়াম',
    'Calcium': 'ক্যালসিয়াম',
    'Magnesium': 'ম্যাগনেসিয়াম',
    'Phosphorus': 'ফসফরাস',
    'Iron': 'আয়রন',
    'Vitamin C': 'ভিটামিন C',
    'Not available': 'তথ্য নেই',
  },
};
