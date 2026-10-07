import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
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

void main() {
  for (final unit in ['entry', 'ml', 'serving', 'item']) {
    testWidgets(
      'Coach gram correction never interprets a saved $unit as grams',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final meals = MealRepository(database);
        final day = DateTime(2026, 9, 5);
        if (unit == 'entry') {
          await meals.addQuickMacroEntry(
            date: day,
            mealType: 'lunch',
            calories: 1905,
            protein: 0,
            carbohydrates: 0,
            fat: 0,
            caloriesKnown: true,
            proteinKnown: false,
            carbohydratesKnown: false,
            fatKnown: false,
          );
        } else {
          final foodId = await FoodRepository(database).addFood(
            name: 'Label quantity fixture $unit',
            category: 'test',
            servingSize: 1,
            servingUnit: unit,
            calories: 50,
            protein: 2,
            carbs: 3,
            fats: 1,
            source: 'label',
          );
          final mealId = await meals.createMeal(
            date: day,
            name: 'lunch',
            type: 'lunch',
          );
          await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 2);
        }
        final before = await database.select(database.mealItems).getSingle();
        expect(before.servingUnitSnapshot, unit);
        final ledgerBefore = await DailyLogRepository(database).readLedger(day);
        final gateway = _QuantityGateway(before.id);
        try {
          await tester.pumpWidget(
            _coachApp(database: database, gateway: gateway),
          );
          await tester.pumpAndSettle();
          await _submitGramCorrection(tester);
          await tester.pumpAndSettle();
          expect(await meals.getMealItem(before.id), before);
          final ledgerAfter = await DailyLogRepository(
            database,
          ).readLedger(day);
          expect(ledgerAfter.calories, ledgerBefore.calories);
          expect(ledgerAfter.protein, ledgerBefore.protein);
          expect(ledgerAfter.carbohydrates, ledgerBefore.carbohydrates);
          expect(ledgerAfter.fat, ledgerBefore.fat);
          expect(
            await _structuredMealReceipts(PreferencesRepository(database)),
            isEmpty,
          );
          expect(find.widgetWithText(OutlinedButton, 'Undo'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(Duration.zero);
        }
      },
    );
  }
}

Widget _coachApp({
  required AppDatabase database,
  required LocalModelGateway gateway,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    appSettingsServiceProvider.overrideWithValue(
      AppSettingsService(store: _QuantitySettings()),
    ),
    intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
    coachActionPermissionModeProvider.overrideWith(
      (ref) => CoachActionPermissionMode.askBeforeWrite,
    ),
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
);

Future<void> _submitGramCorrection(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    'Review the prepared BIL correction',
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
  final action = find.byKey(
    const Key('ai-coach-action-sheet-updateMealItem-update_meal_item'),
  );
  for (var attempt = 0; attempt < 80 && action.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(action, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

Future<List<Map<String, dynamic>>> _structuredMealReceipts(
  PreferencesRepository preferences,
) async {
  final raw = await preferences.get('intelligenceConversationV1');
  if (raw == null) return [];
  final result = <Map<String, dynamic>>[];
  for (final message in (jsonDecode(raw) as List).whereType<Map>()) {
    for (final evidence
        in (message['evidence'] as List? ?? []).whereType<String>()) {
      if (!evidence.startsWith('{')) continue;
      final data = jsonDecode(evidence);
      if (data is Map<String, dynamic> && data['entity_type'] == 'meal_item') {
        result.add(data);
      }
    }
  }
  return result;
}

class _QuantityGateway implements LocalModelGateway {
  _QuantityGateway(this.itemId);
  final int itemId;
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async => LocalModelResult.answer(
    LocalModelAnswer(
      text: 'The correction is ready for review.',
      action: {
        'name': 'update_meal_item',
        'arguments': {'itemId': itemId, 'quantityGrams': 80},
      },
    ),
  );
}

class _QuantitySettings implements SettingsStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async => value = next;
}
