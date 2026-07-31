import 'package:body_intelligence_log/app/theme/app_theme_data.dart';
import 'package:body_intelligence_log/shared/widgets/premium_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('interactive premium surfaces support Enter and Space', (
    tester,
  ) async {
    var activations = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeData.lightTheme(Brightness.light),
        home: Scaffold(
          body: PremiumSurface(
            focusNode: focusNode,
            onTap: () => activations++,
            child: const Text('Open details'),
          ),
        ),
      ),
    );

    expect(find.byType(FocusableActionDetector), findsOneWidget);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(activations, 2);
  });

  testWidgets('non-interactive surfaces stay outside the focus order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeData.lightTheme(Brightness.light),
        home: const Scaffold(body: PremiumSurface(child: Text('Information'))),
      ),
    );

    final detector = tester.widget<FocusableActionDetector>(
      find.byType(FocusableActionDetector),
    );
    expect(detector.enabled, isFalse);
  });
}
