import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import 'dashboard_carousel.dart';

/// Shared presentation shell for the paired Bio Intelligence and Today Insights
/// cards. One implementation keeps title slots, deck bounds, arrows, and pager
/// indicators aligned across themes, pages, and responsive widths.
class DashboardTwinDeckShell extends StatelessWidget {
  const DashboardTwinDeckShell({
    super.key,
    required this.title,
    required this.pages,
    required this.semanticLabel,
    this.subtitle,
    this.compact = false,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final List<Widget> pages;
  final String semanticLabel;
  final bool compact;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        (compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.titleLarge)
            ?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
              height: 1.12,
            );
    final subtitleStyle =
        (compact
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.35,
            );

    return PremiumSurface(
      dashboardGlass: true,
      padding: const EdgeInsets.symmetric(
        horizontal: PremiumDesignTokens.spaceSm,
        vertical: PremiumDesignTokens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const Key('dashboard-twin-header-slot'),
            height: compact ? 68 : 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(height: PremiumDesignTokens.spaceXs),
                if (subtitle != null && subtitle!.trim().isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
              ],
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pagerReserve = pages.length > 1 ? 26.0 : 0.0;
                final deckHeight = (constraints.maxHeight - pagerReserve)
                    .clamp(0.0, constraints.maxHeight)
                    .toDouble();
                return DashboardCarousel(
                  key: const Key('dashboard-twin-deck-carousel'),
                  height: deckHeight,
                  viewportFraction: compact ? .94 : .96,
                  compactControls: compact,
                  semanticLabel: semanticLabel,
                  pages: pages,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
