import 'package:flutter/material.dart';

import 'dashboard_layout_metrics.dart';

/// Presentation-only composition for the dashboard's primary regions.
///
/// The engine deliberately delays side-by-side composition until the viewport
/// can support two useful reading columns. This avoids the large empty column
/// produced by the former 1180px breakpoint while preserving content order,
/// semantics, and all provider/business behavior.
class DashboardComposition extends StatelessWidget {
  const DashboardComposition({
    super.key,
    required this.hero,
    required this.content,
  });

  final Widget hero;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DashboardLayoutMetrics.resolve(constraints.maxWidth);

        if (metrics.useTwoRegions) {
          return Row(
            key: const Key('dashboard-composition-wide'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: metrics.heroFlex, child: hero),
              SizedBox(width: metrics.regionGap),
              Expanded(flex: metrics.contentFlex, child: content),
            ],
          );
        }

        return Column(
          key: const Key('dashboard-composition-stacked'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            SizedBox(height: metrics.regionGap),
            content,
          ],
        );
      },
    );
  }
}
