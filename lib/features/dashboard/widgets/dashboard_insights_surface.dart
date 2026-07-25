import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';

/// Deterministic containment for the dashboard's deep explanation content.
///
/// When collapsed, [children] are absent from the widget, render, semantics,
/// and paint trees. Explicit clipping and repaint isolation prevent glass
/// surfaces from revealing stale or offstage explanation content.
class DashboardInsightsSurface extends StatefulWidget {
  const DashboardInsightsSurface({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.leading,
    this.childrenPadding = EdgeInsets.zero,
    this.initiallyExpanded = false,
    this.collapsible = true,
  });

  final Widget title;
  final Widget subtitle;
  final Widget? leading;
  final List<Widget> children;
  final EdgeInsetsGeometry childrenPadding;
  final bool initiallyExpanded;
  final bool collapsible;

  @override
  State<DashboardInsightsSurface> createState() =>
      _DashboardInsightsSurfaceState();
}

class _DashboardInsightsSurfaceState extends State<DashboardInsightsSurface> {
  late bool expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: PremiumDesignTokens.cardRadius,
      clipBehavior: Clip.hardEdge,
      child: RepaintBoundary(
        child: ColoredBox(
          color: theme.colorScheme.surface.withValues(alpha: .34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: widget.collapsible,
                expanded: expanded,
                child: InkWell(
                  key: const Key('dashboard-insights-toggle'),
                  onTap: widget.collapsible
                      ? () => setState(() => expanded = !expanded)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PremiumDesignTokens.spaceMd,
                      vertical: PremiumDesignTokens.spaceSm,
                    ),
                    child: Row(
                      children: [
                        if (widget.leading != null) ...[
                          widget.leading!,
                          const SizedBox(width: PremiumDesignTokens.spaceSm),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              widget.title,
                              const SizedBox(
                                height: PremiumDesignTokens.spaceXs / 2,
                              ),
                              widget.subtitle,
                            ],
                          ),
                        ),
                        const SizedBox(width: PremiumDesignTokens.spaceSm),
                        if (widget.collapsible)
                          AnimatedRotation(
                            turns: expanded ? .5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(Icons.expand_more_rounded),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (expanded || !widget.collapsible)
                ClipRect(
                  child: Padding(
                    key: const Key('dashboard-insights-content'),
                    padding: widget.childrenPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
