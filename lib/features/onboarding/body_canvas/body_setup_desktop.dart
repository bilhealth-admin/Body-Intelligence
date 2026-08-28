part of '../bil_flagship_onboarding.dart';

class _DesktopBodyCanvas extends StatelessWidget {
  const _DesktopBodyCanvas({
    required this.draft,
    required this.isArabic,
    required this.age,
    required this.onWeight,
    required this.onHeight,
    required this.onWaist,
    required this.onNeck,
    required this.onHips,
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
  final VoidCallback onHips;
  final VoidCallback onBirthDate;
  final VoidCallback onSex;
  final VoidCallback onGoal;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => _bodyCanvasText(context, en, ar);
    String measurement(double? value, String unit) => value == null
        ? ''
        : '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} $unit';
    return _GlassPanel(
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
                  value: draft.goalConfirmed
                      ? switch (draft.goal) {
                          BilGoal.loseFat => tr('Lose fat', 'خسارة الدهون'),
                          BilGoal.maintain => tr(
                            'Maintain',
                            'الحفاظ على الوزن',
                          ),
                          BilGoal.buildMuscle => tr(
                            'Build muscle',
                            'بناء العضلات',
                          ),
                        }
                      : '',
                  optional: false,
                  onTap: onGoal,
                ),
                _PrivateFieldCard(
                  title: tr('Waist', 'الخصر'),
                  icon: Icons.straighten_rounded,
                  completed: draft.waist != null,
                  value: measurement(
                    draft.waist,
                    draft.units == BilUnits.metric ? 'cm' : 'in',
                  ),
                  optional: true,
                  onTap: onWaist,
                ),
                _PrivateFieldCard(
                  title: tr('Neck', 'الرقبة'),
                  icon: Icons.accessibility_new_rounded,
                  completed: draft.neck != null,
                  value: measurement(
                    draft.neck,
                    draft.units == BilUnits.metric ? 'cm' : 'in',
                  ),
                  optional: true,
                  onTap: onNeck,
                ),
                if (draft.sexConfirmed && draft.sex == BilSex.female)
                  _PrivateFieldCard(
                    title: tr('Hips', 'الورك'),
                    icon: Icons.accessibility_rounded,
                    completed: draft.hips != null,
                    value: measurement(
                      draft.hips,
                      draft.units == BilUnits.metric ? 'cm' : 'in',
                    ),
                    optional: true,
                    onTap: onHips,
                  ),
                _PrivateFieldCard(
                  title: tr('Activity', 'النشاط'),
                  icon: Icons.directions_run_rounded,
                  completed: draft.activityConfirmed,
                  value: draft.activityConfirmed
                      ? switch (draft.activity) {
                          BilActivity.low => tr('Low', 'منخفض'),
                          BilActivity.light => tr('Light', 'خفيف'),
                          BilActivity.moderate => tr('Moderate', 'متوسط'),
                          BilActivity.high => tr('High', 'مرتفع'),
                          BilActivity.veryHigh => tr('Very high', 'مرتفع جدًا'),
                        }
                      : '',
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
                  value: measurement(
                    draft.weight,
                    draft.units == BilUnits.metric ? 'kg' : 'lb',
                  ),
                  optional: false,
                  onTap: onWeight,
                ),
                _PrivateFieldCard(
                  title: tr('Height', 'الطول'),
                  icon: Icons.height_rounded,
                  completed: draft.height != null,
                  value: measurement(
                    draft.height,
                    draft.units == BilUnits.metric ? 'cm' : 'in',
                  ),
                  optional: false,
                  onTap: onHeight,
                ),
                _PrivateFieldCard(
                  title: tr('Age', 'العمر'),
                  icon: Icons.cake_outlined,
                  completed: age != null,
                  value: age?.toString() ?? '',
                  optional: false,
                  onTap: onBirthDate,
                ),
                _PrivateFieldCard(
                  title: tr('Sex', 'الجنس'),
                  icon: !draft.sexConfirmed
                      ? Icons.wc_outlined
                      : draft.sex == BilSex.male
                      ? Icons.male_rounded
                      : Icons.female_rounded,
                  completed: draft.sexConfirmed,
                  value: draft.sexConfirmed
                      ? (draft.sex == BilSex.male
                            ? tr('Male', 'ذكر')
                            : tr('Female', 'أنثى'))
                      : '',
                  optional: false,
                  onTap: onSex,
                ),
              ],
            ),
          ),
        ],
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
                    BilWordmark(height: 46, color: Colors.white),
                    SizedBox(height: 5),
                    Text(
                      'BODY INTELLIGENCE LOG',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD0D9E1),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
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
    this.value = '',
  });

  final String title;
  final IconData icon;
  final bool completed;
  final bool optional;
  final VoidCallback onTap;
  final String value;

  @override
  State<_PrivateFieldCard> createState() => _PrivateFieldCardState();
}

class _PrivateFieldCardState extends State<_PrivateFieldCard> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final stateLabel = widget.completed
        ? widget.value
        : widget.optional
        ? _bodyCanvasText(context, 'Optional', 'اختياري')
        : _bodyCanvasText(context, 'Required', 'مطلوب');
    return Semantics(
      button: true,
      label: widget.title,
      value: stateLabel,
      selected: widget.completed,
      child: MouseRegion(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: widget.completed
                      ? _BilColors.emerald
                      : _BilColors.stroke,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Color(0xFF101828),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (stateLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            stateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _BilColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.optional && !widget.completed)
                    const Icon(
                      Icons.add_rounded,
                      color: _BilColors.textMuted,
                      size: 19,
                    ),
                  if (!widget.optional && !widget.completed)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _BilColors.textMuted,
                      size: 24,
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
                            color: const Color(
                              0xFFB9C8D6,
                            ).withValues(alpha: .32),
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
      ),
    );
  }
}
