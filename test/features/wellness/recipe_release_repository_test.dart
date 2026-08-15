import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
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

    for (final summary in [index.first, index[749], index.last]) {
      final detail = await repository.loadDetail(summary);
      expect(detail.record['canonicalId'], summary.id);
      expect(detail.record['contentFingerprint'], summary.fingerprint);
      expect(detail.localization(summary.primaryLocale)['title'], isNotEmpty);
    }
  });

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
