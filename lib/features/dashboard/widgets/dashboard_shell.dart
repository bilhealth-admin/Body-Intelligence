import 'package:flutter/material.dart';

import 'dashboard_layout_metrics.dart';

/// Owns dashboard-level environment concerns only: background, safe area,
/// scrolling, refresh, viewport padding, and maximum content width.
///
/// This widget deliberately knows nothing about weight, nutrition, hydration,
/// providers, routes, or scientific calculations.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  final Widget child;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF01050D) : const Color(0xFFDCEAF0),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: dark ? 1 : .045,
            child: Image.asset(
              'assets/images/v10_master/bil_hdr_starfield_master.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(.12, -.18),
                radius: 1.2,
                colors: dark
                    ? const [
                        Color(0x241E87FF),
                        Color(0x1114C8D8),
                        Color(0x0001050D),
                      ]
                    : const [
                        Color(0xB8D7EEF3),
                        Color(0x9AE5EEF0),
                        Color(0xFFDCE7EC),
                      ],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = DashboardLayoutMetrics.resolve(
                    constraints.maxWidth,
                  );

                  return SingleChildScrollView(
                    key: const Key('dashboard-scroll-view'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      metrics.horizontalPadding,
                      16,
                      metrics.horizontalPadding,
                      120,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: metrics.maxContentWidth,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
