import 'package:flutter/widgets.dart';

import 'bil_flagship_tokens.dart';

/// Canonical layout spacing for BIL.
///
/// Numeric spacing values remain owned by [BilFlagshipTokens]. This class
/// exposes reusable gaps and directional insets without duplicating values.
abstract final class BilSpacing {
  static const double xxs = BilFlagshipTokens.space2;
  static const double xs = BilFlagshipTokens.space4;
  static const double sm = BilFlagshipTokens.space8;
  static const double md = BilFlagshipTokens.space12;
  static const double lg = BilFlagshipTokens.space16;
  static const double xl = BilFlagshipTokens.space24;
  static const double xxl = BilFlagshipTokens.space32;
  static const double display = BilFlagshipTokens.space40;
  static const double hero = BilFlagshipTokens.space48;

  static const EdgeInsets screenCompact = EdgeInsets.all(lg);
  static const EdgeInsets screen = EdgeInsets.all(xl);
  static const EdgeInsets screenWide = EdgeInsets.all(xxl);

  static const EdgeInsets cardCompact = EdgeInsets.all(md);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardComfortable = EdgeInsets.all(xl);

  static const EdgeInsets control = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const EdgeInsets controlLarge = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: lg,
  );

  static const EdgeInsetsDirectional sectionHorizontal =
      EdgeInsetsDirectional.symmetric(horizontal: xl);

  static const EdgeInsetsDirectional sectionWide =
      EdgeInsetsDirectional.symmetric(horizontal: xxl);

  static EdgeInsets screenForWidth(double width) {
    if (width >= 1200) return screenWide;
    if (width >= 600) return screen;
    return screenCompact;
  }

  static double sectionGapForHeight(double height) {
    if (height < 640) return md;
    if (height < 800) return lg;
    return xl;
  }
}

/// Reusable fixed gaps backed by [BilSpacing].
abstract final class BilGap {
  static const Widget xxs = SizedBox.square(dimension: BilSpacing.xxs);
  static const Widget xs = SizedBox.square(dimension: BilSpacing.xs);
  static const Widget sm = SizedBox.square(dimension: BilSpacing.sm);
  static const Widget md = SizedBox.square(dimension: BilSpacing.md);
  static const Widget lg = SizedBox.square(dimension: BilSpacing.lg);
  static const Widget xl = SizedBox.square(dimension: BilSpacing.xl);
  static const Widget xxl = SizedBox.square(dimension: BilSpacing.xxl);
  static const Widget display = SizedBox.square(dimension: BilSpacing.display);
  static const Widget hero = SizedBox.square(dimension: BilSpacing.hero);

  static const Widget horizontalXxs = SizedBox(width: BilSpacing.xxs);
  static const Widget horizontalXs = SizedBox(width: BilSpacing.xs);
  static const Widget horizontalSm = SizedBox(width: BilSpacing.sm);
  static const Widget horizontalMd = SizedBox(width: BilSpacing.md);
  static const Widget horizontalLg = SizedBox(width: BilSpacing.lg);
  static const Widget horizontalXl = SizedBox(width: BilSpacing.xl);
  static const Widget horizontalXxl = SizedBox(width: BilSpacing.xxl);

  static const Widget verticalXxs = SizedBox(height: BilSpacing.xxs);
  static const Widget verticalXs = SizedBox(height: BilSpacing.xs);
  static const Widget verticalSm = SizedBox(height: BilSpacing.sm);
  static const Widget verticalMd = SizedBox(height: BilSpacing.md);
  static const Widget verticalLg = SizedBox(height: BilSpacing.lg);
  static const Widget verticalXl = SizedBox(height: BilSpacing.xl);
  static const Widget verticalXxl = SizedBox(height: BilSpacing.xxl);
  static const Widget verticalDisplay = SizedBox(height: BilSpacing.display);
  static const Widget verticalHero = SizedBox(height: BilSpacing.hero);

  static Widget horizontal(double value) => SizedBox(width: value);

  static Widget vertical(double value) => SizedBox(height: value);
}
