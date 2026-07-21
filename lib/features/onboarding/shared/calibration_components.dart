part of '../bil_flagship_onboarding.dart';

class _ChoiceData<T> {
  const _ChoiceData({
    required this.value,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final T value;
  final IconData icon;
  final String title;
  final String? subtitle;
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _ChoiceData<T> data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1 : .985,
      duration: const Duration(milliseconds: 170),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        decoration: BoxDecoration(
          color: selected
              ? _BilColors.emerald.withValues(alpha: .12)
              : _BilColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _BilColors.emerald : _BilColors.stroke,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _BilColors.emerald.withValues(alpha: .13),
                    blurRadius: 28,
                    spreadRadius: -8,
                  ),
                ]
              : const [],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _IconOrb(icon: data.icon, selected: selected),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (data.subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          data.subtitle!,
                          style: const TextStyle(
                            color: _BilColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? _BilColors.emerald : _BilColors.textDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrecisionBar extends StatelessWidget {
  const _PrecisionBar({required this.decimals, required this.onNudge});

  final int decimals;
  final ValueChanged<double> onNudge;

  @override
  Widget build(BuildContext context) {
    final values = decimals == 0
        ? const [-10.0, -1.0, 1.0, 10.0]
        : const [-10.0, -1.0, -.1, .1, 1.0, 10.0];

    return _GlassPanel(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: TextButton(
                onPressed: () => onNudge(value),
                child: Text(
                  value > 0
                      ? '+${value.abs().toStringAsFixed(value.abs() < 1 ? 1 : 0)}'
                      : '−${value.abs().toStringAsFixed(value.abs() < 1 ? 1 : 0)}',
                  style: const TextStyle(
                    color: _BilColors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.decimals, required this.onKey});

  final int decimals;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      decimals > 0 ? '.' : '',
      '0',
      'back',
    ];

    return _GlassPanel(
      padding: const EdgeInsets.all(4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: keys.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.25,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemBuilder: (context, index) {
          final key = keys[index];
          if (key.isEmpty) return const SizedBox.shrink();

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onKey(key),
            child: Center(
              child: key == 'back'
                  ? const Icon(Icons.backspace_outlined, color: Colors.white)
                  : Text(
                      key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_BilColors.cyan, _BilColors.emerald],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'BIL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HologramPanel extends StatelessWidget {
  const _HologramPanel();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          const Positioned.fill(child: _OrbitBackground()),
          const Center(child: _BodyHologram()),
          PositionedDirectional(
            top: 18,
            start: 18,
            child: _FloatingTag(
              icon: Icons.lock_outline_rounded,
              label: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'خاص'
                  : 'Private',
            ),
          ),
          PositionedDirectional(
            bottom: 18,
            end: 18,
            child: _FloatingTag(
              icon: Icons.psychology_outlined,
              label: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'قابل للتفسير'
                  : 'Explainable',
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingTag extends StatelessWidget {
  const _FloatingTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _BilColors.emerald, size: 17),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyHologram extends StatelessWidget {
  const _BodyHologram({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: compact ? const Size(260, 320) : const Size(360, 500),
      painter: _BodyHologramPainter(),
    );
  }
}

class _BodyHologramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .46);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [_BilColors.cyan.withValues(alpha: .22), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .46));

    canvas.drawCircle(center, size.width * .46, glow);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(3, size.width * .012)
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_BilColors.cyan, _BilColors.blue],
      ).createShader(Offset.zero & size);

    final x = size.width / 2;
    final path = Path()
      ..moveTo(x, size.height * .18)
      ..cubicTo(
        x + size.width * .07,
        size.height * .26,
        x + size.width * .07,
        size.height * .34,
        x,
        size.height * .40,
      )
      ..cubicTo(
        x - size.width * .08,
        size.height * .52,
        x - size.width * .08,
        size.height * .72,
        x - size.width * .04,
        size.height * .88,
      )
      ..moveTo(x, size.height * .40)
      ..cubicTo(
        x + size.width * .08,
        size.height * .52,
        x + size.width * .08,
        size.height * .72,
        x + size.width * .04,
        size.height * .88,
      )
      ..moveTo(x - size.width * .04, size.height * .34)
      ..lineTo(x - size.width * .24, size.height * .53)
      ..moveTo(x + size.width * .04, size.height * .34)
      ..lineTo(x + size.width * .24, size.height * .53);

    canvas.drawPath(path, line);

    final head = Paint()
      ..shader =
          const RadialGradient(
            colors: [_BilColors.cyan, _BilColors.blue],
          ).createShader(
            Rect.fromCircle(
              center: Offset(x, size.height * .12),
              radius: size.width * .07,
            ),
          );
    canvas.drawCircle(Offset(x, size.height * .12), size.width * .065, head);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrbitBackground extends StatelessWidget {
  const _OrbitBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OrbitPainter());
  }
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _BilColors.cyan.withValues(alpha: .11);

    for (final scale in const [.38, .56, .74, .92]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * scale,
          height: size.height * scale,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bounds = rect.deflate(8);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    paint.color = track;
    canvas.drawArc(bounds, 0, math.pi * 2, false, paint);

    paint.shader = SweepGradient(
      colors: [_BilColors.cyan, color],
    ).createShader(bounds);
    canvas.drawArc(bounds, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .105),
                const Color(0xFF87B8D9).withValues(alpha: .045),
                const Color(0xFF07111E).withValues(alpha: .58),
              ],
              stops: const [0, .28, 1],
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .48),
                blurRadius: 40,
                spreadRadius: -15,
                offset: const Offset(0, 22),
              ),
              BoxShadow(
                color: const Color(
                  0xFFBDE9FF,
                ).withValues(alpha: glow ? .22 : .10),
                blurRadius: glow ? 34 : 20,
                spreadRadius: -12,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: .09),
                blurRadius: 2,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  const _IconOrb({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: (selected ? _BilColors.emerald : _BilColors.cyan).withValues(
          alpha: .12,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: selected ? _BilColors.emerald : _BilColors.cyan),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [_BilColors.blue, _BilColors.emerald],
              ),
        color: onPressed == null ? _BilColors.stroke : null,
        borderRadius: BorderRadius.circular(17),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: _BilColors.emerald.withValues(alpha: .20),
                  blurRadius: 26,
                  spreadRadius: -9,
                ),
              ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _BilColors.background,
        gradient: RadialGradient(
          center: Alignment(.42, -.58),
          radius: 1.2,
          colors: [Color(0x1A00E4C2), Color(0x0D087EAC), _BilColors.background],
        ),
      ),
    );
  }
}

abstract final class _BilColors {
  static const background = Color(0xFF020A13);
  static const surface = Color(0xFF071725);
  static const stroke = Color(0xFF183244);
  static const emerald = Color(0xFF14DFA6);
  static const cyan = Color(0xFF11CDE4);
  static const blue = Color(0xFF1877E8);
  static const orange = Color(0xFFFFA24A);
  static const textMuted = Color(0xFF9EB0BE);
  static const textDim = Color(0xFF617687);
}
