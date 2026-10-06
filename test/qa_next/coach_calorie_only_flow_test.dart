import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
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

const _calorieAction = Key(
  'ai-coach-action-sheet-quickAddMacros-calorie-only-2026-10-01-lunch-1905',
);
const _receiptText = 'Calorie-only entry saved. Other nutrients are unknown.';

void main() {
  for (final prompt in [
    'Log 1905 calories for lunch on 2026-10-01 yesterday',
    'سجل ١٩٠٥ سعرة للغداء بتاريخ ٢٠٢٦-١٠-٠١ امس',
  ]) {
    testWidgets(
      'calorie text commits, restores and undoes native rows: $prompt',
      (tester) async {
        await _withCoach(tester, CoachActionPermissionMode.writeAllowed, (
          h,
        ) async {
          await _openEntry(tester, prompt);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(await h.database.select(h.database.mealItems).get(), isEmpty);
          expect(await h.receipts(), isEmpty);
          await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
          await tester.pumpAndSettle();
          await _waitForReceipts(tester, h, 1);
          expect(find.text(_receiptText), findsOneWidget);

          final saved = await h.database
              .select(h.database.mealItems)
              .getSingle();
          final meal = await h.database.select(h.database.meals).getSingle();
          expect(meal.date, DateTime(2026, 10, 1));
          expect(meal.type, 'lunch');
          final receipts = await h.receipts();
          expect(receipts, hasLength(1));
          final receipt = receipts.single;
          expect(receipt['tool_id'], 'quick_add_macros');
          expect(receipt['operation_id'], isA<String>());
          expect(receipt['entity_id'], saved.id.toString());
          final item =
              ((receipt['after'] as Map)['items'] as List).single as Map;
          expect(item['item_uuid'], saved.uuid);
          expect(item['revision'], saved.revision);
          expect(item['calories'], 1905);
          for (final nutrient in ['protein', 'carbohydrates', 'fat']) {
            expect(item[nutrient], isNull);
          }
          final ledger = await DailyLogRepository(
            h.database,
          ).readLedger(DateTime(2026, 10, 1));
          expect(ledger.calories, 1905);
          expect(ledger.protein, isNull);
          expect(ledger.carbohydrates, isNull);
          expect(ledger.fat, isNull);
          expect(h.gateway.calls, 0);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(Duration.zero);
          await tester.pumpWidget(h.app());
          await tester.pumpAndSettle();
          expect(await h.database.select(h.database.mealItems).get(), [saved]);
          expect(
            (await h.receipts()).single['operation_id'],
            receipt['operation_id'],
          );
          expect(find.text(_receiptText), findsOneWidget);
          final undo = find.widgetWithText(OutlinedButton, 'Undo');
          expect(undo, findsOneWidget);
          await tester.ensureVisible(undo);
          final button = tester.widget<OutlinedButton>(undo);
          button.onPressed!();
          button.onPressed!();
          await tester.pumpAndSettle();
          await _waitForReceipts(tester, h, 2);
          final compensated = await MealRepository(
            h.database,
          ).getMealItem(saved.id);
          expect(compensated.deletedAt, isNotNull);
          expect(compensated.revision, saved.revision + 1);
          final afterUndo = await h.receipts();
          expect(afterUndo, hasLength(2));
          expect(afterUndo.last['operation_id'], receipt['operation_id']);
          expect(afterUndo.last['undone_at'], isNotNull);
          expect(h.gateway.calls, 0);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets('cancelled calorie-only review creates no row or receipt', (
    tester,
  ) async {
    await _withCoach(tester, CoachActionPermissionMode.askBeforeWrite, (
      h,
    ) async {
      await _openEntry(tester, 'Log 1905 calories for lunch on 2026-10-01');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await h.database.select(h.database.mealItems).get(), isEmpty);
      expect(await h.database.select(h.database.meals).get(), isEmpty);
      expect(await h.receipts(), isEmpty);
      expect(find.text(_receiptText), findsNothing);
      expect(h.gateway.calls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('read-only mode blocks a natural-language calorie entry', (
    tester,
  ) async {
    await _withCoach(tester, CoachActionPermissionMode.readOnly, (h) async {
      await _openEntry(tester, 'Log 1905 calories for lunch on 2026-10-01');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await h.database.select(h.database.mealItems).get(), isEmpty);
      expect(await h.receipts(), isEmpty);
      expect(find.text(_receiptText), findsNothing);
      expect(h.gateway.calls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('permission revoked during calorie review blocks persistence', (
    tester,
  ) async {
    await _withCoach(tester, CoachActionPermissionMode.askBeforeWrite, (
      h,
    ) async {
      await _openEntry(tester, 'Log 1905 calories for lunch on 2026-10-01');
      expect(find.byType(AlertDialog), findsOneWidget);
      h.container.read(coachActionPermissionModeProvider.notifier).state =
          CoachActionPermissionMode.readOnly;
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(await h.database.select(h.database.mealItems).get(), isEmpty);
      expect(await h.receipts(), isEmpty);
      expect(find.text(_receiptText), findsNothing);
      expect(h.gateway.calls, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

class _CalorieHarness {
  _CalorieHarness(CoachActionPermissionMode mode) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        appSettingsServiceProvider.overrideWithValue(
          AppSettingsService(store: _CalorieSettings()),
        ),
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
        coachActionPermissionModeProvider.overrideWith((ref) => mode),
        coachNativeOwnerWitnessProvider.overrideWithValue(null),
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
    );
  }

  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final gateway = _NoCalorieGateway();
  late final ProviderContainer container;

  Widget app() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      theme: ThemeData.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: const IntelligenceCenterPage(),
    ),
  );

  Future<List<Map<String, dynamic>>> receipts() async {
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    if (raw == null) return [];
    final result = <Map<String, dynamic>>[];
    for (final message in (jsonDecode(raw) as List).whereType<Map>()) {
      for (final evidence
          in (message['evidence'] as List? ?? []).whereType<String>()) {
        if (!evidence.startsWith('{')) continue;
        final data = jsonDecode(evidence);
        if (data is Map<String, dynamic> &&
            data['entity_type'] == 'meal_item') {
          result.add(data);
        }
      }
    }
    return result;
  }
}

Future<void> _withCoach(
  WidgetTester tester,
  CoachActionPermissionMode mode,
  Future<void> Function(_CalorieHarness) body,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  final h = _CalorieHarness(mode);
  try {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await body(h);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    h.container.dispose();
    await tester.runAsync(h.database.close);
    await tester.pump(Duration.zero);
    await tester.binding.setSurfaceSize(null);
  }
}

Future<void> _openEntry(WidgetTester tester, String prompt) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    prompt,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  final action = find.byKey(_calorieAction);
  for (var attempt = 0; attempt < 80 && action.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(action, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _waitForReceipts(
  WidgetTester tester,
  _CalorieHarness harness,
  int count,
) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    if ((await harness.receipts()).length >= count) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(await harness.receipts(), hasLength(count));
}

class _NoCalorieGateway implements LocalModelGateway {
  int calls = 0;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    calls++;
    throw StateError('The native calorie entry must not call a provider');
  }
}

class _CalorieSettings implements SettingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
