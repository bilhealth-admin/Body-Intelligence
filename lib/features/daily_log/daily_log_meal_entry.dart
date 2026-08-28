part of 'daily_log_page.dart';

extension _DailyLogMealEntryPresentation on _DailyLogPageState {
  String get _mealLocale =>
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  String _mealCopy(String key) {
    return dailyLogMealCopyForLocale(key, _mealLocale);
  }

  Widget _buildMealEntry() {
    return Offstage(
      offstage: selectedFood == null && !mealSearchActive,
      child: PremiumSurface(
        key: mealEntryKey,
        child: Column(
          children: [
            if (selectedFood == null) ...[
              SearchAnchor(
                searchController: foodSearch,
                viewBuilder: (suggestions) => ListView(
                  padding: EdgeInsets.zero,
                  children: suggestions.toList(growable: false),
                ),
                viewHintText: _mealCopy('searchDetail'),
                builder: (context, controller) => SearchBar(
                  enabled: !mealSaving,
                  controller: controller,
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surface,
                  ),
                  side: WidgetStatePropertyAll(
                    BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  hintText: _mealCopy('searchFoods'),
                  onTap: mealSaving ? null : controller.openView,
                ),
                suggestionsBuilder: (context, controller) {
                  final locale = _mealLocale;
                  final query = controller.text.trim();
                  if (query.isEmpty) {
                    return const <Widget>[];
                  }
                  return _mealQuerySuggestions(controller, query, locale);
                },
              ),
            ],
            if (selectedFood != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayFoodName(
                              selectedFood!,
                              FoodPresentationLocalizer.resultLocaleForQuery(
                                query: foodSearch.text,
                                interfaceLocaleTag: _mealLocale,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: ref
                          .read(foodRepositoryProvider)
                          .isFavorite(selectedFood!.id),
                      builder: (context, snapshot) {
                        final favorite = snapshot.data ?? false;
                        return IconButton(
                          key: const ValueKey('daily-log-toggle-favorite'),
                          tooltip: favorite
                              ? _mealCopy('removeFavorite')
                              : _mealCopy('saveFavorite'),
                          onPressed:
                              mealSaving ||
                                  snapshot.connectionState ==
                                      ConnectionState.waiting
                              ? null
                              : () async {
                                  await ref
                                      .read(foodRepositoryProvider)
                                      .setFavorite(selectedFood!.id, !favorite);
                                  ref.invalidate(favoriteFoodsProvider);
                                  if (mounted) _updateState(() {});
                                },
                          icon: Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: context.strings.text('Close'),
                      onPressed: mealSaving
                          ? null
                          : () => _updateState(() => selectedFood = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            if (selectedFood != null) ...[
              _selectedFoodNutritionPreview(selectedFood!),
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              FilledButton.tonalIcon(
                key: const Key('daily-log-save-meal-action'),
                onPressed: mealSaving ? null : _saveMeal,
                icon: const Icon(Icons.restaurant_menu),
                label: Text(
                  context.strings.text(mealSaving ? 'Saving…' : 'Save meal'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectedFoodNutritionPreview(Food food) {
    final enteredAmount = double.tryParse(quantity.text.trim());
    final amount = enteredAmount != null && enteredAmount > 0
        ? enteredAmount
        : food.servingSize;
    final servingGrams = dailyLogAmountInGrams(
      amount: food.servingSize,
      unit: food.servingUnit,
    );
    final amountGrams = dailyLogAmountInGrams(
      amount: amount,
      unit: mealQuantityUnit,
    );
    final scale =
        servingGrams != null &&
            servingGrams > 0 &&
            amountGrams != null &&
            amountGrams.isFinite
        ? amountGrams / servingGrams
        : 1.0;
    final calories = food.calories * scale;
    final protein = food.protein * scale;
    final carbs = food.carbs * scale;
    final fat = food.fats * scale;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final scheme = Theme.of(context).colorScheme;
    bool available(TrackedNutrient nutrient, double value) =>
        value != 0 ||
        NutrientEvidenceMask.contains(food.nutrientEvidenceMask, nutrient);
    final nutritionFacts = <({String label, double value, String unit})>[
      if (available(TrackedNutrient.fiber, food.fiber))
        (label: 'Fiber', value: food.fiber * scale, unit: 'g'),
      if (available(TrackedNutrient.sugar, food.sugar))
        (label: 'Sugar', value: food.sugar * scale, unit: 'g'),
      if (available(TrackedNutrient.sodium, food.sodium))
        (label: 'Sodium', value: food.sodium * scale, unit: 'mg'),
      if (available(TrackedNutrient.potassium, food.potassium))
        (label: 'Potassium', value: food.potassium * scale, unit: 'mg'),
      if (available(TrackedNutrient.calcium, food.calcium))
        (label: 'Calcium', value: food.calcium * scale, unit: 'mg'),
      if (available(TrackedNutrient.magnesium, food.magnesium))
        (label: 'Magnesium', value: food.magnesium * scale, unit: 'mg'),
      if (available(TrackedNutrient.phosphorus, food.phosphorus))
        (label: 'Phosphorus', value: food.phosphorus * scale, unit: 'mg'),
      if (food.iron != 0) (label: 'Iron', value: food.iron * scale, unit: 'mg'),
      if (food.vitaminC != 0)
        (label: 'Vitamin C', value: food.vitaminC * scale, unit: 'mg'),
    ];
    final nutritionFactsExpanded = expandedNutritionFactsFoodId == food.id;

    return Container(
      key: const Key('daily-log-selected-food-details'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('daily-log-meal-type-field'),
            initialValue: mealType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.strings.text('Meal type'),
              prefixIcon: const Icon(Icons.restaurant_outlined),
            ),
            items: [
              for (final type in const [
                'breakfast',
                'lunch',
                'dinner',
                'snack',
              ])
                DropdownMenuItem(
                  value: type,
                  child: Text(
                    context.strings.text(
                      '${type[0].toUpperCase()}${type.substring(1)}',
                    ),
                  ),
                ),
            ],
            selectedItemBuilder: (context) => [
              for (final type in const [
                'breakfast',
                'lunch',
                'dinner',
                'snack',
              ])
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.strings.text(
                      '${type[0].toUpperCase()}${type.substring(1)}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: mealSaving
                ? null
                : (value) {
                    if (value == null || value == mealType) return;
                    _updateState(() => mealType = value);
                  },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final amountField = TextFormField(
                key: const Key('daily-log-serving-amount-field'),
                controller: quantity,
                enabled: !mealSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: _mealCopy('servingSize'),
                  prefixIcon: const Icon(Icons.scale_outlined),
                ),
                onChanged: (_) => _updateState(() {}),
              );
              final unitField = DropdownButtonFormField<String>(
                key: const Key('daily-log-serving-unit-field'),
                initialValue: mealQuantityUnit,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                items: [
                  for (final unit in const ['g', 'oz', 'kg', 'lb'])
                    DropdownMenuItem(
                      value: unit,
                      child: Text(
                        FoodPresentationLocalizer.servingUnit(unit, locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: mealSaving
                    ? null
                    : (value) {
                        if (value == null || value == mealQuantityUnit) {
                          return;
                        }
                        _changeMealQuantityUnit(value);
                      },
              );
              final largeText =
                  MediaQuery.textScalerOf(context).scale(1) >= 1.35;
              if (largeText || constraints.maxWidth < 330) {
                return Column(
                  children: [
                    amountField,
                    const SizedBox(height: 10),
                    unitField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: amountField),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: unitField),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final macroRow = Row(
                children: [
                  Expanded(
                    child: _FoodMacroValue(
                      label: _mealCopy('carbs'),
                      value: carbs,
                      color: const Color(0xFF0A8F88),
                    ),
                  ),
                  Expanded(
                    child: _FoodMacroValue(
                      label: _mealCopy('fat'),
                      value: fat,
                      color: const Color(0xFF6F1096),
                    ),
                  ),
                  Expanded(
                    child: _FoodMacroValue(
                      label: _mealCopy('protein'),
                      value: protein,
                      color: const Color(0xFFC56A00),
                    ),
                  ),
                ],
              );
              final ring = DailyLogCalorieMacroRing(
                calories: calories,
                calorieGoal: null,
                carbs: carbs,
                fat: fat,
                protein: protein,
              );
              final guardedMacros = PremiumNutritionGlass(
                key: const Key('daily-log-food-macros-glass'),
                borderRadius: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: macroRow,
                ),
              );
              if (constraints.maxWidth < 420 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.35) {
                return Column(
                  children: [ring, const SizedBox(height: 16), guardedMacros],
                );
              }
              return Row(
                children: [
                  ring,
                  const SizedBox(width: 16),
                  Expanded(child: guardedMacros),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          PremiumNutritionGlass(
            key: const Key('daily-log-nutrition-facts-glass'),
            borderRadius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  expanded: nutritionFactsExpanded,
                  label: FoodPresentationLocalizer.label(
                    'nutritionFacts',
                    locale,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      key: const Key('daily-log-nutrition-facts'),
                      minTileHeight: 56,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: Icon(
                        Icons.fact_check_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(
                        FoodPresentationLocalizer.label(
                          'nutritionFacts',
                          locale,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: nutritionFacts.isEmpty
                          ? Text(
                              FoodPresentationLocalizer.label(
                                'noAdditionalNutrients',
                                locale,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: Icon(
                        nutritionFactsExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      onTap: nutritionFacts.isEmpty
                          ? null
                          : () => _updateState(() {
                              expandedNutritionFactsFoodId =
                                  nutritionFactsExpanded ? null : food.id;
                            }),
                    ),
                  ),
                ),
                if (nutritionFactsExpanded && nutritionFacts.isNotEmpty) ...[
                  Divider(height: 1, color: scheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final largeText =
                            MediaQuery.textScalerOf(context).scale(1) >= 1.35;
                        final factWidth = largeText
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          key: const Key('daily-log-nutrition-facts-expanded'),
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            for (final fact in nutritionFacts)
                              SizedBox(
                                width: factWidth,
                                child: _NutritionFactRow(
                                  label: context.strings.text(fact.label),
                                  value: fact.value,
                                  unit: fact.unit,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _changeMealQuantityUnit(String nextUnit) {
    final current = double.tryParse(quantity.text.trim().replaceAll(',', '.'));
    final grams = current == null
        ? null
        : dailyLogAmountInGrams(amount: current, unit: mealQuantityUnit);
    _updateState(() {
      mealQuantityUnit = nextUnit;
      if (grams != null && grams.isFinite && grams > 0) {
        final converted = dailyLogAmountFromGrams(grams: grams, unit: nextUnit);
        quantity.text = converted.toStringAsFixed(
          converted >= 100 || converted == converted.roundToDouble() ? 0 : 2,
        );
      }
    });
  }
}

class _NutritionFactRow extends StatelessWidget {
  const _NutritionFactRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final decimals = value.abs() >= 100 ? 0 : 1;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${value.toStringAsFixed(decimals)} $unit',
          textDirection: TextDirection.ltr,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
