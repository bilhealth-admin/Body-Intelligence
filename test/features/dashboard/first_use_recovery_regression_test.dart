import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/shared/widgets/first_use_target_guide.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'first_use_reference_journey_test.dart' show journeyApp, journeyRouter;

Future<int> seed(AppDatabase db) => FoodRepository(db).addFood(
  name: 'TEST first food',
  category: 'beans',
  calories: 95,
  protein: 5.1,
  carbs: 11.9,
  fats: 3.4,
  servingSize: 100,
  servingUnit: 'g',
);

void expectSkipInsidePearl(
  WidgetTester tester,
  String guideKey,
  String skipKey,
) {
  final guide = find.byKey(Key(guideKey));
  expect(guide, findsOneWidget);
  final card = tester.getRect(guide);
  final skip = tester.getRect(find.byKey(Key(skipKey)));
  expect(card.contains(skip.topLeft), isTrue);
  expect(card.contains(skip.bottomRight - const Offset(.1, .1)), isTrue);
  expect(
    find.ancestor(of: guide, matching: find.byType(FirstUseGuidePlacement)),
    findsOneWidget,
  );
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final phase in ['menu', 'search', 'choose', 'quantity', 'save']) {
    testWidgets(
      '$phase Skip is inside pearl and preserves the real control without saving',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'reference-test',
        );
        addTearDown(db.close);
        final id = await seed(db);
        final router = journeyRouter();
        addTearDown(router.dispose);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        await tester.pumpWidget(journeyApp(db, router, 'ar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('shell-quick-add')));
        await tester.pumpAndSettle();
        if (phase == 'menu') {
          expectSkipInsidePearl(
            tester,
            'quick-add-food-guide',
            'quick-add-food-guide-skip',
          );
          await tester.tap(find.byKey(const Key('quick-add-food-guide-skip')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('quick-add-food-guide')), findsNothing);
          expect(find.byKey(const Key('quick-add-primary-0')), findsOneWidget);
          await tester.tap(find.byKey(const Key('quick-add-primary-0')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('food-log-search')), findsOneWidget);
          expect(find.byKey(const Key('food-log-search-guide')), findsNothing);
        } else {
          await tester.tap(find.byKey(const Key('quick-add-primary-0')));
          await tester.pumpAndSettle();
          if (phase != 'search') {
            await tester.enterText(
              find.byKey(const Key('food-log-search')),
              'TEST',
            );
            await tester.pumpAndSettle();
          }
          if (phase == 'quantity' || phase == 'save') {
            await tester.tap(find.byKey(Key('food-log-add-$id')));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('food-log-choose-guide')),
              findsNothing,
            );
            if (phase == 'save') {
              await tester.enterText(
                find.byKey(const Key('food-log-serving-quantity-field')),
                '80',
              );
              await tester.pumpAndSettle();
            }
          }
          final guide = 'food-log-$phase-guide';
          final skip = '$guide-skip';
          expectSkipInsidePearl(tester, guide, skip);
          await tester.tap(find.byKey(Key(skip)));
          await tester.pumpAndSettle();
          expect(find.byKey(Key(guide)), findsNothing);
          final control = (phase == 'quantity' || phase == 'save')
              ? 'food-log-serving-quantity-field'
              : 'food-log-search';
          expect(find.byKey(Key(control)), findsOneWidget);
          if (phase == 'quantity' || phase == 'save') {
            await tester.enterText(find.byKey(Key(control)), '90');
            expect(find.text('90'), findsOneWidget);
            await tester.tap(find.text('إلغاء').last);
            await tester.pumpAndSettle();
          }
        }
        expect(await MealRepository(db).watchAll().first, isEmpty);
        expect(
          await PreferencesRepository(
            db,
          ).get(firstMealCelebrationPreferenceKey),
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 20));
      },
    );
  }
  for (final language in ['fr', 'es', 'tr']) {
    testWidgets(
      '$language starter CTA opens the actual optional Log Food menu',
      (tester) async {
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'reference-test',
        );
        addTearDown(db.close);
        final router = journeyRouter();
        addTearDown(router.dispose);
        await tester.pumpWidget(journeyApp(db, router, language));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('shell-quick-add')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('quick-add-primary-0')), findsOneWidget);
        expectSkipInsidePearl(
          tester,
          'quick-add-food-guide',
          'quick-add-food-guide-skip',
        );
        expect(
          find.text(
            language == 'fr'
                ? 'Enregistrez votre aliment'
                : language == 'es'
                ? 'Registra tu comida'
                : 'Yemeğini kaydet',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('quick-add-food-guide-skip')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('quick-add-food-guide')), findsNothing);
        expect(await MealRepository(db).watchAll().first, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 20));
      },
    );
  }
  testWidgets(
    'failed real SQLite meal insert cannot celebrate or create partial food',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'reference-test',
      );
      addTearDown(db.close);
      final id = await seed(db);
      await db.customStatement(
        "CREATE TRIGGER reject_first_food BEFORE INSERT ON meal_items BEGIN SELECT RAISE(ABORT, 'intentional first-food rejection'); END",
      );
      final router = journeyRouter()..go('/daily-log?foodLog=1&guide=1');
      addTearDown(router.dispose);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      await tester.pumpWidget(journeyApp(db, router, 'en'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food-log-search')), 'TEST');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('food-log-add-$id')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('food-log-serving-quantity-field')),
        '80',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-log-serving-confirm')));
      await tester.pumpAndSettle();
      expect(await db.select(db.mealItems).get(), isEmpty);
      expect(await db.select(db.meals).get(), isEmpty);
      expect(
        await PreferencesRepository(db).get(firstMealCelebrationPreferenceKey),
        isNull,
      );
      expect(
        find.byKey(const Key('dashboard-first-food-celebration')),
        findsNothing,
      );
      expect(find.byKey(const Key('food-log-success-guide')), findsNothing);
      expect(find.text('Could not add food'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
  testWidgets(
    'A to B to A while quantity is open rejects stale save for both owners',
    (tester) async {
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'reference-test',
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-b',
      );
      addTearDown(a.close);
      addTearDown(b.close);
      final id = await seed(a);
      await seed(b);
      // Keep a single live router and update the real database namespace.
      final router = journeyRouter()..go('/daily-log?foodLog=1&guide=1');
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(a),
          seedCatalogProvider.overrideWith((ref) async {}),
          foodRuntimeSearchAuthorityProvider.overrideWithValue(
            FoodRuntimeSearchAuthority(
              FoodRepository(a),
              catalogResolver: () async => null,
            ),
          ),
        ],
      );
      var containerDisposed = false;
      void disposeContainer() {
        if (!containerDisposed) {
          containerDisposed = true;
          container.dispose();
        }
      }

      addTearDown(disposeContainer);
      final app = journeyApp(a, router, 'en') as ProviderScope;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: app.child),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food-log-search')), 'TEST');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('food-log-add-$id')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('food-log-serving-quantity-field')),
        '80',
      );
      container.updateOverrides([
        databaseProvider.overrideWithValue(b),
        seedCatalogProvider.overrideWith((ref) async {}),
        foodRuntimeSearchAuthorityProvider.overrideWithValue(
          FoodRuntimeSearchAuthority(
            FoodRepository(b),
            catalogResolver: () async => null,
          ),
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-log-serving-confirm')));
      await tester.pumpAndSettle();
      expect(await a.select(a.mealItems).get(), isEmpty);
      expect(await b.select(b.mealItems).get(), isEmpty);
      expect(
        await PreferencesRepository(a).get(firstMealCelebrationPreferenceKey),
        isNull,
      );
      expect(
        await PreferencesRepository(b).get(firstMealCelebrationPreferenceKey),
        isNull,
      );
      expect(
        find.byKey(const Key('dashboard-first-food-celebration')),
        findsNothing,
      );
      container.updateOverrides([
        databaseProvider.overrideWithValue(a),
        seedCatalogProvider.overrideWith((ref) async {}),
        foodRuntimeSearchAuthorityProvider.overrideWithValue(
          FoodRuntimeSearchAuthority(
            FoodRepository(a),
            catalogResolver: () async => null,
          ),
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food-log-search')), 'TEST');
      await tester.pumpAndSettle();
      expect(find.byKey(Key('food-log-add-$id')), findsOneWidget);
      expect(await a.select(a.mealItems).get(), isEmpty);
      expect(await b.select(b.mealItems).get(), isEmpty);
      expect(tester.takeException(), isNull);
      disposeContainer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
}
