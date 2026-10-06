import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final prompt in ['Log water 375 ml', 'سجل ٣٧٥ مل ماء']) {
    testWidgets('read only blocks deterministic water: $prompt', (
      tester,
    ) async {
      final fixture = await _mount(tester);
      await _sendAndSelect(tester, prompt, 'addWater-add-water-375');
      await _acceptIfVisible(tester);

      expect(
        await WaterRepository(fixture.database).totalForDay(DateTime.now()),
        0,
      );
      expect(fixture.gateway.calls, 0);
      expect(await fixture.committedReceipts(), isEmpty);
      expect(await fixture.verifiedEvidence(), isEmpty);
      await _dispose(tester);
    });
  }

  testWidgets(
    'read only preserves a recorded weight on the local parser path',
    (tester) async {
      final fixture = await _mount(tester);
      final weights = WeightRepository(fixture.database);
      await weights.addWeight(90, date: DateTime.now());
      final before = (await weights.getAll()).single;
      await _sendAndSelect(
        tester,
        'Log weight 82.4 kg',
        'addWeight-add-weight-82.4',
      );
      await _acceptIfVisible(tester);

      final after = (await weights.getAll()).single;
      expect(after.id, before.id);
      expect(after.weight, before.weight);
      expect(after.revision, before.revision);
      expect(fixture.gateway.calls, 0);
      expect(await fixture.committedReceipts(), isEmpty);
      await _dispose(tester);
    },
  );

  for (final command in [
    ('Switch to dark mode', 'setThemeMode-set-theme-dark'),
    ('Change language to Arabic', 'setLanguage-set-language-ar'),
  ]) {
    testWidgets('read only blocks local settings: ${command.$1}', (
      tester,
    ) async {
      final fixture = await _mount(tester);
      final before = fixture.settings.value;
      final container = _container(tester);
      final beforeMode = container.read(appSettingsProvider).themeMode;
      final beforeLocale = container.read(appSettingsProvider).localeCode;
      await _sendAndSelect(tester, command.$1, command.$2);
      await _acceptIfVisible(tester);

      expect(fixture.settings.value, before);
      expect(container.read(appSettingsProvider).themeMode, beforeMode);
      expect(container.read(appSettingsProvider).localeCode, beforeLocale);
      expect(fixture.gateway.calls, 0);
      expect(await fixture.committedReceipts(), isEmpty);
      await _dispose(tester);
    });
  }

  testWidgets('permission is checked again after actual confirmation', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      mode: CoachActionPermissionMode.askBeforeWrite,
      tools: [
        {
          'name': 'log_water',
          'arguments': {'amountMl': 250},
        },
      ],
    );
    await _sendAndSelect(
      tester,
      'Proceed with prepared BIL operation',
      'addWater-log_water',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    _container(tester).read(coachActionPermissionModeProvider.notifier).state =
        CoachActionPermissionMode.readOnly;
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(
      await WaterRepository(fixture.database).totalForDay(DateTime.now()),
      0,
    );
    expect(await fixture.committedReceipts(), isEmpty);
    expect(fixture.gateway.calls, 1);
    await _dispose(tester);
  });

  for (final id in ['navigate', 'unknown_native_write']) {
    testWidgets('restored goal cannot borrow permission from $id', (
      tester,
    ) async {
      final fixture = await _mount(tester, restoredGoalId: id);
      final chip = find.byKey(Key('ai-coach-action-updateGoal-$id'));
      if (chip.evaluate().isNotEmpty) {
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        await _acceptIfVisible(tester);
      }

      final profile = await UserProfileRepository(
        fixture.database,
      ).getProfile();
      expect(profile!.targetWeight, 82);
      expect(profile.revision, 1);
      expect(await GoalRepository(fixture.database).getActive(), isNull);
      expect(await fixture.committedReceipts(), isEmpty);
      expect(
        find.text('Keep this proposed goal in the transcript.'),
        findsOneWidget,
      );
      expect(fixture.gateway.calls, 0);
      await _dispose(tester);
    });
  }

  testWidgets('typed confirmation recognizes the actual local goal proposal', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      mode: CoachActionPermissionMode.askBeforeWrite,
    );
    await fixture.seedProfile();
    await _sendAndSelect(
      tester,
      'Set my target weight to 79 kg',
      'updateGoal-update-goal-79.0',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ai-coach-action-updateGoal-update-goal-79.0')),
      findsOneWidget,
    );
    await _send(tester, 'confirm');
    await tester.pumpAndSettle();

    expect(
      (await UserProfileRepository(
        fixture.database,
      ).getProfile())!.targetWeight,
      79,
    );
    expect(
      (await GoalRepository(fixture.database).getActive())!.targetWeight,
      79,
    );
    expect(
      fixture.gateway.calls,
      0,
      reason: 'The exact pending decision is local.',
    );
    expect(await fixture.committedReceipts(), hasLength(1));
    await _dispose(tester);
  });

  testWidgets(
    'canonical identity governs an opaque UI ID and a denied proposal can retry',
    (tester) async {
      final fixture = await _mount(
        tester,
        restoredGoalId: 'navigate',
        restoredToolId: 'update_goal',
      );
      final chip = find.byKey(const Key('ai-coach-action-updateGoal-navigate'));
      expect(chip, findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(
        (await UserProfileRepository(
          fixture.database,
        ).getProfile())!.targetWeight,
        82,
      );
      expect(await fixture.verifiedEvidence(), isEmpty);
      expect(
        (await fixture.goalProposals()).single['operationId'],
        'saved-goal-operation',
      );

      _container(
            tester,
          ).read(coachActionPermissionModeProvider.notifier).state =
          CoachActionPermissionMode.askBeforeWrite;
      await tester.pump();
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await _acceptIfVisible(tester);
      expect(
        (await UserProfileRepository(
          fixture.database,
        ).getProfile())!.targetWeight,
        79,
      );
      expect(
        (await fixture.committedReceipts()).single['operation_id'],
        'saved-goal-operation',
      );
      expect(await fixture.goalProposals(), isEmpty);
      expect(fixture.gateway.calls, 0);
      await _dispose(tester);
    },
  );

  testWidgets(
    'equal explicit water requests keep distinct canonical operation receipts',
    (tester) async {
      final fixture = await _mount(
        tester,
        mode: CoachActionPermissionMode.askBeforeWrite,
        tools: [
          {
            'name': 'log_water',
            'arguments': {'amountMl': 250},
          },
          {
            'name': 'log_water',
            'arguments': {'amountMl': 250},
          },
        ],
      );
      for (var index = 0; index < 2; index++) {
        await _sendAndSelect(
          tester,
          'Proceed with prepared BIL operation $index',
          'addWater-log_water',
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        await _acceptIfVisible(tester);
      }
      final receipts = await fixture.committedReceipts();
      expect(
        await WaterRepository(fixture.database).totalForDay(DateTime.now()),
        500,
      );
      expect(receipts, hasLength(2));
      expect(receipts.map((value) => value['action_id']).toSet(), {
        'log_water',
      });
      expect(receipts.map((value) => value['tool_id']).toSet(), {'log_water'});
      final operations = receipts.map((value) => value['operation_id']).toSet();
      expect(operations, hasLength(2));
      expect(
        operations,
        everyElement(isA<String>().having((id) => id.length, 'length', 36)),
      );

      await _dispose(tester);
      await _mount(tester, existing: fixture);
      expect(await fixture.committedReceipts(), receipts);
      expect(
        await WaterRepository(fixture.database).totalForDay(DateTime.now()),
        500,
      );
      expect(
        fixture.gateway.calls,
        2,
        reason: 'Reading receipt history must not replay a write.',
      );
      await _dispose(tester);
    },
  );

  testWidgets(
    'goal completion retires one operation while preserving an equal-key proposal',
    (tester) async {
      final fixture = await _mount(
        tester,
        mode: CoachActionPermissionMode.askBeforeWrite,
        tools: [
          {
            'name': 'update_goal',
            'arguments': {'targetWeightKg': 79},
          },
          {
            'name': 'update_goal',
            'arguments': {'targetWeightKg': 79},
          },
        ],
      );
      await fixture.seedProfile();
      for (var index = 0; index < 2; index++) {
        await _sendAndSelect(
          tester,
          'Proceed with prepared BIL operation $index',
          'updateGoal-update_goal',
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
      }
      final before = await fixture.goalProposals();
      expect(before, hasLength(2));
      expect(before.map((action) => action['id']).toSet(), {'update_goal'});
      expect(
        before.map((action) => action['operationId']).toSet(),
        hasLength(2),
      );
      await _send(tester, 'confirm');
      await tester.pumpAndSettle();
      final after = await fixture.goalProposals();
      final receipts = await fixture.committedReceipts();
      expect(after, hasLength(1));
      expect(after.single['operationId'], before.first['operationId']);
      expect(receipts, hasLength(1));
      expect(receipts.single['operation_id'], before.last['operationId']);
      expect(receipts.single['tool_id'], 'update_goal');
      expect(
        (await UserProfileRepository(fixture.database).getProfile())!.revision,
        2,
      );

      await _dispose(tester);
      await _mount(tester, existing: fixture);
      expect(
        (await fixture.goalProposals()).single['operationId'],
        before.first['operationId'],
      );
      expect(await fixture.committedReceipts(), receipts);
      expect(fixture.gateway.calls, 2);
      await _dispose(tester);
    },
  );
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(IntelligenceCenterPage)),
);

Future<_Fixture> _mount(
  WidgetTester tester, {
  CoachActionPermissionMode mode = CoachActionPermissionMode.readOnly,
  List<Map<String, Object?>> tools = const [],
  String? restoredGoalId,
  String? restoredToolId,
  _Fixture? existing,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fixture = existing ?? _Fixture(tools);
  if (existing == null) addTearDown(fixture.database.close);
  if (restoredGoalId != null) {
    await fixture.seedProfile();
    await PreferencesRepository(fixture.database).set(
      'intelligenceConversationV1',
      jsonEncode([
        {
          'id': 'restored-goal-message',
          'role': 'bil',
          'kind': 'action',
          'text': 'Keep this proposed goal in the transcript.',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'actionLinks': [
            {
              'id': restoredGoalId,
              'toolId': ?restoredToolId,
              if (restoredToolId != null) 'operationId': 'saved-goal-operation',
              'label': 'Set target to 79 kg',
              'type': 'updateGoal',
              'payload': {'targetWeightKg': 79},
              'requiresConfirmation': true,
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            },
          ],
        },
      ]),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        appSettingsServiceProvider.overrideWithValue(
          AppSettingsService(store: fixture.settings),
        ),
        intelligenceCenterModelGatewayProvider.overrideWithValue(
          fixture.gateway,
        ),
        coachActionPermissionModeProvider.overrideWith((ref) => mode),
        coachContextSnapshotProvider.overrideWith(
          (ref) async => CoachContextSnapshot.empty(),
        ),
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
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: IntelligenceCenterPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _send(WidgetTester tester, String prompt) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(IntelligenceCenterPage)),
  ).clearSnackBars();
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    prompt,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _sendAndSelect(
  WidgetTester tester,
  String prompt,
  String suffix,
) async {
  await _send(tester, prompt);
  final action = find.byKey(Key('ai-coach-action-sheet-$suffix'));
  for (var attempt = 0; attempt < 80 && action.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(action, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pump(const Duration(milliseconds: 350));
  expect(action.hitTestable(), findsOneWidget);
  await tester.tap(action);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _acceptIfVisible(WidgetTester tester) async {
  final confirmation = find.widgetWithText(FilledButton, 'Continue');
  if (confirmation.evaluate().isNotEmpty) {
    await tester.tap(confirmation);
  }
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(Duration.zero);
}

class _Fixture {
  _Fixture(List<Map<String, Object?>> tools) : gateway = _Gateway(tools);

  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = _Settings();
  final _Gateway gateway;

  Future<void> seedProfile() => UserProfileRepository(database).save(
    gender: 'male',
    age: 35,
    height: 180,
    currentWeight: 88,
    targetWeight: 82,
    activityLevel: 'moderate',
    exercises: true,
  );

  Future<List<Map<String, Object?>>> committedReceipts() async {
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    if (raw == null) return [];
    final result = <Map<String, Object?>>[];
    for (final message in (jsonDecode(raw) as List).whereType<Map>()) {
      final evidence = message['evidence'];
      if (evidence is! List) continue;
      for (final item in evidence.whereType<String>()) {
        if (!item.startsWith('{')) continue;
        final receipt = jsonDecode(item);
        if (receipt is Map && receipt['committed'] == true) {
          result.add(Map<String, Object?>.from(receipt));
        }
      }
    }
    return result;
  }

  Future<List<Map<String, Object?>>> goalProposals() async {
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    if (raw == null) return [];
    return [
      for (final message in (jsonDecode(raw) as List).whereType<Map>())
        if (message['actionLinks'] is List)
          for (final action
              in (message['actionLinks'] as List).whereType<Map>())
            if (action['type'] == 'updateGoal')
              Map<String, Object?>.from(action),
    ];
  }

  Future<List<Object?>> verifiedEvidence() async {
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    if (raw == null) return [];
    return [
      for (final message in (jsonDecode(raw) as List).whereType<Map>())
        if (message['evidence'] is List)
          for (final evidence in message['evidence'] as List)
            if (evidence == 'BIL verified tool result') evidence,
    ];
  }
}

class _Gateway implements LocalModelGateway {
  _Gateway(this.tools);
  final List<Map<String, Object?>> tools;
  int calls = 0;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    final index = calls++;
    if (index >= tools.length) {
      return const LocalModelResult.answer(
        LocalModelAnswer(
          text: 'No prepared action is available.',
          action: null,
        ),
      );
    }
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: 'The action is ready for review.',
        action: tools[index],
      ),
    );
  }
}

class _Settings implements SettingsStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }
}
