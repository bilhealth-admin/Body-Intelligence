import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_recipe_editor.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:body_intelligence_log/features/recipe_import/presentation/recipe_draft_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget form({
  TrustedRecipeDraft? initial,
  required Future<void> Function(TrustedRecipeDraft) onReview,
  Locale locale = const Locale('ar'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: RecipeDraftForm(initial: initial, onReview: onReview),
  ),
);

void main() {
  test(
    'recipe editor translations cover all 25 released locales and all columns',
    () {
      expect(RecipeEditorRuntimeCopy.translations, hasLength(25));
      for (final row in RecipeEditorRuntimeCopy.translations.entries) {
        expect(
          row.value.length,
          RecipeEditorRuntimeCopy.keys.length,
          reason: row.key,
        );
      }
      for (final locale in AppLocalizations.supportedLocales) {
        final copy = AppLocalizations(locale);
        for (final key in [
          ...RecipeEditorRuntimeCopy.keys,
          'Name',
          'Servings',
          'Ingredients',
          'Quantity',
          'Remove',
          'Add',
          'Method',
          'Save',
          'Edit',
          'Source',
        ]) {
          expect(copy.text(key), isNotEmpty, reason: '$locale: $key');
        }
      }
    },
  );

  testWidgets('normal recipe form accepts Arabic digits without a JSON field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TrustedRecipeDraft? reviewed;
    await tester.pumpWidget(form(onReview: (draft) async => reviewed = draft));
    await tester.pumpAndSettle();
    expect(find.textContaining('JSON'), findsNothing);
    for (final entry in {
      'recipe-name': 'شوربة',
      'recipe-servings': '٢',
      'recipe-prep': '١٠',
      'recipe-cook': '٢٠',
      'recipe-ingredient-name-0': 'عدس',
      'recipe-ingredient-quantity-0': '١٢٥٫٥',
      'recipe-method': 'اغسل العدس.\nاطهه جيدًا.',
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.ensureVisible(find.byKey(const Key('review-imported-recipe')));
    await tester.tap(find.byKey(const Key('review-imported-recipe')));
    await tester.pumpAndSettle();
    expect(reviewed?.name, 'شوربة');
    expect(reviewed?.servings, 2);
    expect(reviewed?.totalMinutes, 30);
    expect(reviewed?.ingredients.single.quantity, 125.5);
    expect(reviewed?.nutrition, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final change in [false, true]) {
    testWidgets(
      'editing ingredient quantity drops stale nutrition: changed=$change',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final draft = TrustedRecipeDraft(
          name: 'Bowl',
          servings: 2,
          prepMinutes: 1,
          cookMinutes: 2,
          ingredients: const [
            TrustedRecipeIngredient(
              name: 'Lentils',
              quantity: 200,
              unit: 'g',
              sourceRecordId: 'usda:123',
            ),
          ],
          steps: const ['Cook.'],
          sourceUrl: null,
          nutrition: TrustedRecipeNutrition(
            caloriesKcal: 200,
            proteinG: 10,
            carbohydrateG: 30,
            fatG: 2,
            provenance: RecipeNutritionProvenance(
              source: 'USDA',
              recordId: 'fdc-123',
              verifiedAt: DateTime(2026, 9, 1),
            ),
          ),
        );
        TrustedRecipeDraft? reviewed;
        await tester.pumpWidget(
          form(initial: draft, onReview: (value) async => reviewed = value),
        );
        await tester.pumpAndSettle();
        if (change) {
          await tester.enterText(
            find.byKey(const Key('recipe-ingredient-quantity-0')),
            '250',
          );
        }
        await tester.ensureVisible(
          find.byKey(const Key('review-imported-recipe')),
        );
        await tester.tap(find.byKey(const Key('review-imported-recipe')));
        await tester.pumpAndSettle();
        expect(reviewed, isNotNull);
        expect(reviewed!.nutrition?.caloriesKcal, change ? isNull : 200);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'passive daily activity is coalesced and never prompts or imports full history',
    () async {
      final gateway = _DailyGateway();
      final controller = ConnectedHealthController(gateway);
      addTearDown(controller.dispose);
      final first = controller.refreshDailyActivity();
      final second = controller.refreshDailyActivity();
      expect(gateway.dailyReads, 1);
      expect(controller.state.value!.isBusy, isTrue);
      gateway.pending.complete(const ConnectedHealthSnapshot.unavailable());
      await Future.wait([first, second]);
      await controller.refreshDailyActivity();
      expect(gateway.dailyReads, 1);
      gateway.pending = Completer();
      final forced = controller.refreshDailyActivity(force: true);
      expect(gateway.dailyReads, 2);
      gateway.pending.complete(const ConnectedHealthSnapshot.unavailable());
      await forced;
      expect(gateway.otherCalls, 0);
      expect(controller.state.value!.isBusy, isFalse);
    },
  );
}

class _DailyGateway
    implements ConnectedHealthGateway, ConnectedHealthDailyActivityGateway {
  int dailyReads = 0;
  int otherCalls = 0;
  Completer<ConnectedHealthSnapshot> pending = Completer();
  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() {
    dailyReads++;
    return pending.future;
  }

  Future<ConnectedHealthSnapshot> other() async {
    otherCalls++;
    return const ConnectedHealthSnapshot.unavailable();
  }

  @override
  Future<ConnectedHealthSnapshot> load() => other();
  @override
  Future<ConnectedHealthSnapshot> synchronize() => other();
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() => other();
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() => other();
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => other();
  @override
  Future<void> openSystemSettings() async {
    otherCalls++;
  }
}
