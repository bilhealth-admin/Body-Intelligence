import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_card_models.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_receipt_content.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/coach_food_cards_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoachFoodCardsFixture fixture;
  setUp(() async => fixture = await CoachFoodCardsFixture.create());
  tearDown(() async => fixture.close());

  for (final mismatch in [
    'operation',
    'tool',
    'time',
    'uncommitted',
    'entity type',
    'entity id',
    'digest',
    'state',
    'item',
    'current item',
  ]) {
    test(
      'rejects $mismatch even with a real commit beside the receipt',
      () async {
        final commit = await fixture.commitReview();
        final after = <String, Object?>{...commit.afterPayload};
        if (mismatch == 'digest') {
          after['arguments_digest'] = 'different-digest';
        }
        if (mismatch == 'state') after['state'] = 'undone';
        if (mismatch == 'item') {
          after['items'] = [
            {...commit.after.first.toReceiptPayload(), 'protein': 999},
            ...commit.after.skip(1).map((item) => item.toReceiptPayload()),
          ];
        }
        if (mismatch == 'current item') after['current_items'] = [];
        final receipt = foodCardReceipt(
          commit,
          operationId: mismatch == 'operation' ? 'different-operation' : null,
          toolId: mismatch == 'tool' ? 'quick_add_macros' : null,
          completedAt: mismatch == 'time'
              ? commit.committedAt.add(const Duration(seconds: 1))
              : null,
          committed: mismatch != 'uncommitted',
          entityType: mismatch == 'entity type' ? 'meal_item' : null,
          entityId: mismatch == 'entity id' ? '999999' : null,
          after: after,
        );
        expect(CoachFoodReceiptBinding.matches(commit, receipt), isFalse);
      },
    );
  }

  test(
    'real journal replay retains original receipt time and exact readback',
    () async {
      final original = await fixture.commitReview();
      final receipt = foodCardReceipt(original);
      final replayed = await fixture.commitReview();
      expect(replayed.replayed, isTrue);
      expect(replayed.committedAt, original.committedAt);
      expect(CoachFoodReceiptBinding.matches(replayed, receipt), isTrue);
      expect(
        CoachFoodReceiptBinding.matches(replayed, foodCardReceipt(replayed)),
        isTrue,
      );
      expect(
        await fixture.database.select(fixture.database.mealItems).get(),
        hasLength(4),
      );
    },
  );

  test(
    'modified readback and completed undo remain bound without becoming successful',
    () async {
      final original = await fixture.commitReview();
      await fixture.repository.updateMealItem(
        id: original.after.first.item.id,
        quantity: 170,
      );
      final modified = await fixture.commitReview();
      expect(modified.state, CoachMealResultState.modified);
      expect(modified.canUndo, isFalse);
      expect(
        CoachFoodReceiptBinding.matches(modified, foodCardReceipt(modified)),
        isTrue,
      );
      expect(
        CoachFoodReceiptBinding.matches(modified, foodCardReceipt(original)),
        isFalse,
      );
      final other = await fixture.commitCalories();
      final undone = await fixture.undo(other);
      expect(
        CoachFoodReceiptBinding.matches(undone, foodCardReceipt(undone)),
        isTrue,
      );
      expect(undone.canUndo, isFalse);
      expect(
        CoachFoodReceiptBinding.matches(undone, foodCardReceipt(other)),
        isFalse,
      );
    },
  );

  test(
    'readback totals preserve unknown protein, known zero and all thirteen fields',
    () async {
      final commit = await fixture.commitReview(
        proposal: foodCardFixtureReview(unknownProtein: true),
      );
      final values = CoachFoodReceiptValues(commit);
      expect(values.total(FoodNutrient.protein), isNull);
      expect(values.total(FoodNutrient.calories), 407);
      expect(values.total(FoodNutrient.potassium), 0);
      expect(values.total(FoodNutrient.iron), 0);
      expect(values.total(FoodNutrient.vitaminC), 0);
      expect(values.total(FoodNutrient.sodium), 242);
      expect(commit.after[2].toReceiptPayload()['protein'], isNull);
    },
  );
}
