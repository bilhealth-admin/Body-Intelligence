import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import 'dashboard_carousel.dart';

class DashboardTwinDeckShell extends StatefulWidget {
  const DashboardTwinDeckShell({
    super.key,
    required this.title,
    required this.pages,
    required this.semanticLabel,
    this.subtitle,
    this.compact = false,
    this.titleColor,
    this.pageTitles,
    this.pageSubtitles,
  });

  final String title;
  final String? subtitle;
  final List<Widget> pages;
  final String semanticLabel;
  final bool compact;
  final Color? titleColor;
  final List<String>? pageTitles;
  final List<String?>? pageSubtitles;

  @override
  State<DashboardTwinDeckShell> createState() => _DashboardTwinDeckShellState();
}

class _DashboardTwinDeckShellState extends State<DashboardTwinDeckShell> {
  var _page = 0;

  String get _title {
    final titles = widget.pageTitles;
    if (titles == null || _page >= titles.length) return widget.title;
    return titles[_page];
  }

  String? get _subtitle {
    final subtitles = widget.pageSubtitles;
    if (subtitles == null || _page >= subtitles.length) return widget.subtitle;
    return subtitles[_page];
  }

  @override
  void didUpdateWidget(covariant DashboardTwinDeckShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final last = widget.pages.isEmpty ? 0 : widget.pages.length - 1;
    if (_page > last) _page = last;
  }

  @override
  Widget build(BuildContext context) {
    final headerBaseHeight = widget.compact ? 68.0 : 72.0;
    final headerHeight = MediaQuery.textScalerOf(context)
        .scale(headerBaseHeight)
        .clamp(headerBaseHeight, widget.compact ? 112.0 : 120.0);
    final titleStyle =
        (widget.compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.titleLarge)
            ?.copyWith(
              color: widget.titleColor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
              height: 1.12,
            );
    final subtitleStyle =
        (widget.compact
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.35,
            );
    final subtitle = _subtitle;

    return PremiumSurface(
      level: PremiumSurfaceLevel.detail,
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
            height: headerHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(height: PremiumDesignTokens.spaceXs),
                if (subtitle != null && subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: widget.compact ? 2 : 1,
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
                final pagerReserve = widget.pages.length > 1
                    ? MediaQuery.textScalerOf(
                        context,
                      ).scale(26.0).clamp(26.0, 48.0)
                    : 0.0;
                final deckHeight = (constraints.maxHeight - pagerReserve)
                    .clamp(0.0, constraints.maxHeight)
                    .toDouble();
                return DashboardCarousel(
                  key: const Key('dashboard-twin-deck-carousel'),
                  height: deckHeight,
                  viewportFraction: widget.compact ? .94 : .96,
                  compactControls: widget.compact,
                  semanticLabel: widget.semanticLabel,
                  pages: widget.pages,
                  onPageChanged: (page) {
                    if (_page == page) return;
                    setState(() => _page = page);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
