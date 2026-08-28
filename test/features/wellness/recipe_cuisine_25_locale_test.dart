import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
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

  late RecipeCatalogSummary egyptian;
  late RecipeCatalogSummary global;

  setUpAll(() async {
    final index = await RecipeReleaseRepository().loadIndex();
    egyptian = index.singleWhere((recipe) => recipe.id == 'egyptian-koshari');
    global = index.singleWhere((recipe) => recipe.id == 'shakshuka');
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    testWidgets('recipe cuisine is localized and stable for $tag', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cuisineLabel = RuntimeCopy.resolve('Egyptian cuisine', tag)!;
      final recipeTitle = egyptian.titleFor(tag);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: RecipeLibraryPage(initialCatalog: [egyptian, global]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipe-cuisine-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(cuisineLabel).last);
      await tester.pumpAndSettle();

      expect(egyptian.resolveTitle(tag).isFallback, isFalse, reason: tag);
      expect(find.text(cuisineLabel), findsNWidgets(2), reason: tag);
      expect(find.text(recipeTitle), findsOneWidget, reason: tag);
      expect(find.text(global.titleFor(tag)), findsNothing, reason: tag);
      expect(tester.takeException(), isNull, reason: tag);
    });
  }
}
