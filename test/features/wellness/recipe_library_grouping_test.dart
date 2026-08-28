import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('groups the home catalog by cuisine and pages filtered results', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = <RecipeCatalogSummary>[
      for (var index = 0; index < 4; index++)
        _recipe(index: index, cuisine: 'global'),
      for (var index = 0; index < 26; index++)
        _recipe(index: index + 4, cuisine: 'egypt'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RecipeLibraryPage(initialCatalog: catalog),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recipe-cuisine-sections')), findsOneWidget);
    expect(find.byKey(const Key('recipe-results-grid')), findsNothing);
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey('recipe-cuisine-section-list-global')),
          )
          .semanticChildCount,
      4,
    );
    expect(
      tester
          .widget<ListView>(
            find.byKey(const ValueKey('recipe-cuisine-section-list-egypt')),
          )
          .semanticChildCount,
      4,
    );

    await tester.tap(
      find.byKey(const ValueKey('recipe-cuisine-section-open-egypt')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recipe-cuisine-sections')), findsNothing);
    var grid = tester.widget<SliverGrid>(
      find.byKey(const Key('recipe-results-grid')),
    );
    expect(grid.delegate.estimatedChildCount, 24);

    await tester.scrollUntilVisible(
      find.byKey(const Key('recipe-show-more')),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('recipe-show-more')));
    await tester.pumpAndSettle();

    grid = tester.widget<SliverGrid>(
      find.byKey(const Key('recipe-results-grid')),
    );
    expect(grid.delegate.estimatedChildCount, 26);
    expect(find.byKey(const Key('recipe-show-more')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

RecipeCatalogSummary _recipe({required int index, required String cuisine}) {
  final id = '$cuisine-recipe-${index.toString().padLeft(2, '0')}';
  return RecipeCatalogSummary(
    id: id,
    fingerprint: index.toRadixString(16).padLeft(64, '0'),
    shard: 0,
    ordinal: index,
    primaryLocale: 'en',
    title: 'Recipe $index',
    localizedTitles: {'en': 'Recipe $index'},
    totalMinutes: 30,
    mealTypes: const ['lunch'],
    dietTags: const ['balanced'],
    allergens: const [],
    imageStatus: 'external_candidate',
    region: cuisine,
    cuisine: cuisine,
  );
}
