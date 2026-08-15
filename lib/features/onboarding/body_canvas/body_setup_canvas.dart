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

  String tr(BuildContext context, String en, String ar) =>
      _bodyCanvasText(context, en, ar);

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
            const ColoredBox(color: _BilColors.background),
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
                              context,
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
                ? const [_BilColors.blue, _BilColors.emerald]
                : const [Color(0xFFE4E7EC), Color(0xFFEAECF0)],
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
                          : _bodyCanvasText(
                              context,
                              'Complete required details',
                              'أكمل البيانات الأساسية',
                            ),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFFEAF1F7)
                            : _BilColors.textDim,
                        fontWeight: FontWeight.w700,
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
          label: _bodyCanvasText(context, 'Back', 'الرجوع'),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _BilColors.stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14101828),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              tooltip: _bodyCanvasText(context, 'Back', 'الرجوع'),
              onPressed: onBack,
              iconSize: 30,
              splashRadius: 28,
              color: const Color(0xFF101828),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Text(
                _bodyCanvasText(
                  context,
                  'Build your body model',
                  'إعداد نموذج جسمك',
                ),
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: _BilColors.blue,
                  backgroundColor: _BilColors.stroke,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$completed/6',
          style: const TextStyle(
            color: _BilColors.textMuted,
            fontWeight: FontWeight.w700,
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
  });

  final String title;
  final String value;
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
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
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
            color: Color(0xFFB9C8D6),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _bodyCanvasText(
                context,
                'Profile completion',
                'اكتمال الملف الشخصي',
              ),
              style: const TextStyle(
                color: _BilColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFFB9C8D6),
              fontSize: 22,
              fontWeight: FontWeight.w700,
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
