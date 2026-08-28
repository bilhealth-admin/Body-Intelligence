import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:body_intelligence_log/features/wellness/services/recipe_image_delivery_client.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_media_cache.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipeReleaseRepository repository;
  late RecipeCatalogSummary shakshuka;
  late RecipeCatalogSummary remoteRecipe;

  setUpAll(() async {
    await loadVisualEvidenceFont();
    repository = RecipeReleaseRepository();
    final index = await repository.loadIndex();
    shakshuka = index.singleWhere((recipe) => recipe.id == 'shakshuka');
    remoteRecipe = index.singleWhere(
      (recipe) => recipe.id == 'aji-gallina-ligero',
    );
  });

  testWidgets('promotes a verified remote resolver file into the card', (
    tester,
  ) async {
    final imageResolver = _ReadyImageResolver(
      File('assets/images/professional/recipes/aji-gallina-ligero.png'),
    );
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    _setPhoneSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      _app(
        database,
        RecipeLibraryPage(
          initialCatalog: [remoteRecipe],
          repository: repository,
          imageClient: imageResolver,
          remoteImageDeliveryEnabled: true,
        ),
      ),
    );
    for (var frame = 0; frame < 80; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('recipe-remote-image-aji-gallina-ligero'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(
      find.byKey(const ValueKey('recipe-remote-image-aji-gallina-ligero')),
      findsOneWidget,
    );
    expect(imageResolver.canonicalIds, [remoteRecipe.id]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await tester.pump();
  });

  testWidgets('uses exact local art and verified nutrition on a real card', (
    tester,
  ) async {
    final facts = (await tester.runAsync(
      () => repository.loadCardFacts(shakshuka.id),
    ))!;
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    _setPhoneSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      _app(
        database,
        RecipeLibraryPage(
          initialCatalog: [shakshuka],
          initialCardFacts: {shakshuka.id: facts},
          repository: repository,
        ),
      ),
    );
    // Static asset decoding can keep global image bookkeeping active longer
    // than the UI work itself on Windows. Wait for the card's actual ready
    // state with a bounded number of frames.
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .text('${facts.kcalPerServing.round()} kcal')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    final exactImage = find.byKey(const ValueKey('recipe-image-shakshuka'));
    final proteinDigits =
        facts.proteinGramsPerServing ==
            facts.proteinGramsPerServing.roundToDouble()
        ? 0
        : 1;

    expect(exactImage, findsOneWidget);
    expect(find.text('${facts.kcalPerServing.round()} kcal'), findsOneWidget);
    expect(
      find.text(
        '${facts.proteinGramsPerServing.toStringAsFixed(proteinDigits)} g',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await settleVisualAssetImages(tester);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/recipe_library_polish_phone.png'),
    );
  });

  testWidgets('grid adapts from one to two columns at large text scale', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    _setPhoneSize(tester, const Size(320, 844));

    await tester.pumpWidget(
      _app(
        database,
        RecipeLibraryPage(
          initialCatalog: [
            for (var index = 0; index < 4; index++) _recipe(index),
          ],
        ),
        textScaler: const TextScaler.linear(1.8),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recipe-search-field')),
      'Recipe',
    );
    await tester.pumpAndSettle();

    SliverGrid grid = tester.widget(
      find.byKey(const Key('recipe-results-grid')),
    );
    var delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 1);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    grid = tester.widget(find.byKey(const Key('recipe-results-grid')));
    delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 2);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  AppDatabase database,
  Widget home, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
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
      theme: visualEvidenceTheme(BilFlagshipTheme.light(isArabic: false)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: visualEvidenceTextSurface(child),
      ),
      home: home,
    ),
  );
}

void _setPhoneSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

RecipeCatalogSummary _recipe(int index) {
  return RecipeCatalogSummary(
    id: 'polish-recipe-$index',
    fingerprint: index.toRadixString(16).padLeft(64, '0'),
    shard: 0,
    ordinal: index,
    primaryLocale: 'en',
    title: 'Recipe card $index with a readable title',
    localizedTitles: {'en': 'Recipe card $index with a readable title'},
    totalMinutes: 18,
    mealTypes: const ['lunch'],
    dietTags: const ['balanced'],
    allergens: const [],
    imageStatus: 'placeholder',
    region: 'egypt',
    cuisine: 'egypt',
  );
}

class _ReadyImageResolver implements RecipeImageResolver {
  _ReadyImageResolver(this.file);

  final File file;
  final List<String> canonicalIds = [];

  @override
  Future<WellnessMediaCacheResult> resolve(
    String canonicalId, {
    required bool online,
  }) async {
    canonicalIds.add(canonicalId);
    return WellnessMediaCacheResult.ready(file, fromCache: true);
  }
}
