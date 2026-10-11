enum MacroGoal { carbohydrate, protein, fat }

/// One authoritative 4/4/9 energy allocation. Stored precision is retained;
/// rounding belongs to the display, not to repeated allocation operations.
final class MacroGoalAllocation {
  const MacroGoalAllocation(
    this.calories,
    this.carbohydrate,
    this.protein,
    this.fat,
  );
  final double calories, carbohydrate, protein, fat;
  double percent(MacroGoal goal) => switch (goal) {
    MacroGoal.carbohydrate => carbohydrate,
    MacroGoal.protein => protein,
    MacroGoal.fat => fat,
  };
  double grams(MacroGoal goal) =>
      calories * percent(goal) / (100 * (goal == MacroGoal.fat ? 9 : 4));

  MacroGoalAllocation edit(
    MacroGoal goal,
    double value, {
    bool inGrams = false,
    Set<MacroGoal> locked = const {},
    MacroGoal? previous,
  }) {
    if (!calories.isFinite ||
        calories <= 0 ||
        calories > 10000 ||
        !value.isFinite ||
        value < 0 ||
        MacroGoal.values.any(
          (item) =>
              !percent(item).isFinite ||
              percent(item) < 0 ||
              percent(item) > 100,
        )) {
      throw const FormatException('Invalid energy allocation.');
    }
    final values = {for (final item in MacroGoal.values) item: percent(item)};
    final next = inGrams
        ? value * (goal == MacroGoal.fat ? 9 : 4) * 100 / calories
        : value;
    if (next > 100 || locked.contains(goal)) {
      throw const FormatException('Unlock this macro or review its energy.');
    }
    final siblings = MacroGoal.values.where((item) => item != goal).toList();
    final pinned = siblings.where(locked.contains).toList();
    if (pinned.length == 2 &&
        (next + values[siblings[0]]! + values[siblings[1]]! - 100).abs() >
            1e-7) {
      throw const FormatException('Both other macros are locked.');
    }
    // Protein is protected by default when carbohydrate is lowered. The last
    // user-edited sibling takes precedence unless an explicit lock exists.
    final preserve = pinned.isNotEmpty
        ? pinned.first
        : siblings.contains(previous)
        ? previous!
        : siblings.contains(MacroGoal.protein)
        ? MacroGoal.protein
        : MacroGoal.carbohydrate;
    final balance = siblings.firstWhere((item) => item != preserve);
    final remainder = 100 - next - values[preserve]!;
    if (remainder < -1e-7) {
      throw const FormatException(
        'Locked allocation exceeds the calorie goal.',
      );
    }
    values[goal] = next;
    values[balance] = remainder < 0 ? 0 : remainder;
    return MacroGoalAllocation(
      calories,
      values[MacroGoal.carbohydrate]!,
      values[MacroGoal.protein]!,
      values[MacroGoal.fat]!,
    );
  }

  /// Locked gram targets keep grams when calories change. Locked percentage
  /// targets keep percentages. Only unlocked targets share the remainder.
  MacroGoalAllocation withCalories(
    double next, {
    Set<MacroGoal> locked = const {},
    Set<MacroGoal> gramLocks = const {},
  }) {
    if (!next.isFinite ||
        next <= 0 ||
        next > 10000 ||
        !calories.isFinite ||
        calories <= 0 ||
        MacroGoal.values.any(
          (item) =>
              !percent(item).isFinite ||
              percent(item) < 0 ||
              percent(item) > 100,
        )) {
      throw const FormatException('Invalid energy allocation.');
    }
    final values = {
      for (final item in MacroGoal.values)
        item: locked.contains(item) && gramLocks.contains(item)
            ? percent(item) * calories / next
            : percent(item),
    };
    final fixed = locked.fold<double>(0, (sum, item) => sum + values[item]!);
    final free = MacroGoal.values
        .where((item) => !locked.contains(item))
        .toList();
    if (fixed > 100 + 1e-7 || (free.isEmpty && (fixed - 100).abs() > 1e-7)) {
      throw const FormatException('Unlock a macro before changing calories.');
    }
    final originalFree = free.fold<double>(
      0,
      (sum, item) => sum + percent(item),
    );
    final remainder = (100 - fixed).clamp(0.0, 100.0);
    for (final item in free) {
      values[item] = originalFree > 0
          ? remainder * percent(item) / originalFree
          : remainder / free.length;
    }
    return MacroGoalAllocation(
      next,
      values[MacroGoal.carbohydrate]!,
      values[MacroGoal.protein]!,
      values[MacroGoal.fat]!,
    );
  }

  Map<String, String> toPreferences() => {
    'goal.calories': calories.toString(),
    for (final item in MacroGoal.values) ...{
      'goal.${key(item)}Percent': percent(item).toString(),
      'goal.${key(item)}Grams': grams(item).toString(),
    },
  };
  static String key(MacroGoal goal) => switch (goal) {
    MacroGoal.carbohydrate => 'carbs',
    MacroGoal.protein => 'protein',
    MacroGoal.fat => 'fat',
  };
}
