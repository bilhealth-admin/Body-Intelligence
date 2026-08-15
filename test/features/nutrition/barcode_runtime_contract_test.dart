import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/nutrition/domain/barcode_identity.dart';
import 'package:body_intelligence_log/features/nutrition/domain/product_identity.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/barcode_food_contract.dart';

void main() {
  test('regional fixtures cover GTIN-8/12/13/14 with valid check digits', () {
    final decoded =
        jsonDecode(
              File(
                'test/fixtures/barcodes/regional_gtins.json',
              ).readAsStringSync(),
            )
            as List<dynamic>;
    expect(decoded.length, greaterThanOrEqualTo(9));
    final lengths = <int>{};
    for (final entry in decoded.cast<Map<String, dynamic>>()) {
      final identity = BarcodeIdentity.parse(entry['value'] as String);
      expect(identity.isValid, isTrue, reason: entry.toString());
      lengths.add(identity.digits.length);
      expect((entry['market'] as String).trim(), isNotEmpty);
    }
    expect(lengths, containsAll(<int>{8, 12, 13, 14}));
  });

  test(
    'normalizes manual separators and Arabic digits but rejects bad check digit',
    () {
      expect(BarcodeIdentity.parse('٤٠٠-٦٣٨١٣٣٣٩٣١').digits, '4006381333931');
      expect(BarcodeIdentity.parse('٤٠٠-٦٣٨١٣٣٣٩٣١').isValid, isTrue);
      expect(BarcodeIdentity.parse('4006381333932').isValid, isFalse);
    },
  );

  test(
    'unified barcode food requires exact GTIN, serving, source and calorie evidence',
    () {
      final identity = BarcodeIdentity.parse('4006381333931');
      expect(BarcodeFoodContract.acceptsUnified(_food(), identity), isTrue);
      expect(
        BarcodeFoodContract.acceptsUnified(_food(sourceLabel: ''), identity),
        isFalse,
      );
      expect(
        BarcodeFoodContract.acceptsUnified(_food(servingGrams: 0), identity),
        isFalse,
      );
      expect(
        BarcodeFoodContract.acceptsUnified(
          _food(caloriesKnown: false),
          identity,
        ),
        isFalse,
      );
    },
  );

  test('tobacco cosmetics and supplements cannot be materialized as food', () {
    for (final kind in <ProductKind>[
      ProductKind.tobacco,
      ProductKind.personalCare,
      ProductKind.household,
      ProductKind.medicine,
      ProductKind.supplement,
    ]) {
      expect(
        BarcodeFoodContract.canMaterializeProduct(_product(kind)),
        isFalse,
        reason: kind.name,
      );
    }
    expect(
      BarcodeFoodContract.canMaterializeProduct(_product(ProductKind.food)),
      isTrue,
    );
  });

  test('barcode serving review copy exists for all five release languages', () {
    final source = File(
      'lib/features/nutrition/presentation/barcode_food_review_dialog.dart',
    ).readAsStringSync();
    for (final language in <String>['en', 'ar', 'fr', 'es', 'tr']) {
      expect(source, contains("'$language': _BarcodeReviewCopy"));
    }
    expect(source, contains('barrierDismissible: false'));
    expect(source, contains('food.servingSize'));
    expect(source, contains('food.source'));
    expect(source, contains('food.verified'));
  });

  test('barcode runtime errors exist for all five release languages', () {
    final source = File(
      'lib/features/nutrition/presentation/barcode_runtime_copy.dart',
    ).readAsStringSync();
    for (final language in <String>['en', 'ar', 'fr', 'es', 'tr']) {
      expect(source, contains("'$language': BarcodeRuntimeCopy"));
    }
    expect(source, contains('GTIN-14'));
    expect(source, contains('will not invent nutrition values'));
  });
}

UnifiedFood _food({
  String sourceLabel = 'Open Food Facts',
  double servingGrams = 100,
  bool caloriesKnown = true,
}) => UnifiedFood(
  id: 'barcode-food',
  name: 'Test food',
  barcode: '4006381333931',
  serving: FoodServing(amount: 100, unit: 'g', grams: servingGrams),
  nutrients: <FoodNutrient, NutrientAmount>{
    FoodNutrient.calories: caloriesKnown
        ? const NutrientAmount.known(120)
        : const NutrientAmount.missing(),
  },
  source: FoodDataSource.branded,
  sourceLabel: sourceLabel,
  verified: true,
  isCustom: false,
);

ProductIdentity _product(ProductKind kind) => ProductIdentity(
  barcode: '4006381333931',
  kind: kind,
  name: kind.name,
  source: 'fixture',
  confidence: ProductIdentityConfidence.high,
);
