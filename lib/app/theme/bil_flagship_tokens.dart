import 'package:flutter/material.dart';
import 'bil_pearl_finish.dart';

abstract final class BilFlagshipTokens {
  static const Color navy950 = Color(0xFF071120);
  static const Color navy900 = Color(0xFF0A1730);
  static const Color navy800 = Color(0xFF10254A);
  // BIL action blue: reserved for links, selected values and primary actions.
  // A single restrained accent reads more clearly than mixing cyan/green on
  // every surface.
  static const Color cyan500 = Color(0xFF0877D1);
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color orange500 = Color(0xFFF59E0B);
  static const Color red500 = Color(0xFFEF4444);

  static const Color canvasLight = BilPearlFinish.lightCanvas;
  static const Color surfaceLight = BilPearlFinish.lightSurface;
  static const Color surfaceMutedLight = BilPearlFinish.lightInset;
  static const Color outlineLight = BilPearlFinish.lightEdge;
  static const Color textPrimaryLight = BilPearlFinish.lightInk;
  static const Color textSecondaryLight = BilPearlFinish.lightSecondary;

  // Refined blue-silver elevation with restrained, non-glowing text.
  static const Color canvasDark = BilPearlFinish.darkCanvas;
  static const Color surfaceDark = BilPearlFinish.darkSurface;
  static const Color surfaceMutedDark = BilPearlFinish.darkInset;
  static const Color outlineDark = BilPearlFinish.darkEdge;
  static const Color textPrimaryDark = BilPearlFinish.darkInk;
  static const Color textSecondaryDark = BilPearlFinish.darkSecondary;

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space64 = 64;

  static const double radiusSm = 10;
  // One compact geometry scale across auth, onboarding and the signed-in app.
  // These values intentionally match the canonical premium foundation.
  static const double radiusMd = 12;
  static const double radiusLg = 14;
  static const double radiusXl = 16;
  static const double radiusPill = 999;

  static const LinearGradient brandGradient = LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: [cyan500, emerald400],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy800, navy950],
  );

  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x12071120),
      blurRadius: 24,
      spreadRadius: -10,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> shadowFloating = [
    BoxShadow(
      color: Color(0x1A24415B),
      blurRadius: 24,
      spreadRadius: -10,
      offset: Offset(0, 10),
    ),
  ];
}
