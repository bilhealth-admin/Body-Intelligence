import 'package:flutter/material.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/v10_master/bil_hdr_starfield_master.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(.12, -.18),
                radius: 1.2,
                colors: [
                  Color(0x301E87FF),
                  Color(0x1614C8D8),
                  Color(0x0001050D),
                ],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontal = constraints.maxWidth < 700 ? 16.0 : 28.0;
                  return SingleChildScrollView(
                    key: const Key('dashboard-scroll-view'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      16,
                      horizontal,
                      120,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1380),
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
