import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_daily_brief.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:body_intelligence_log/app/services/recoverable_image_picker.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_image_analysis_service.dart';

const delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class Gateway implements LocalModelGateway {
  final questions = <String>[];
  final contexts = <CoachContextSnapshot>[];
  Completer<LocalModelResult>? pending;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    questions.add(question);
    contexts.add(context);
    if (pending != null) return pending!.future;
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: locale == 'ar' ? 'رد اختباري محلي.' : 'Local diagnostic reply.',
        action: null,
      ),
    );
  }
}

Future<GoRouter> mount(
  WidgetTester tester,
  AppDatabase database, {
  required Gateway gateway,
  CoachContextSnapshot? snapshot,
  bool arabic = false,
  PreferencesRepository? preferences,
  ImagePicker? imagePicker,
  MealImageAnalysisService Function(String)? imageAnalysis,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: '/intelligence-center',
    routes: [
      GoRoute(
        path: '/intelligence-center',
        builder: (_, _) => const IntelligenceCenterPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) => const Scaffold(body: Text('Dashboard')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (imagePicker != null)
          intelligenceCoachImagePickerProvider.overrideWithValue(
            BilRecoverableImagePicker(picker: imagePicker, isAndroid: false),
          ),
        if (imageAnalysis != null)
          intelligenceCoachImageAnalysisProvider.overrideWithValue(
            imageAnalysis,
          ),
        if (preferences != null)
          preferencesRepositoryProvider.overrideWithValue(preferences),
        coachContextSnapshotProvider.overrideWith(
          (ref) async => snapshot ?? CoachContextSnapshot.empty(),
        ),
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
        intelligenceHealthContextProvider.overrideWith(
          (ref) async => const IntelligenceHealthContext(
            primaryMessage: '',
            explanation: [],
            confidence: 1,
            evidence: [],
            missingData: [],
          ),
        ),
      ],
      child: MaterialApp.router(
        locale: Locale(arabic ? 'ar' : 'en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: delegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

const historyKey = 'intelligenceConversationHistoryV1';
const transcriptKey = 'intelligenceConversationV1';
const activeKey = 'intelligenceConversationActiveIdV1';

class FailingPreferences extends PreferencesRepository {
  FailingPreferences(super.database);
  bool failDelete = false;
  @override
  Future<void> mutate({
    Map<String, String> set = const {},
    Iterable<String> remove = const [],
  }) {
    if (failDelete && remove.contains(transcriptKey)) {
      return Future.error(StateError('controlled delete failure'));
    }
    return super.mutate(set: set, remove: remove);
  }
}

Future<void> seed(PreferencesRepository preferences) async {
  List<Map<String, Object?>> turns(String text) => [
    IntelligenceMessage(
      id: text,
      role: IntelligenceMessageRole.user,
      kind: IntelligenceMessageKind.coach,
      text: text,
      createdAt: DateTime(2026, 9, 9),
    ).toJson(),
  ];
  await preferences.setMany({
    transcriptKey: jsonEncode(turns('Current private message')),
    activeKey: 'current',
    historyKey: encodeCoachConversationHistory(
      conversations: [
        {
          'id': 'current',
          'title': 'Current chat',
          'createdAt': '2026-09-09',
          'messages': turns('Current private message'),
        },
        {
          'id': 'other',
          'title': 'Other chat',
          'createdAt': '2026-09-08',
          'messages': turns('Other private message'),
        },
      ],
      activeConversationId: 'current',
    ),
  });
}

Future<void> openDelete(WidgetTester tester, {String id = 'current'}) async {
  await tester.tap(find.byTooltip('Coach controls'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.text('Clear conversation'));
  await tester.pump();
  await tester.tap(find.text('Clear conversation'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(AlertDialog), findsNothing);
  expect(find.text('Choose the conversation to delete'), findsOneWidget);
  expect(find.text('New conversation'), findsNothing);
  await tester.tap(find.byKey(Key('ai-coach-conversation-$id')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(AlertDialog), findsOneWidget);
}

CoachContextSnapshot nutritionContext() {
  final now = DateTime.now();
  final day =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return CoachContextSnapshot(
    generatedAt: now,
    profile: const {},
    weights: const [],
    nutritionDays: [
      CoachNutritionDay(
        day: day,
        meals: const [],
        calories: 500,
        protein: 20,
        carbs: 50,
        fat: 24,
        sodium: 100,
      ),
    ],
    waterHistory: const [],
    computedHealth: const {
      'dailyTargets': {
        'caloriesKcal': 1675,
        'proteinG': 142,
        'carbsG': 150,
        'fatG': 50,
      },
    },
  );
}

void main() {
  test(
    'delete preserves unrelated and unrecognized archive rows and metadata',
    () {
      final raw = jsonEncode({
        'version': 2,
        'custom': 'preserve',
        'activeConversationId': 'current',
        'conversations': [
          {'id': 'current', 'messages': []},
          {
            'id': 'other',
            'messages': ['unchanged'],
            'custom': 3,
          },
          {'legacy_unknown': 'do not discard'},
        ],
      });
      final result = jsonDecode(
        deleteCoachConversationFromArchive(raw, 'current'),
      );
      expect(result['activeConversationId'], isNull);
      expect(result['custom'], 'preserve');
      expect(result['conversations'], [
        {
          'id': 'other',
          'messages': ['unchanged'],
          'custom': 3,
        },
        {'legacy_unknown': 'do not discard'},
      ]);
      expect(
        deleteCoachConversationFromArchive(
          jsonEncode([
            {'id': 'current', 'messages': []},
          ]),
          'current',
        ),
        contains('"conversations":[]'),
      );
      expect(
        () => deleteCoachConversationFromArchive('broken-index', 'current'),
        throwsFormatException,
      );
      expect(
        () => deleteCoachConversationFromArchive(
          '{"conversations":0}',
          'current',
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'deleting an inactive chat keeps current selection, draft and reply',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final prefs = PreferencesRepository(db);
      await seed(prefs);
      final gateway = Gateway()..pending = Completer<LocalModelResult>();
      await mount(tester, db, gateway: gateway);
      final field = find.byKey(const Key('ai-coach-question-field'));
      await tester.enterText(field, 'Compare protein foods for dinner');
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-coach-send-button')));
      for (var i = 0; i < 20 && gateway.questions.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(gateway.questions, hasLength(1));
      await tester.enterText(field, 'Keep this next draft');
      await openDelete(tester, id: 'other');
      expect(find.text('Other chat'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(await prefs.get(activeKey), 'current');
      final archive = decodeCoachConversationHistory(
        await prefs.get(historyKey),
      );
      expect(archive.activeConversationId, 'current');
      expect(archive.conversations.map((entry) => entry['id']), ['current']);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Keep this next draft',
      );
      gateway.pending!.complete(
        LocalModelResult.answer(
          const LocalModelAnswer(
            text: 'The current reply survives',
            action: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The current reply survives'), findsOneWidget);
      await unmount(tester);
      await mount(tester, db, gateway: Gateway());
      expect(find.text('The current reply survives'), findsOneWidget);
      expect(await prefs.get(activeKey), 'current');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'dismiss deletion selection without changing or creating any chat',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final prefs = PreferencesRepository(db);
      await seed(prefs);
      final before = await prefs.get(historyKey);
      await mount(tester, db, gateway: Gateway());
      await tester.tap(find.byTooltip('Coach controls'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear conversation'));
      await tester.tap(find.text('Clear conversation'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const Key('ai-coach-conversation-current')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ai-coach-conversation-other')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(15, 30));
      await tester.pumpAndSettle();
      expect(await prefs.get(historyKey), before);
      expect(find.text('Current private message'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'cancel preserves chat; delete removes only its tile across reopen',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final prefs = PreferencesRepository(db);
      await seed(prefs);
      final before = await prefs.get(historyKey);
      await mount(tester, db, gateway: Gateway());
      await openDelete(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await prefs.get(historyKey), before);
      expect(find.text('Current private message'), findsOneWidget);
      await openDelete(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Current private message'), findsNothing);
      expect(await prefs.get(activeKey), isNull);
      expect(await prefs.get(transcriptKey), isNull);
      final history = decodeCoachConversationHistory(
        await prefs.get(historyKey),
      );
      expect(history.conversations.map((entry) => entry['id']), ['other']);
      await unmount(tester);
      await mount(tester, db, gateway: Gateway());
      expect(find.text('Current private message'), findsNothing);
      expect(find.text('Other private message'), findsNothing);
      await tester.tap(
        find.byKey(const Key('ai-coach-conversation-history-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai-coach-conversation-current')),
        findsNothing,
      );
      final other = find.byKey(const Key('ai-coach-conversation-other'));
      expect(other, findsOneWidget);
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(find.text('Other private message'), findsOneWidget);
      expect(find.text('Current private message'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'failed delete preserves both transcript and history and recovers',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final prefs = FailingPreferences(db);
      await seed(prefs);
      final before = await prefs.get(historyKey);
      await mount(tester, db, gateway: Gateway(), preferences: prefs);
      prefs.failDelete = true;
      await openDelete(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await prefs.get(historyKey), before);
      expect(await prefs.get(activeKey), 'current');
      expect(find.text('Current private message'), findsOneWidget);
      expect(
        find.text(
          'The local conversation could not be cleared. Your data was unchanged.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
            .enabled,
        isTrue,
      );
      prefs.failDelete = false;
      await openDelete(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await prefs.get(activeKey), isNull);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets('a late model reply cannot resurrect a deleted conversation', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = PreferencesRepository(db);
    await seed(prefs);
    final gateway = Gateway()..pending = Completer<LocalModelResult>();
    await mount(tester, db, gateway: gateway);
    await tester.enterText(
      find.byKey(const Key('ai-coach-question-field')),
      'Compare protein foods for dinner',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-coach-send-button')));
    for (var i = 0; i < 20 && gateway.questions.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(gateway.questions, hasLength(1));
    await openDelete(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    gateway.pending!.complete(
      LocalModelResult.answer(
        const LocalModelAnswer(text: 'Late obsolete answer', action: null),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Late obsolete answer'), findsNothing);
    expect(await prefs.get(activeKey), isNull);
    expect(
      decodeCoachConversationHistory(
        await prefs.get(historyKey),
      ).conversations.map((item) => item['id']),
      ['other'],
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  for (final arabic in [false, true]) {
    testWidgets(
      'Help me choose reaches the model with remaining intake, Arabic=$arabic',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final snapshot = nutritionContext();
        final brief = const CoachDailyBriefEngine().build(
          context: snapshot,
          now: DateTime.now(),
          locale: arabic ? 'ar' : 'en',
        );
        final gateway = Gateway();
        final router = await mount(
          tester,
          db,
          gateway: gateway,
          snapshot: snapshot,
          arabic: arabic,
        );
        final page = tester.state(find.byType(IntelligenceCenterPage));
        final button = find.text(brief.actionLabel);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(gateway.questions, [brief.suggestedPrompt.toLowerCase()]);
        expect(
          gateway.contexts.single.nutritionRemainingFor(
            DateTime.now(),
          )!['proteinG'],
          122,
        );
        expect(
          router.routeInformationProvider.value.uri.path,
          '/intelligence-center',
        );
        expect(
          identical(page, tester.state(find.byType(IntelligenceCenterPage))),
          isTrue,
        );
        expect(find.text(brief.suggestedPrompt), findsOneWidget);
        expect(
          find.text(arabic ? 'رد اختباري محلي.' : 'Local diagnostic reply.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }

  for (final locale in BilLocalePolicy.productionTags) {
    test('daily nutrition choice is not a target lookup in $locale', () async {
      final snapshot = nutritionContext();
      final brief = const CoachDailyBriefEngine().build(
        context: snapshot,
        now: DateTime.now(),
        locale: locale,
      );
      final gateway = Gateway();
      final engine = IntelligenceCenterEngine(
        localApi: ModelBackedLocalCoachApi(gateway: gateway, context: snapshot),
      );
      await engine.answer(
        question: brief.suggestedPrompt,
        arabic: locale == 'ar',
        localeCode: locale,
        coachContext: snapshot,
      );
      expect(gateway.questions, [brief.suggestedPrompt.toLowerCase()]);
    });
  }

  for (final question in [
    'Compare protein foods for dinner',
    'How much protein remains today?',
    'How many calories have I eaten?',
    'اقترح لي مصدر بروتين',
    'كم باقي لي من البروتين اليوم',
    'ما الفرق بين البروتين والكارب؟',
  ]) {
    test('non-target question is not swallowed: $question', () async {
      final snapshot = nutritionContext();
      final gateway = Gateway();
      final engine = IntelligenceCenterEngine(
        localApi: ModelBackedLocalCoachApi(gateway: gateway, context: snapshot),
      );
      await engine.answer(
        question: question,
        arabic: false,
        coachContext: snapshot,
      );
      expect(gateway.questions, [question.toLowerCase()]);
    });
  }
}
