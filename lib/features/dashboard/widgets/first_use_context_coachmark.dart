import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import '../../../shared/widgets/bil_experience_presentation.dart';
import '../../../shared/widgets/first_use_target_guide.dart';

/// Actual target actions advance anchored steps; Skip is inside the pearl card.
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
    this.pointerAlignment = AlignmentDirectional.centerStart,
  });
  final String title, message;
  final VoidCallback onSkip;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData icon;
  final Color accent;
  final Key? skipKey, actionKey;
  final bool compact;
  final int? step, stepCount;
  final AlignmentGeometry pointerAlignment;
  String get _emoji {
    if (icon == Icons.scale_rounded) return '⚖️';
    if (icon == Icons.touch_app_rounded) return '👆';
    if (icon == Icons.restaurant_rounded) return '🍽️';
    if (icon == Icons.calendar_month_rounded) return '📅';
    if (icon == Icons.check_circle_outline_rounded) return '✅';
    if (icon == Icons.search_rounded) return '🔎';
    return '🎉';
  }

  String _skip(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ar' => 'تخطي',
        'fr' => 'Ignorer',
        'es' => 'Omitir',
        'tr' => 'Atla',
        _ => 'Skip',
      };
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: BilExperiencePresentation.occupied,
    builder: (context, busy, _) =>
        busy ? const SizedBox.shrink() : _card(context),
  );
  Widget _card(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final anchored = FirstUseGuidePlacement.maybeOf(context) != null;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $message',
      child: Container(
        decoration: BilPearlFinish.panel(
          context,
          radius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: reduced ? 0 : 720),
                          builder: (_, value, child) => Transform.rotate(
                            angle: reduced
                                ? 0
                                : math.sin(value * math.pi * 4) *
                                      .15 *
                                      (1 - value),
                            child: child,
                          ),
                          child: ExcludeSemantics(
                            child: Text(
                              _emoji,
                              style: const TextStyle(
                                fontSize: 34,
                                fontFamilyFallback: [
                                  'Apple Color Emoji',
                                  'Segoe UI Emoji',
                                  'Noto Color Emoji',
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.8,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (step != null && stepCount != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$step / $stepCount',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (!anchored && onAction != null && actionLabel != null)
                      TextButton(
                        key: actionKey,
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: skipKey,
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: theme.brightness == Brightness.dark
                      ? BilPearlFinish.darkInk
                      : const Color(0xFF38648B),
                  minimumSize: const Size(48, 48),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(_skip(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
