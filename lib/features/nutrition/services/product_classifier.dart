import '../domain/product_identity.dart';

class ProductClassifier {
  const ProductClassifier();

  ProductKind classify(Map<String, dynamic> product, String displayName) {
    final productType = '${product['product_type'] ?? ''}'.toLowerCase();
    final searchable = <Object?>[
      displayName,
      product['categories'],
      product['categories_tags'],
      product['labels_tags'],
      product['brands'],
    ].join(' ').toLowerCase();

    bool containsAny(Iterable<String> terms) =>
        terms.any((term) => searchable.contains(term));

    // Unicode escapes make the Arabic vocabulary immune to console/code-page
    // corruption on Windows while keeping classification fully offline.
    if (containsAny(const [
      '\u062a\u0628\u063a',
      '\u062f\u062e\u0627\u0646',
      '\u0633\u064a\u062c\u0627\u0631\u0629',
      '\u0633\u062c\u0627\u0626\u0631',
      '\u0646\u064a\u0643\u0648\u062a\u064a\u0646',
    ])) {
      return ProductKind.tobacco;
    }
    if (containsAny(const [
      '\u062f\u0648\u0627\u0621',
      '\u0639\u0644\u0627\u062c',
      '\u0635\u064a\u062f\u0644\u064a\u0629',
    ])) {
      return ProductKind.medicine;
    }
    if (containsAny(const [
      '\u0645\u0643\u0645\u0644',
      '\u0641\u064a\u062a\u0627\u0645\u064a\u0646',
      '\u0645\u0639\u0627\u062f\u0646',
    ])) {
      return ProductKind.supplement;
    }
    if (containsAny(const [
      '\u0645\u0633\u062a\u062d\u0636\u0631\u0627\u062a \u062a\u062c\u0645\u064a\u0644',
      '\u0639\u0646\u0627\u064a\u0629 \u0634\u062e\u0635\u064a\u0629',
      '\u0634\u0627\u0645\u0628\u0648',
      '\u0635\u0627\u0628\u0648\u0646',
      '\u0643\u0631\u064a\u0645',
    ])) {
      return ProductKind.personalCare;
    }
    if (containsAny(const [
      '\u0645\u0646\u0638\u0641',
      '\u063a\u0633\u064a\u0644',
      '\u0645\u0646\u0632\u0644\u064a',
      '\u0645\u0637\u0647\u0631',
      '\u0645\u0639\u0642\u0645',
    ])) {
      return ProductKind.household;
    }

    // Arabic product identity must remain useful even when the upstream
    // catalog exposes only an Arabic product/category name.
    if (containsAny(const ['تبغ', 'دخان', 'سيجارة', 'سجائر', 'نيكوتين'])) {
      return ProductKind.tobacco;
    }
    if (containsAny(const ['دواء', 'علاج', 'صيدلية'])) {
      return ProductKind.medicine;
    }
    if (containsAny(const ['مكمل', 'فيتامين', 'معادن'])) {
      return ProductKind.supplement;
    }
    if (containsAny(const ['كحول', 'بيرة', 'نبيذ'])) {
      return ProductKind.alcohol;
    }
    if (containsAny(const ['مشروب', 'ماء', 'عصير'])) {
      return ProductKind.beverage;
    }
    if (containsAny(const ['منظف', 'غسيل', 'منزلي'])) {
      return ProductKind.household;
    }

    if (containsAny(const [
      'tobacco',
      'cigarette',
      'cigar',
      'nicotine',
      'تبغ',
      'دخان',
    ])) {
      return ProductKind.tobacco;
    }
    if (containsAny(const [
      'medicine',
      'medication',
      'pharmaceutical',
      'drug',
      'دواء',
    ])) {
      return ProductKind.medicine;
    }
    if (containsAny(const [
      'supplement',
      'vitamin',
      'minerals',
      'مكمل',
      'فيتامين',
    ])) {
      return ProductKind.supplement;
    }
    if (productType == 'beauty' ||
        containsAny(const [
          'cosmetic',
          'beauty',
          'personal care',
          'shampoo',
          'soap',
          'مستحضرات تجميل',
          'عناية شخصية',
          'شامبو',
          'صابون',
          'كريم',
        ])) {
      return ProductKind.personalCare;
    }
    if (productType == 'petfood') return ProductKind.petFood;
    if (containsAny(const [
      'alcohol',
      'beer',
      'wine',
      'spirits',
      'liquor',
      'كحول',
      'بيرة',
      'نبيذ',
    ])) {
      return ProductKind.alcohol;
    }
    if (containsAny(const [
      'beverage',
      'drink',
      'water',
      'juice',
      'مشروب',
      'ماء',
      'عصير',
    ])) {
      return ProductKind.beverage;
    }
    if (productType == 'food') return ProductKind.food;
    if (containsAny(const [
      'cleaner',
      'detergent',
      'household',
      'laundry',
      'disinfectant',
      'منظف',
      'غسيل',
      'منزلي',
      'مطهر',
      'معقم',
    ])) {
      return ProductKind.household;
    }
    if (productType == 'product') return ProductKind.generalProduct;
    return ProductKind.unknown;
  }
}
