import 'package:flutter/material.dart';

import 'first_use_glass_surface.dart';

/// Inline, contextual guidance: deliberately not a modal or a tap-blocking
/// overlay. It sits immediately before the real field or action it describes.
class FirstUseContextCoachmark extends StatelessWidget {
  const FirstUseContextCoachmark({
    super.key,
    required this.title,
    required this.message,
    required this.onSkip,
    this.onAction,
    this.actionLabel,
    this.icon = Icons.celebration_rounded,
    this.accent = const Color(0xFF95F5E1),
    this.skipKey,
    this.actionKey,
    this.compact = false,
    this.step,
    this.stepCount,
  });

  final String title;
  final String message;
  final VoidCallback onSkip;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData icon;
  final Color accent;
  final Key? skipKey;
  final Key? actionKey;
  final bool compact;
  final int? step;
  final int? stepCount;

  String _skipLabel(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ar' => 'تخطي',
        'fr' => 'Ignorer',
        'es' => 'Omitir',
        'tr' => 'Atla',
        _ => 'Skip',
      };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label: '$title. $message',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
        duration: Duration(milliseconds: reduceMotion ? 1 : 520),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 17),
            child: child,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FirstUseGlassSurface(
              accent: accent,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 15 : 20,
                vertical: compact ? 13 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: compact ? 36 : 43,
                        height: compact ? 36 : 43,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .17),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: accent.withValues(alpha: .36),
                          ),
                        ),
                        child: Icon(icon, color: accent, size: compact ? 20 : 25),
                      ),
                      const Spacer(),
                      if (step != null && stepCount != null)
                        Text(
                          '$step / $stepCount',
                          style: const TextStyle(
                            color: Color(0xFFD6E9F3),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 17 : 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 14,
                      height: 1.45,
                      color: const Color(0xFFD9E9F0),
                    ),
                  ),
                  if (step != null && stepCount != null) ...[
                    const SizedBox(height: 17),
                    Row(
                      children: [
                        for (var i = 1; i <= stepCount!; i++) ...[
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              height: 3,
                              decoration: BoxDecoration(
                                color: i <= step!
                                    ? accent
                                    : Colors.white.withValues(alpha: .22),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                          if (i < stepCount!) const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ],
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        key: actionKey,
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: const Color(0xFF0A2638),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 25),
                child: CustomPaint(
                  size: const Size(25, 11),
                  painter: _GlassGuidePointer(accent),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                key: skipKey,
                onPressed: onSkip,
                child: Text(
                  _skipLabel(context),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassGuidePointer extends CustomPainter {
  const _GlassGuidePointer(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xEC173B4E),
    );
    canvas.drawLine(
      Offset.zero,
      Offset(size.width / 2, size.height),
      Paint()
        ..color = accent.withValues(alpha: .4)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassGuidePointer oldDelegate) =>
      oldDelegate.accent != accent;
}
