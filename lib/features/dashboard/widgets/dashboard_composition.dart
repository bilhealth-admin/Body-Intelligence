import 'package:flutter/material.dart';

/// Presentation-only composition for the dashboard's primary regions.
///
/// BDAR-003A intentionally preserves the approved V10 geometry. Later BDAR
/// packages may evolve the layout engine without coupling it to provider or
/// business logic.
class DashboardComposition extends StatelessWidget {
  const DashboardComposition({
    super.key,
    required this.hero,
    required this.content,
  });

  static const wideBreakpoint = 1180.0;
  static const regionGap = 22.0;

  final Widget hero;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;

        if (wide) {
          return Row(
            key: const Key('dashboard-composition-wide'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: hero),
              const SizedBox(width: regionGap),
              Expanded(flex: 7, child: content),
            ],
          );
        }

        return Column(
          key: const Key('dashboard-composition-stacked'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            const SizedBox(height: regionGap),
            content,
          ],
        );
      },
    );
  }
}
