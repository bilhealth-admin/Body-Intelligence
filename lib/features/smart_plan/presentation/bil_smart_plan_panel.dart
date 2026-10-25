import 'package:flutter/material.dart';
import '../../../app/theme/bil_pearl_finish.dart';

/// Scoped My Plan artwork: these assets are already bundled with BIL.
/// Covers are atmospheric category art, never a claim that a particular
/// recipe, movement, or remote video has been verified.
abstract final class BilSmartPlanArt {
  static const overview =
      'assets/images/nutrition_plans/strength_lifestyle_v1.webp';
  static const schedule =
      'assets/images/professional/workouts/mobility_flow.jpg';
  static const recovery =
      'assets/images/professional/workouts/gentle_stretching.jpg';
  static const meals =
      'assets/images/nutrition_plans/balanced_market_lifestyle_v1.webp';
  static const progress = 'assets/images/flagship/bil_movement_v1.png';
  static const session =
      'assets/images/professional/workouts/full_body_strength.jpg';

  static String forWorkout(String templateId) {
    if (templateId.contains('kettlebell')) {
      return 'assets/images/workouts/workout_kettlebell_cover_v1.png';
    }
    if (templateId.startsWith('home-')) {
      return 'assets/images/professional/workouts/full_body_strength.jpg';
    }
    return 'assets/images/workouts/workout_strength_cover_v1.png';
  }
}

/// The same pearl radius, stroke and shadow as Coach Overview.
/// Optional artwork is muted with an opaque, directional scrim and omitted
/// entirely for high-contrast users. No network image, BackdropFilter,
/// expensive per-row blur, interaction interception, or extra semantics.
class BilSmartPlanPanel extends StatelessWidget {
  const BilSmartPlanPanel({
    super.key,
    required this.child,
    this.margin,
    this.artwork,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final String? artwork;

  @override
  Widget build(BuildContext context) {
    final contrast = MediaQuery.highContrastOf(context);
    final showArtwork = artwork != null && !contrast;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scrim = dark
        ? BilPearlFinish.darkSurface
        : BilPearlFinish.lightSurface;
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BilPearlFinish.panel(context),
      child: Material(
        type: MaterialType.transparency,
        child: showArtwork
            ? Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: RepaintBoundary(
                          child: Image.asset(
                            artwork!,
                            fit: BoxFit.cover,
                            alignment: AlignmentDirectional.centerEnd,
                            cacheWidth: 560,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (context, error, stack) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            stops: const [0, .6, 1],
                            colors: [
                              scrim.withValues(alpha: .98),
                              scrim.withValues(alpha: .95),
                              scrim.withValues(alpha: dark ? .82 : .70),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child,
                ],
              )
            : child,
      ),
    );
  }
}

/// Aligned typography reused in Today, Schedule, Progress and session sheets.
class BilSmartPlanSectionTitle extends StatelessWidget {
  const BilSmartPlanSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final styles = Theme.of(context).textTheme;
    // The Progress subtitle was measured below WCAG AA over illustration art.
    final subtitleInk = scheme.brightness == Brightness.light
        ? BilPearlFinish.lightInk
        : scheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 21, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: styles.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.16,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: styles.bodyMedium?.copyWith(
                    color: subtitleInk,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A non-interactive metric, with explicit labelling for screen readers.
class BilSmartPlanMetric extends StatelessWidget {
  const BilSmartPlanMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final styles = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BilPearlFinish.panel(
            context,
            shadow: false,
            radius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) Icon(icon, color: scheme.primary, size: 19),
              if (icon != null) const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: styles.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: styles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
