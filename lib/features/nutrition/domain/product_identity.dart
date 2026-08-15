enum ProductKind {
  food,
  beverage,
  alcohol,
  supplement,
  medicine,
  tobacco,
  personalCare,
  petFood,
  household,
  generalProduct,
  unknown,
}

enum ProductIdentityConfidence { high, medium, low }

class ProductIdentity {
  const ProductIdentity({
    required this.barcode,
    required this.kind,
    required this.name,
    required this.source,
    required this.confidence,
    this.arabicName,
    this.brand,
  });

  final String barcode;
  final ProductKind kind;
  final String name;
  final String? arabicName;
  final String? brand;
  final String source;
  final ProductIdentityConfidence confidence;

  bool get isFood => const {
    ProductKind.food,
    ProductKind.beverage,
    ProductKind.alcohol,
    ProductKind.supplement,
  }.contains(kind);

  bool get hasNutritionUse =>
      kind == ProductKind.food ||
      kind == ProductKind.beverage ||
      kind == ProductKind.alcohol;
}
