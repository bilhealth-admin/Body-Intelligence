enum MealValidationSeverity { information, warning, error }

enum MealValidationIssueKind {
  emptyMeal,
  invalidFoodId,
  invalidQuantity,
  excessiveQuantity,
  duplicateFood,
  duplicatePosition,
  invalidPosition,
}

class MealValidationIssue {
  final MealValidationIssueKind kind;
  final MealValidationSeverity severity;
  final String message;
  final int? itemIndex;

  const MealValidationIssue({
    required this.kind,
    required this.severity,
    required this.message,
    this.itemIndex,
  });
}

class MealValidationReport {
  final List<MealValidationIssue> issues;

  const MealValidationReport(this.issues);

  bool get hasErrors =>
      issues.any((issue) => issue.severity == MealValidationSeverity.error);

  bool get isSafeToPersist => !hasErrors;
}
