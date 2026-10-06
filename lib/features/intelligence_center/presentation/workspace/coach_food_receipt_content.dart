import 'package:flutter/material.dart';

import '../../../../data/database/meal_food_evidence.dart';
import '../../../../data/repositories/meal_repository.dart';
import '../../domain/food_v2/coach_food_v2.dart';
import 'coach_food_card_components.dart';
import 'coach_food_card_copy.dart';
import 'coach_food_card_models.dart';

/// All displayed values are from the immutable committed diary snapshots.
/// Missing evidence in any row makes that nutrient's complete total unknown.
final class CoachFoodReceiptValues {
  CoachFoodReceiptValues(this.commit)
    : evidence = [
        for (final row in commit.after)
          MealFoodEvidence.read(row.item, ownerKey: commit.ownerScope),
      ];

  final CoachMealCommit commit;
  final List<MealFoodEvidence> evidence;

  double? total(FoodNutrient nutrient) {
    if (evidence.isEmpty) return null;
    var total = 0.0;
    for (final item in evidence) {
      final value = item.fullValue(nutrient);
      if (value == null || !value.isFinite || value < 0) return null;
      total += value;
    }
    return total.isFinite ? total : null;
  }

  bool get calorieOnly =>
      commit.kind == CoachMealCommandKind.quickMacros &&
      total(FoodNutrient.calories) != null &&
      const [
        FoodNutrient.protein,
        FoodNutrient.carbohydrates,
        FoodNutrient.fat,
      ].every((nutrient) => total(nutrient) == null);
}

class CoachFoodReceiptContent extends StatelessWidget {
  const CoachFoodReceiptContent({
    required this.values,
    required this.selectedUuid,
    required this.onSelect,
    required this.onEdit,
    required this.showNutrition,
    this.thumbnailFor,
    super.key,
  });

  final CoachFoodReceiptValues values;
  final String? selectedUuid;
  final void Function(String uuid)? onSelect;
  final void Function(CoachMealSnapshot item)? onEdit;
  final bool showNutrition;
  final CoachFoodThumbnailResolver? thumbnailFor;

  @override
  Widget build(BuildContext context) {
    final copy = CoachFoodCardCopy(context);
    final rows = values.commit.after;
    final nutrientsOnly =
        values.commit.kind == CoachMealCommandKind.quickMacros;
    CoachMealSnapshot? selected;
    CoachFoodPortion? selectedPortion;
    for (var index = 0; index < rows.length; index++) {
      if (rows[index].item.uuid == selectedUuid) {
        selected = rows[index];
        selectedPortion = values.evidence[index].portion;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CoachFoodCardPalette.inset,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoachFoodNutrientStrip(value: values.total),
              if (!nutrientsOnly) ...[
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        MediaQuery.textScalerOf(context).scale(13) > 18 ||
                            constraints.maxWidth < 285
                        ? 2
                        : 4;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 9) / columns;
                    return Wrap(
                      spacing: 9,
                      runSpacing: 11,
                      children: [
                        for (var index = 0; index < rows.length; index++)
                          SizedBox(
                            width: width,
                            child: _food(
                              context,
                              copy,
                              rows[index],
                              values.evidence[index].portion,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        if (!nutrientsOnly) ...[
          const SizedBox(height: 7),
          Text(
            '${copy.sources}: ${_sources(copy)}',
            style: const TextStyle(
              fontSize: 10,
              color: CoachFoodCardPalette.muted,
            ),
          ),
        ],
        if (selected != null) ...[
          const SizedBox(height: 9),
          CoachFoodEvidenceDetails(portion: selectedPortion),
          _edit(copy, selected),
        ],
        if (nutrientsOnly && rows.length == 1) _edit(copy, rows.single),
        if (showNutrition) ...[
          const SizedBox(height: 9),
          CoachFoodNutritionDetails(value: values.total),
        ],
      ],
    );
  }

  Widget _food(
    BuildContext context,
    CoachFoodCardCopy copy,
    CoachMealSnapshot row,
    CoachFoodPortion? portion,
  ) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final name = arabic && row.arabicFoodName?.trim().isNotEmpty == true
        ? row.arabicFoodName!
        : row.foodName;
    final amount = portion == null
        ? '${copy.number(row.item.quantity)} ${row.item.servingUnitSnapshot}'
        : copy.receiptAmount(portion);
    return InkWell(
      key: CoachFoodCardKeys.receiptFood(row.item.uuid),
      onTap: onSelect == null ? null : () => onSelect!(row.item.uuid),
      borderRadius: BorderRadius.circular(7),
      child: Semantics(
        button: true,
        expanded: selectedUuid == row.item.uuid,
        label: copy.details,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoachFoodThumbnail(food: portion?.food, resolver: thumbnailFor),
            const SizedBox(height: 5),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, height: 1.3),
            ),
            const SizedBox(height: 2),
            Text(
              amount,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                color: CoachFoodCardPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _edit(CoachFoodCardCopy copy, CoachMealSnapshot row) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton.icon(
      key: CoachFoodCardKeys.edit(row.item.uuid),
      onPressed: onEdit == null ? null : () => onEdit!(row),
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: Text(copy.edit),
      style: TextButton.styleFrom(
        foregroundColor: CoachFoodCardPalette.blue,
        disabledForegroundColor: CoachFoodCardPalette.muted,
        textStyle: Theme.of(
          copy.context,
        ).textTheme.labelLarge?.copyWith(fontSize: 12),
      ),
    ),
  );

  String _sources(CoachFoodCardCopy copy) {
    final labels = <String>{};
    for (final evidence in values.evidence) {
      final portion = evidence.portion;
      labels.add(
        portion == null
            ? copy.unknown
            : copy.sourceKind(portion.food.source.kind),
      );
      if (portion?.quantity.evidence.kind == CoachFoodQuantityKind.estimated) {
        labels.add(copy.estimatedPortion);
      }
    }
    return labels.join(' • ');
  }
}

class CoachFoodNutritionDetails extends StatelessWidget {
  const CoachFoodNutritionDetails({required this.value, super.key});
  final double? Function(FoodNutrient nutrient) value;

  @override
  Widget build(BuildContext context) {
    final copy = CoachFoodCardCopy(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CoachFoodCardPalette.inset,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.nutritionDetails,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          for (final nutrient in FoodNutrient.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${copy.nutrient(nutrient)}: ${value(nutrient) == null ? copy.unknown : '${copy.number(value(nutrient)!)} ${CoachFoodNutrients.units[nutrient]}'}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
