import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_cuisine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads exact 1500 index and hash-verified lazy shards', () async {
    final repository = RecipeReleaseRepository();
    final index = await repository.loadIndex();
    expect(index, hasLength(1500));
    expect(index.map((recipe) => recipe.id).toSet(), hasLength(1500));
    expect(
      index.where((recipe) => recipe.primaryLocale == 'ar'),
      hasLength(300),
    );
    expect(
      index.where((recipe) => recipe.primaryLocale == 'en'),
      hasLength(300),
    );
    expect(
      index.where((recipe) => recipe.primaryLocale == 'es'),
      hasLength(300),
    );
    expect(
      index.where((recipe) => recipe.primaryLocale == 'fr'),
      hasLength(300),
    );
    expect(
      index.where((recipe) => recipe.primaryLocale == 'tr'),
      hasLength(300),
    );
    const catalogLocales = {
      'ar',
      'en',
      'fr',
      'es',
      'tr',
      'de',
      'it',
      'pt-BR',
      'pt-PT',
      'ur',
      'fa',
      'hi',
      'id',
      'ms',
      'ja',
      'ko',
      'zh-Hans',
      'zh-Hant',
      'ru',
      'bn',
      'vi',
      'th',
      'pl',
      'nl',
      'uk',
    };
    expect(
      index.every(
        (recipe) =>
            recipe.localizedTitles.keys.toSet().containsAll(catalogLocales),
      ),
      isTrue,
    );
    for (final locale in catalogLocales) {
      expect(
        index.map((recipe) => recipe.titleFor(locale).toLowerCase()).toSet(),
        hasLength(1500),
        reason: '$locale recipe titles must remain unique',
      );
    }
    expect(
      index
          .where((recipe) => recipe.id.startsWith('bil-'))
          .every((recipe) => recipeCuisineKey(recipe) != 'global'),
      isTrue,
      reason:
          'every BIL original must expose its explicit cuisine-inspired profile',
    );
    expect(
      index.where((recipe) => recipeCuisineKey(recipe) == 'global'),
      hasLength(18),
    );

    for (final summary in [index.first, index[749], index.last]) {
      final detail = await repository.loadDetail(summary);
      expect(detail.record['canonicalId'], summary.id);
      expect(detail.record['contentFingerprint'], summary.fingerprint);
      expect(detail.localization(summary.primaryLocale)['title'], isNotEmpty);
    }
  });

  test(
    'maps all 1500 ids to digest-pinned bucket-hidden delivery URLs',
    () async {
      final repository = RecipeReleaseRepository();
      final index = await repository.loadIndex();
      final images = await repository.loadImageAssets();

      expect(images, hasLength(1500));
      expect(
        images.map((image) => image.canonicalId),
        index.map((recipe) => recipe.id),
      );
      expect(images.map((image) => image.sha256).toSet(), hasLength(1500));
      for (final image in images) {
        expect(image.url.scheme, 'https');
        expect(image.url.host, 'workouts.bilhealth.com');
        expect(image.url.hasPort, isFalse);
        expect(image.url.query, isEmpty);
        expect(image.url.fragment, isEmpty);
        expect(
          image.url.path,
          '/v3/recipes/images/${image.canonicalId}/${image.sha256}',
        );
        expect(image.url.toString(), isNot(contains('bil-recipes-2026-v1')));
        expect(image.url.path, isNot(contains('recipes/v1/images')));
        expect(image.sizeBytes, greaterThan(0));
        expect(image.sizeBytes, lessThanOrEqualTo(8 * 1024 * 1024));
        expect(image.mimeType, anyOf('image/jpeg', 'image/png'));
        expect(image.mediaAsset.sha256, image.sha256);
      }

      await expectLater(
        repository.loadImageAsset('not-a-catalog-recipe'),
        throwsFormatException,
      );
    },
  );

  test('keeps Algerian chakhchoukha distinct from egg shakshuka', () async {
    final repository = RecipeReleaseRepository();
    final index = await repository.loadIndex();
    final chakhchoukha = index.singleWhere(
      (recipe) => recipe.id == 'algerian-chakhchoukha-chicken',
    );
    final shakshuka = index.singleWhere((recipe) => recipe.id == 'shakshuka');

    expect(chakhchoukha.titleFor('ar'), 'الشخشوخة الجزائرية بالدجاج');
    expect(shakshuka.titleFor('ar'), 'شكشوكة بالأعشاب');
    expect(recipeCuisineKey(chakhchoukha), 'algeria');
    expect(recipeCuisineKey(shakshuka), 'global');

    final chakhchoukhaIngredients =
        (await repository.loadDetail(chakhchoukha)).record['ingredients']
            as List<dynamic>;
    final shakshukaIngredients =
        (await repository.loadDetail(shakshuka)).record['ingredients']
            as List<dynamic>;
    final chakhchoukhaIds = chakhchoukhaIngredients
        .cast<Map<String, dynamic>>()
        .map((ingredient) => ingredient['itemId'])
        .toSet();
    final shakshukaIds = shakshukaIngredients
        .cast<Map<String, dynamic>>()
        .map((ingredient) => ingredient['itemId'])
        .toSet();
    expect(chakhchoukhaIds, containsAll(['flatbread', 'chickpeas']));
    expect(chakhchoukhaIds, isNot(contains('eggs')));
    expect(shakshukaIds, contains('eggs'));
    expect(shakshukaIds, isNot(contains('flatbread')));
  });

  test(
    'projects and caches real card nutrition from the verified shard',
    () async {
      final repository = RecipeReleaseRepository();
      final index = await repository.loadIndex();
      final shakshuka = index.singleWhere((recipe) => recipe.id == 'shakshuka');
      final firstLoad = repository.loadCardFacts(shakshuka.id);
      final secondLoad = repository.loadCardFacts(shakshuka.id);

      expect(identical(firstLoad, secondLoad), isTrue);
      final facts = await firstLoad;
      final detail = await repository.loadDetail(shakshuka);
      final nutrition = detail.record['nutrition'] as Map<String, dynamic>;
      final perServing = nutrition['perServing'] as Map<String, dynamic>;
      final serving = detail.record['serving'] as Map<String, dynamic>;

      expect(facts.kcalPerServing, (perServing['kcal'] as num).toDouble());
      expect(
        facts.proteinGramsPerServing,
        (perServing['proteinG'] as num).toDouble(),
      );
      expect(facts.servings, serving['count']);
    },
  );

  test(
    'every catalog recipe maps to a visible verified cuisine page',
    () async {
      final index = await RecipeReleaseRepository().loadIndex();
      final cuisines = index.map(recipeCuisineKey).toSet();
      expect(cuisines, isNot(contains('')));
      expect(cuisines.difference(recipeCuisineOrder.toSet()), isEmpty);
      expect(
        cuisines,
        containsAll([
          'egypt',
          'turkey',
          'maghreb',
          'algeria',
          'morocco',
          'tunisia',
        ]),
      );
      expect(
        index
            .where((recipe) => recipe.primaryLocale == 'tr')
            .map(recipeCuisineKey)
            .toSet(),
        {'turkey'},
      );
      expect(
        index
            .where(
              (recipe) =>
                  recipe.primaryLocale == 'tr' && recipe.region != 'global',
            )
            .map(recipeCuisineKey)
            .toSet(),
        {'turkey'},
      );
    },
  );

  test(
    'rejects caller-created summary outside the authoritative index',
    () async {
      final repository = RecipeReleaseRepository();
      final index = await repository.loadIndex();
      final source = index.first;
      final forged = RecipeCatalogSummary(
        id: source.id,
        fingerprint: source.fingerprint,
        shard: source.shard,
        ordinal: source.ordinal,
        primaryLocale: source.primaryLocale,
        title: source.title,
        localizedTitles: source.localizedTitles,
        totalMinutes: source.totalMinutes,
        mealTypes: source.mealTypes,
        dietTags: source.dietTags,
        allergens: source.allergens,
        imageStatus: source.imageStatus,
      );
      expect(() => repository.loadDetail(forged), throwsFormatException);
    },
  );
}
