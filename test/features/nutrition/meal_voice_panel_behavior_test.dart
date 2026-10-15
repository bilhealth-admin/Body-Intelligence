import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_candidate.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'meal_voice_session_test.dart' show ControlledMealSpeech;
import '../../visual_closure/visual_evidence_font.dart';
import '../../visual_closure/closure_surface_capture.dart';
import '../../support/system_speech_disclosure_test_support.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  Future<BuildContext> mount(
    WidgetTester tester, {
    String language = 'en',
    Brightness brightness = Brightness.light,
    double width = 390,
    double scale = 1,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF318BFF),
            brightness: brightness,
          ),
          fontFamily: language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('Host capture boundary'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return context;
  }

  testWidgets(
    'panel appears during delayed native initialization and double tap cannot open two recordings',
    (tester) async {
      final context = await mount(tester);
      final speech = ControlledMealSpeech()..available = Completer<bool>();
      final service = MealVoiceInputService(
        speech,
        permissionGate: (_) async => true,
      );
      final first = service.capture(
        context: context,
        localeId: 'en',
        arabic: false,
      );
      final second = service.capture(
        context: context,
        localeId: 'en',
        arabic: false,
      );
      await acceptSystemSpeechDisclosure(tester);
      expect(await second, isNull);
      expect(find.byKey(systemSpeechDisclosureAllowKey), findsNothing);
      expect(find.text('Preparing microphone…'), findsOneWidget);
      expect(speech.listens, 0);
      await tester.tap(find.byKey(const Key('cancel-voice-food-candidate')));
      await tester.pumpAndSettle();
      expect(await first, isNull);
      speech.available!.complete(true);
      await tester.pump();
      expect(speech.listens, 0);
      expect(speech.listening, isFalse);
      expect(speech.disposals, 1);
    },
  );
  testWidgets('denied permission never listens or returns a candidate', (
    tester,
  ) async {
    final context = await mount(tester);
    final speech = ControlledMealSpeech();
    var permissionChecks = 0;
    final pending = MealVoiceInputService(
      speech,
      permissionGate: (_) async {
        permissionChecks++;
        return false;
      },
    ).capture(context: context, localeId: 'en', arabic: false);
    expect(permissionChecks, 0);
    await acceptSystemSpeechDisclosure(tester);
    final value = await pending;
    expect(permissionChecks, 1);
    expect(value, isNull);
    expect(speech.listens, 0);
    expect(speech.disposals, 1);
  });
  testWidgets('system back and background stop microphone without confirming', (
    tester,
  ) async {
    final context = await mount(tester);
    final speech = ControlledMealSpeech();
    final result = MealVoiceInputService(
      speech,
      permissionGate: (_) async => true,
    ).capture(context: context, localeId: 'en', arabic: false);
    await acceptSystemSpeechDisclosure(tester);
    expect(speech.listening, isTrue);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(speech.listening, isFalse);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(find.text('Microphone stopped'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(speech.disposals, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  for (final language in ['ar', 'en']) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 800.0]) {
        testWidgets(
          'reviewed search only $language $brightness $width keyboard 2x real taps and late speech',
          (tester) async {
            final context = await mount(
              tester,
              language: language,
              brightness: brightness,
              width: width,
              scale: 2,
              keyboard: 280,
            );
            final speech = ControlledMealSpeech();
            final result =
                MealVoiceInputService(
                  speech,
                  permissionGate: (_) async => true,
                ).capture(
                  context: context,
                  localeId: language,
                  arabic: language == 'ar',
                );
            await acceptSystemSpeechDisclosure(tester);
            final editor = find.byKey(
              const Key('editable-voice-food-candidate'),
            );
            final text = language == 'ar'
                ? 'فول مدمس مع طحينة 80 غرامًا واختيار الطعام بنفسي بعد البحث'
                : 'Chicken 80 grams with a long reviewed food search phrase';
            await tester.ensureVisible(editor);
            await tester.tap(editor);
            await tester.enterText(editor, text);
            await tester.pumpAndSettle();
            speech.emit('late wrong phrase', finalResult: true);
            await tester.pumpAndSettle();
            expect(tester.widget<TextField>(editor).controller!.text, text);
            expect(speech.listening, isFalse);
            final confirm = find.byKey(
              const Key('accept-reviewed-voice-candidate'),
            );
            await tester.ensureVisible(confirm);
            await tester.pumpAndSettle();
            if (width == 320 && language == 'ar') {
              await captureClosureSurface(
                tester,
                find.byType(Dialog),
                'voice-ar-$brightness-320-keyboard-2x',
              );
            }
            final semantics = tester.ensureSemantics();
            expect(
              tester.getSemantics(confirm).getSemanticsData().label,
              isNotEmpty,
            );
            await tester.tap(confirm);
            await tester.pumpAndSettle();
            final MealVoiceCandidate? candidate = await result;
            expect(candidate, isNotNull);
            expect(candidate!.originalTranscript, text);
            semantics.dispose();
            expect(tester.takeException(), isNull);
            expect(speech.disposals, 1);
          },
        );
      }
    }
  }
}
