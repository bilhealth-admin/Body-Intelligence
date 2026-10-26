import 'package:body_intelligence_log/features/onboarding/widgets/modern_onboarding_scaffold.dart';
import 'package:body_intelligence_log/features/visual_2026/bil_calm_visual_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final onboarding in [false, true]) {
      testWidgets(
        'actual status layer follows surface dark=$dark onboarding=$onboarding',
        (tester) async {
          tester.view.padding = const FakeViewPadding(top: 24);
          addTearDown(tester.view.resetPadding);
          final theme = ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            platform: TargetPlatform.iOS,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                child: onboarding
                    ? ModernOnboardingScaffold(
                        step: 0,
                        totalSteps: 3,
                        title: 'Local onboarding fixture',
                        body: const Text('Local information'),
                        onBack: null,
                        onNext: () {},
                      )
                    : BilCalmVisualScope(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text('Apps & Devices')),
                          body: const Text('Local health surface fixture'),
                        ),
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final style = tester.binding.renderViews.single.debugLayer!
              .find<SystemUiOverlayStyle>(const Offset(20, 10));
          expect(style, isNotNull);
          expect(
            style!.statusBarIconBrightness,
            dark ? Brightness.light : Brightness.dark,
            reason:
                'Android status glyphs must contrast with the real surface.',
          );
          expect(
            style.statusBarBrightness,
            dark ? Brightness.dark : Brightness.light,
            reason: 'iOS uses the inverse status brightness convention.',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
