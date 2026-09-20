import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ControlledFoodSearchAuthority extends FoodRuntimeSearchAuthority {
  // The superclass positional parameter is private to another library, so it
  // cannot be named as a Dart super-parameter here.
  // ignore: use_super_parameters
  _ControlledFoodSearchAuthority(FoodRepository repository)
    : super(repository, catalogResolver: () async => null);

  final pending = <String, Completer<FoodRuntimeSearchResult>>{};
  int calls = 0;

  @override
  Future<FoodRuntimeSearchResult> searchDetailed(
    String query, {
    int limit = 50,
  }) {
    calls += 1;
    return pending
        .putIfAbsent(query, Completer<FoodRuntimeSearchResult>.new)
        .future;
  }
}

void main() {
  testWidgets(
    'embedded My foods is task-first and consolidates capture methods',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodsProvider.overrideWith((ref) => Stream.value(const [])),
            favoriteFoodsProvider.overrideWith((ref) => Stream.value(const [])),
            recentFoodsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: FoodPage(embedded: true, userOwnedOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final search = find.byKey(const Key('food-primary-search'));
      final add = find.byKey(const Key('food-primary-add-action'));
      final filters = find.byKey(const Key('food-browse-filters'));
      expect(search, findsOneWidget);
      expect(add, findsOneWidget);
      expect(filters, findsOneWidget);
      expect(find.text('Log smarter. Understand your food.'), findsNothing);
      expect(
        find.text('Explore sleep, movement, and daily rhythm'),
        findsNothing,
      );
      expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
      expect(
        tester.getTopLeft(search).dy,
        lessThan(tester.getTopLeft(filters).dy),
      );

      await tester.tap(add);
      await tester.pumpAndSettle();
      for (final key in const [
        'food-add-scan-barcode',
        'food-add-manual-barcode',
        'food-add-meal-photo',
        'food-add-custom-food',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
        expect(
          tester.getSize(find.byKey(Key(key))).height,
          greaterThanOrEqualTo(48),
          reason: '$key touch target',
        );
      }
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
      expect(
        find.byKey(const Key('food-add-barcode-premium-group')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('avocado search separates loading, results, and empty states', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FoodRepository(database);
    await repository.addFood(
      name: 'Avocado',
      category: 'fruit',
      servingSize: 100,
      servingUnit: 'g',
      calories: 160,
      protein: 2,
      carbs: 8.5,
      fats: 14.7,
    );
    final avocado = (await repository.getFoods()).single;
    final authority = _ControlledFoodSearchAuthority(repository);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodRepositoryProvider.overrideWithValue(repository),
          foodRuntimeSearchAuthorityProvider.overrideWithValue(authority),
          foodsProvider.overrideWith((ref) => Stream.value([avocado])),
          favoriteFoodsProvider.overrideWith((ref) => Stream.value(const [])),
          recentFoodsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: FoodPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-browse-filters')), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'avocado');
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byKey(const Key('food-browse-filters')), findsNothing);
    expect(
      find.byKey(const Key('food-search-results-loading')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('food-search-empty-state')), findsNothing);

    authority.pending['avocado']!.complete(
      FoodRuntimeSearchResult(
        foods: [avocado],
        source: FoodRuntimeSearchSource.localOnly,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Avocado'), findsOneWidget);
    expect(find.byKey(const Key('food-search-empty-state')), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'no-such-food');
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      find.byKey(const Key('food-search-results-loading')),
      findsOneWidget,
    );
    authority.pending['no-such-food']!.complete(
      const FoodRuntimeSearchResult(
        foods: [],
        source: FoodRuntimeSearchSource.localOnly,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food-search-results-loading')), findsNothing);
    expect(find.byKey(const Key('food-search-empty-state')), findsOneWidget);
  });

  testWidgets(
    'My foods excludes materialized catalog rows and searches owned foods only',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = FoodRepository(database);
      await repository.addFood(
        name: 'Owner apple oats',
        category: 'custom',
        servingSize: 100,
        servingUnit: 'g',
        calories: 389,
        protein: 16.9,
        carbs: 66.3,
        fats: 6.9,
      );
      await repository.addFood(
        uuid: 'usda:1105782',
        name: 'APPLES, FUJI',
        category: 'foundation',
        servingSize: 100,
        servingUnit: 'g',
        calories: 0,
        protein: 0,
        carbs: 0,
        fats: 0,
        caloriesKnown: false,
        proteinKnown: false,
        carbsKnown: false,
        fatsKnown: false,
        isCustom: false,
        source: 'USDA FoodData Central — foundation',
        verified: true,
      );
      final foods = await repository.getFoods();
      final authority = _ControlledFoodSearchAuthority(repository);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodRepositoryProvider.overrideWithValue(repository),
            foodRuntimeSearchAuthorityProvider.overrideWithValue(authority),
            foodsProvider.overrideWith((ref) => Stream.value(foods)),
            favoriteFoodsProvider.overrideWith((ref) => Stream.value(foods)),
            recentFoodsProvider.overrideWith((ref) => Stream.value(foods)),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: FoodPage(embedded: true, userOwnedOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Owner apple oats'), findsOneWidget);
      expect(find.text('APPLES, FUJI'), findsNothing);

      await tester.enterText(find.byType(SearchBar), 'apple');
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();

      expect(authority.calls, 0);
      expect(find.text('Owner apple oats'), findsOneWidget);
      expect(find.text('APPLES, FUJI'), findsNothing);
      expect(find.byKey(const Key('food-search-empty-state')), findsNothing);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'food browse fits ${locale.toLanguageTag()} at 390x844 and 160%',
      (tester) async {
        final missingTranslations = <String>[];
        final previousDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message?.startsWith('Missing reviewed runtime translation:') ==
              true) {
            missingTranslations.add(message!);
            return;
          }
          previousDebugPrint(message, wrapWidth: wrapWidth);
        };
        addTearDown(() => debugPrint = previousDebugPrint);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              foodsProvider.overrideWith((ref) => Stream.value(const [])),
              favoriteFoodsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              recentFoodsProvider.overrideWith((ref) => Stream.value(const [])),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
              home: const FoodPage(embedded: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SearchBar), findsOneWidget);
        expect(
          find.byKey(const Key('food-primary-add-action')),
          findsOneWidget,
        );
        expect(find.text('Log smarter. Understand your food.'), findsNothing);
        await tester.tap(find.byKey(const Key('food-primary-add-action')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('food-add-scan-barcode')), findsOneWidget);
        expect(find.byKey(const Key('food-add-meal-photo')), findsOneWidget);
        expect(find.byKey(const Key('food-add-custom-food')), findsOneWidget);
        expect(tester.takeException(), isNull);
        debugPrint = previousDebugPrint;
        expect(
          missingTranslations,
          isEmpty,
          reason: 'Food search must not fall back to English in $locale.',
        );
      },
    );
  }
}
