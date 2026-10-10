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
    PreferencesRepository preferences,
  ) async {
    if (!context.mounted) return false;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;

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
    if (!claimed || !context.mounted) return false;

    late OverlayEntry entry;
    var removed = false;
    void finish() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(builder: (_) => _FirstFoodBurst(onFinished: finish));
    overlay.insert(entry);
    return true;
  }
}

class _FirstFoodBurst extends StatefulWidget {
  const _FirstFoodBurst({required this.onFinished});

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
        child: Semantics(
          key: const Key('dashboard-first-food-celebration'),
          liveRegion: true,
          label: '$title $subtitle',
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
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
              return Center(
                child: SizedBox(
                  width: 340,
                  height: 380,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (!_reducedMotion)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ConfettiBurstPainter(
                              progress: burst,
                              opacity: particleFade,
                            ),
                          ),
                        ),
                      if (!_reducedMotion)
                        for (var i = 0; i < 10; i++)
                          Positioned(
                            left:
                                155 +
                                math.cos(i * math.pi * 2 / 10) *
                                    (35 + burst * (116 + i % 3 * 14)),
                            top:
                                165 +
                                math.sin(i * math.pi * 2 / 10) *
                                    (30 + burst * (108 + i % 4 * 12)),
                            child: Opacity(
                              opacity: particleFade,
                              child: Transform.rotate(
                                angle: burst * (i.isEven ? 1.4 : -1.6),
                                child: Text(
                                  const ['🎉', '✨', '🎊', '🥳', '💚'][i % 5],
                                  style: TextStyle(
                                    fontSize: 19.0 + (i % 3) * 6,
                                    fontFamilyFallback: const [
                                      'Apple Color Emoji',
                                      'Noto Color Emoji',
                                      'Segoe UI Emoji',
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      Center(
                        child: Opacity(
                          opacity: fade,
                          child: Transform.scale(
                            scale: cardScale,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 298),
                              child: FirstUseGlassSurface(
                                accent: const Color(0xFFB8FFE6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 23,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.celebration_rounded,
                                      size: 40,
                                      color: Color(0xFFFFD76A),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFDCEFEF),
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Deterministic vector pieces remain crisp when emoji fonts differ across
/// devices. The larger emoji layer above adds joyful native OS glyphs.
class _ConfettiBurstPainter extends CustomPainter {
  const _ConfettiBurstPainter({required this.progress, required this.opacity});

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
    final origin = Offset(size.width / 2, size.height / 2 - 8);
    for (var i = 0; i < 72; i++) {
      final delay = (i % 7) * .037;
      final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final angle = i * 2.39996;
      final distance = (62 + (i % 6) * 27) * eased;
      final dx = math.cos(angle) * distance;
      final dy = math.sin(angle) * distance + local * local * (i % 4) * 11;
      final paint = Paint()
        ..color = _palette[i % _palette.length].withValues(
          alpha: opacity * (1 - local * .23),
        );
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(angle + local * (i.isEven ? 3 : -3));
      if (i % 3 == 0) {
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
