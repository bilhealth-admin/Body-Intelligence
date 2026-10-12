import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/community/services/community_composer_voice_input_service.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_input_service.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'meal_voice_session_test.dart' show ControlledMealSpeech;
import '../../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  Future<BuildContext> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'NotoArabicEvidence',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('Controlled voice host'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return context;
  }

  Future<Object?> capture(
    String kind,
    BuildContext context,
    ControlledMealSpeech speech, {
    bool allowed = true,
  }) => kind == 'community'
      ? CommunityComposerVoiceInputService(
          speech,
          permissionGate: (_) async => allowed,
        ).capture(context)
      : WeightVoiceInputService(
          speech,
          permissionGate: (_) async => allowed,
        ).capture(context: context, fallbackSystem: MeasurementSystem.metric);
  for (final kind in ['community', 'weight']) {
    testWidgets(
      '$kind voice permission denial cannot return or persist a value',
      (tester) async {
        final context = await mount(tester), speech = ControlledMealSpeech();
        expect(await capture(kind, context, speech, allowed: false), isNull);
        expect(speech.listens, 0);
        expect(speech.disposals, 1);
        expect(find.byType(Dialog), findsNothing);
      },
    );
    testWidgets(
      '$kind delayed preparation cancels early and rejects cross-purpose double capture',
      (tester) async {
        final context = await mount(tester),
            speech = ControlledMealSpeech()..available = Completer<bool>();
        final pending = capture(kind, context, speech);
        await tester.pumpAndSettle();
        expect(find.text('جارٍ تهيئة الميكروفون…'), findsOneWidget);
        final another = ControlledMealSpeech();
        expect(
          await MealVoiceInputService(
            another,
            permissionGate: (_) async => true,
          ).capture(context: context, localeId: 'ar', arabic: true),
          isNull,
        );
        expect(another.disposals, 0);
        expect(another.listens, 0);
        final cancel = find.byKey(const Key('cancel-voice-food-candidate'));
        await tester.ensureVisible(cancel);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(await pending, isNull);
        speech.available!.complete(true);
        await tester.pump();
        expect(speech.listens, 0);
        expect(speech.listening, isFalse);
      },
    );
    testWidgets(
      '$kind reviewed Arabic edit survives late voice at 320 keyboard 2x and confirms only a draft',
      (tester) async {
        final context = await mount(tester), speech = ControlledMealSpeech();
        final pending = capture(kind, context, speech);
        await tester.pumpAndSettle();
        speech.emit(kind == 'community' ? 'نص جزئي' : 'وزني ٨٢ كيلوغرام');
        await tester.pumpAndSettle();
        final field = find.byKey(
          Key(
            kind == 'community'
                ? 'community-voice-transcript'
                : 'spoken-weight-review-field',
          ),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        final edited = kind == 'community'
            ? 'مسودة معدلة 🥗 لا تنشر تلقائيًا'
            : '٨٣٫٥';
        await tester.enterText(field, edited);
        await tester.pumpAndSettle();
        speech.emit(
          kind == 'community' ? 'نص خطأ متأخر' : 'وزني ٧٠ رطل',
          finalResult: true,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, edited);
        expect(speech.listening, isFalse);
        final use = find.byKey(
          Key(
            kind == 'community'
                ? 'community-use-voice-transcript'
                : 'use-spoken-weight',
          ),
        );
        await tester.ensureVisible(use);
        await tester.tap(use);
        await tester.pumpAndSettle();
        final result = await pending;
        if (kind == 'community') {
          expect(result, edited);
        } else {
          final value = result! as SpokenWeightCandidate;
          expect(value.value, 83.5);
          expect(value.unit, SpokenWeightUnit.kilograms);
        }
        expect(speech.disposals, 1);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$kind background and navigator disposal do not confirm a recording',
      (tester) async {
        final context = await mount(tester), speech = ControlledMealSpeech();
        final pending = capture(kind, context, speech);
        await tester.pumpAndSettle();
        expect(speech.listening, isTrue);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        expect(speech.listening, isFalse);
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(await pending, isNull);
        expect(speech.disposals, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
