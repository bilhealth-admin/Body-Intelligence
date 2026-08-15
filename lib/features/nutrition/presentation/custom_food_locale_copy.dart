part of '../food_page.dart';

const _customFoodAuthored = <String, Map<String, String>>{
  'fr': {
    'Create custom food': 'Créer un aliment personnalisé',
    'Edit custom food': 'Modifier l’aliment personnalisé',
    'English name': 'Nom anglais',
    'Arabic name': 'Nom arabe',
    'Barcode': 'Code-barres',
    'Serving size': 'Taille de portion',
    'Serving unit': 'Unité de portion',
    'Calories': 'Calories',
    'Protein': 'Protéines',
    'Carbohydrates': 'Glucides',
    'Fat': 'Lipides',
    'Fiber': 'Fibres',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnésium',
    'Sugar': 'Sucres',
    'Required': 'Obligatoire',
    'Enter a non-negative number': 'Saisissez un nombre positif ou nul',
    'Enter a valid 8 to 14 digit barcode':
        'Saisissez un code-barres valide de 8 à 14 chiffres',
    'Could not save this food. Review the values and try again.':
        'Impossible d’enregistrer cet aliment. Vérifiez les valeurs et réessayez.',
    'A food with this barcode already exists.':
        'Un aliment avec ce code-barres existe déjà.',
  },
  'es': {
    'Create custom food': 'Crear alimento personalizado',
    'Edit custom food': 'Editar alimento personalizado',
    'English name': 'Nombre en inglés',
    'Arabic name': 'Nombre en árabe',
    'Barcode': 'Código de barras',
    'Serving size': 'Tamaño de porción',
    'Serving unit': 'Unidad de porción',
    'Calories': 'Calorías',
    'Protein': 'Proteína',
    'Carbohydrates': 'Carbohidratos',
    'Fat': 'Grasa',
    'Fiber': 'Fibra',
    'Sodium': 'Sodio',
    'Potassium': 'Potasio',
    'Calcium': 'Calcio',
    'Magnesium': 'Magnesio',
    'Sugar': 'Azúcar',
    'Required': 'Obligatorio',
    'Enter a non-negative number': 'Introduce un número no negativo',
    'Enter a valid 8 to 14 digit barcode':
        'Introduce un código de barras válido de 8 a 14 dígitos',
    'Could not save this food. Review the values and try again.':
        'No se pudo guardar este alimento. Revisa los valores e inténtalo de nuevo.',
    'A food with this barcode already exists.':
        'Ya existe un alimento con este código de barras.',
  },
  'tr': {
    'Create custom food': 'Özel yiyecek oluştur',
    'Edit custom food': 'Özel yiyeceği düzenle',
    'English name': 'İngilizce ad',
    'Arabic name': 'Arapça ad',
    'Barcode': 'Barkod',
    'Serving size': 'Porsiyon boyutu',
    'Serving unit': 'Porsiyon birimi',
    'Calories': 'Kalori',
    'Protein': 'Protein',
    'Carbohydrates': 'Karbonhidrat',
    'Fat': 'Yağ',
    'Fiber': 'Lif',
    'Sodium': 'Sodyum',
    'Potassium': 'Potasyum',
    'Calcium': 'Kalsiyum',
    'Magnesium': 'Magnezyum',
    'Sugar': 'Şeker',
    'Required': 'Gerekli',
    'Enter a non-negative number': 'Negatif olmayan bir sayı girin',
    'Enter a valid 8 to 14 digit barcode':
        '8–14 basamaklı geçerli bir barkod girin',
    'Could not save this food. Review the values and try again.':
        'Bu yiyecek kaydedilemedi. Değerleri gözden geçirip yeniden deneyin.',
    'A food with this barcode already exists.':
        'Bu barkoda sahip bir yiyecek zaten var.',
  },
};

String customFoodText(BuildContext context, String key) {
  final locale = Localizations.localeOf(context).languageCode;
  final authored = customFoodAuthoredValue(locale, key);
  return authored ?? context.strings.text(key);
}

String? customFoodAuthoredValue(String locale, String key) =>
    _customFoodAuthored[locale]?[key];
