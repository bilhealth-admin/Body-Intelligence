import 'package:flutter/foundation.dart';

/// Canonical dashboard viewport classes.
///
/// Breakpoints are intentionally content-led rather than device-named. They
/// protect reading width, prevent premature two-column layouts, and keep the
/// dashboard usable from compact phones through ultra-wide desktops.
enum DashboardViewportClass { compact, medium, expanded, wide, ultraWide }

@immutable
class DashboardLayoutMetrics {
  const DashboardLayoutMetrics({
    required this.viewportClass,
    required this.horizontalPadding,
    required this.maxContentWidth,
    required this.regionGap,
    required this.useTwoRegions,
    required this.heroFlex,
    required this.contentFlex,
  });

  static const compactBreakpoint = 600.0;
  static const mediumBreakpoint = 840.0;
  static const expandedBreakpoint = 1200.0;
  static const wideBreakpoint = 1500.0;
  static const ultraWideBreakpoint = 1900.0;

  final DashboardViewportClass viewportClass;
  final double horizontalPadding;
  final double maxContentWidth;
  final double regionGap;
  final bool useTwoRegions;
  final int heroFlex;
  final int contentFlex;

  static DashboardLayoutMetrics resolve(double width) {
    if (width < compactBreakpoint) {
      return const DashboardLayoutMetrics(
        viewportClass: DashboardViewportClass.compact,
        horizontalPadding: 16,
        maxContentWidth: 720,
        regionGap: 18,
        useTwoRegions: false,
        heroFlex: 1,
        contentFlex: 1,
      );
    }

    if (width < mediumBreakpoint) {
      return const DashboardLayoutMetrics(
        viewportClass: DashboardViewportClass.medium,
        horizontalPadding: 20,
        maxContentWidth: 820,
        regionGap: 20,
        useTwoRegions: false,
        heroFlex: 1,
        contentFlex: 1,
      );
    }

    if (width < expandedBreakpoint) {
      return const DashboardLayoutMetrics(
        viewportClass: DashboardViewportClass.expanded,
        horizontalPadding: 24,
        maxContentWidth: 1080,
        regionGap: 22,
        useTwoRegions: false,
        heroFlex: 1,
        contentFlex: 1,
      );
    }

    if (width < wideBreakpoint) {
      return const DashboardLayoutMetrics(
        viewportClass: DashboardViewportClass.wide,
        horizontalPadding: 28,
        maxContentWidth: 1320,
        regionGap: 24,
        useTwoRegions: false,
        heroFlex: 1,
        contentFlex: 1,
      );
    }

    return DashboardLayoutMetrics(
      viewportClass: width >= ultraWideBreakpoint
          ? DashboardViewportClass.ultraWide
          : DashboardViewportClass.wide,
      horizontalPadding: width >= ultraWideBreakpoint ? 40 : 32,
      maxContentWidth: width >= ultraWideBreakpoint ? 1680 : 1440,
      regionGap: width >= ultraWideBreakpoint ? 30 : 26,
      useTwoRegions: false,
      heroFlex: 4,
      contentFlex: 8,
    );
  }
}
