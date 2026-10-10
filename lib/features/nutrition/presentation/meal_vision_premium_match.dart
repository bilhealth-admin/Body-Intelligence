part of 'meal_vision_premium_review.dart';

String _visionFoodTitle(BuildContext context, Food food) {
  final arabic = food.arabicName?.trim() ?? '';
  return Localizations.localeOf(context).languageCode == 'ar' &&
          arabic.isNotEmpty
      ? arabic
      : food.name;
}

class _PremiumTrustedMatchDialog extends StatefulWidget {
  const _PremiumTrustedMatchDialog({
    required this.recognizedName,
    required this.foods,
    this.reviewedAmount,
    this.reviewedUnit,
    this.evidenceOwnerKey,
    this.imagePath,
    this.editable = false,
  });
  final String recognizedName;
  final List<Food> foods;
  final double? reviewedAmount;
  final String? reviewedUnit;
  final String? evidenceOwnerKey;
  final String? imagePath;
  final bool editable;

  @override
  State<_PremiumTrustedMatchDialog> createState() =>
      _PremiumTrustedMatchDialogState();
}

class _PremiumTrustedMatchDialogState
    extends State<_PremiumTrustedMatchDialog> {
  Food? _selected;
  bool _full = false;
  late final TextEditingController _amount;
  late final TextEditingController _unit;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: '${widget.reviewedAmount ?? ''}');
    _unit = TextEditingController(text: widget.reviewedUnit ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _unit.dispose();
    super.dispose();
  }

  double? get _currentAmount =>
      double.tryParse(_PremiumVisionReviewDialogState._digits(_amount.text));
  String get _currentUnit => _unit.text.trim();

  bool get _validPortion {
    if (!widget.editable && widget.reviewedAmount == null) return true;
    final amount = _currentAmount;
    return _selected != null &&
        amount != null &&
        amount.isFinite &&
        amount > 0 &&
        mealImageReviewedQuantity(
              amount: amount,
              unit: _currentUnit,
              servingSize: _selected!.servingSize,
              servingUnit: _selected!.servingUnit,
            ) !=
            null;
  }

  void _stepAmount(double delta) {
    final amount = _currentAmount;
    if (amount == null || !amount.isFinite || amount + delta <= 0) return;
    setState(() => _amount.text = '${amount + delta}');
  }

  void _portionUpdate(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => _glassShell(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                        'Review nutrition source',
                        'مراجعة الطعام ومصدر التغذية',
                      ),
                      style: TextStyle(
                        color: _foreground(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              if (widget.editable) _portionEditor(context),
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
                          onTap:
                              mealVisionFoodCanBeUsed(
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
                            _visionFoodTitle(context, food),
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
                  padding: const EdgeInsets.all(12),
                  decoration: _glassDecoration(context),
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
                            child: Semantics(
                              selected: !_full,
                              child: FilledButton(
                                key: const Key('premium-vision-quick-toggle'),
                                onPressed: () => setState(() => _full = false),
                                style: FilledButton.styleFrom(
                                  backgroundColor: !_full
                                      ? _accent(context)
                                      : Colors.transparent,
                                  foregroundColor: !_full
                                      ? const Color(0xFF063029)
                                      : _foreground(context),
                                  side: BorderSide(color: _accent(context)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  _word(
                                    context,
                                    'Quick summary',
                                    'الملخص السريع',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Semantics(
                              selected: _full,
                              child: FilledButton(
                                key: const Key('premium-vision-full-toggle'),
                                onPressed: () => setState(() => _full = true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _full
                                      ? _accent(context)
                                      : Colors.transparent,
                                  foregroundColor: _full
                                      ? const Color(0xFF063029)
                                      : _foreground(context),
                                  side: BorderSide(color: _accent(context)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  _word(
                                    context,
                                    'Full analysis',
                                    'التحليل الكامل',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: FilledButton(
                key: const Key('premium-vision-use-food'),
                onPressed:
                    _selected == null ||
                        !mealVisionFoodCanBeUsed(
                          _selected!,
                          evidenceOwnerKey: widget.evidenceOwnerKey,
                        ) ||
                        !_validPortion
                    ? null
                    : () {
                        if (widget.editable) {
                          Navigator.pop(
                            context,
                            TrustedVisionFoodSelection(
                              food: _selected!,
                              amount: _currentAmount!,
                              unit: _currentUnit,
                            ),
                          );
                        } else {
                          Navigator.pop(context, _selected);
                        }
                      },
                style: _visionActionStyle(context),
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
        ),
      ],
    ),
  );

  Widget _nutritionFacts(BuildContext context, Food food) {
    // This does not infer nutrients from image pixels. It reads only the
    // explicitly selected, verified catalog record and its evidence mask.
    final portion = _currentAmount == null || _currentUnit.isEmpty
        ? null
        : mealImageReviewedQuantity(
            amount: _currentAmount!,
            unit: _currentUnit,
            servingSize: food.servingSize,
            servingUnit: food.servingUnit,
          );
    // Factor is tied to the catalog's actual mass, count or volume basis.
    // Neither the picture nor a piece count supplies an invented gram amount.
    final factor = portion?.servingFactor;
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
      (
        FoodNutrient.carbohydrates,
        _word(context, 'Carbs', 'الكربوهيدرات'),
        food.carbs,
        'g',
      ),
      (FoodNutrient.fat, _word(context, 'Fat', 'الدهون'), food.fats, 'g'),
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
    final primary = facts.take(5).toList();
    final extra = facts.skip(6).toList();

    Widget tiles(
      List<(FoodNutrient, String, double, String)> entries, {
      bool showNetCarbs = false,
    }) {
      return LayoutBuilder(
        builder: (context, dimensions) {
          final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
          final columns = (dimensions.maxWidth / (90 * scale + 8))
              .floor()
              .clamp(1, 3);
          final cellWidth = (dimensions.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            textDirection: TextDirection.ltr,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: cellWidth,
                  child: Directionality(
                    textDirection: Directionality.of(context),
                    child: _nutrientTile(
                      entry.$1.name,
                      entry.$2,
                      factor == null || !known(entry.$1, entry.$3)
                          ? null
                          : entry.$3 * factor,
                      entry.$4,
                    ),
                  ),
                ),
              if (showNetCarbs)
                SizedBox(
                  width: cellWidth,
                  child: Directionality(
                    textDirection: Directionality.of(context),
                    child: _nutrientTile(
                      'netCarbs',
                      _word(context, 'Net carbs', 'صافي الكربوهيدرات'),
                      !carbsKnown || !fiberKnown || factor == null
                          ? null
                          : (food.carbs - food.fiber)
                                    .clamp(0.0, double.infinity)
                                    .toDouble() *
                                factor,
                      'g',
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          factor == null
              ? _word(
                  context,
                  'Catalog serving only — reviewed amount not convertible',
                  'لكل حصة في المصدر فقط — لا يمكن تحويل الكمية المراجعة',
                )
              : _word(
                  context,
                  'For the amount you confirmed eating',
                  'للكمية التي أكدت تناولها',
                ),
          style: TextStyle(color: _secondary(context), fontSize: 11),
        ),
        const SizedBox(height: 10),
        Text(
          _word(context, 'Calories and macros', 'السعرات والمغذيات الكبرى'),
          style: TextStyle(
            color: _foreground(context),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        tiles(primary, showNetCarbs: true),
        const SizedBox(height: 8),
        Container(
          key: const Key('premium-vision-nutrient-sugar'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: _glassDecoration(context),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _word(context, 'Sugar', 'السكر'),
                style: TextStyle(color: _secondary(context), fontSize: 12),
              ),
              Directionality(
                textDirection:
                    factor == null || !known(FoodNutrient.sugar, food.sugar)
                    ? Directionality.of(context)
                    : TextDirection.ltr,
                child: Text(
                  factor == null || !known(FoodNutrient.sugar, food.sugar)
                      ? _word(context, 'Not available', 'غير متوفر')
                      : '${(food.sugar * factor).toStringAsFixed(1)} g',
                  style: TextStyle(
                    color: _foreground(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_full) ...[
          const SizedBox(height: 14),
          Text(
            _word(context, 'Minerals and vitamins', 'المعادن والفيتامينات'),
            style: TextStyle(
              color: _foreground(context),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          tiles(extra),
        ],
        const SizedBox(height: 12),
        Text(
          '${_word(context, 'Nutrition source: ', 'مصدر التغذية: ')}${food.source}',
          style: TextStyle(color: _accent(context), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          _word(
            context,
            'Recognition confidence is separate; the photo never verifies nutrient values.',
            'ثقة التعرّف مستقلة؛ الصورة لا تثبت القيم الغذائية.',
          ),
          style: TextStyle(color: _secondary(context), fontSize: 11),
        ),
      ],
    );
  }

  Widget _nutrientTile(String id, String label, double? value, String unit) {
    final (symbol, tint) = switch (id) {
      'calories' => (
        Icons.local_fire_department_rounded,
        const Color(0xFFFFA66B),
      ),
      'protein' => (Icons.egg_alt_rounded, const Color(0xFF75F2AD)),
      'fat' => (Icons.opacity_rounded, const Color(0xFFFFCC78)),
      'carbohydrates' => (Icons.bubble_chart_rounded, const Color(0xFF92C8FF)),
      'fiber' => (Icons.spa_rounded, const Color(0xFF73D999)),
      'netCarbs' => (Icons.water_drop_outlined, const Color(0xFF8AD8EA)),
      'sodium' => (Icons.science_outlined, const Color(0xFFBCD2E2)),
      'potassium' => (Icons.eco_outlined, const Color(0xFF86EB94)),
      'magnesium' => (Icons.grain_rounded, const Color(0xFFC1B1FF)),
      'calcium' => (Icons.bubble_chart_outlined, const Color(0xFFCDE9FF)),
      'phosphorus' => (Icons.hub_outlined, const Color(0xFFE7BBF8)),
      _ => (Icons.circle_outlined, _accent(context)),
    };
    return Container(
      key: Key('premium-vision-nutrient-$id'),
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(symbol, color: tint, size: 19),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: _secondary(context),
              fontSize: 10,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: value == null
                ? Directionality.of(context)
                : TextDirection.ltr,
            child: Text(
              value == null
                  ? _word(context, 'Not available', 'غير متوفر')
                  : '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                color: _foreground(context),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
