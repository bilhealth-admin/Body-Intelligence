import 'package:flutter/material.dart';

abstract final class BilFlagshipTokens {
  static const Color navy950 = Color(0xFF071120);
  static const Color navy900 = Color(0xFF0A1730);
  static const Color navy800 = Color(0xFF10254A);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color orange500 = Color(0xFFF59E0B);
  static const Color red500 = Color(0xFFEF4444);

  static const Color canvasLight = Color(0xFFF4F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF8FAFC);
  static const Color outlineLight = Color(0xFFDCE4EF);
  static const Color textPrimaryLight = Color(0xFF101828);
  static const Color textSecondaryLight = Color(0xFF5F6B7A);

  static const Color canvasDark = navy950;
  static const Color surfaceDark = Color(0xFF0D1B33);
  static const Color surfaceMutedDark = Color(0xFF122342);
  static const Color outlineDark = Color(0xFF263B5D);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFB8C6D9);

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
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 30;
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
    BoxShadow(color: Color(0x12071920), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> shadowFloating = [
    BoxShadow(
      color: Color(0x2606B6D4),
      blurRadius: 36,
      spreadRadius: -8,
      offset: Offset(0, 16),
    ),
  ];
}
