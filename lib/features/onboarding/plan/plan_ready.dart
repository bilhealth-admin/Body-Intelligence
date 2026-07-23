part of '../bil_flagship_onboarding.dart';

class _PlanReady extends StatefulWidget {
  const _PlanReady({
    required this.draft,
    required this.plan,
    required this.isArabic,
    required this.busy,
    required this.onBack,
    required this.onPlanChanged,
    required this.onEnter,
  });

  final BilOnboardingDraft draft;
  final BilInitialPlan? plan;
  final bool isArabic;
  final bool busy;
  final VoidCallback onBack;
  final ValueChanged<BilInitialPlan> onPlanChanged;
  final VoidCallback onEnter;

  @override
  State<_PlanReady> createState() => _PlanReadyState();
}

class _PlanReadyState extends State<_PlanReady> {
  BilInitialPlan? displayedPlan;

  String tr(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    displayedPlan = widget.plan;
  }

  @override
  void didUpdateWidget(covariant _PlanReady oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plan != null && widget.plan != oldWidget.plan) {
      displayedPlan = widget.plan;
    }
  }

  int? get age {
    final birthDate = widget.draft.birthDate;
    if (birthDate == null) return null;
    final today = DateTime.now();
    var value = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      value--;
    }
    return value;
  }

  double? get bmi {
    final weight = widget.draft.weight;
    final height = widget.draft.height;
    if (weight == null || height == null) return null;
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  double? get bodyFat {
    final height = widget.draft.height;
    final waist = widget.draft.waist;
    final neck = widget.draft.neck;

    // US Navy circumference method for men requires height, waist and neck.
    if (widget.draft.sex == BilSex.male &&
        height != null &&
        waist != null &&
        neck != null &&
        waist > neck) {
      final denominator =
          1.0324 -
          0.19077 * (math.log(waist - neck) / math.ln10) +
          0.15456 * (math.log(height) / math.ln10);
      final estimate = 495 / denominator - 450;
      if (estimate.isFinite) return estimate.clamp(3, 60);
    }

    // Female Navy calculation also requires hip circumference, which the
    // onboarding intentionally does not request. Use the BMI-age fallback
    // rather than presenting false precision.
    final currentBmi = bmi;
    final currentAge = age;
    if (currentBmi == null || currentAge == null) return null;
    final sexOffset = widget.draft.sex == BilSex.male ? 1 : 0;
    return ((1.20 * currentBmi) +
            (0.23 * currentAge) -
            (10.8 * sexOffset) -
            5.4)
        .clamp(3, 60);
  }

  String get bodyFatMethod {
    if (widget.draft.sex == BilSex.male &&
        widget.draft.height != null &&
        widget.draft.waist != null &&
        widget.draft.neck != null &&
        widget.draft.waist! > widget.draft.neck!) {
      return tr('Navy circumference estimate', 'تقدير محيطات Navy');
    }
    return tr('BMI-based estimate', 'تقدير قائم على BMI');
  }

  Future<void> editSuggestedTargets(
    BuildContext context,
    BilInitialPlan current,
  ) async {
    final updated = await showModalBottomSheet<BilInitialPlan>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuggestedTargetsSheet(
        initialPlan: current,
        goal: widget.draft.goal,
        weightKg: widget.draft.weight ?? 70,
        isArabic: widget.isArabic,
      ),
    );

    if (updated == null || !mounted) return;
    setState(() => displayedPlan = updated);
    widget.onPlanChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final current = displayedPlan ?? widget.plan;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final score = widget.draft.waist != null && widget.draft.neck != null
        ? .92
        : widget.draft.waist != null
        ? .86
        : .78;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        final desktopWeb = constraints.maxWidth >= 1100;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/v10_master/bil_hdr_starfield_master.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            const Positioned.fill(child: _V8PlanBackground()),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                desktopWeb ? 54 : (wide ? 40 : 16),
                desktopWeb ? 14 : 18,
                desktopWeb ? 54 : (wide ? 40 : 16),
                desktopWeb ? 22 : 26,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: desktopWeb ? 1000 : 1120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Semantics(
                            button: true,
                            label: tr('Edit data', 'تعديل البيانات'),
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: .18),
                                    const Color(
                                      0xFF5AD9FF,
                                    ).withValues(alpha: .10),
                                    const Color(
                                      0xFF765FFF,
                                    ).withValues(alpha: .09),
                                    Colors.white.withValues(alpha: .045),
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x704FD6FF),
                                    blurRadius: 28,
                                    spreadRadius: -8,
                                  ),
                                  BoxShadow(
                                    color: Color(0x50000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 9),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: widget.onBack,
                                tooltip: tr('Edit data', 'تعديل البيانات'),
                                iconSize: 30,
                                splashRadius: 28,
                                color: const Color(0xFFF3F7FA),
                                icon: Icon(
                                  widget.isArabic
                                      ? Icons.arrow_forward_rounded
                                      : Icons.arrow_back_rounded,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          const _V8PlanBrand(),
                        ],
                      ),
                      Text(
                        tr('Your Body Model is Ready', 'نموذج جسمك جاهز'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFDDE6EE),
                          fontSize: desktopWeb ? 30 : 33,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.55,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'A strong starting model that improves with your daily data.',
                          'نموذج بداية قوي يتحسن مع بياناتك اليومية.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _BilColors.textMuted,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: desktopWeb ? 13 : 17),
                      Center(
                        child: Transform.scale(
                          scale: desktopWeb ? .90 : 1,
                          alignment: Alignment.center,
                          child: _V8ScoreRing(
                            progress: score,
                            isArabic: widget.isArabic,
                          ),
                        ),
                      ),
                      SizedBox(height: desktopWeb ? 6 : 18),
                      _V8MetricsGrid(
                        draft: widget.draft,
                        bmi: bmi,
                        bodyFat: bodyFat,
                        bodyFatMethod: bodyFatMethod,
                        isArabic: widget.isArabic,
                      ),
                      const SizedBox(height: 16),
                      wide
                          ? Row(
                              children: [
                                Expanded(
                                  child: _V8EnergyCard(
                                    plan: current,
                                    isArabic: widget.isArabic,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _V8MacroCard(
                                    plan: current,
                                    isArabic: widget.isArabic,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _V8EnergyCard(
                                  plan: current,
                                  isArabic: widget.isArabic,
                                ),
                                const SizedBox(height: 14),
                                _V8MacroCard(
                                  plan: current,
                                  isArabic: widget.isArabic,
                                ),
                              ],
                            ),
                      const SizedBox(height: 15),
                      _V8SuggestedTargetsButton(
                        label: tr(
                          'Edit suggested targets',
                          'تعديل الأهداف المقترحة',
                        ),
                        onPressed: () => editSuggestedTargets(context, current),
                      ),
                      const SizedBox(height: 12),
                      _V8StartBilButton(
                        label: tr('Start with BIL', 'ابدأ مع BIL'),
                        busy: widget.busy,
                        onPressed: widget.busy ? null : widget.onEnter,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _V8PlanBackground extends StatelessWidget {
  const _V8PlanBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(.72, -.78),
          radius: 1.25,
          colors: [Color(0x3A235CFF), Color(0x1D19D8FF), Color(0x00030712)],
        ),
      ),
    );
  }
}

class _V8PlanBrand extends StatelessWidget {
  const _V8PlanBrand();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'BIL®',
          style: TextStyle(
            color: Color(0xFFE8EEF4),
            fontSize: 72,
            height: .82,
            fontWeight: FontWeight.w900,
            letterSpacing: -3.5,
            shadows: [
              Shadow(color: Color(0x704DD6FF), blurRadius: 30),
              Shadow(color: Color(0x407B5FFF), blurRadius: 46),
            ],
          ),
        ),
        SizedBox(height: 7),
        Text(
          'BODY INTELLIGENCE LOG',
          style: TextStyle(
            color: Color(0xFFC4CFD9),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
          ),
        ),
      ],
    );
  }
}

class _V8ScoreRing extends StatelessWidget {
  const _V8ScoreRing({required this.progress, required this.isArabic});

  final double progress;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _BilColors.cyan.withValues(alpha: .28),
                  blurRadius: 56,
                  spreadRadius: -8,
                ),
                BoxShadow(
                  color: const Color(0xFF866CFF).withValues(alpha: .20),
                  blurRadius: 72,
                  spreadRadius: -12,
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size.square(230),
            painter: _RingPainter(
              progress: progress,
              color: const Color(0xFFE2EAF1),
              track: const Color(0x334D6478),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BIL®',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Score',
                style: TextStyle(color: _BilColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 50,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic ? 'ممتاز' : 'Excellent',
                style: const TextStyle(
                  color: Color(0xFFBBC9D5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _V8MetricsGrid extends StatelessWidget {
  const _V8MetricsGrid({
    required this.draft,
    required this.bmi,
    required this.bodyFat,
    required this.bodyFatMethod,
    required this.isArabic,
  });

  final BilOnboardingDraft draft;
  final double? bmi;
  final double? bodyFat;
  final String bodyFatMethod;
  final bool isArabic;

  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (tr('Weight', 'الوزن'), draft.weight?.toStringAsFixed(1) ?? '—', 'kg'),
      (tr('Height', 'الطول'), draft.height?.toStringAsFixed(1) ?? '—', 'cm'),
      ('BMI', bmi?.toStringAsFixed(1) ?? '—', ''),
      (tr('Waist', 'الخصر'), draft.waist?.toStringAsFixed(1) ?? '—', 'cm'),
      (tr('Neck', 'الرقبة'), draft.neck?.toStringAsFixed(1) ?? '—', 'cm'),
      (
        tr('Body fat', 'دهون الجسم'),
        bodyFat?.toStringAsFixed(1) ?? '—',
        bodyFat == null ? '' : '%',
      ),
    ];

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 6 : 3;
            final width =
                (constraints.maxWidth - ((columns - 1) * 9)) / columns;
            return Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: width,
                    child: _GlassPanel(
                      radius: 19,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 14,
                      ),
                      child: Column(
                        children: [
                          Text(
                            metric.$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _BilColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            metric.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (metric.$3.isNotEmpty)
                            Text(
                              metric.$3,
                              style: const TextStyle(
                                color: _BilColors.textDim,
                                fontSize: 11,
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
        const SizedBox(height: 7),
        Text(
          bodyFatMethod,
          style: const TextStyle(color: _BilColors.textDim, fontSize: 11),
        ),
      ],
    );
  }
}

class _V8EnergyCard extends StatelessWidget {
  const _V8EnergyCard({required this.plan, required this.isArabic});

  final BilInitialPlan plan;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      glow: true,
      radius: 24,
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'هدف الطاقة اليومي' : 'Daily energy target',
            style: const TextStyle(
              color: _BilColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            '${plan.calories}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isArabic ? 'سعرة حرارية' : 'kcal',
            style: const TextStyle(color: _BilColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _V8MacroCard extends StatelessWidget {
  const _V8MacroCard({required this.plan, required this.isArabic});

  final BilInitialPlan plan;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      glow: true,
      radius: 24,
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'توزيع الماكروز' : 'Macro distribution',
            style: const TextStyle(
              color: _BilColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          _V8MacroLine(
            label: isArabic ? 'البروتين' : 'Protein',
            grams: plan.protein,
            color: Color(0xFFBBC9D5),
          ),
          const SizedBox(height: 9),
          _V8MacroLine(
            label: isArabic ? 'الكربوهيدرات' : 'Carbs',
            grams: plan.carbs,
            color: _BilColors.cyan,
          ),
          const SizedBox(height: 9),
          _V8MacroLine(
            label: isArabic ? 'الدهون' : 'Fat',
            grams: plan.fat,
            color: const Color(0xFF9AA9B8),
          ),
        ],
      ),
    );
  }
}

class _V8MacroLine extends StatelessWidget {
  const _V8MacroLine({
    required this.label,
    required this.grams,
    required this.color,
  });

  final String label;
  final int grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = (grams / 300).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5DE),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: const Color(0x26394B5E),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2248D4FF),
                  blurRadius: 14,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF8293A4),
                      Color(0xFFF2F6FA),
                      Color(0xFFAAB8C5),
                      Color(0xFFE7EDF3),
                    ],
                    stops: [0, .38, .72, 1],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x7059D9FF),
                      blurRadius: 12,
                      spreadRadius: -3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$grams g',
          style: const TextStyle(
            color: Color(0xFFE7EDF3),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _V8SuggestedTargetsButton extends StatefulWidget {
  const _V8SuggestedTargetsButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_V8SuggestedTargetsButton> createState() =>
      _V8SuggestedTargetsButtonState();
}

class _V8SuggestedTargetsButtonState extends State<_V8SuggestedTargetsButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: hovered ? .12 : .075),
              _BilColors.cyan.withValues(alpha: hovered ? .14 : .07),
              const Color(0xFF7A62FF).withValues(alpha: hovered ? .13 : .06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _BilColors.cyan.withValues(alpha: hovered ? .58 : .30),
          ),
          boxShadow: [
            BoxShadow(
              color: _BilColors.cyan.withValues(alpha: hovered ? .20 : .09),
              blurRadius: hovered ? 28 : 18,
              spreadRadius: -9,
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tune_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V8StartBilButton extends StatelessWidget {
  const _V8StartBilButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .16),
            const Color(0xFF84C8FF).withValues(alpha: .08),
            Colors.white.withValues(alpha: .035),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF308BFF).withValues(alpha: .36),
            blurRadius: 32,
            spreadRadius: -9,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox.square(
                dimension: 21,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            const SizedBox(width: 11),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SuggestedTargetsSheet extends StatefulWidget {
  const _SuggestedTargetsSheet({
    required this.initialPlan,
    required this.goal,
    required this.weightKg,
    required this.isArabic,
  });

  final BilInitialPlan initialPlan;
  final BilGoal goal;
  final double weightKg;
  final bool isArabic;

  @override
  State<_SuggestedTargetsSheet> createState() => _SuggestedTargetsSheetState();
}

class _SuggestedTargetsSheetState extends State<_SuggestedTargetsSheet> {
  late int calories;
  late int protein;
  late int carbs;
  late int fat;

  String tr(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    calories = widget.initialPlan.calories;
    protein = widget.initialPlan.protein;
    carbs = widget.initialPlan.carbs;
    fat = widget.initialPlan.fat;
  }

  int get macroCalories => protein * 4 + carbs * 4 + fat * 9;

  void changeCalories(double rawValue) {
    final requested = rawValue.round();

    if (widget.goal == BilGoal.loseFat) {
      // Loss plan: protein and fat stay at their verified targets.
      // Carbohydrates alone absorb calorie changes.
      final fixedCalories = protein * 4 + fat * 9;
      carbs = math.max(0, ((requested - fixedCalories) / 4).round());
    } else if (widget.goal == BilGoal.buildMuscle) {
      // Balanced muscle-gain distribution: 20% protein, 50% carbs, 30% fat.
      protein = math.max(1, (requested * .20 / 4).round());
      carbs = math.max(0, (requested * .50 / 4).round());
      fat = math.max(1, (requested * .30 / 9).round());
    } else {
      // Maintenance preserves the initial calorie contribution ratios.
      final initialTotal =
          widget.initialPlan.protein * 4 +
          widget.initialPlan.carbs * 4 +
          widget.initialPlan.fat * 9;
      final pRatio = widget.initialPlan.protein * 4 / initialTotal;
      final cRatio = widget.initialPlan.carbs * 4 / initialTotal;
      protein = math.max(1, (requested * pRatio / 4).round());
      carbs = math.max(0, (requested * cRatio / 4).round());
      fat = math.max(1, ((requested - protein * 4 - carbs * 4) / 9).round());
    }

    calories = macroCalories;
    setState(() {});
  }

  void changeMacro({int? newProtein, int? newCarbs, int? newFat}) {
    protein = newProtein ?? protein;
    carbs = newCarbs ?? carbs;
    fat = newFat ?? fat;
    calories = macroCalories;
    setState(() {});
  }

  BilInitialPlan get result => BilInitialPlan(
    calories: macroCalories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    weeklyPace: widget.initialPlan.weeklyPace,
  );

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Material(
          color: Colors.transparent,
          child: _GlassPanel(
            glow: true,
            radius: 31,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr('Edit suggested targets', 'تعديل الأهداف المقترحة'),
                    style: const TextStyle(
                      color: Color(0xFFE5EBF1),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr(
                      'Calories are the priority. The equation always remains exact.',
                      'السعرات هي الأولوية، وتبقى المعادلة متطابقة دائمًا.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _BilColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  _V8TargetCard(
                    label: tr('Daily calories', 'السعرات اليومية'),
                    value: calories,
                    min: 1200,
                    max: 6000,
                    unit: tr('kcal', 'سعرة'),
                    color: _BilColors.cyan,
                    priority: true,
                    onChanged: changeCalories,
                  ),
                  const SizedBox(height: 11),
                  _V8TargetCard(
                    label: tr('Protein', 'البروتين'),
                    value: protein,
                    min: 40,
                    max: 350,
                    unit: 'g',
                    color: Color(0xFFBBC9D5),
                    onChanged: (value) =>
                        changeMacro(newProtein: value.round()),
                  ),
                  const SizedBox(height: 11),
                  _V8TargetCard(
                    label: tr('Carbohydrates', 'الكربوهيدرات'),
                    value: carbs,
                    min: 0,
                    max: 800,
                    unit: 'g',
                    color: _BilColors.cyan,
                    onChanged: (value) => changeMacro(newCarbs: value.round()),
                  ),
                  const SizedBox(height: 11),
                  _V8TargetCard(
                    label: tr('Fat', 'الدهون'),
                    value: fat,
                    min: 25,
                    max: 250,
                    unit: 'g',
                    color: const Color(0xFF9AA9B8),
                    onChanged: (value) => changeMacro(newFat: value.round()),
                  ),
                  const SizedBox(height: 14),
                  _V8StartBilButton(
                    label: tr('Apply targets', 'تطبيق الأهداف'),
                    busy: false,
                    onPressed: () => Navigator.pop(context, result),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _V8TargetCard extends StatelessWidget {
  const _V8TargetCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
    required this.onChanged,
    this.priority = false,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final Color color;
  final ValueChanged<double> onChanged;
  final bool priority;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: priority ? .12 : .075),
                const Color(0xFF4FD9FF).withValues(alpha: .035),
                const Color(0xFF795FFF).withValues(alpha: .032),
                Colors.white.withValues(alpha: .018),
              ],
            ),
            boxShadow: priority
                ? const [
                    BoxShadow(
                      color: Color(0x304FD6FF),
                      blurRadius: 26,
                      spreadRadius: -8,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (priority) ...[
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFDDE6EE),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFDCE4EB),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$value $unit',
                    style: const TextStyle(
                      color: Color(0xFFF1F5F8),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: const Color(0xFFE5ECF2),
                  inactiveTrackColor: const Color(0x35495E72),
                  thumbColor: const Color(0xFFF5F8FB),
                  overlayColor: const Color(0x2856D8FF),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                    elevation: 8,
                    pressedElevation: 12,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                ),
                child: Slider(
                  value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
