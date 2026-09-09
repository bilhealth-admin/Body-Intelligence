import 'community_models.dart';

enum CommunityFoodField { name, serving, calories, protein, carbohydrate, fat }

enum CommunityFoodInputIssue {
  missingValue,
  nameLength,
  invalidNumber,
  positiveServing,
  tooLarge,
  macroExceedsServing,
  macroTotalExceedsServing,
}

class CommunityFoodInputResult {
  const CommunityFoodInputResult({required this.issues, this.draft});
  final Map<CommunityFoodField, CommunityFoodInputIssue> issues;
  final CommunityFoodDraft? draft;
  bool get isValid => issues.isEmpty && draft != null;
}

/// Plain per-serving decimal input, not scientific notation or grouped numbers.
/// Decimal comma and the Arabic decimal separator are accepted. Grouping
/// separators are deliberately not removed: their interpretation is ambiguous.
double? parseCommunityFoodNumber(String input) {
  var text = input.trim();
  const digitSets = [
    '٠١٢٣٤٥٦٧٨٩',
    '۰۱۲۳۴۵۶۷۸۹',
    '０１２３４５６７８９',
    '०१२३४५६७८९',
    '০১২৩৪৫৬৭৮৯',
    '๐๑๒๓๔๕๖๗๘๙',
  ];
  for (final digits in digitSets) {
    for (var index = 0; index < 10; index++) {
      text = text.replaceAll(digits[index], '$index');
    }
  }
  text = text.replaceAll('٫', '.').replaceAll(',', '.');
  if (!RegExp(r'^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$').hasMatch(text)) {
    return null;
  }
  final value = double.tryParse(text);
  return value != null && value.isFinite ? value : null;
}

/// Completeness and physical plausibility only, not a nutrition recommendation.
/// The caller must not replace missing values with zero or approve the food.
CommunityFoodInputResult validateCommunityFoodInput(
  Map<CommunityFoodField, String> input,
) {
  final issues = <CommunityFoodField, CommunityFoodInputIssue>{};
  final name = (input[CommunityFoodField.name] ?? '').trim();
  if (name.isEmpty) {
    issues[CommunityFoodField.name] = CommunityFoodInputIssue.missingValue;
  } else if (name.runes.length < 2 || name.runes.length > 180) {
    issues[CommunityFoodField.name] = CommunityFoodInputIssue.nameLength;
  }
  final numbers = <CommunityFoodField, double>{};
  for (final field in CommunityFoodField.values.skip(1)) {
    final raw = (input[field] ?? '').trim();
    if (raw.isEmpty) {
      issues[field] = CommunityFoodInputIssue.missingValue;
      continue;
    }
    final value = parseCommunityFoodNumber(raw);
    if (value == null) {
      issues[field] = CommunityFoodInputIssue.invalidNumber;
      continue;
    }
    numbers[field] = value;
    final maximum = switch (field) {
      CommunityFoodField.serving => 100000.0,
      CommunityFoodField.calories => 10000.0,
      _ => 5000.0,
    };
    if (field == CommunityFoodField.serving && value <= 0) {
      issues[field] = CommunityFoodInputIssue.positiveServing;
    } else if (value > maximum) {
      issues[field] = CommunityFoodInputIssue.tooLarge;
    }
  }
  final serving = numbers[CommunityFoodField.serving];
  const macros = [
    CommunityFoodField.protein,
    CommunityFoodField.carbohydrate,
    CommunityFoodField.fat,
  ];
  if (serving != null && !issues.containsKey(CommunityFoodField.serving)) {
    // Small allowance for rounded per-serving label values, not for impossible
    // measurements such as 255 g protein in a 5 g serving.
    final tolerance = serving * .01 > .5 ? serving * .01 : .5;
    for (final field in macros) {
      final value = numbers[field];
      if (value != null && value > serving + tolerance) {
        issues.putIfAbsent(
          field,
          () => CommunityFoodInputIssue.macroExceedsServing,
        );
      }
    }
    if (macros.every(
      (field) => numbers.containsKey(field) && !issues.containsKey(field),
    )) {
      final total = macros.fold<double>(
        0,
        (sum, field) => sum + numbers[field]!,
      );
      if (total > serving + tolerance) {
        for (final field in macros) {
          issues[field] = CommunityFoodInputIssue.macroTotalExceedsServing;
        }
      }
    }
  }
  return CommunityFoodInputResult(
    issues: Map.unmodifiable(issues),
    draft: issues.isNotEmpty
        ? null
        : CommunityFoodDraft(
            name: name,
            servingGrams: numbers[CommunityFoodField.serving]!,
            calories: numbers[CommunityFoodField.calories]!,
            protein: numbers[CommunityFoodField.protein]!,
            carbohydrate: numbers[CommunityFoodField.carbohydrate]!,
            fat: numbers[CommunityFoodField.fat]!,
          ),
  );
}
