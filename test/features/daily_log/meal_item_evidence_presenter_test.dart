import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/meal_item_evidence_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealItem item({
    String source = 'usda',
    bool verified = true,
    double servingSize = 100,
    String servingUnit = 'g',
    double quantity = 150,
  }) {
    final now = DateTime(2026, 8, 1);
    return MealItem(
      id: 1,
      uuid: 'meal-item-1',
      mealId: 1,
      foodId: 1,
      quantity: quantity,
      position: 1,
      calories: 100,
      protein: 10,
      carbs: 12,
      fats: 2,
      fiber: 1,
      sodium: 20,
      potassium: 40,
      calcium: 30,
      magnesium: 10,
      phosphorus: 15,
      sugar: 4,
      nutrientEvidenceMask: 0,
      foodSourceSnapshot: source,
      foodVerifiedSnapshot: verified,
      servingSizeSnapshot: servingSize,
      servingUnitSnapshot: servingUnit,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'pending',
      revision: 0,
    );
  }

  test('uses immutable USDA evidence snapshot in English', () {
    final text = MealItemEvidencePresenter.subtitle(
      item: item(),
      mealLabel: 'Breakfast',
      arabic: false,
    );

    expect(text, 'Breakfast · 150 g · Verified USDA · reference serving 100 g');
  });

  test('uses immutable local unverified evidence in Arabic', () {
    final text = MealItemEvidencePresenter.subtitle(
      item: item(
        source: 'local',
        verified: false,
        servingSize: 1,
        servingUnit: 'piece',
        quantity: 2,
      ),
      mealLabel: 'فطور',
      arabic: true,
    );

    expect(
      text,
      'فطور · 2 قطعة · إدخال محلي — غير موثّق · الحصة المرجعية 1 قطعة',
    );
  });

  test(
    'presentation depends on snapshot rather than current food metadata',
    () {
      final text = MealItemEvidencePresenter.subtitle(
        item: item(
          source: 'catalog',
          verified: true,
          servingSize: 170,
          servingUnit: 'g',
          quantity: 85,
        ),
        mealLabel: 'Snack',
        arabic: false,
      );

      expect(text, contains('Verified catalog'));
      expect(text, contains('reference serving 170 g'));
      expect(text, contains('85 g'));
    },
  );
}
