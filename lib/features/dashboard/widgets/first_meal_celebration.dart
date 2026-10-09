import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/repositories/first_meal_milestone.dart';
import '../../../data/repositories/preferences_repository.dart';

/// Show a single celebratory burst after the database has actually saved
/// the owner's first food item. The atomic marker claim prevents duplicates
/// on rebuilds, route returns, edits, retries and repeated save callbacks.
abstract final class FirstMealCelebration {
  static Future<bool> showIfPending(
    BuildContext context,
    PreferencesRepository preferences,
  ) async {
    // Never consume a once-only celebration when its view cannot be painted.
    if (!context.mounted) return false;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;
    bool claimed;
    try {
      claimed = await preferences.mutateIfUnchanged(
        expected: const {firstMealCelebrationPreferenceKey: 'ready'},
        set: const {firstMealCelebrationPreferenceKey: 'done'},
      );
    } catch (_) {
      // The meal remains saved; a display effect is never a write prerequisite.
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

    entry = OverlayEntry(
      builder: (_) => _FirstFoodBurst(onFinished: finish),
    );
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
    duration: const Duration(milliseconds: 1450),
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
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion) {
      _reducedMotionTimer = Timer(
        const Duration(milliseconds: 1250),
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

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final message = arabic ? 'أحسنت! تم تسجيل أول وجبة' : 'Your first meal is logged!';
    return Positioned.fill(
      child: IgnorePointer(
        child: Semantics(
          key: const Key('dashboard-first-food-celebration'),
          liveRegion: true,
          label: message,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _reducedMotion
                  ? 0.45
                  : Curves.easeOutCubic.transform(_controller.value);
              final fade = _reducedMotion
                  ? 1.0
                  : (1 - _controller.value).clamp(0.0, 1.0);
              return Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (!_reducedMotion)
                        for (var index = 0; index < 16; index++)
                          Positioned(
                            left: 150 +
                                math.cos(index * math.pi / 8) *
                                    (18 + progress * 127) -
                                15,
                            top: 150 +
                                math.sin(index * math.pi / 8) *
                                    (18 + progress * 127) -
                                15,
                            child: Opacity(
                              opacity: fade,
                              child: Transform.rotate(
                                angle: progress * (index.isEven ? .65 : -.65),
                                child: Text(
                                  const ['🎉', '🎊', '✨', '✅'][index % 4],
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                          ),
                      Center(
                        child: Opacity(
                          opacity: _reducedMotion ? 1 : fade,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xF1092753),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFACDAFF),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              child: Text(
                                '🎉 $message',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
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
