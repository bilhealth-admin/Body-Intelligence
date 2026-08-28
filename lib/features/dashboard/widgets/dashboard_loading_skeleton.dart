import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/premium_design_tokens.dart';

class DashboardLoadingSkeleton extends StatelessWidget {
  const DashboardLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.strings.text('Loading Today dashboard'),
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SkeletonBlock(
            key: Key('dashboard-loading-coach'),
            height: 72,
            dark: true,
            leadingCircle: true,
          ),
          const SizedBox(height: 12),
          const _SkeletonBlock(
            key: Key('dashboard-loading-watch'),
            height: 236,
            leadingCircle: true,
          ),
          const SizedBox(height: 12),
          const _SkeletonBlock(
            key: Key('dashboard-loading-nutrition'),
            height: 174,
            leadingCircle: true,
          ),
          const SizedBox(height: 10),
          const _SkeletonBlock(
            key: Key('dashboard-loading-goal-strip'),
            height: 42,
          ),
        ],
      ),
    ),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    super.key,
    required this.height,
    this.dark = false,
    this.leadingCircle = false,
  });

  final double height;
  final bool dark;
  final bool leadingCircle;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      gradient: dark
          ? const LinearGradient(colors: [Color(0xFF12394E), Color(0xFF071923)])
          : LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerLow,
              ],
            ),
      borderRadius: BorderRadius.circular(dark ? 20 : 14),
      border: dark
          ? null
          : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: PremiumDesignTokens.spaceMd,
      vertical: 14,
    ),
    child: Row(
      children: [
        if (leadingCircle) ...[
          Container(
            width: dark ? 44 : 58,
            height: dark ? 44 : 58,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: .14)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: .54,
                child: _SkeletonLine(dark: dark, height: 12),
              ),
              if (height > 60) ...[
                const SizedBox(height: 9),
                FractionallySizedBox(
                  widthFactor: .82,
                  child: _SkeletonLine(dark: dark, height: 9),
                ),
              ],
              if (height > 100) ...[
                const SizedBox(height: 18),
                FractionallySizedBox(
                  widthFactor: .95,
                  child: _SkeletonLine(dark: dark, height: 8),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.dark, required this.height});

  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: dark
          ? Colors.white.withValues(alpha: .16)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
    child: SizedBox(height: height),
  );
}
