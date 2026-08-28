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

  final cases = <(Locale, String, String)>[
    (const Locale('ar'), 'المطبخ المصري', 'كشري مصري'),
    (const Locale('en'), 'Egyptian cuisine', 'Egyptian koshary'),
    (const Locale('fr'), 'Cuisine égyptienne', 'Koshary égyptien'),
    (const Locale('es'), 'Cocina egipcia', 'Koshary egipcio'),
    (const Locale('tr'), 'Mısır mutfağı', 'Mısır koşarisi'),
  ];

  for (final (locale, cuisineLabel, recipeTitle) in cases) {
    testWidgets('filters the cuisine page in ${locale.languageCode}', (
      tester,
    ) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
            home: RecipeLibraryPage(initialCatalog: _catalog),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recipe-cuisine-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(cuisineLabel).last);
      await tester.pumpAndSettle();

      expect(find.text(cuisineLabel), findsNWidgets(2));
      expect(find.text(recipeTitle), findsOneWidget);
      expect(find.text('Herbed shakshuka'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

const _catalog = <RecipeCatalogSummary>[
  RecipeCatalogSummary(
    id: 'egyptian-koshari',
    fingerprint:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    shard: 0,
    ordinal: 0,
    primaryLocale: 'ar',
    title: 'كشري مصري',
    localizedTitles: {
      'ar': 'كشري مصري',
      'en': 'Egyptian koshary',
      'fr': 'Koshary égyptien',
      'es': 'Koshary egipcio',
      'tr': 'Mısır koşarisi',
    },
    totalMinutes: 65,
    mealTypes: ['lunch'],
    dietTags: ['balanced'],
    allergens: [],
    imageStatus: 'placeholder',
    region: 'egypt',
  ),
  RecipeCatalogSummary(
    id: 'shakshuka',
    fingerprint:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    shard: 0,
    ordinal: 1,
    primaryLocale: 'en',
    title: 'Herbed shakshuka',
    localizedTitles: {
      'ar': 'شكشوكة بالأعشاب',
      'en': 'Herbed shakshuka',
      'fr': 'Chakchouka aux herbes',
      'es': 'Shakshuka con hierbas',
      'tr': 'Otlu shakshuka',
    },
    totalMinutes: 25,
    mealTypes: ['breakfast'],
    dietTags: ['balanced'],
    allergens: [],
    imageStatus: 'placeholder',
    region: 'global',
  ),
];
