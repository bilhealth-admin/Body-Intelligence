/// Explicit daily macro targets entered by the user.
///
/// A zero value means "use the plan-derived target". Invalid persisted values
/// fail closed to the plan target so corrupt preferences never distort advice.
final class MacroGramGoals {
  const MacroGramGoals({this.protein, this.carbohydrates, this.fat});

  final double? protein;
  final double? carbohydrates;
  final double? fat;

  static double? parse(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0 || parsed > 1000) {
      return null;
    }
    return parsed;
  }

  double proteinOr(double planTarget) => protein ?? planTarget;
  double carbohydratesOr(double planTarget) => carbohydrates ?? planTarget;
  double fatOr(double planTarget) => fat ?? planTarget;
}
