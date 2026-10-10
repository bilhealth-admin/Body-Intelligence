part of 'meal_vision_premium_review.dart';

class _PremiumTrustedMatchDialog extends StatefulWidget {
  const _PremiumTrustedMatchDialog({
    required this.recognizedName,
    required this.foods,
    this.reviewedAmount,
    this.reviewedUnit,
    this.evidenceOwnerKey,
  });
  final String recognizedName;
  final List<Food> foods;
  final double? reviewedAmount;
  final String? reviewedUnit;
  final String? evidenceOwnerKey;

  @override
  State<_PremiumTrustedMatchDialog> createState() =>
      _PremiumTrustedMatchDialogState();
}

class _PremiumTrustedMatchDialogState
    extends State<_PremiumTrustedMatchDialog> {
  Food? _selected;
  bool _full = false;

  @override
  Widget build(BuildContext context) => _glassShell(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: _accent(context)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _word(
                        context,
                        'Choose a trusted food record',
                        'اختر سجل الطعام الموثوق',
                      ),
                      style: TextStyle(
                        color: _foreground(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: _foreground(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.recognizedName,
                style: TextStyle(color: _accent(context), fontSize: 15),
              ),
              const SizedBox(height: 5),
              Text(
                _word(
                  context,
                  'Check the serving and source. No food is saved by this choice alone.',
                  'راجع الحصة والمصدر. مجرد الاختيار لا يحفظ الوجبة.',
                ),
                style: TextStyle(color: _secondary(context), fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final food in widget.foods)
                Builder(
                  builder: (context) {
                    final active = identical(_selected, food);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      decoration: _glassDecoration(context, active: active),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          onTap: mealVisionFoodCanBeUsed(
                            food,
                            evidenceOwnerKey: widget.evidenceOwnerKey,
                          )
                              ? () => setState(() => _selected = food)
                              : null,
                          leading: Icon(
                            active
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: active
                                ? _accent(context)
                                : _secondary(context),
                          ),
                          title: Text(
                            food.name,
                            style: TextStyle(
                              color: _foreground(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            food.verified
                              ? '${food.servingSize} ${food.servingUnit} · ${food.source}'
                              : '${food.servingSize} ${food.servingUnit} · ${food.source} · ${_word(context, 'Label evidence, not catalog-verified', 'دليل من ملصق غذائي، غير موثّق من الكتالوج')}',
                            style: TextStyle(
                              color: _secondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (_selected != null)
                Container(
                  key: const Key('premium-vision-trusted-nutrients'),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: _glassDecoration(context, active: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _word(
                          context,
                          _selected!.verified
                              ? 'Nutrition from trusted record'
                              : 'Nutrition from reviewed label evidence',
                          _selected!.verified
                              ? 'القيمة الغذائية من السجل الموثوق'
                              : 'القيمة الغذائية من دليل ملصق راجعته أنت',
                        ),
                        style: TextStyle(
                          color: _accent(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _word(
                          context,
                          'Values come from the selected catalog record, not the photo.',
                          'القيم من سجل الطعام المختار، وليس من الصورة.',
                        ),
                        style: TextStyle(
                          color: _secondary(context),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _word(context, 'Quick summary', 'الملخص السريع'),
                              style: TextStyle(color: _foreground(context)),
                            ),
                          ),
                          Switch(
                            key: const Key('premium-vision-full-toggle'),
                            value: _full,
                            onChanged: (v) => setState(() => _full = v),
                          ),
                          Text(
                            _word(context, 'Full analysis', 'التحليل الكامل'),
                            style: TextStyle(
                              color: _secondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      _nutritionFacts(context, _selected!),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('premium-vision-use-food'),
              onPressed:
                  _selected == null ||
                      !mealVisionFoodCanBeUsed(
                        _selected!,
                        evidenceOwnerKey: widget.evidenceOwnerKey,
                      ) ||
                      (widget.reviewedAmount != null &&
                          widget.reviewedUnit != null &&
                          mealImageAmountInGrams(
                                amount: widget.reviewedAmount!,
                                unit: widget.reviewedUnit!,
                                servingSize: _selected!.servingSize,
                                servingUnit: _selected!.servingUnit,
                              ) ==
                              null)
                  ? null
                  : () => Navigator.pop(context, _selected),
              child: Text(
                _word(
                  context,
                  _selected?.verified == true
                      ? 'Use this verified food'
                      : 'Use this reviewed food source',
                  _selected?.verified == true
                      ? 'استخدام الطعام الموثوق'
                      : 'استخدام مصدر الطعام الذي راجعته',
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _nutritionFacts(BuildContext context, Food food) {
    // This does not infer nutrients from image pixels. It reads only the
    // explicitly selected, verified catalog record and its evidence mask.
    final grams = widget.reviewedAmount == null || widget.reviewedUnit == null
        ? null
        : mealImageAmountInGrams(
            amount: widget.reviewedAmount!,
            unit: widget.reviewedUnit!,
            servingSize: food.servingSize,
            servingUnit: food.servingUnit,
          );
    // Existing diary contract stores catalog nutrients per servingSize grams.
    // Do not scale unless the unit conversion is guaranteed by that contract.
    final factor = grams == null || food.servingSize <= 0
        ? null
        : grams / food.servingSize;
    final facts = <(FoodNutrient, String, double, String)>[
      (
        FoodNutrient.calories,
        _word(context, 'Calories', 'السعرات'),
        food.calories,
        'kcal',
      ),
      (
        FoodNutrient.protein,
        _word(context, 'Protein', 'البروتين'),
        food.protein,
        'g',
      ),
      (FoodNutrient.fat, _word(context, 'Fat', 'الدهون'), food.fats, 'g'),
      (
        FoodNutrient.carbohydrates,
        _word(context, 'Carbs', 'الكربوهيدرات'),
        food.carbs,
        'g',
      ),
      (FoodNutrient.fiber, _word(context, 'Fiber', 'الألياف'), food.fiber, 'g'),
      (FoodNutrient.sugar, _word(context, 'Sugar', 'السكر'), food.sugar, 'g'),
      (
        FoodNutrient.potassium,
        _word(context, 'Potassium', 'البوتاسيوم'),
        food.potassium,
        'mg',
      ),
      (
        FoodNutrient.sodium,
        _word(context, 'Sodium', 'الصوديوم'),
        food.sodium,
        'mg',
      ),
      (
        FoodNutrient.magnesium,
        _word(context, 'Magnesium', 'المغنيسيوم'),
        food.magnesium,
        'mg',
      ),
      (
        FoodNutrient.calcium,
        _word(context, 'Calcium', 'الكالسيوم'),
        food.calcium,
        'mg',
      ),
      (
        FoodNutrient.phosphorus,
        _word(context, 'Phosphorus', 'الفوسفور'),
        food.phosphorus,
        'mg',
      ),
      (FoodNutrient.iron, _word(context, 'Iron', 'الحديد'), food.iron, 'mg'),
      (
        FoodNutrient.vitaminC,
        _word(context, 'Vitamin C', 'فيتامين C'),
        food.vitaminC,
        'mg',
      ),
    ];
    bool known(FoodNutrient nutrient, double value) =>
        (nutrient != FoodNutrient.iron &&
            nutrient != FoodNutrient.vitaminC &&
            UnifiedFood.evidenceFromMask(
              food.nutrientEvidenceMask,
              nutrient,
            )) ||
        value != 0;
    final carbsKnown = known(FoodNutrient.carbohydrates, food.carbs);
    final fiberKnown = known(FoodNutrient.fiber, food.fiber);
    final visible = _full ? facts : facts.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          factor == null
              ? _word(
                  context,
                  'Per catalog serving (not adjusted)',
                  'القيم لكل حصة في السجل (لم تحوّل الكمية)',
                )
              : _word(
                  context,
                  'For your reviewed eaten amount',
                  'للكمية المأكولة التي راجعتها',
                ),
          style: TextStyle(color: _secondary(context), fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final entry in visible)
              _nutrientTile(
                entry.$1.name,
                entry.$2,
                factor == null || !known(entry.$1, entry.$3)
                    ? null
                    : entry.$3 * factor,
                entry.$4,
              ),
            if (carbsKnown && fiberKnown && factor != null)
              _nutrientTile(
                'netCarbs',
                _word(context, 'Net carbs', 'صافي الكربوهيدرات'),
                (food.carbs - food.fiber).clamp(0, double.infinity).toDouble() *
                    factor,
                'g',
              ),
            if (_full && (!carbsKnown || !fiberKnown))
              _nutrientTile(
                'netCarbs',
                _word(context, 'Net carbs', 'صافي الكربوهيدرات'),
                null,
                'g',
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _word(context, 'Nutrition source: ', 'مصدر التغذية: ') + food.source,
          style: TextStyle(color: _accent(context), fontSize: 12),
        ),
        Text(
          _word(
            context,
            'Image recognition is a separate source and does not verify calories.',
            'التعرّف بالصورة مصدر منفصل ولا يثبت السعرات.',
          ),
          style: TextStyle(color: _secondary(context), fontSize: 11),
        ),
      ],
    );
  }

  Widget _nutrientTile(String id, String label, double? value, String unit) =>
      Container(
        key: Key('premium-vision-nutrient-$id'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: _glassDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: _secondary(context), fontSize: 11),
            ),
            Text(
              value == null
                  ? _word(context, 'Not available', 'غير متوفر')
                  : '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                color: _foreground(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
}
