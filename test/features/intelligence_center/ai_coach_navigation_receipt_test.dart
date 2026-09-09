import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/ai_coach_chat_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/bil_tool_registry.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'typed replies use current text then the last clear writing language',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final gateway = _RecordingLanguageGateway();
      await tester.pumpWidget(
        _coachApp(
          database: database,
          navigation: (context, path, push) async {},
          gateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      await _send(tester, 'اشرح لي تعافي جسمي اليوم');
      await _pumpUntilCalls(tester, gateway, 1);
      await _send(tester, 'protein 30 g');
      await _pumpUntilCalls(tester, gateway, 2);
      await _send(tester, 'hi');
      await _pumpUntilCalls(tester, gateway, 3);

      expect(gateway.locales, <String>['ar', 'ar', 'en']);
      expect(gateway.detected, everyElement(isTrue));
    },
  );

  testWidgets('weight plan meal and workout actions use their exact routes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final actions = <IntelligenceAction>[
      const BilToolRegistry().createAction(
        name: 'open_weight_log',
        arguments: const <String, Object?>{},
        label: 'Open weight history',
      )!,
      const IntelligenceAction(
        id: 'open-plan',
        type: IntelligenceActionType.openPlan,
        label: 'Open plan',
        requiresConfirmation: false,
      ),
      const IntelligenceAction(
        id: 'open-meals',
        type: IntelligenceActionType.reviewMeal,
        label: 'Open meals',
        requiresConfirmation: false,
      ),
      const IntelligenceAction(
        id: 'open-workouts',
        type: IntelligenceActionType.reviewWorkout,
        label: 'Open workouts',
        requiresConfirmation: false,
      ),
    ];
    final message = IntelligenceMessage(
      id: 'coach-route-matrix',
      role: IntelligenceMessageRole.bil,
      kind: IntelligenceMessageKind.action,
      text: 'Choose a screen.',
      createdAt: DateTime.utc(2026, 9, 8),
      actionLinks: actions
          .map(IntelligenceMessageAction.fromAction)
          .whereType<IntelligenceMessageAction>()
          .toList(),
    );
    await PreferencesRepository(database).set(
      'intelligenceConversationV1',
      jsonEncode(<Object?>[message.toJson()]),
    );
    final opened = <(String, bool)>[];
    await tester.pumpWidget(
      _coachApp(
        database: database,
        navigation: (context, path, push) async {
          opened.add((path, push));
        },
      ),
    );
    await tester.pumpAndSettle();

    // The restored action is above the newest session greeting. Use a real
    // drag so the reversed chat stops following the newest message exactly as
    // it does for a person reading earlier messages.
    await tester.drag(find.byType(ListView), const Offset(0, 420));
    await tester.pumpAndSettle();

    for (final action in actions) {
      final finder = find.byKey(
        Key('ai-coach-action-${action.type.name}-${action.id}'),
      );
      await tester.tap(finder);
      await tester.pump();
    }

    expect(opened, <(String, bool)>[
      ('/weight-history', false),
      ('/plan?origin=dashboard', false),
      ('/daily-log?focus=meal', false),
      ('/wellness/workouts/log', true),
    ]);
  });

  testWidgets('failed screen open is explicit and retry runs the same route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final action = IntelligenceMessageAction.fromAction(
      const IntelligenceAction(
        id: 'open-plan',
        type: IntelligenceActionType.openPlan,
        label: 'Open plan',
        requiresConfirmation: false,
      ),
    )!;
    final message = IntelligenceMessage(
      id: 'coach-open-plan',
      role: IntelligenceMessageRole.bil,
      kind: IntelligenceMessageKind.action,
      text: 'Use the action below to open the requested screen.',
      createdAt: DateTime.utc(2026, 9, 8),
      actionLinks: <IntelligenceMessageAction>[action],
    );
    await PreferencesRepository(database).set(
      'intelligenceConversationV1',
      jsonEncode(<Object?>[message.toJson()]),
    );
    var attempts = 0;
    final openedPaths = <String>[];
    final firstAttempt = Completer<void>();

    await tester.pumpWidget(
      _coachApp(
        database: database,
        navigation: (context, path, push) async {
          attempts += 1;
          if (attempts == 1) await firstAttempt.future;
          openedPaths.add(path);
        },
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.byKey(const Key('ai-coach-action-openPlan-open-plan'));
    await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
    await tester.tap(chip);
    await tester.pump();

    expect(
      find.text(AiCoachChatCopy.resolve('en', AiCoachChatCopy.opening)),
      findsOneWidget,
    );
    firstAttempt.completeError(StateError('synthetic route failure'));
    await tester.pump();

    expect(
      find.text(
        AiCoachChatCopy.resolve('en', AiCoachChatCopy.navigationFailed),
      ),
      findsOneWidget,
    );
    final retry = find.byKey(
      const Key('ai-coach-action-retry-openPlan-open-plan'),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pump();

    expect(attempts, 2);
    expect(openedPaths, <String>['/plan?origin=dashboard']);
    expect(retry, findsNothing);
    expect(
      find.text(
        AiCoachChatCopy.resolve('en', AiCoachChatCopy.navigationFailed),
      ),
      findsNothing,
    );
  });

  testWidgets('open it reuses the latest trusted read-only action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final action = IntelligenceMessageAction.fromAction(
      const IntelligenceAction(
        id: 'open-plan-follow-up',
        type: IntelligenceActionType.openPlan,
        label: 'Open plan',
        requiresConfirmation: false,
      ),
    )!;
    await PreferencesRepository(database).set(
      'intelligenceConversationV1',
      jsonEncode(<Object?>[
        IntelligenceMessage(
          id: 'coach-plan-follow-up',
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.action,
          text: 'Your draft is ready to review.',
          createdAt: DateTime.utc(2026, 9, 8),
          actionLinks: <IntelligenceMessageAction>[action],
        ).toJson(),
      ]),
    );
    final openedPaths = <String>[];
    await tester.pumpWidget(
      _coachApp(
        database: database,
        navigation: (context, path, push) async {
          openedPaths.add(path);
        },
      ),
    );
    await tester.pumpAndSettle();

    await _send(tester, 'Open it.');
    for (var attempt = 0; attempt < 40 && openedPaths.isEmpty; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(openedPaths, <String>['/plan?origin=dashboard']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic weight-history request opens the real history route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final openedPaths = <String>[];
    await tester.pumpWidget(
      _coachApp(
        database: database,
        navigation: (context, path, push) async {
          openedPaths.add(path);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-coach-question-field')),
      'استعرض سجل أوزاني',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-coach-send-button')));
    for (var attempt = 0; attempt < 80 && openedPaths.isEmpty; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(openedPaths, <String>['/weight-history']);
    expect(
      find.text(AiCoachChatCopy.resolve('ar', AiCoachChatCopy.navigationReady)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _coachApp({
  required AppDatabase database,
  required IntelligenceCenterNavigationExecutor navigation,
  LocalModelGateway? gateway,
}) {
  final router = GoRouter(
    initialLocation: '/intelligence-center',
    routes: <RouteBase>[
      GoRoute(
        path: '/intelligence-center',
        builder: (_, _) => const IntelligenceCenterPage(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      intelligenceCenterNavigationExecutorProvider.overrideWithValue(
        navigation,
      ),
      if (gateway != null)
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
      coachContextSnapshotProvider.overrideWith(
        (ref) async => CoachContextSnapshot.empty(),
      ),
      intelligenceHealthContextProvider.overrideWith(
        (ref) async => const IntelligenceHealthContext(
          primaryMessage: '',
          explanation: <String>[],
          confidence: 1,
          evidence: <String>[],
          missingData: <String>[],
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

Future<void> _send(WidgetTester tester, String value) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    value,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
}

Future<void> _pumpUntilCalls(
  WidgetTester tester,
  _RecordingLanguageGateway gateway,
  int count,
) async {
  for (
    var attempt = 0;
    attempt < 80 && gateway.locales.length < count;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(gateway.locales.length, count);
  await tester.pumpAndSettle();
}

class _RecordingLanguageGateway implements LocalModelGateway {
  final locales = <String>[];
  final detected = <bool>[];

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    locales.add(locale);
    detected.add(languageDetected);
    return const LocalModelResult.answer(
      LocalModelAnswer(text: 'Fixture answer.', action: null),
    );
  }
}
