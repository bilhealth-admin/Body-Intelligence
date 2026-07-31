import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/app/theme/premium_design_tokens.dart';
import 'package:body_intelligence_log/shared/widgets/premium_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('high contrast strengthens the surface and removes blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeData.lightTheme(Brightness.light),
        home: const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: Scaffold(
            body: PremiumSurface(
              dashboardGlass: true,
              child: Text('Health summary'),
            ),
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(
      border.top.width,
      PremiumDesignTokens.dashboardCardHighContrastBorderWidth,
    );
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.begin, AlignmentDirectional.topStart);
    expect(gradient.end, AlignmentDirectional.bottomEnd);
  });

  testWidgets('premium surface remains stable in RTL at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeData.lightTheme(Brightness.light),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PremiumSurface(
                dashboardGlass: true,
                child: Text('ملخص الصحة'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ملخص الصحة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
