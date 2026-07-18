import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

class DashboardLoadingSkeleton extends StatelessWidget {
  const DashboardLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.strings.text('Loading Today dashboard'),
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: const [
              _SkeletonBlock(),
              _SkeletonBlock(),
              _SkeletonBlock(),
              _SkeletonBlock(),
            ],
          ),
          const SizedBox(height: 12),
          const _SkeletonBlock(height: 150),
          const SizedBox(height: 12),
          const _SkeletonBlock(height: 110),
        ],
      ),
    ),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: BoxShape.circle,
          ),
        ),
        const Spacer(),
        FractionallySizedBox(
          widthFactor: 0.7,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  );
}
