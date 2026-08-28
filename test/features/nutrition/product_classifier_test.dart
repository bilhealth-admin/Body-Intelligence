import 'package:body_intelligence_log/features/nutrition/domain/product_identity.dart';
import 'package:body_intelligence_log/features/nutrition/services/product_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = ProductClassifier();

  test('classifies tobacco instead of treating it as missing food', () {
    expect(
      classifier.classify(const <String, dynamic>{
        'product_type': 'product',
        'categories_tags': <String>['en:tobacco', 'en:cigarettes'],
      }, 'Cigarettes'),
      ProductKind.tobacco,
    );
  });

  test('classifies Arabic tobacco and medicine names', () {
    expect(
      classifier.classify(const {}, 'علبة سجائر تبغ'),
      ProductKind.tobacco,
    );
    expect(
      classifier.classify(const {}, 'دواء من الصيدلية'),
      ProductKind.medicine,
    );
  });

  test('preserves universal Open Facts product families', () {
    expect(
      classifier.classify(const <String, dynamic>{
        'product_type': 'beauty',
      }, 'Face cream'),
      ProductKind.personalCare,
    );
    expect(
      classifier.classify(const <String, dynamic>{
        'product_type': 'petfood',
      }, 'Cat food'),
      ProductKind.petFood,
    );
  });

  test('trusted food product type defeats ambiguous cosmetic words', () {
    expect(
      classifier.classify(const <String, dynamic>{
        'product_type': 'food',
        'categories_tags': <String>['en:ice-creams'],
      }, 'Vanilla ice cream'),
      ProductKind.food,
    );
  });

  test('blocks Arabic cleaners and cosmetics from nutrition use', () {
    final household = classifier.classify(
      const {},
      '\u0645\u0646\u0638\u0641 \u0648\u0645\u0637\u0647\u0631 \u0645\u0646\u0632\u0644\u064a',
    );
    final cosmetic = classifier.classify(
      const {},
      '\u0643\u0631\u064a\u0645 \u0639\u0646\u0627\u064a\u0629 \u0634\u062e\u0635\u064a\u0629',
    );

    expect(household, ProductKind.household);
    expect(cosmetic, ProductKind.personalCare);
    expect(_identity(household).hasNutritionUse, isFalse);
    expect(_identity(cosmetic).hasNutritionUse, isFalse);
  });

  test('distinguishes supplements, medicines, and food', () {
    expect(
      classifier.classify(const {}, 'Vitamin D supplement'),
      ProductKind.supplement,
    );
    expect(
      classifier.classify(const {}, 'Pharmaceutical medicine'),
      ProductKind.medicine,
    );
    expect(
      classifier.classify(const <String, dynamic>{
        'product_type': 'food',
      }, 'Rice'),
      ProductKind.food,
    );
  });

  test('unknown products remain unknown and never become food', () {
    final kind = classifier.classify(const {}, 'ZXQ 2049 unlisted item');
    expect(kind, ProductKind.unknown);
    expect(_identity(kind).hasNutritionUse, isFalse);
  });
}

ProductIdentity _identity(ProductKind kind) => ProductIdentity(
  barcode: 'test',
  kind: kind,
  name: 'test',
  source: 'test',
  confidence: ProductIdentityConfidence.low,
);
