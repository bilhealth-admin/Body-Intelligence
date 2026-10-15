import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/services/system_speech_disclosure.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/community/services/community_composer_voice_input_service.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_voice_input_service.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';

import '../../features/nutrition/meal_voice_session_test.dart'
    show ControlledMealSpeech;

const _allow = Key('system-speech-disclosure-allow');
const _decline = Key('system-speech-disclosure-decline');
const _body = Key('system-speech-disclosure-body');

Future<BuildContext> _host(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (value) {
          context = value;
          return const Scaffold(body: Text('Manual entry is available'));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return context;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _speechTest('disclosure explains the actual Android boundary before voice', (
    tester,
  ) async {
    final context = await _host(tester);
    final consent = BilSystemSpeechDisclosure();
    final result = consent.authorize(context, use: BilSpeechUse.food);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.byKey(_body)).data!;
    expect(text, contains('provider selected in your Android device settings'));
    expect(text, contains('personal or health information'));
    expect(text, contains('process it on its servers'));
    expect(text, contains('separate consent'));
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(find.text('Manual entry is available'), findsOneWidget);
    consent.resetLive();
  });

  _speechTest('accept waits until the dialog leaves the real route', (
    tester,
  ) async {
    final context = await _host(tester);
    final consent = BilSystemSpeechDisclosure();
    bool currentRoute() => ModalRoute.of(context)?.isCurrent == true;
    expect(currentRoute(), isTrue);
    var completed = false;
    final result = consent
        .authorize(context, use: BilSpeechUse.coach, isCurrent: currentRoute)
        .then((value) {
          completed = true;
          return value;
        });
    await tester.pumpAndSettle();
    expect(currentRoute(), isFalse);
    await tester.tap(find.byKey(_allow));
    expect(completed, isFalse);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(currentRoute(), isTrue);
    consent.resetLive();
  });

  _speechTest('back is a refusal; normal entry asks again on the next use', (
    tester,
  ) async {
    final context = await _host(tester);
    final consent = BilSystemSpeechDisclosure();
    final first = consent.authorize(context, use: BilSpeechUse.weight);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await first, isFalse);
    final second = consent.authorize(context, use: BilSpeechUse.weight);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_allow));
    await tester.pumpAndSettle();
    expect(await second, isTrue);
    final third = consent.authorize(context, use: BilSpeechUse.weight);
    await tester.pumpAndSettle();
    expect(find.byKey(_body), findsOneWidget);
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await third, isFalse);
    consent.resetLive();
  });

  _speechTest('one live call reuses consent until an explicit reset', (
    tester,
  ) async {
    final context = await _host(tester);
    final consent = BilSystemSpeechDisclosure();
    bool current = true;
    Future<bool> request() => consent.authorize(
      context,
      use: BilSpeechUse.coach,
      liveScope: ('owner-a', 1),
      isCurrent: () => current,
      isLiveCurrent: () => current,
    );
    final first = request();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_allow));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(await request(), isTrue);
    expect(find.byKey(_body), findsNothing);
    consent.resetLive();
    final afterPause = request();
    await tester.pumpAndSettle();
    expect(find.byKey(_body), findsOneWidget);
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await afterPause, isFalse);
    current = false;
    expect(await request(), isFalse);
    consent.resetLive();
  });

  _speechTest('owner or conversation change cannot inherit live access', (
    tester,
  ) async {
    final context = await _host(tester);
    final consent = BilSystemSpeechDisclosure();
    var owner = 'a';
    final first = consent.authorize(
      context,
      use: BilSpeechUse.coach,
      liveScope: ('a', 1),
      isLiveCurrent: () => owner == 'a',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_allow));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    owner = 'b';
    final second = consent.authorize(
      context,
      use: BilSpeechUse.coach,
      liveScope: ('b', 2),
      isLiveCurrent: () => owner == 'b',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_body), findsOneWidget);
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await second, isFalse);
    consent.resetLive();
  });

  _speechTest('generation invalidation rejects an already open decision', (
    tester,
  ) async {
    final context = await _host(tester);
    final consent = BilSystemSpeechDisclosure();
    final result = consent.authorize(
      context,
      use: BilSpeechUse.coach,
      liveScope: ('a', 1),
      isLiveCurrent: () => true,
    );
    await tester.pumpAndSettle();
    consent.resetLive();
    await tester.tap(find.byKey(_allow));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    final retry = consent.authorize(
      context,
      use: BilSpeechUse.coach,
      liveScope: ('a', 1),
      isLiveCurrent: () => true,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_body), findsOneWidget);
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await retry, isFalse);
    consent.resetLive();
  });

  _speechTest('backgrounding ends the temporary live call decision', (
    tester,
  ) async {
    final context = await _host(tester);
    final consent = BilSystemSpeechDisclosure();
    Future<bool> request() => consent.authorize(
      context,
      use: BilSpeechUse.coach,
      liveScope: ('a', 1),
      isLiveCurrent: () => true,
    );
    final first = request();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_allow));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final next = request();
    await tester.pumpAndSettle();
    expect(find.byKey(_body), findsOneWidget);
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await next, isFalse);
    consent.resetLive();
  });

  _speechTest('other locales receive a complete English fallback', (
    tester,
  ) async {
    final context = await _host(tester, locale: const Locale('fr'));
    final consent = BilSystemSpeechDisclosure();
    final result = consent.authorize(context, use: BilSpeechUse.community);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(_body)).data,
      contains('process it on its servers'),
    );
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    consent.resetLive();
  });

  _speechTest('Arabic remains readable on a small display with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = await _host(
      tester,
      locale: const Locale('ar'),
      textScale: 2,
    );
    final consent = BilSystemSpeechDisclosure();
    final result = consent.authorize(context, use: BilSpeechUse.weight);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(_body)).data,
      contains('معلومات شخصية أو صحية'),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(_decline));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    consent.resetLive();
  });

  _speechTest(
    'iOS keeps its existing on-device permission flow',
    (tester) async {
      final context = await _host(tester);
      final consent = BilSystemSpeechDisclosure();
      expect(await consent.authorize(context, use: BilSpeechUse.food), isTrue);
      expect(find.byKey(_body), findsNothing);
      consent.resetLive();
    },
    platform: TargetPlatform.iOS,
  );

  _speechTest(
    'food voice still starts after disclosure and granted permission',
    (tester) async {
      final context = await _host(tester);
      var permissionChecks = 0;
      final speech = ControlledMealSpeech();
      final result = MealVoiceInputService(
        speech,
        permissionGate: (_) async {
          permissionChecks++;
          return true;
        },
      ).capture(context: context, localeId: 'en', arabic: false);
      await tester.pumpAndSettle();
      expect(speech.listens, 0);
      expect(permissionChecks, 0);
      await tester.tap(find.byKey(_allow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(permissionChecks, 1);
      expect(speech.listens, 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(speech.isListening, isFalse);
      expect(speech.disposals, 1);
    },
  );

  for (final use in [
    BilSpeechUse.food,
    BilSpeechUse.weight,
    BilSpeechUse.community,
  ]) {
    _speechTest(
      '$use cannot capture after decline even with granted permission',
      (tester) async {
        final context = await _host(tester);
        var permissionChecks = 0;
        Future<bool> granted(BuildContext _) async {
          permissionChecks++;
          return true;
        }

        final speech = ControlledMealSpeech();
        final Future<Object?> result = switch (use) {
          BilSpeechUse.food => MealVoiceInputService(
            speech,
            permissionGate: granted,
          ).capture(context: context, localeId: 'en', arabic: false),
          BilSpeechUse.weight => WeightVoiceInputService(
            speech,
            permissionGate: granted,
          ).capture(context: context, fallbackSystem: MeasurementSystem.metric),
          BilSpeechUse.community => CommunityComposerVoiceInputService(
            speech,
            permissionGate: granted,
          ).capture(context),
          BilSpeechUse.coach => throw StateError(
            'not a standalone phrase surface',
          ),
        };
        await tester.pumpAndSettle();
        expect(speech.listens, 0);
        expect(permissionChecks, 0);
        await tester.tap(find.byKey(_decline));
        await tester.pumpAndSettle();
        expect(await result, isNull);
        expect(speech.listens, 0);
        expect(permissionChecks, 0);
        expect(find.text('Manual entry is available'), findsOneWidget);
        expect(speech.isListening, isFalse);
        expect(speech.disposals, 1);
      },
    );
  }
}

void _speechTest(
  String description,
  Future<void> Function(WidgetTester) callback, {
  TargetPlatform platform = TargetPlatform.android,
}) => testWidgets(
  description,
  callback,
  variant: TargetPlatformVariant.only(platform),
);
