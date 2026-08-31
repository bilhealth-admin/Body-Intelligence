part of 'diet_plan_editor_page.dart';

class _DietHero extends StatelessWidget {
  const _DietHero({required this.pathway, required this.localeTag});
  final NutritionPathway pathway;
  final String localeTag;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(pathway.asset, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x05000000), Color(0xD900111C)],
              stops: [.25, 1],
            ),
          ),
        ),
        PositionedDirectional(
          start: 18,
          end: 18,
          bottom: 17,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nutritionPathwayTitle(pathway, localeTag),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                nutritionPathwaySubtitle(pathway, localeTag),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .9),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EvidenceNotice extends StatelessWidget {
  const _EvidenceNotice({required this.pathwayId});
  final String pathwayId;

  @override
  Widget build(BuildContext context) {
    final message = pathwayId == 'carb-cycling'
        ? nutritionText(
            context,
            'Carb cycling has no single proven universal schedule. This editable starting week keeps energy fixed and can follow training demand.',
            'لا يوجد جدول عالمي واحد مثبت لتدوير الكربوهيدرات. أسبوع البداية قابل للتعديل، يثبت الطاقة ويمكن ربطه بحمل التدريب.',
          )
        : pathwayId == 'pregnancy'
        ? nutritionText(
            context,
            'Built from WHO maternal nutrition guidance and trimester energy references. Your obstetric clinician remains the decision-maker.',
            'مبني على إرشادات منظمة الصحة العالمية لتغذية الأم ومراجع طاقة مراحل الحمل. يبقى طبيب الحمل صاحب القرار.',
          )
        : nutritionText(
            context,
            'A practical editable starting point using recognized adult macro ranges. It is not a diagnosis or prescription.',
            'نقطة بداية عملية قابلة للتعديل ضمن نطاقات المغذيات المعترف بها للبالغين، وليست تشخيصًا أو وصفة علاجية.',
          );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB9E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fact_check_outlined, color: Color(0xFF087F8C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(height: 1.4, color: Color(0xFF344054)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesField extends StatelessWidget {
  const _CaloriesField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('diet-calories-field'),
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: nutritionText(
        context,
        'Fixed daily calories',
        'السعرات اليومية الثابتة',
      ),
      suffixText: nutritionText(context, 'kcal', 'سعرة'),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class _MacroEditingNotice extends StatelessWidget {
  const _MacroEditingNotice();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('diet-macro-editing-notice'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F9FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFB9E6FE)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.calculate_outlined, color: Color(0xFF026AA2)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            nutritionText(
              context,
              'Calories and macros balanced for you',
              'تبقى السعرات ثابتة. عدّل الكربوهيدرات أو البروتين أو الدهون وسيوازن BIL القيمتين الأخريين ليبقى 4ك + 4ب + 9د مساويًا لهدفك.',
            ),
            style: const TextStyle(height: 1.4, color: Color(0xFF344054)),
          ),
        ),
      ],
    ),
  );
}

class _DietDayCard extends StatelessWidget {
  const _DietDayCard({
    required this.weekday,
    required this.carbController,
    required this.proteinController,
    required this.fatController,
    required this.target,
    required this.enabled,
    required this.onCarbsChanged,
    required this.onProteinChanged,
    required this.onFatChanged,
  });
  final int weekday;
  final TextEditingController carbController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final DietMacroTarget? target;
  final bool enabled;
  final ValueChanged<String> onCarbsChanged;
  final ValueChanged<String> onProteinChanged;
  final ValueChanged<String> onFatChanged;

  @override
  Widget build(BuildContext context) {
    final date = DateTime(2026, 1, 5 + weekday - 1);
    final day = MaterialLocalizations.of(
      context,
    ).formatFullDate(date).split(',').first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: target == null
              ? const Color(0xFFFDA29B)
              : const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              day,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 330 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.35;
              final width = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              Widget field({
                required Key key,
                required String label,
                required TextEditingController controller,
                required ValueChanged<String> onChanged,
              }) => SizedBox(
                width: width,
                child: TextField(
                  key: key,
                  controller: controller,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onChanged,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: label,
                    suffixText: 'g',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  field(
                    key: Key('diet-carbs-$weekday'),
                    label: nutritionText(context, 'Carbs', 'كربوهيدرات'),
                    controller: carbController,
                    onChanged: onCarbsChanged,
                  ),
                  field(
                    key: Key('diet-protein-$weekday'),
                    label: nutritionText(context, 'Protein', 'بروتين'),
                    controller: proteinController,
                    onChanged: onProteinChanged,
                  ),
                  field(
                    key: Key('diet-fat-$weekday'),
                    label: nutritionText(context, 'Fat', 'دهون'),
                    controller: fatController,
                    onChanged: onFatChanged,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (target == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                nutritionText(
                  context,
                  'Fixed calories',
                  'يجب أن تقع قيم الماكروز ضمن هدف السعرات الثابت: 4ك + 4ب + 9د.',
                ),
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            )
          else
            _MacroRail(target: target!),
        ],
      ),
    );
  }
}

class _MacroRail extends StatelessWidget {
  const _MacroRail({required this.target});
  final DietMacroTarget target;

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        nutritionText(context, 'Carbs', 'الكربوهيدرات'),
        target.carbsGrams,
        const Color(0xFF0BA5EC),
      ),
      (
        nutritionText(context, 'Protein', 'البروتين'),
        target.proteinGrams,
        const Color(0xFF7F56D9),
      ),
      (
        nutritionText(context, 'Fat', 'الدهون'),
        target.fatGrams,
        const Color(0xFFF79009),
      ),
    ];
    final ring = _MacroEnergyRing(target: target);
    final legend = _MacroLegend(values: values);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25;
        if (stacked) {
          return Column(children: [ring, const SizedBox(height: 10), legend]);
        }
        return Row(
          children: [
            ring,
            const SizedBox(width: 18),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _MacroEnergyRing extends StatelessWidget {
  const _MacroEnergyRing({required this.target});
  final DietMacroTarget target;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final dimension = 112.0 + ((scale - 1).clamp(0, 1) * 48);
    return SizedBox.square(
      dimension: dimension,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _MacroRingPainter(target: target, progress: progress),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${target.calories.round()}',
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.7,
                      ),
                    ),
                    Text(
                      nutritionText(context, 'kcal fixed', 'سعرة ثابتة'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter({required this.target, required this.progress});
  final DietMacroTarget target;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 7;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..color = const Color(0xFFEAECF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    canvas.drawCircle(center, radius, background);

    final energy = <(double, Color)>[
      (target.carbsGrams * 4, const Color(0xFF0BA5EC)),
      (target.proteinGrams * 4, const Color(0xFF7F56D9)),
      (target.fatGrams * 9, const Color(0xFFF79009)),
    ];
    const gap = .055;
    var start = -math.pi / 2;
    for (final segment in energy) {
      final sweep = math.pi * 2 * segment.$1 / target.calories;
      final paint = Paint()
        ..color = segment.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        bounds,
        start + gap / 2,
        math.max(0, sweep - gap) * progress,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.progress != progress;
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.values});
  final List<(String, double, Color)> values;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final item in values)
        Expanded(
          child: Column(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: item.$3,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${item.$2.round()} g',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: item.$3, fontWeight: FontWeight.w900),
              ),
              Text(
                item.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
    ],
  );
}

class _PregnancyControls extends StatelessWidget {
  const _PregnancyControls({
    required this.baseCaloriesController,
    required this.trimester,
    required this.effectiveCalories,
    required this.enabled,
    required this.onChanged,
    required this.onBaseChanged,
  });
  final TextEditingController baseCaloriesController;
  final int trimester;
  final double? effectiveCalories;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final ValueChanged<String> onBaseChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4E7EC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          nutritionText(context, 'Pregnancy stage', 'مرحلة الحمل'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: [
            for (var value = 1; value <= 3; value += 1)
              ButtonSegment(
                value: value,
                label: Text('$value'),
                tooltip:
                    '${nutritionText(context, 'Trimester', 'الثلث')} $value',
              ),
          ],
          selected: {trimester},
          onSelectionChanged: enabled
              ? (values) => onChanged(values.single)
              : null,
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('pregnancy-base-calories'),
          controller: baseCaloriesController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          onChanged: onBaseChanged,
          decoration: InputDecoration(
            labelText: nutritionText(
              context,
              'Pre-pregnancy daily calories',
              'السعرات اليومية قبل الحمل',
            ),
            suffixText: nutritionText(context, 'kcal', 'سعرة'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          effectiveCalories == null
              ? nutritionText(
                  context,
                  'Enter a valid calorie baseline.',
                  'أدخل قيمة صحيحة للسعرات الأساسية.',
                )
              : '${nutritionText(context, 'Current trimester target', 'هدف الثلث الحالي')}: ${effectiveCalories!.round()} ${nutritionText(context, 'kcal', 'سعرة')} '
                    '(+${PregnancyNutritionGuidance.extraCaloriesByTrimester[trimester]!.round()})',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF087F8C),
          ),
        ),
      ],
    ),
  );
}

class _PregnancyNutrientGuide extends StatelessWidget {
  const _PregnancyNutrientGuide();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        nutritionText(context, 'Iron', 'الحديد'),
        '30–60 mg',
        nutritionText(
          context,
          'WHO daily supplement range',
          'نطاق المكمل اليومي وفق WHO',
        ),
      ),
      (
        nutritionText(context, 'Folic acid', 'حمض الفوليك'),
        '400 µg',
        nutritionText(context, 'WHO daily supplement', 'مكمل يومي وفق WHO'),
      ),
      (
        nutritionText(context, 'Iodine', 'اليود'),
        '250 µg',
        nutritionText(context, 'WHO daily reference', 'مرجع WHO اليومي'),
      ),
      (
        nutritionText(context, 'Calcium', 'الكالسيوم'),
        '1500–2000 mg',
        nutritionText(
          context,
          'Only where dietary calcium intake is low, with clinician guidance',
          'فقط عند انخفاض المدخول الغذائي وبإرشاد المختص',
        ),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            nutritionText(
              context,
              'Maternal nutrition guide',
              'دليل تغذية الأم',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${item.$1}\n${item.$3}',
                      style: const TextStyle(height: 1.3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.$2,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            nutritionText(
              context,
              'Do not start or change supplements from this screen. Confirm doses with your antenatal clinician.',
              'لا تبدئي أو تغيّري المكملات من هذه الشاشة. أكدي الجرعات مع طبيب متابعة الحمل.',
            ),
            style: const TextStyle(
              color: Color(0xFF9A3412),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicianReview extends StatelessWidget {
  const _ClinicianReview({
    required this.medicallyLocked,
    required this.enabled,
    required this.acknowledged,
    required this.onChanged,
  });
  final bool medicallyLocked;
  final bool enabled;
  final bool acknowledged;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFFAEB),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFFEC84B)),
    ),
    child: CheckboxListTile(
      value: medicallyLocked ? false : acknowledged,
      onChanged: enabled ? onChanged : null,
      title: Text(
        medicallyLocked
            ? nutritionText(
                context,
                'This protocol stays locked without active medical supervision.',
                'يبقى هذا البروتوكول مقفلًا دون إشراف طبي فعلي.',
              )
            : nutritionText(
                context,
                'I will review this plan with my clinician before using it.',
                'سأراجع هذه الخطة مع المختص قبل استخدامها.',
              ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );
}
