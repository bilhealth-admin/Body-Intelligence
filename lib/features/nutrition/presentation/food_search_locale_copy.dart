part of '../food_page.dart';

String _foodSearchText(BuildContext context, String english) {
  final locale = Localizations.localeOf(context);
  final translations = _foodSearchCopy[english];
  return translations?[locale.toLanguageTag()] ??
      translations?[locale.languageCode] ??
      context.strings.text(english);
}

const _foodSearchCopy = <String, Map<String, String>>{
  'English, Arabic, keyword, or barcode': {
    'fr': 'Anglais, arabe, mot-clé ou code-barres',
    'es': 'Inglés, árabe, palabra clave o código de barras',
    'tr': 'İngilizce, Arapça, anahtar kelime veya barkod',
  },
  'No local food matches this search': {
    'fr': 'Aucun aliment local ne correspond à cette recherche',
    'es': 'Ningún alimento local coincide con esta búsqueda',
    'tr': 'Bu aramayla eşleşen yerel yiyecek yok',
  },
  'BIL will not invent a match. Create a custom food from verified label evidence.': {
    'fr':
        'BIL n’inventera pas de correspondance. Créez un aliment personnalisé à partir d’une étiquette vérifiée.',
    'es':
        'BIL no inventará una coincidencia. Crea un alimento personalizado a partir de una etiqueta verificada.',
    'tr':
        'BIL eşleşme uydurmaz. Doğrulanmış etiket bilgileriyle özel bir yiyecek oluşturun.',
  },
};
