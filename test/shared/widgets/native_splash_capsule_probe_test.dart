import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_splash_capsule_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/native_feature_splashes_test.dart' as native;

void main() {
  for (final width in [16.0, 24.0]) {
    for (final reduced in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
          'actual native capsule probe width=$width reduced=$reduced dark=$dark',
          (tester) async {
            try {
              await tester.pumpWidget(
                MaterialApp(
                  theme: dark ? ThemeData.dark() : ThemeData.light(),
                  home: Builder(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(disableAnimations: reduced),
                      child: Scaffold(
                        body: Center(
                          child: SizedBox.square(
                            dimension: width,
                            child: const BilFeatureWelcomeStatus(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final result = await native.verifyNativeSplashCapsuleProbe(
                tester,
                find.byType(BilSplashCapsuleProgress),
                reduced: reduced,
              );
              expect(result['render_width'], width);
              expect(result['render_height'], 7);
              expect(result['painted_pixel_count'], greaterThan(0));
              expect(
                result['changed_rgba_pixel_count'],
                reduced ? 0 : greaterThan(0),
              );
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
            }
          },
        );
      }
    }
  }

  testWidgets(
    'native probe rejects a static layer advertised as normal motion',
    (tester) async {
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  child: BilSplashCapsuleProgress(width: 24, progress: .1),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          native.verifyNativeSplashCapsuleProbe(
            tester,
            find.byType(BilSplashCapsuleProgress),
            reduced: false,
          ),
          throwsA(isA<TestFailure>()),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}
