part of 'daily_log_summary_widgets.dart';

String _summaryText(BuildContext context, String key) {
  final active = Localizations.localeOf(context);
  final locale = active.languageCode.toLowerCase();
  final english = _dailySummaryCopy['en']?[key] ?? key;
  return _dailySummaryCopy[locale]?[key] ??
      RuntimeCopy.resolve(english, BilLocalePolicy.canonicalTag(active)) ??
      english;
}

const _dailySummaryCopy = <String, Map<String, String>>{
  'en': {
    'today': 'Today',
    'previous': 'Previous day',
    'next': 'Next day',
    'summary': 'Today’s recorded summary',
    'kcal': 'kcal',
    'carbs': 'Carbs',
    'fat': 'Fat',
    'proteinShort': 'Protein',
    'noWater': 'No water recorded',
    'mlWater': 'ml water',
    'protein': 'g protein',
    'water': 'ml water',
    'honest':
        'BIL shows only what you recorded and never fills missing values automatically.',
    'g': 'g',
    'mg': 'mg',
  },
  'ar': {
    'today': 'اليوم',
    'previous': 'اليوم السابق',
    'next': 'اليوم التالي',
    'summary': 'ملخص اليوم المسجّل',
    'kcal': 'سعرة',
    'carbs': 'كربوهيدرات',
    'fat': 'دهون',
    'proteinShort': 'بروتين',
    'noWater': 'لم يُسجّل ماء',
    'mlWater': 'مل ماء',
    'protein': 'جم بروتين',
    'water': 'مل ماء',
    'honest': 'يعرض BIL ما سُجّل فقط، ولا يملأ القيم الناقصة تلقائيًا.',
    'g': 'جم',
    'mg': 'مجم',
  },
  'fr': {
    'today': 'Aujourd’hui',
    'previous': 'Jour précédent',
    'next': 'Jour suivant',
    'summary': 'Résumé enregistré du jour',
    'kcal': 'kcal',
    'carbs': 'Glucides',
    'fat': 'Lipides',
    'proteinShort': 'Protéines',
    'noWater': 'Aucune eau enregistrée',
    'mlWater': 'ml d’eau',
    'protein': 'g de protéines',
    'water': 'ml d’eau',
    'honest':
        'BIL affiche uniquement ce que vous avez enregistré et ne complète jamais automatiquement les valeurs manquantes.',
    'g': 'g',
    'mg': 'mg',
  },
  'es': {
    'today': 'Hoy',
    'previous': 'Día anterior',
    'next': 'Día siguiente',
    'summary': 'Resumen registrado de hoy',
    'kcal': 'kcal',
    'carbs': 'Carbohidratos',
    'fat': 'Grasa',
    'proteinShort': 'Proteína',
    'noWater': 'No hay agua registrada',
    'mlWater': 'ml de agua',
    'protein': 'g de proteína',
    'water': 'ml de agua',
    'honest':
        'BIL solo muestra lo que registraste y nunca completa automáticamente los valores que faltan.',
    'g': 'g',
    'mg': 'mg',
  },
  'tr': {
    'today': 'Bugün',
    'previous': 'Önceki gün',
    'next': 'Sonraki gün',
    'summary': 'Bugünün kayıtlı özeti',
    'kcal': 'kcal',
    'carbs': 'Karbonhidrat',
    'fat': 'Yağ',
    'proteinShort': 'Protein',
    'noWater': 'Su kaydı yok',
    'mlWater': 'ml su',
    'protein': 'g protein',
    'water': 'ml su',
    'honest':
        'BIL yalnızca kaydettiğiniz verileri gösterir ve eksik değerleri otomatik olarak doldurmaz.',
    'g': 'g',
    'mg': 'mg',
  },
};

double? knownNutrientTotal(
  List<MealItem> items,
  TrackedNutrient nutrient,
  double Function(MealItem item) valueOf,
) {
  if (items.isEmpty ||
      items.any(
        (item) =>
            !NutrientEvidenceMask.contains(item.nutrientEvidenceMask, nutrient),
      )) {
    return null;
  }
  return items.fold<double>(0, (total, item) => total + valueOf(item));
}
