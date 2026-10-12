/// UI draft increments in the SELECTED unit, never a serving-to-mass conversion
/// or nutrition recommendation. Unrecognized units remain manually editable.
({double step, int decimals})? mealPortionDraftStep(String unit) =>
    switch (unit.trim().toLowerCase()) {
      'g' || 'gram' || 'grams' || 'gm' || 'جم' => (step: 5, decimals: 1),
      'kg' || 'kilogram' || 'kilograms' || 'كجم' => (step: .005, decimals: 3),
      'mg' || 'milligram' || 'milligrams' => (step: 5000, decimals: 0),
      'oz' || 'ounce' || 'ounces' => (step: .1, decimals: 1),
      'lb' || 'lbs' || 'pound' || 'pounds' => (step: .01, decimals: 2),
      'ml' || 'milliliter' || 'milliliters' => (step: 5, decimals: 1),
      'l' || 'liter' || 'liters' => (step: .005, decimals: 3),
      'piece' ||
      'pieces' ||
      'serving' ||
      'servings' ||
      'cup' ||
      'tbsp' ||
      'tsp' => (step: .25, decimals: 2),
      _ => null,
    };
