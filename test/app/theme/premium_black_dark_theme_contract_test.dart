import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme uses premium neutral black surfaces instead of navy canvas', () {
    final theme = BilFlagshipTheme.dark();
    expect(BilFlagshipTokens.canvasDark, const Color(0xFF030405));
    expect(BilFlagshipTokens.surfaceDark, const Color(0xFF0B0D10));
    expect(BilFlagshipTokens.surfaceMutedDark, const Color(0xFF11151A));
    expect(theme.scaffoldBackgroundColor, BilFlagshipTokens.canvasDark);
    expect(theme.cardTheme.color, BilFlagshipTokens.surfaceDark);
    expect(theme.colorScheme.surface, BilFlagshipTokens.surfaceDark);
    expect(theme.colorScheme.surface, isNot(BilFlagshipTokens.navy950));
  });
}
