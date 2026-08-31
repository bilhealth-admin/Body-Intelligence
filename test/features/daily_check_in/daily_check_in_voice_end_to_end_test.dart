import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/daily_check_in/daily_check_in_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/bil_speech_to_text.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:body_intelligence_log/features/weight/services/weight_voice_input_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'spoken pounds flow through review and daily check-in into kilograms only',
    (tester) async {
      const transcript = 'one hundred eighty pounds';
      final speech = _FakeSpeechToText(
        transcript: transcript,
        localeId: 'en-US',
        availableLocaleIds: const [..._releaseLocaleIds, 'xx-YY'],
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final weights = WeightRepository(database);
      addTearDown(database.close);

      final router = _dailyCheckInRouter(
        voiceCapture: (context, system) => WeightVoiceInputService(
          speech,
          permissionGate: (_) async => true,
        ).capture(context: context, fallbackSystem: system),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _dailyCheckInApp(
          router: router,
          locale: const Locale('en'),
          system: MeasurementSystem.imperial,
          weights: weights,
        ),
      );
      await tester.pumpAndSettle();

      await _startVoiceCapture(tester);

      final review = tester.widget<TextField>(
        find.byKey(const Key('spoken-weight-review-field')),
      );
      expect(review.controller?.text, '180');
      expect(review.decoration?.suffixText, 'lb');
      expect(find.textContaining(transcript), findsNothing);
      expect(speech.options?.localeId, 'en-US');
      expect(speech.options?.allowedLocaleIds, hasLength(25));
      expect(speech.options?.allowedLocaleIds, isNot(contains('xx-YY')));
      expect(speech.options?.allowedLocaleIds, containsAll(_releaseLocaleIds));
      expect(speech.options?.autoDetectLanguage, isTrue);

      await tester.tap(find.byKey(const Key('use-spoken-weight')));
      await tester.pumpAndSettle();
      expect(find.text('180.0'), findsOneWidget);
      expect(find.textContaining(transcript), findsNothing);

      await tester.tap(find.byKey(const Key('daily-check-in-save')));
      await tester.pumpAndSettle();

      expect(find.text('dashboard'), findsOneWidget);
      final stored = await weights.getForDay(DateTime.now());
      expect(stored, isNotNull);
      expect(stored!.weight, closeTo(81.6466, 0.001));
      expect(stored.measurementContext, 'morning');
      expect(stored.note, isNull);
      expect(stored.toJson().values, isNot(contains(transcript)));
      expect(speech.disposed, isTrue);
    },
  );

  testWidgets(
    'Arabic speech becomes a reviewed number and persists no raw speech',
    (tester) async {
      const transcript = 'اثنين وثمانين فاصلة خمسة كيلو';
      final speech = _FakeSpeechToText(
        transcript: transcript,
        localeId: 'ar-EG',
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final weights = WeightRepository(database);
      addTearDown(database.close);

      final router = _dailyCheckInRouter(
        voiceCapture: (context, system) => WeightVoiceInputService(
          speech,
          permissionGate: (_) async => true,
        ).capture(context: context, fallbackSystem: system),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _dailyCheckInApp(
          router: router,
          locale: const Locale('ar'),
          system: MeasurementSystem.metric,
          weights: weights,
        ),
      );
      await tester.pumpAndSettle();

      await _startVoiceCapture(tester);

      final review = tester.widget<TextField>(
        find.byKey(const Key('spoken-weight-review-field')),
      );
      expect(review.controller?.text, '82.5');
      expect(review.decoration?.suffixText, 'kg');
      expect(find.textContaining(transcript), findsNothing);
      expect(speech.options?.localeId, 'ar-EG');

      await tester.tap(find.byKey(const Key('use-spoken-weight')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('daily-check-in-save')));
      await tester.pumpAndSettle();

      final stored = await weights.getForDay(DateTime.now());
      expect(stored?.weight, closeTo(82.5, 0.001));
      expect(stored?.toJson().values, isNot(contains(transcript)));
      expect(speech.disposed, isTrue);
    },
  );

  testWidgets(
    'ambiguous speech never enables acceptance or changes the daily weight',
    (tester) async {
      const transcript = 'at 7:30, weight 82 kilograms';
      final speech = _FakeSpeechToText(
        transcript: transcript,
        localeId: 'en-US',
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final weights = WeightRepository(database);
      addTearDown(database.close);

      final router = _dailyCheckInRouter(
        voiceCapture: (context, system) => WeightVoiceInputService(
          speech,
          permissionGate: (_) async => true,
        ).capture(context: context, fallbackSystem: system),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _dailyCheckInApp(
          router: router,
          locale: const Locale('en'),
          system: MeasurementSystem.metric,
          weights: weights,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('80.0'), findsOneWidget);
      await _startVoiceCapture(tester);

      final review = tester.widget<TextField>(
        find.byKey(const Key('spoken-weight-review-field')),
      );
      expect(review.controller?.text, isEmpty);
      expect(find.textContaining(transcript), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('use-spoken-weight')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('80.0'), findsOneWidget);
      expect(await weights.getForDay(DateTime.now()), isNull);
      expect(speech.disposed, isTrue);
    },
  );
}

Future<void> _startVoiceCapture(WidgetTester tester) async {
  final action = find.byKey(const Key('daily-check-in-weight-voice'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

GoRouter _dailyCheckInRouter({required DailyCheckInVoiceCapture voiceCapture}) {
  return GoRouter(
    initialLocation: '/daily-check-in',
    routes: [
      GoRoute(
        path: '/daily-check-in',
        builder: (_, _) => DailyCheckInPage(voiceCapture: voiceCapture),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('dashboard')),
      ),
    ],
  );
}

Widget _dailyCheckInApp({
  required GoRouter router,
  required Locale locale,
  required MeasurementSystem system,
  required WeightRepository weights,
}) {
  return ProviderScope(
    overrides: [
      weightRepositoryProvider.overrideWithValue(weights),
      todayWeightProvider.overrideWith((ref) => Stream.value(null)),
      latestWeightProvider.overrideWith((ref) => Stream.value(null)),
      userProfileProvider.overrideWith(
        (ref) => Stream.value(
          UserProfileData(
            id: 1,
            uuid: 'profile-id',
            age: 30,
            gender: 'male',
            height: 175,
            currentWeight: 80,
            targetWeight: 76,
            activityLevel: 'moderate',
            exercises: false,
            createdAt: DateTime(2026, 8, 30),
            updatedAt: DateTime(2026, 8, 30),
            revision: 1,
            syncStatus: 'local',
          ),
        ),
      ),
      measurementSystemProvider.overrideWith((ref) => Stream.value(system)),
    ],
    child: MaterialApp.router(
      locale: locale,
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

final class _FakeSpeechToText extends SpeechToText {
  _FakeSpeechToText({
    required this.transcript,
    required this.localeId,
    this.availableLocaleIds,
  });

  final String transcript;
  final String localeId;
  final List<String>? availableLocaleIds;
  SpeechListenOptions? options;
  bool disposed = false;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
  }) async => true;

  @override
  Future<List<LocaleName>> locales() async =>
      (availableLocaleIds ?? [localeId]).map(LocaleName.new).toList();

  @override
  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    required SpeechListenOptions listenOptions,
  }) async {
    options = listenOptions;
    _listening = true;
    scheduleMicrotask(() {
      _listening = false;
      onResult(
        SpeechRecognitionResult(transcript, isFinal: true, localeId: localeId),
      );
    });
  }

  @override
  Future<void> stop() async => _listening = false;

  @override
  Future<void> cancel() async => _listening = false;

  @override
  Future<void> dispose() async {
    _listening = false;
    disposed = true;
  }
}

const _releaseLocaleIds = <String>[
  'ar-EG',
  'en-US',
  'fr-FR',
  'es-ES',
  'tr-TR',
  'de-DE',
  'it-IT',
  'pt-BR',
  'pt-PT',
  'ur-PK',
  'fa-IR',
  'hi-IN',
  'id-ID',
  'ms-MY',
  'ja-JP',
  'ko-KR',
  'zh-CN',
  'zh-TW',
  'ru-RU',
  'bn-BD',
  'vi-VN',
  'th-TH',
  'pl-PL',
  'nl-NL',
  'uk-UA',
];
