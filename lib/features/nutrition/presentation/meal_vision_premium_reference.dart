part of 'meal_vision_premium_review.dart';

ButtonStyle _visionActionStyle(BuildContext context) => FilledButton.styleFrom(
  backgroundColor: const Color(0xFF39E59D),
  foregroundColor: const Color(0xFF052C25),
  disabledBackgroundColor: _light(context)
      ? const Color(0xFFD6E4DE)
      : const Color(0xFF284249),
  disabledForegroundColor: _secondary(context),
  minimumSize: const Size(0, 54),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
  textStyle: Theme.of(
    context,
  ).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
);

extension _PremiumVisionReference on _PremiumVisionReviewDialogState {
  Widget _candidateHeading(int index) {
    final item = _foods[index];
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final diameter = 72 * scale.clamp(1.0, 1.65);
    final low = item.confidence < .55;
    final tint = low ? const Color(0xFFFFC66E) : _accent(context);
    return Row(
      children: [
        SizedBox(
          width: diameter,
          height: diameter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: item.confidence.clamp(0, 1).toDouble()),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 600),
            builder: (_, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 5,
                  backgroundColor: const Color(0x334B8F80),
                  color: tint,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _word(context, 'Recognition', 'ثقة التعرّف'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _secondary(context),
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        '${(item.confidence * 100).round()}%',
                        style: TextStyle(
                          color: tint,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  color: _foreground(context),
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: _glassDecoration(context),
                child: Text(
                  _word(context, 'Review ingredient', 'مراجعة المكوّن'),
                  style: TextStyle(color: _secondary(context), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Checkbox(
          key: Key('premium-vision-select-$index'),
          value: _selected.contains(index),
          onChanged: (value) => _visualUpdate(() {
            if (value == true) {
              _selected.add(index);
            } else {
              _selected.remove(index);
            }
          }),
          activeColor: _accent(context),
          checkColor: _bgBottom,
        ),
      ],
    );
  }

  Widget _reviewContext(String clock) {
    final single = _foods.length == 1 ? _foods.first : null;
    final quantity = single?.amount;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final unit = mealImageUnitLabel(single?.unit ?? '', locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, dimensions) {
            final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
            final columns = (dimensions.maxWidth / (88 * scale)).floor().clamp(
              1,
              3,
            );
            final width = (dimensions.maxWidth - 8 * (columns - 1)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: width,
                  child: _contextTile(
                    context,
                    Icons.wb_sunny_outlined,
                    _word(context, 'Meal', 'الوجبة'),
                    _mealLabel(context, widget.mealType),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _contextTile(
                    context,
                    Icons.schedule_rounded,
                    _word(context, 'Time', 'الوقت'),
                    clock,
                    clock: true,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _contextTile(
                    context,
                    Icons.scale_outlined,
                    _word(context, 'Suggested', 'مقترحة'),
                    quantity == null
                        ? '—'
                        : '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} $unit',
                    numeric: true,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: _glassDecoration(context),
          child: _stageChooser(context),
        ),
      ],
    );
  }

  Widget _reviewActionBar(int count) {
    final enabled = _canContinue;
    final primary = FilledButton.icon(
      key: const Key('premium-vision-continue'),
      onPressed: enabled ? _confirm : null,
      icon: const Icon(Icons.check_rounded),
      label: Text(_word(context, 'Match ingredients', 'مطابقة المكونات')),
      style: _visionActionStyle(context),
    );
    final edit = OutlinedButton.icon(
      key: const Key('premium-vision-edit-ingredients'),
      onPressed: () {
        final target = _ingredientsAnchor.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          );
        }
      },
      icon: const Icon(Icons.tune_rounded, size: 18),
      label: Text(_word(context, 'Edit ingredients', 'تعديل المكونات')),
      style: OutlinedButton.styleFrom(
        foregroundColor: _foreground(context),
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        side: BorderSide(color: _secondary(context).withValues(alpha: .45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontSize: 12),
      ),
    );
    return Container(
      key: const Key('premium-vision-sticky-action'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: _light(context)
            ? const Color(0xFFF0FAF6)
            : const Color(0xFF031C1D),
        border: const Border(top: BorderSide(color: _outline, width: .8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_word(context, 'Selected ingredients: ', 'المكونات المحددة: ')}$count · ${_word(context, 'Nothing saved yet', 'لم يُحفظ شيء بعد')}',
            style: TextStyle(color: _secondary(context), fontSize: 10),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _word(
                  context,
                  'Select a food, stage and amount actually eaten.',
                  'حدّد الصنف ومرحلة الصورة والكمية المأكولة.',
                ),
                style: TextStyle(color: _secondary(context), fontSize: 10),
              ),
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, dimensions) {
              if (MediaQuery.textScalerOf(context).scale(12) > 18 ||
                  dimensions.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [primary, const SizedBox(height: 8), edit],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: primary),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: edit),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _contextTile(
  BuildContext context,
  IconData icon,
  String label,
  String value, {
  bool clock = false,
  bool numeric = false,
}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  decoration: _glassDecoration(context),
  child: Column(
    children: [
      Icon(icon, color: _accent(context), size: 20),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: _secondary(context), fontSize: 11),
      ),
      const SizedBox(height: 3),
      Directionality(
        textDirection: clock || numeric
            ? TextDirection.ltr
            : Directionality.of(context),
        child: Text(
          value,
          key: clock ? const Key('premium-vision-clock') : null,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _foreground(context),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  ),
);

Widget _unverifiedNutrition(BuildContext context) => Container(
  key: const Key('premium-vision-unverified-nutrition'),
  padding: const EdgeInsets.all(12),
  decoration: _glassDecoration(context),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _word(context, 'Nutrition', 'القيمة الغذائية'),
        style: TextStyle(
          color: _foreground(context),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFFFA65D),
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '—',
                  style: TextStyle(
                    color: _foreground(context),
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _word(
                    context,
                    'Awaiting trusted nutrition source',
                    'بانتظار مصدر غذائي موثوق',
                  ),
                  style: TextStyle(color: _secondary(context), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, dimensions) {
          final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
          final columns = (dimensions.maxWidth / (90 * scale + 8))
              .floor()
              .clamp(1, 3);
          final width = (dimensions.maxWidth - 8 * (columns - 1)) / columns;
          final facts = [
            (
              Icons.egg_alt_rounded,
              _word(context, 'Protein', 'البروتين'),
              const Color(0xFF69EBA2),
            ),
            (
              Icons.water_drop_outlined,
              _word(context, 'Carbs', 'الكربوهيدرات'),
              const Color(0xFF92C8FF),
            ),
            (
              Icons.opacity_rounded,
              _word(context, 'Fat', 'الدهون'),
              const Color(0xFFFFC578),
            ),
            (
              Icons.spa_outlined,
              _word(context, 'Fiber', 'الألياف'),
              const Color(0xFF79D9A0),
            ),
            (
              Icons.grain_rounded,
              _word(context, 'Net carbs', 'صافي الكربوهيدرات'),
              const Color(0xFF8AD8EA),
            ),
            (
              Icons.view_in_ar_outlined,
              _word(context, 'Sugar', 'السكر'),
              const Color(0xFFCDD8E5),
            ),
          ];
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _glassDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(fact.$1, color: fact.$3, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          fact.$2,
                          style: TextStyle(
                            color: _secondary(context),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          _word(context, 'Not available', 'غير متوفر'),
                          style: TextStyle(
                            color: _foreground(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      Text(
        _word(
          context,
          'Calories and nutrients appear after matching a trusted food record.',
          'تظهر السعرات والمغذيات بعد مطابقة الطعام بمصدر موثوق.',
        ),
        style: TextStyle(color: _secondary(context), fontSize: 11),
      ),
    ],
  ),
);
