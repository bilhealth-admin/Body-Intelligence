import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/community/services/community_composer_voice_input_service.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../features/nutrition/meal_voice_session_test.dart'
    show ControlledMealSpeech;
import '../visual_closure/visual_evidence_font.dart';
import '../visual_closure/closure_surface_capture.dart';
import '../support/system_speech_disclosure_test_support.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final kind in ['community', 'weight']) {
    testWidgets('actual $kind voice window before and after capture', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
      final speech = ControlledMealSpeech();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: visualEvidenceTheme(
            BilFlagshipTheme.dark(isArabic: true),
            fontFamily: 'NotoArabicEvidence',
          ),
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold(body: Text('TEST host boundary'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final capture = kind == 'community'
          ? CommunityComposerVoiceInputService(
              speech,
              permissionGate: (_) async => true,
            ).capture(context)
          : WeightVoiceInputService(
              speech,
              permissionGate: (_) async => true,
            ).capture(
              context: context,
              fallbackSystem: MeasurementSystem.metric,
            );
      await acceptSystemSpeechDisclosure(tester);
      speech.emit(
        kind == 'community' ? 'مسودة منشور للمراجعة فقط' : 'وزني ٨٢٫٥ كيلوغرام',
        finalResult: true,
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      await captureClosureSurface(tester, field, '$kind-voice-ar-dark');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await capture, isNull);
      expect(speech.listening, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
