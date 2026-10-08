import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/services/app_settings_provider.dart';
import 'package:body_intelligence_log/app/services/app_settings_service.dart';
import 'package:body_intelligence_log/app/services/settings_store.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_permission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/food_flow/coach_food_catalog_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_receipt_card.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_review_card.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'multi-food text opens review, commits only on confirm, restores verified receipt',
    (tester) async {
      await _withFoodCoach(tester, (h) async {
        await h.seedFood(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        await h.seedFood(
          'Chicken',
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3.6,
          sodium: 74,
          potassium: 256,
        );

        await _send(tester, 'اكلت 100غ Rice و 200غ Chicken غداء اليوم');
        await _pumpUntil(
          tester,
          () => find.byType(CoachFoodReviewCard).evaluate().isNotEmpty,
        );
        expect(find.byType(CoachFoodReviewCard), findsOneWidget);
        expect(await h.database.select(h.database.meals).get(), isEmpty);
        expect(await h.database.select(h.database.mealItems).get(), isEmpty);
        expect(await h.foodReceipts(), isEmpty);
        expect(h.gateway.calls, 0);

        final review = tester.widget<CoachFoodReviewCard>(
          find.byType(CoachFoodReviewCard),
        );
        expect(review.review.items, hasLength(2));
        expect(review.mealType, 'lunch');
        expect(review.day, DateTime(2026, 10, 7));
        final operationId = review.operationId;
        final confirm = find.byKey(CoachFoodCardKeys.confirm(operationId));
        expect(confirm, findsOneWidget);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

        await tester.ensureVisible(confirm);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(confirm);
        // Coach may keep a milestone spinner animating. Await its verified
        // receipt below, not pumpAndSettle's unrelated animation quiescence.
        await tester.pump(const Duration(milliseconds: 200));
        await _waitForFoodReceipts(tester, h, 1);

        final items = await h.database.select(h.database.mealItems).get();
        final meals = await h.database.select(h.database.meals).get();
        expect(items, hasLength(2));
        expect(meals, hasLength(1));
        expect(meals.single.type, 'lunch');
        expect(meals.single.dayKey, '2026-10-07');
        expect(find.byType(CoachFoodReceiptCard), findsOneWidget);
        expect(
          find.byKey(CoachFoodCardKeys.receipt(operationId)),
          findsOneWidget,
        );
        final receipt = (await h.foodReceipts()).single;
        expect(receipt['tool_id'], 'log_foods');
        expect(receipt['operation_id'], operationId);
        expect(receipt['verified'], true);
        expect(receipt['entity_type'], 'meal');
        expect(
          Set<String>.from(
            (receipt['refresh_targets'] as List).whereType<String>(),
          ),
          containsAll(<String>[
            'dailyMeals',
            'dailyLedger',
            'dashboard',
            'coachContext',
          ]),
        );
        expect(((receipt['after'] as Map)['items'] as List), hasLength(2));
        expect(h.gateway.calls, 0);

        // Conversation restore must render the repository-bound receipt and
        // never re-run the write.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(Duration.zero);
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();
        expect(
          await h.database.select(h.database.mealItems).get(),
          hasLength(2),
        );
        expect((await h.foodReceipts()).single['operation_id'], operationId);
        expect(find.byType(CoachFoodReceiptCard), findsOneWidget);
        expect(
          find.byKey(CoachFoodCardKeys.receipt(operationId)),
          findsOneWidget,
        );
        expect(h.gateway.calls, 0);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('permission revoked after review blocks log_foods persistence', (
    tester,
  ) async {
    await _withFoodCoach(tester, (h) async {
      await h.seedFood('Rice', calories: 130, protein: 2.5, carbs: 28, fat: .3);
      await _send(tester, 'اكلت 100غ Rice غداء اليوم');
      await _pumpUntil(
        tester,
        () => find.byType(CoachFoodReviewCard).evaluate().isNotEmpty,
      );
      final review = tester.widget<CoachFoodReviewCard>(
        find.byType(CoachFoodReviewCard),
      );
      final operationId = review.operationId;
      h.container.read(coachActionPermissionModeProvider.notifier).state =
          CoachActionPermissionMode.readOnly;
      await tester.pump();
      final confirm = find.byKey(CoachFoodCardKeys.confirm(operationId));
      await tester.ensureVisible(confirm);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 200));

      expect(await h.database.select(h.database.mealItems).get(), isEmpty);
      expect(await h.database.select(h.database.meals).get(), isEmpty);
      expect(await h.foodReceipts(), isEmpty);
      expect(find.byType(CoachFoodReceiptCard), findsNothing);
      expect(h.gateway.calls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('prepared food review is permanently cancelled by owner A B A', (
    tester,
  ) async {
    final changes = StreamController<String?>.broadcast(sync: true);
    addTearDown(changes.close);
    String? owner = 'food-widget-owner';
    await _withFoodCoach(
      tester,
      (h) async {
        await h.seedFood(
          'Rice',
          calories: 130,
          protein: 2.5,
          carbs: 28,
          fat: .3,
        );
        await _send(tester, 'اكلت 100غ Rice غداء اليوم');
        await _pumpUntil(
          tester,
          () => find.byType(CoachFoodReviewCard).evaluate().isNotEmpty,
        );
        final review = tester.widget<CoachFoodReviewCard>(
          find.byType(CoachFoodReviewCard),
        );
        final operationId = review.operationId;
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(CoachFoodCardKeys.confirm(operationId)),
              )
              .onPressed,
          isNotNull,
        );

        owner = 'owner-b';
        changes.add(owner);
        await tester.pump();
        owner = 'food-widget-owner';
        changes.add(owner);
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.byKey(CoachFoodCardKeys.confirm(operationId)),
          findsNothing,
        );
        expect(await h.database.select(h.database.mealItems).get(), isEmpty);
        expect(await h.database.select(h.database.meals).get(), isEmpty);
        expect(await h.foodReceipts(), isEmpty);
        expect(h.gateway.calls, 0);
        expect(tester.takeException(), isNull);
      },
      ownerWitness: CoachNativeOwnerWitness(
        readOwner: () => owner,
        changes: changes.stream,
      ),
    );
  });
}

final class _FoodWidgetHarness {
  _FoodWidgetHarness({CoachNativeOwnerWitness? ownerWitness}) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        appSettingsServiceProvider.overrideWithValue(
          AppSettingsService(store: _FoodSettings()),
        ),
        intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
        intelligenceConversationClockProvider.overrideWithValue(
          () => DateTime(2026, 10, 7, 13, 15),
        ),
        coachActionPermissionModeProvider.overrideWith(
          (ref) => CoachActionPermissionMode.askBeforeWrite,
        ),
        coachNativeOwnerWitnessProvider.overrideWithValue(ownerWitness),
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

  final database = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: 'food-widget-owner',
  );
  final gateway = _NoFoodGateway();
  late final ProviderContainer container;

  Widget app() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ar'),
      theme: ThemeData.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: const IntelligenceCenterPage(),
    ),
  );

  Future<void> seedFood(
    String name, {
    required double? calories,
    required double? protein,
    required double? carbs,
    required double? fat,
    double? sodium,
    double? potassium,
  }) async {
    final snapshot = CoachFoodSnapshot(
      identity: 'widget:${normalizeFoodConcept(name)}',
      name: name,
      preparedState: 'as-recorded',
      basisGrams: 100,
      nutrients: CoachFoodNutrients({
        FoodNutrient.calories: calories,
        FoodNutrient.protein: protein,
        FoodNutrient.carbohydrates: carbs,
        FoodNutrient.fat: fat,
        FoodNutrient.fiber: null,
        FoodNutrient.sugar: null,
        FoodNutrient.sodium: sodium,
        FoodNutrient.potassium: potassium,
        FoodNutrient.calcium: null,
        FoodNutrient.magnesium: null,
        FoodNutrient.phosphorus: null,
        FoodNutrient.iron: null,
        FoodNutrient.vitaminC: null,
      }),
      source: CoachFoodSourceEvidence(
        kind: CoachFoodSourceKind.label,
        ref: 'widget-label:$name',
        revision: 'widget-v1',
      ),
    );
    final foods = FoodRepository(database);
    final id = await foods.addFood(
      name: name,
      category: 'fixture',
      servingSize: 100,
      servingUnit: 'g',
      calories: calories ?? 0,
      protein: protein ?? 0,
      carbs: carbs ?? 0,
      fats: fat ?? 0,
      sodium: sodium,
      potassium: potassium,
      source: FoodBasisEvidence.sourceLabel(snapshot),
      verified: false,
      caloriesKnown: calories != null,
      proteinKnown: protein != null,
      carbsKnown: carbs != null,
      fatsKnown: fat != null,
    );
    await (database.update(
      database.foods,
    )..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        category: const Value('coach_snapshot'),
        servingSize: const Value(100),
        servingUnit: const Value('g'),
        calories: Value(calories ?? 0),
        protein: Value(protein ?? 0),
        carbs: Value(carbs ?? 0),
        fats: Value(fat ?? 0),
        sodium: Value(sodium ?? 0),
        potassium: Value(potassium ?? 0),
        source: Value(FoodBasisEvidence.sourceLabel(snapshot)),
        verified: const Value(false),
        nutrientEvidenceMask: Value(FoodBasisEvidence.mask(snapshot)),
        foodEvidenceJson: Value(FoodBasisEvidence.encode(snapshot)),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> foodReceipts() async {
    final raw = await PreferencesRepository(
      database,
    ).get('intelligenceConversationV1');
    if (raw == null) return const [];
    final receipts = <Map<String, dynamic>>[];
    for (final message in (jsonDecode(raw) as List).whereType<Map>()) {
      for (final evidence
          in (message['evidence'] as List? ?? const []).whereType<String>()) {
        if (!evidence.startsWith('{')) continue;
        final value = jsonDecode(evidence);
        if (value is Map<String, dynamic> &&
            value['source'] == 'ai_coach' &&
            const {
              'log_foods',
              'replace_meal_item',
            }.contains(value['tool_id'])) {
          receipts.add(value);
        }
      }
    }
    return receipts;
  }
}

Future<void> _withFoodCoach(
  WidgetTester tester,
  Future<void> Function(_FoodWidgetHarness harness) body, {
  CoachNativeOwnerWitness? ownerWitness,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  final harness = _FoodWidgetHarness(ownerWitness: ownerWitness);
  try {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await body(harness);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    harness.container.dispose();
    await tester.runAsync(harness.database.close);
    await tester.pump(Duration.zero);
    await tester.binding.setSurfaceSize(null);
  }
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const Key('ai-coach-question-field')),
    text,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pump();
  await tester.tap(find.byKey(const Key('ai-coach-send-button')));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var attempt = 0; attempt < 100 && !predicate(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(predicate(), isTrue);
}

Future<void> _waitForFoodReceipts(
  WidgetTester tester,
  _FoodWidgetHarness harness,
  int count,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if ((await harness.foodReceipts()).length >= count) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(await harness.foodReceipts(), hasLength(count));
}

final class _NoFoodGateway implements LocalModelGateway {
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
    throw StateError('The native Food host must not call a model provider');
  }
}

final class _FoodSettings implements SettingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
