import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/barcode_identity.dart';
import 'package:body_intelligence_log/features/nutrition/services/offline_barcode_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barcode identity normalizes localized digits and validates GTIN', () {
    final identity = BarcodeIdentity.parse('٤٠٠-٦٣٨١٣٣٣٩٣١');

    expect(identity.digits, '4006381333931');
    expect(identity.symbology, BarcodeSymbology.ean13);
    expect(identity.isValid, isTrue);
    expect(
      BarcodeIdentity.parse('4006381333932').issue,
      BarcodeValidationIssue.invalidCheckDigit,
    );
    expect(
      BarcodeIdentity.parse('123').issue,
      BarcodeValidationIssue.unsupportedLength,
    );
  });

  test('offline repository resolves one canonical barcode match', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FoodRepository(database);
    final id = await repository.addFood(
      name: 'Canonical product',
      category: 'branded',
      barcode: '4006381333931',
      calories: 100,
      protein: 5,
      carbs: 12,
      fats: 3,
      source: 'branded',
      isCustom: false,
      verified: true,
    );

    final result = await repository.resolveBarcode('٤٠٠ ٦٣٨١٣٣٣٩٣١');

    expect(result.status, BarcodeResolutionStatus.resolved);
    expect(result.food?.localId, id);
    expect(result.identity.digits, '4006381333931');
  });

  test(
    'offline resolution reports ambiguity without choosing silently',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = FoodRepository(database);
      for (final name in ['Zulu legacy', 'Alpha foundation']) {
        await repository.addFood(
          name: name,
          category: 'food',
          barcode: '036000291452',
          calories: 100,
          protein: 5,
          carbs: 12,
          fats: 3,
          source: name.contains('foundation') ? 'foundation' : 'legacy',
          isCustom: false,
          verified: name.contains('foundation'),
        );
      }

      final result = await repository.resolveBarcode('036000291452');

      expect(result.status, BarcodeResolutionStatus.ambiguous);
      expect(result.requiresDisambiguation, isTrue);
      expect(result.food, isNull);
      expect(result.candidates, hasLength(2));
      expect(result.candidates.first.name, 'Alpha foundation');
    },
  );

  test('invalid and missing barcodes are explicit offline states', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FoodRepository(database);

    expect(
      (await repository.resolveBarcode('4006381333932')).status,
      BarcodeResolutionStatus.invalid,
    );
    expect(
      (await repository.resolveBarcode('96385074')).status,
      BarcodeResolutionStatus.notFound,
    );
  });
}
