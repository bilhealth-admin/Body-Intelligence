import 'package:body_intelligence_log/shared/widgets/bil_coach_identity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../qa_next/feature_splashes_test_support.dart';
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final language in ['ar', 'en']) {
    for (final reduced in [false, true]) {
      testWidgets(
        'AI Coach entry keeps approved portrait typography and 2.2-second hold $language reduced=$reduced',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final harness = FeatureCoachSplashHarness(
            language: language,
            dark: false,
            scale: 2,
            reduceMotion: reduced,
          );
          try {
            debugPrint('BIL_FEATURE_CASE stage=before_mount');
            await harness.mount(tester);
            debugPrint('BIL_FEATURE_CASE stage=mounted');
            final title = find.text(
              language == 'ar'
                  ? 'مرحبًا بك في المدرب الذكي'
                  : 'Welcome to AI Coach',
            );
            expect(title, findsOneWidget);
            final text = tester.widget<Text>(title);
            expect(
              text.style?.fontFamily,
              language == 'ar' ? 'BILArabic' : 'BILDisplay',
            );
            expect(text.style?.shadows ?? const [], isEmpty);
            expect(text.style!.color!.computeLuminance(), lessThan(.05));
            expect(find.byType(BilCoachPortrait), findsOneWidget);
            expect(
              find.byType(ClipOval),
              findsNothing,
              reason:
                  'the approved captain portrait has no external visible frame',
            );
            expect(
              tester
                  .widget<CupertinoActivityIndicator>(
                    find.byType(CupertinoActivityIndicator),
                  )
                  .animating,
              !reduced,
            );
            expect(
              find.text(
                language == 'ar' ? 'أتكلم لغتك' : 'Speak your language',
              ),
              findsOneWidget,
            );
            debugPrint('BIL_FEATURE_CASE stage=before_2199');
            await tester.pump(const Duration(milliseconds: 2199));
            debugPrint('BIL_FEATURE_CASE stage=after_2199');
            expect(title, findsOneWidget);
            debugPrint('BIL_FEATURE_CASE stage=before_last_millisecond');
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pump();
            debugPrint('BIL_FEATURE_CASE stage=after_2200');
            expect(title, findsNothing);
            expect(find.byKey(const ValueKey('ai-coach-hero')), findsOneWidget);
            expect(tester.takeException(), isNull);
            debugPrint('BIL_FEATURE_CASE stage=body_pass');
          } catch (error, stack) {
            // Emit the original assertion before bounded cleanup, so teardown
            // cannot hide which existing requirement actually failed.
            debugPrint(
              'BIL_FEATURE_CASE stage=body_failed '
              'type=${error.runtimeType} error=$error',
            );
            debugPrintStack(stackTrace: stack);
            rethrow;
          } finally {
            debugPrint('BIL_FEATURE_CASE stage=before_dispose');
            await harness.dispose(tester);
            debugPrint('BIL_FEATURE_CASE stage=after_dispose');
          }
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    }
  }
}
