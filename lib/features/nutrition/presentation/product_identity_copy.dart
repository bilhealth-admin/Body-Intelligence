import '../domain/product_identity.dart';

String productKindLabel(
  ProductKind kind, {
  required bool arabic,
  String? languageCode,
}) {
  final code = _resolvedLanguage(languageCode, arabic);
  final labels = _productLabels[kind]!;
  return labels[code] ?? labels['en']!;
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
  final explanation = _identityExplanation[code] ?? _identityExplanation['en']!;
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
