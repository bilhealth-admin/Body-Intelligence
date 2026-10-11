import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/repositories/first_meal_milestone.dart';
import '../../../data/repositories/preferences_repository.dart';
import 'first_use_glass_surface.dart';

/// Only a real, committed first food item may trigger the one-time effect.
/// The local database owns the decision; this UI never writes nutrition data.
abstract final class FirstMealCelebration {
  static Future<bool> showIfPending(
    BuildContext context,
    PreferencesRepository preferences, {
    BuildContext? targetContext,
    VoidCallback? onFinished,
    bool Function()? ownerIsCurrent,
  }) async {
    if (!context.mounted || (ownerIsCurrent != null && !ownerIsCurrent()))
      return false;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;

    Rect? targetRect;
    final target = targetContext?.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    if (target is RenderBox &&
        target.hasSize &&
        target.attached &&
        overlayBox is RenderBox) {
      targetRect =
          target.localToGlobal(Offset.zero, ancestor: overlayBox) & target.size;
    }
    bool claimed;
    try {
      claimed = await preferences.mutateIfUnchanged(
        expected: const {firstMealCelebrationPreferenceKey: 'ready'},
        set: const {
          firstMealCelebrationPreferenceKey: 'done',
          firstMealStreakGuidePreferenceKey: 'ready',
        },
      );
    } on Object {
      // A decoration must not interfere with an already committed meal.
      return false;
    }
    if (!claimed ||
        !context.mounted ||
        (ownerIsCurrent != null && !ownerIsCurrent()))
      return false;

    late OverlayEntry entry;
    var removed = false;
    void finish() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
      if (ownerIsCurrent == null || ownerIsCurrent()) onFinished?.call();
    }

    entry = OverlayEntry(
      builder: (_) => _FirstFoodBurst(
        onFinished: finish,
        targetRect: targetRect,
        ownerIsCurrent: ownerIsCurrent,
      ),
    );
    overlay.insert(entry);
    return true;
  }
}

class _FirstFoodBurst extends StatefulWidget {
  const _FirstFoodBurst({
    required this.onFinished,
    this.targetRect,
    this.ownerIsCurrent,
  });
  final Rect? targetRect;
  final bool Function()? ownerIsCurrent;

  final VoidCallback onFinished;

  @override
  State<_FirstFoodBurst> createState() => _FirstFoodBurstState();
}

class _FirstFoodBurstState extends State<_FirstFoodBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2450),
  );
  Timer? _reducedMotionTimer;
  bool _started = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _reducedMotionTimer = Timer(
        const Duration(milliseconds: 1350),
        widget.onFinished,
      );
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _reducedMotionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _copy(String en, String ar, String fr, String es, String tr) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ar' => ar,
        'fr' => fr,
        'es' => es,
        'tr' => tr,
        _ => en,
      };

  @override
  Widget build(BuildContext context) {
    final title = _copy(
      'What a start!',
      'بداية رائعة!',
      'Quel beau début !',
      '¡Un gran comienzo!',
      'Harika başlangıç!',
    );
    final subtitle = _copy(
      'Your first meal is saved.',
      'تم حفظ أول وجبة بنجاح.',
      'Votre premier repas est enregistré.',
      'Tu primera comida está guardada.',
      'İlk öğünün kaydedildi.',
    );
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            key: const Key('dashboard-first-food-celebration'),
            liveRegion: true,
            label: '$title $subtitle',
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (widget.ownerIsCurrent != null &&
                    !widget.ownerIsCurrent!()) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => widget.onFinished(),
                  );
                  return const SizedBox.shrink();
                }
                final value = _reducedMotion ? .40 : _controller.value;
                final burst = Curves.easeOutCubic.transform(
                  (value / .76).clamp(0.0, 1.0),
                );
                final fade = _reducedMotion
                    ? 1.0
                    : (1 - ((value - .80) / .20).clamp(0.0, 1.0));
                final particleFade = _reducedMotion
                    ? 0.0
                    : (1 - ((value - .52) / .48).clamp(0.0, 1.0));
                final cardScale = _reducedMotion
                    ? 1.0
                    : .78 +
                          .22 *
                              Curves.easeOutBack.transform(
                                (value / .32).clamp(0.0, 1.0),
                              );
                if (widget.targetRect case final Rect target) {
                  final media = MediaQuery.of(context);
                  final width = math.min(340.0, media.size.width - 24);
                  final left = (target.center.dx - width / 2).clamp(
                    12.0,
                    media.size.width - width - 12,
                  );
                  final top = target.bottom.clamp(
                    media.padding.top + 8,
                    math.max(
                      media.padding.top + 8,
                      media.size.height - media.viewInsets.bottom - 210,
                    ),
                  );
                  return Opacity(
                    opacity: fade,
                    child: Stack(
                      children: [
                        if (!_reducedMotion)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ConfettiBurstPainter(
                                progress: burst,
                                opacity: particleFade,
                                origin: target.center,
                              ),
                            ),
                          ),
                        Positioned(
                          left: left,
                          top: top.toDouble(),
                          width: width,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.max(
                                48,
                                media.size.height -
                                    media.viewInsets.bottom -
                                    top -
                                    8,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: FirstUseGlassSurface(
                                accent: const Color(0xFFFFD879),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFFFFD879),
                                      size: 44,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
                                              color: Color(0xFFE1FFF4),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Opacity(
                  opacity: fade,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              radius: .85,
                              colors: [
                                const Color(0xFF064B47).withValues(alpha: .26),
                                const Color(0xFF062038).withValues(alpha: .04),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!_reducedMotion)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ConfettiBurstPainter(
                              progress: burst,
                              opacity: particleFade,
                            ),
                          ),
                        ),
                      SafeArea(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Transform.scale(
                              scale: cardScale,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 340,
                                ),
                                child: FirstUseGlassSurface(
                                  accent: const Color(0xFF66F0C1),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 28,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 104,
                                        height: 104,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFFF0BA),
                                              Color(0xFFFFCC61),
                                              Color(0xFFC7882F),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFF5D2),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFFD76A,
                                              ).withValues(alpha: .3),
                                              blurRadius: 36,
                                              spreadRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.celebration_rounded,
                                          size: 48,
                                          color: Color(0xFF644016),
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          height: 1.2,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        subtitle,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFE1FFF4),
                                          fontSize: 16,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF8BFFD4),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'BIL',
                                            style: TextStyle(
                                              color: Color(0xFFE8FFF7),
                                              letterSpacing: 3,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Deterministic gold ribbons and jewel confetti, independent of emoji fonts.
class _ConfettiBurstPainter extends CustomPainter {
  const _ConfettiBurstPainter({
    required this.progress,
    required this.opacity,
    this.origin,
  });
  final Offset? origin;

  final double progress;
  final double opacity;

  static const _palette = [
    Color(0xFFFDD879),
    Color(0xFF8BEAD5),
    Color(0xFFB3D7FF),
    Color(0xFFE5B6FF),
    Color(0xFFFFACCA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final origin = this.origin ?? Offset(size.width / 2, size.height / 2 - 8);
    for (var i = 0; i < 120; i++) {
      final delay = (i % 7) * .037;
      final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final angle = i * 2.39996;
      final distance =
          math.min(size.width, size.height) * (.28 + (i % 9) * .06) * eased;
      final dx = math.cos(angle) * distance;
      final dy = math.sin(angle) * distance + local * local * (i % 4) * 11;
      final paint = Paint()
        ..color = _palette[i % _palette.length].withValues(
          alpha: opacity * (1 - local * .23),
        );
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(angle + local * (i.isEven ? 3 : -3));
      if (i % 11 == 0) {
        final ribbon = Path()
          ..moveTo(-4, -20)
          ..cubicTo(18, -10, -18, 8, 4, 24);
        canvas.drawPath(
          ribbon,
          Paint()
            ..color = paint.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      } else if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 2.3 + (i % 3), paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: 3.4 + (i % 4),
              height: 9.0 + (i % 3) * 3,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}
