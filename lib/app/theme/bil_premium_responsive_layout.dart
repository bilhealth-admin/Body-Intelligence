import 'premium_design_tokens.dart';

/// Canonical responsive policy for Premium UI dashboard composition.
abstract final class BilPremiumResponsiveLayout {
  static const double phoneBreakpoint = 600;
  static const double compactRhythmBreakpoint = 900;
  static const double splitHeroBreakpoint = 1180;
  static const double pairedDaySectionsBreakpoint = 1400;

  static const double wideSectionGap = 12;
  static const double phoneTwinHeight = 420;
  static const double standardTwinHeight = 390;
  static const double maximumTwinHeight = 540;
  static const double dayPairHeight = 188;
  static const double maximumDayPairHeight = 240;

  static bool isPhone(double width) => width < phoneBreakpoint;

  static bool usesSplitHero(double width) => width >= splitHeroBreakpoint;

  static bool pairsDaySections(double width) =>
      width >= pairedDaySectionsBreakpoint;

  static double sectionGap(double width) => width >= compactRhythmBreakpoint
      ? wideSectionGap
      : PremiumDesignTokens.spaceMd;

  static double twinBaseHeight(double width) =>
      isPhone(width) ? phoneTwinHeight : standardTwinHeight;
}
