import '../domain/meal_builder.dart';

enum MealBuilderIssueKind {
  blankName,
  unsupportedMealType,
  emptyMeal,
  tooManyItems,
  invalidFoodId,
  invalidQuantity,
  invalidPosition,
  duplicatePosition,
}

class MealBuilderIssue {
  final MealBuilderIssueKind kind;
  final String message;
  final int? itemIndex;

  const MealBuilderIssue({
    required this.kind,
    required this.message,
    this.itemIndex,
  });
}

class MealBuilderValidation {
  final List<MealBuilderIssue> issues;

  const MealBuilderValidation(this.issues);

  bool get isValid => issues.isEmpty;
}

class MealBuilderEngine {
  const MealBuilderEngine();

  static const Set<String> supportedMealTypes = <String>{
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  };

  MealBuilderValidation validate(MealBuilderDraft draft) {
    final issues = <MealBuilderIssue>[];
    final name = draft.name.trim();
    if (name.isEmpty) {
      issues.add(
        const MealBuilderIssue(
          kind: MealBuilderIssueKind.blankName,
          message: 'Meal name must not be blank.',
        ),
      );
    }

    if (!supportedMealTypes.contains(draft.mealType)) {
      issues.add(
        const MealBuilderIssue(
          kind: MealBuilderIssueKind.unsupportedMealType,
          message: 'Meal type is not supported.',
        ),
      );
    }

    if (draft.items.isEmpty) {
      issues.add(
        const MealBuilderIssue(
          kind: MealBuilderIssueKind.emptyMeal,
          message: 'A meal must contain at least one food item.',
        ),
      );
    } else if (draft.items.length > 100) {
      issues.add(
        const MealBuilderIssue(
          kind: MealBuilderIssueKind.tooManyItems,
          message: 'A meal cannot contain more than 100 food items.',
        ),
      );
    }

    final positions = <int>{};
    for (var index = 0; index < draft.items.length; index++) {
      final item = draft.items[index];
      if (item.foodId <= 0) {
        issues.add(
          MealBuilderIssue(
            kind: MealBuilderIssueKind.invalidFoodId,
            message: 'Food id must be positive.',
            itemIndex: index,
          ),
        );
      }
      if (!item.quantityGrams.isFinite ||
          item.quantityGrams <= 0 ||
          item.quantityGrams > 100000) {
        issues.add(
          MealBuilderIssue(
            kind: MealBuilderIssueKind.invalidQuantity,
            message: 'Quantity must be finite and between 0 and 100000 grams.',
            itemIndex: index,
          ),
        );
      }
      if (item.position <= 0) {
        issues.add(
          MealBuilderIssue(
            kind: MealBuilderIssueKind.invalidPosition,
            message: 'Position must be positive.',
            itemIndex: index,
          ),
        );
      } else if (!positions.add(item.position)) {
        issues.add(
          MealBuilderIssue(
            kind: MealBuilderIssueKind.duplicatePosition,
            message: 'Meal item positions must be unique.',
            itemIndex: index,
          ),
        );
      }
    }

    return MealBuilderValidation(List<MealBuilderIssue>.unmodifiable(issues));
  }

  MealBuilderDraft canonicalize(MealBuilderDraft draft) {
    final validation = validate(draft);
    if (!validation.isValid) {
      throw ArgumentError.value(
        draft,
        'draft',
        validation.issues.map((issue) => issue.message).join(' '),
      );
    }

    final ordered = List<MealBuilderItemDraft>.from(draft.items)
      ..sort((left, right) => left.position.compareTo(right.position));
    final canonicalItems = <MealBuilderItemDraft>[
      for (var index = 0; index < ordered.length; index++)
        MealBuilderItemDraft(
          foodId: ordered[index].foodId,
          quantityGrams: ordered[index].quantityGrams,
          position: index + 1,
        ),
    ];

    return MealBuilderDraft(
      name: draft.name.trim(),
      mealType: draft.mealType,
      items: List<MealBuilderItemDraft>.unmodifiable(canonicalItems),
    );
  }
}
