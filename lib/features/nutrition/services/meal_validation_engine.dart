import '../domain/meal_builder.dart';
import '../domain/meal_validation.dart';

class MealValidationEngine {
  const MealValidationEngine();

  static const double warningQuantityGrams = 5000;
  static const double maximumQuantityGrams = 100000;

  MealValidationReport validate(MealBuilderDraft draft) {
    final issues = <MealValidationIssue>[];
    if (draft.items.isEmpty) {
      issues.add(
        const MealValidationIssue(
          kind: MealValidationIssueKind.emptyMeal,
          severity: MealValidationSeverity.error,
          message: 'A meal must contain at least one food item.',
        ),
      );
    }

    final foodIds = <int>{};
    final positions = <int>{};
    for (var index = 0; index < draft.items.length; index++) {
      final item = draft.items[index];
      if (item.foodId <= 0) {
        issues.add(
          MealValidationIssue(
            kind: MealValidationIssueKind.invalidFoodId,
            severity: MealValidationSeverity.error,
            message: 'Food id must be positive.',
            itemIndex: index,
          ),
        );
      } else if (!foodIds.add(item.foodId)) {
        issues.add(
          MealValidationIssue(
            kind: MealValidationIssueKind.duplicateFood,
            severity: MealValidationSeverity.warning,
            message: 'The same food appears more than once in the meal.',
            itemIndex: index,
          ),
        );
      }

      if (!item.quantityGrams.isFinite || item.quantityGrams <= 0) {
        issues.add(
          MealValidationIssue(
            kind: MealValidationIssueKind.invalidQuantity,
            severity: MealValidationSeverity.error,
            message: 'Quantity must be finite and greater than zero.',
            itemIndex: index,
          ),
        );
      } else if (item.quantityGrams > maximumQuantityGrams) {
        issues.add(
          MealValidationIssue(
            kind: MealValidationIssueKind.invalidQuantity,
            severity: MealValidationSeverity.error,
            message: 'Quantity exceeds the supported safety limit.',
            itemIndex: index,
          ),
        );
      } else if (item.quantityGrams > warningQuantityGrams) {
        issues.add(
          MealValidationIssue(
            kind: MealValidationIssueKind.excessiveQuantity,
            severity: MealValidationSeverity.warning,
            message: 'Quantity is unusually large and should be reviewed.',
            itemIndex: index,
          ),
        );
      }

      if (item.position <= 0) {
        issues.add(
          MealValidationIssue(
            kind: MealValidationIssueKind.invalidPosition,
            severity: MealValidationSeverity.error,
            message: 'Position must be positive.',
            itemIndex: index,
          ),
        );
      } else if (!positions.add(item.position)) {
        issues.add(
          MealValidationIssue(
            kind: MealValidationIssueKind.duplicatePosition,
            severity: MealValidationSeverity.error,
            message: 'Meal item positions must be unique.',
            itemIndex: index,
          ),
        );
      }
    }

    issues.sort((left, right) {
      final severityOrder = right.severity.index.compareTo(left.severity.index);
      if (severityOrder != 0) return severityOrder;
      final indexOrder = (left.itemIndex ?? -1).compareTo(
        right.itemIndex ?? -1,
      );
      if (indexOrder != 0) return indexOrder;
      return left.kind.index.compareTo(right.kind.index);
    });

    return MealValidationReport(List<MealValidationIssue>.unmodifiable(issues));
  }
}
