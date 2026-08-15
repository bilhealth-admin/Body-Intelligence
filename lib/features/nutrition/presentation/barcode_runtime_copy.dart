class BarcodeRuntimeCopy {
  const BarcodeRuntimeCopy({
    required this.invalidTitle,
    required this.invalidBody,
    required this.notFoundTitle,
    required this.notFoundBody,
    required this.unavailableTitle,
    required this.unavailableBody,
  });

  final String invalidTitle, invalidBody, notFoundTitle, notFoundBody;
  final String unavailableTitle, unavailableBody;

  static BarcodeRuntimeCopy of(String languageCode) =>
      _all[languageCode.toLowerCase()] ?? _all['en']!;

  static const _all = <String, BarcodeRuntimeCopy>{
    'en': BarcodeRuntimeCopy(
      invalidTitle: 'Invalid barcode',
      invalidBody:
          'Enter a valid GTIN-8, UPC-A, EAN-13, or GTIN-14, including its check digit.',
      notFoundTitle: 'Barcode not found',
      notFoundBody: 'No trusted food record matched this barcode.',
      unavailableTitle: 'Catalog unavailable',
      unavailableBody:
          'Trusted catalogs are unavailable. BIL will not invent nutrition values.',
    ),
    'ar': BarcodeRuntimeCopy(
      invalidTitle: 'رمز غير صالح',
      invalidBody:
          'أدخل GTIN-8 أو UPC-A أو EAN-13 أو GTIN-14 صالحًا مع رقم التحقق.',
      notFoundTitle: 'لم يُعثر على الرمز',
      notFoundBody: 'لا يوجد سجل طعام موثوق يطابق هذا الرمز.',
      unavailableTitle: 'دليل الأطعمة غير متاح',
      unavailableBody:
          'الأدلة الموثوقة غير متاحة. لن يخمّن BIL القيم الغذائية.',
    ),
    'fr': BarcodeRuntimeCopy(
      invalidTitle: 'Code-barres invalide',
      invalidBody:
          'Saisissez un GTIN-8, UPC-A, EAN-13 ou GTIN-14 valide avec son chiffre de contrôle.',
      notFoundTitle: 'Code-barres introuvable',
      notFoundBody: 'Aucun aliment fiable ne correspond à ce code-barres.',
      unavailableTitle: 'Catalogue indisponible',
      unavailableBody:
          'Les catalogues fiables sont indisponibles. BIL n’inventera aucune valeur nutritionnelle.',
    ),
    'es': BarcodeRuntimeCopy(
      invalidTitle: 'Código de barras no válido',
      invalidBody:
          'Introduce un GTIN-8, UPC-A, EAN-13 o GTIN-14 válido con su dígito de control.',
      notFoundTitle: 'Código no encontrado',
      notFoundBody: 'Ningún alimento fiable coincide con este código.',
      unavailableTitle: 'Catálogo no disponible',
      unavailableBody:
          'Los catálogos fiables no están disponibles. BIL no inventará valores nutricionales.',
    ),
    'tr': BarcodeRuntimeCopy(
      invalidTitle: 'Geçersiz barkod',
      invalidBody:
          'Kontrol basamağıyla birlikte geçerli bir GTIN-8, UPC-A, EAN-13 veya GTIN-14 girin.',
      notFoundTitle: 'Barkod bulunamadı',
      notFoundBody: 'Bu barkodla eşleşen güvenilir bir yiyecek kaydı yok.',
      unavailableTitle: 'Katalog kullanılamıyor',
      unavailableBody:
          'Güvenilir kataloglar kullanılamıyor. BIL besin değerlerini uydurmaz.',
    ),
  };
}
