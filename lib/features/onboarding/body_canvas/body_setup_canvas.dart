part of '../bil_flagship_onboarding.dart';

class _BodySetupCanvas extends StatelessWidget {
  const _BodySetupCanvas({
    required this.draft,
    required this.isArabic,
    required this.busy,
    required this.onBack,
    required this.onChanged,
    required this.onContinue,
  });

  final BilOnboardingDraft draft;
  final bool isArabic;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onChanged;
  final VoidCallback onContinue;

  String tr(String en, String ar) => isArabic ? ar : en;

  int get _completed {
    var count = 0;
    if (draft.weight != null) count++;
    if (draft.height != null) count++;
    if (draft.birthDate != null) count++;
    if (draft.sexConfirmed) count++;
    if (draft.goalConfirmed) count++;
    if (draft.activityConfirmed) count++;
    return count;
  }

  double get _progress => _completed / 6;

  int? get _age {
    final birthDate = draft.birthDate;
    if (birthDate == null) return null;
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    final birthdayPassed =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayPassed) age--;
    return age;
  }

  bool get _canContinue =>
      draft.weight != null &&
      draft.height != null &&
      draft.birthDate != null &&
      draft.sexConfirmed &&
      draft.goalConfirmed &&
      draft.activityConfirmed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 940;
        final horizontal = desktop ? 30.0 : 14.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/v10_master/bil_hdr_starfield_master.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(.16, -.12),
                  radius: 1.25,
                  colors: [
                    Color(0x2D1C83FF),
                    Color(0x1413D7DE),
                    Color(0x0001050D),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 18),
              child: Column(
                children: [
                  _CanvasHeader(
                    isArabic: isArabic,
                    progress: _progress,
                    completed: _completed,
                    onBack: onBack,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: desktop ? 610 : null,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: desktop
                            ? _DesktopBodyCanvas(
                                draft: draft,
                                isArabic: isArabic,
                                age: _age,
                                onWeight: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.weight,
                                ),
                                onHeight: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.height,
                                ),
                                onWaist: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.waist,
                                ),
                                onNeck: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.neck,
                                ),
                                onBirthDate: () => _editBirthDate(context),
                                onSex: () => _editSex(context),
                                onGoal: () => _editGoal(context),
                                onActivity: () => _editActivity(context),
                              )
                            : _CompactBodyCanvas(
                                draft: draft,
                                isArabic: isArabic,
                                age: _age,
                                onWeight: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.weight,
                                ),
                                onHeight: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.height,
                                ),
                                onWaist: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.waist,
                                ),
                                onNeck: () => _editMeasurement(
                                  context,
                                  type: _CanvasField.neck,
                                ),
                                onBirthDate: () => _editBirthDate(context),
                                onSex: () => _editSex(context),
                                onGoal: () => _editGoal(context),
                                onActivity: () => _editActivity(context),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: LayoutBuilder(
                      builder: (context, footerConstraints) {
                        final stackFooter = footerConstraints.maxWidth < 620;
                        final accuracy = _ModelAccuracyBar(
                          isArabic: isArabic,
                          progress: _progress,
                        );
                        final action = SizedBox(
                          width: stackFooter
                              ? footerConstraints.maxWidth
                              : (desktop ? 260 : 190),
                          child: _FlagshipContinueButton(
                            label: tr(
                              'Create my body model',
                              'إنشاء نموذج جسمي',
                            ),
                            enabled: _canContinue && !busy,
                            busy: busy,
                            onPressed: onContinue,
                          ),
                        );
                        return stackFooter
                            ? Column(
                                children: [
                                  accuracy,
                                  const SizedBox(height: 12),
                                  action,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: accuracy),
                                  const SizedBox(width: 12),
                                  action,
                                ],
                              );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editBirthDate(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _BirthDateEditor(initialDate: draft.birthDate, isArabic: isArabic),
    );
    if (picked == null) return;
    draft.birthDate = picked;
    onChanged();
  }

  Future<void> _editMeasurement(
    BuildContext context, {
    required _CanvasField type,
  }) async {
    final config = switch (type) {
      _CanvasField.weight => _EditorConfig(
        title: tr('Weight', 'الوزن'),
        value: draft.weight,
        min: draft.units == BilUnits.metric ? 30 : 66,
        max: draft.units == BilUnits.metric ? 300 : 660,
        unit: draft.units == BilUnits.metric ? 'kg' : 'lb',
        decimals: 1,
      ),
      _CanvasField.height => _EditorConfig(
        title: tr('Height', 'الطول'),
        value: draft.height,
        min: draft.units == BilUnits.metric ? 120 : 48,
        max: draft.units == BilUnits.metric ? 230 : 90,
        unit: draft.units == BilUnits.metric ? 'cm' : 'in',
        decimals: 1,
      ),
      _CanvasField.waist => _EditorConfig(
        title: tr('Waist', 'الخصر'),
        value: draft.waist,
        min: draft.units == BilUnits.metric ? 45 : 18,
        max: draft.units == BilUnits.metric ? 200 : 79,
        unit: draft.units == BilUnits.metric ? 'cm' : 'in',
        decimals: 1,
        optional: true,
      ),
      _CanvasField.neck => _EditorConfig(
        title: tr('Neck', 'الرقبة'),
        value: draft.neck,
        min: draft.units == BilUnits.metric ? 20 : 8,
        max: draft.units == BilUnits.metric ? 80 : 32,
        unit: draft.units == BilUnits.metric ? 'cm' : 'in',
        decimals: 1,
        optional: true,
      ),
    };

    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CanvasNumberEditor(config: config, isArabic: isArabic),
    );

    if (result == null) return;
    final value = result.clear ? null : result.value;

    switch (type) {
      case _CanvasField.weight:
        draft.weight = value;
      case _CanvasField.height:
        draft.height = value;
      case _CanvasField.waist:
        draft.waist = value;
      case _CanvasField.neck:
        draft.neck = value;
    }
    onChanged();
  }

  Future<void> _editSex(BuildContext context) async {
    final value = await _showChoiceSheet<BilSex>(
      context,
      title: tr('Biological sex', 'الجنس البيولوجي'),
      current: draft.sex,
      choices: [
        _SheetChoice(BilSex.male, tr('Male', 'ذكر'), Icons.male_rounded),
        _SheetChoice(BilSex.female, tr('Female', 'أنثى'), Icons.female_rounded),
      ],
    );
    if (value == null) return;
    draft.sex = value;
    draft.sexConfirmed = true;
    onChanged();
  }

  Future<void> _editGoal(BuildContext context) async {
    final value = await _showChoiceSheet<BilGoal>(
      context,
      title: tr('Goal', 'الهدف'),
      current: draft.goal,
      choices: [
        _SheetChoice(
          BilGoal.loseFat,
          tr('Lose fat', 'خسارة دهون'),
          Icons.trending_down_rounded,
        ),
        _SheetChoice(
          BilGoal.maintain,
          tr('Maintain', 'تثبيت الوزن'),
          Icons.balance_rounded,
        ),
        _SheetChoice(
          BilGoal.buildMuscle,
          tr('Build muscle', 'بناء عضلات'),
          Icons.fitness_center_rounded,
        ),
      ],
    );
    if (value == null) return;
    draft.goal = value;
    draft.goalConfirmed = true;
    onChanged();
  }

  Future<void> _editActivity(BuildContext context) async {
    final value = await _showChoiceSheet<BilActivity>(
      context,
      title: tr('Activity', 'النشاط'),
      current: draft.activity,
      choices: [
        _SheetChoice(
          BilActivity.low,
          tr('Low', 'منخفض'),
          Icons.weekend_outlined,
        ),
        _SheetChoice(
          BilActivity.light,
          tr('Light', 'خفيف'),
          Icons.directions_walk_rounded,
        ),
        _SheetChoice(
          BilActivity.moderate,
          tr('Moderate', 'متوسط'),
          Icons.fitness_center_rounded,
        ),
        _SheetChoice(
          BilActivity.high,
          tr('High', 'مرتفع'),
          Icons.directions_run_rounded,
        ),
        _SheetChoice(
          BilActivity.veryHigh,
          tr('Very high', 'مرتفع جدًا'),
          Icons.bolt_rounded,
        ),
      ],
    );
    if (value == null) return;
    draft.activity = value;
    draft.activityConfirmed = true;
    onChanged();
  }

  Future<T?> _showChoiceSheet<T>(
    BuildContext context, {
    required String title,
    required T current,
    required List<_SheetChoice<T>> choices,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CanvasChoiceSheet<T>(
        title: title,
        current: current,
        choices: choices,
      ),
    );
  }
}

class _DesktopBodyCanvas extends StatelessWidget {
  const _DesktopBodyCanvas({
    required this.draft,
    required this.isArabic,
    required this.age,
    required this.onWeight,
    required this.onHeight,
    required this.onWaist,
    required this.onNeck,
    required this.onBirthDate,
    required this.onSex,
    required this.onGoal,
    required this.onActivity,
  });

  final BilOnboardingDraft draft;
  final bool isArabic;
  final int? age;
  final VoidCallback onWeight;
  final VoidCallback onHeight;
  final VoidCallback onWaist;
  final VoidCallback onNeck;
  final VoidCallback onBirthDate;
  final VoidCallback onSex;
  final VoidCallback onGoal;
  final VoidCallback onActivity;

  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _GlassPanel(
        padding: const EdgeInsets.all(18),
        radius: 30,
        glow: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PrivateFieldCard(
                    title: tr('Goal', 'الهدف'),
                    icon: Icons.track_changes_rounded,
                    completed: draft.goalConfirmed,
                    optional: false,
                    onTap: onGoal,
                  ),
                  _PrivateFieldCard(
                    title: tr('Waist', 'الخصر'),
                    icon: Icons.straighten_rounded,
                    completed: draft.waist != null,
                    optional: true,
                    onTap: onWaist,
                  ),
                  _PrivateFieldCard(
                    title: tr('Neck', 'الرقبة'),
                    icon: Icons.accessibility_new_rounded,
                    completed: draft.neck != null,
                    optional: true,
                    onTap: onNeck,
                  ),
                  _PrivateFieldCard(
                    title: tr('Activity', 'النشاط'),
                    icon: Icons.directions_run_rounded,
                    completed: draft.activityConfirmed,
                    optional: false,
                    onTap: onActivity,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 22),
            const Expanded(flex: 2, child: _V8HologramStage()),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PrivateFieldCard(
                    title: tr('Weight', 'الوزن'),
                    icon: Icons.monitor_weight_outlined,
                    completed: draft.weight != null,
                    optional: false,
                    onTap: onWeight,
                  ),
                  _PrivateFieldCard(
                    title: tr('Height', 'الطول'),
                    icon: Icons.height_rounded,
                    completed: draft.height != null,
                    optional: false,
                    onTap: onHeight,
                  ),
                  _PrivateFieldCard(
                    title: tr('Age', 'العمر'),
                    icon: Icons.cake_outlined,
                    completed: age != null,
                    optional: false,
                    onTap: onBirthDate,
                  ),
                  _PrivateFieldCard(
                    title: tr('Biological sex', 'الجنس'),
                    icon: draft.sex == BilSex.male
                        ? Icons.male_rounded
                        : Icons.female_rounded,
                    completed: draft.sexConfirmed,
                    optional: false,
                    onTap: onSex,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _V8HologramStage extends StatefulWidget {
  const _V8HologramStage();

  @override
  State<_V8HologramStage> createState() => _V8HologramStageState();
}

class _V8HologramStageState extends State<_V8HologramStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse = 1 + controller.value * .022;
        return Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: _CanvasOrbitBackground()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: .72,
                    colors: [
                      _BilColors.cyan.withValues(
                        alpha: .10 + controller.value * .08,
                      ),
                      _BilColors.blue.withValues(alpha: .055),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'BIL®',
                      style: TextStyle(
                        color: Color(0xFFE8EEF4),
                        fontSize: 46,
                        height: .88,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.2,
                        shadows: [
                          Shadow(color: Color(0x804DDCFF), blurRadius: 28),
                          Shadow(color: Color(0x407B5FFF), blurRadius: 40),
                        ],
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'BODY INTELLIGENCE LOG',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD0D9E1),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        shadows: [
                          Shadow(color: Color(0x4055CCFF), blurRadius: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              left: 10,
              right: 10,
              top: 82,
              bottom: -24,
              child: Transform.scale(
                scale: pulse * .95,
                child: Image.asset(
                  'assets/images/v10_master/bil_hologram_master.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PrivateFieldCard extends StatefulWidget {
  const _PrivateFieldCard({
    required this.title,
    required this.icon,
    required this.completed,
    required this.optional,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool completed;
  final bool optional;
  final VoidCallback onTap;

  @override
  State<_PrivateFieldCard> createState() => _PrivateFieldCardState();
}

class _PrivateFieldCardState extends State<_PrivateFieldCard> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() {
        hovered = false;
        pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) {
          setState(() => pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: pressed ? .975 : (hovered ? 1.018 : 1),
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 210),
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: hovered ? .095 : .060),
                  _BilColors.cyan.withValues(alpha: hovered ? .095 : .035),
                ],
              ),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: widget.completed
                    ? Colors.white.withValues(alpha: hovered ? .28 : .10)
                    : Colors.white.withValues(alpha: hovered ? .24 : .08),
                width: hovered ? 1.45 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.completed
                      ? const Color(0xFFB9C8D6).withValues(alpha: .15)
                      : _BilColors.cyan.withValues(alpha: .08),
                  blurRadius: hovered ? 28 : 18,
                  spreadRadius: -9,
                ),
              ],
            ),
            child: Row(
              children: [
                _IconOrb(icon: widget.icon, selected: widget.completed),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: const Color(0xFFD9E2EA),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.optional && !widget.completed)
                  const Icon(
                    Icons.add_rounded,
                    color: _BilColors.textDim,
                    size: 19,
                  ),
                if (widget.completed)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFB9C8D6).withValues(alpha: .35),
                          _BilColors.cyan.withValues(alpha: .18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFB9C8D6).withValues(alpha: .55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB9C8D6).withValues(alpha: .32),
                          blurRadius: 14,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBodyCanvas extends StatelessWidget {
  const _CompactBodyCanvas({
    required this.draft,
    required this.isArabic,
    required this.age,
    required this.onWeight,
    required this.onHeight,
    required this.onWaist,
    required this.onNeck,
    required this.onBirthDate,
    required this.onSex,
    required this.onGoal,
    required this.onActivity,
  });

  final BilOnboardingDraft draft;
  final bool isArabic;
  final int? age;
  final VoidCallback onWeight;
  final VoidCallback onHeight;
  final VoidCallback onWaist;
  final VoidCallback onNeck;
  final VoidCallback onBirthDate;
  final VoidCallback onSex;
  final VoidCallback onGoal;
  final VoidCallback onActivity;

  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final fields = [
      (
        tr('Weight', 'الوزن'),
        Icons.monitor_weight_outlined,
        draft.weight != null,
        false,
        onWeight,
      ),
      (
        tr('Height', 'الطول'),
        Icons.height_rounded,
        draft.height != null,
        false,
        onHeight,
      ),
      (
        tr('Age', 'العمر'),
        Icons.cake_outlined,
        age != null,
        false,
        onBirthDate,
      ),
      (
        tr('Biological sex', 'الجنس'),
        draft.sex == BilSex.male ? Icons.male_rounded : Icons.female_rounded,
        draft.sexConfirmed,
        false,
        onSex,
      ),
      (
        tr('Goal', 'الهدف'),
        Icons.track_changes_rounded,
        draft.goalConfirmed,
        false,
        onGoal,
      ),
      (
        tr('Waist', 'الخصر'),
        Icons.straighten_rounded,
        draft.waist != null,
        true,
        onWaist,
      ),
      (
        tr('Neck', 'الرقبة'),
        Icons.accessibility_new_rounded,
        draft.neck != null,
        true,
        onNeck,
      ),
      (
        tr('Activity', 'النشاط'),
        Icons.directions_run_rounded,
        draft.activityConfirmed,
        false,
        onActivity,
      ),
    ];

    return Column(
      children: [
        const SizedBox(height: 290, child: _V8HologramStage()),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 620
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final field in fields)
                  SizedBox(
                    width: cardWidth,
                    child: _PrivateFieldCard(
                      title: field.$1,
                      icon: field.$2,
                      completed: field.$3,
                      optional: field.$4,
                      onTap: field.$5,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FlagshipContinueButton extends StatefulWidget {
  const _FlagshipContinueButton({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_FlagshipContinueButton> createState() =>
      _FlagshipContinueButtonState();
}

class _FlagshipContinueButtonState extends State<_FlagshipContinueButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.busy;
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hovered = active),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: active
                ? [
                    Colors.white.withValues(alpha: hovered ? .17 : .11),
                    const Color(0xFF58D8FF).withValues(alpha: .075),
                    const Color(0xFF795FFF).withValues(alpha: .075),
                    Colors.white.withValues(alpha: .035),
                  ]
                : [
                    Colors.white.withValues(alpha: .045),
                    Colors.white.withValues(alpha: .018),
                  ],
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF4DCEFF).withValues(alpha: .18),
                    blurRadius: hovered ? 30 : 22,
                    spreadRadius: -9,
                  ),
                ]
              : const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: InkWell(
              onTap: active ? widget.onPressed : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active
                        ? Icons.auto_awesome_rounded
                        : Icons.lock_outline_rounded,
                    color: active
                        ? const Color(0xFFEAF1F7)
                        : _BilColors.textDim,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      active
                          ? widget.label
                          : (Directionality.of(context) == TextDirection.rtl
                                ? 'أكمل البيانات الأساسية'
                                : 'Complete required details'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFFEAF1F7)
                            : _BilColors.textDim,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _CanvasHeader extends StatelessWidget {
  const _CanvasHeader({
    required this.isArabic,
    required this.progress,
    required this.completed,
    required this.onBack,
  });

  final bool isArabic;
  final double progress;
  final int completed;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: isArabic ? 'الرجوع' : 'Back',
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
                  const Color(0xFF5AD9FF).withValues(alpha: .10),
                  const Color(0xFF765FFF).withValues(alpha: .09),
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
              tooltip: isArabic ? 'الرجوع' : 'Back',
              onPressed: onBack,
              iconSize: 30,
              splashRadius: 28,
              color: const Color(0xFFF3F7FA),
              icon: Icon(
                isArabic
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Text(
                isArabic ? 'إعداد نموذج جسمك' : 'Build your body model',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: const Color(0xFFB9C8D6),
                  backgroundColor: _BilColors.stroke,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          isArabic ? '$completed/6' : '$completed/6',
          style: const TextStyle(
            color: const Color(0xFFB9C8D6),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SetupTile extends StatefulWidget {
  const _SetupTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.completed,
    required this.onTap,
    this.unit,
  });

  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final bool completed;
  final VoidCallback onTap;

  @override
  State<_SetupTile> createState() => _SetupTileState();
}

class _SetupTileState extends State<_SetupTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.completed ? const Color(0xFFB9C8D6) : _BilColors.cyan;

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedScale(
        scale: hovered ? 1.025 : 1,
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 104),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: hovered ? .105 : .070),
                _BilColors.surface.withValues(alpha: .80),
                _BilColors.background.withValues(alpha: .72),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(
                alpha: hovered ? .72 : (widget.completed ? .38 : .20),
              ),
              width: hovered ? 1.35 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .36),
                blurRadius: hovered ? 30 : 22,
                spreadRadius: -12,
                offset: Offset(0, hovered ? 16 : 12),
              ),
              if (hovered)
                BoxShadow(
                  color: accent.withValues(alpha: .18),
                  blurRadius: 24,
                  spreadRadius: -8,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      _IconOrb(icon: widget.icon, selected: widget.completed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _BilColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (widget.unit != null) ...[
                                  const SizedBox(width: 5),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 1),
                                    child: Text(
                                      widget.unit!,
                                      style: const TextStyle(
                                        color: _BilColors.textDim,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        widget.completed
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: widget.completed
                            ? const Color(0xFFB9C8D6)
                            : _BilColors.textDim,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelAccuracyBar extends StatelessWidget {
  const _ModelAccuracyBar({required this.isArabic, required this.progress});

  final bool isArabic;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: const Color(0xFFB9C8D6),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic ? 'دقة النموذج' : 'Model accuracy',
              style: const TextStyle(
                color: _BilColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              color: const Color(0xFFB9C8D6),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasOrbitBackground extends StatelessWidget {
  const _CanvasOrbitBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CanvasOrbitPainter());
  }
}

class _CanvasOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .47);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _BilColors.cyan.withValues(alpha: .10);

    for (final scale in const [.40, .58, .76, .94]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * scale,
          height: size.height * scale * .76,
        ),
        orbitPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _CanvasField { weight, height, waist, neck }

class _EditorResult {
  const _EditorResult.value(this.value) : clear = false;
  const _EditorResult.clear() : value = null, clear = true;
  final double? value;
  final bool clear;
}

class _EditorConfig {
  const _EditorConfig({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.decimals,
    this.optional = false,
  });

  final String title;
  final double? value;
  final double min;
  final double max;
  final String unit;
  final int decimals;
  final bool optional;
}
