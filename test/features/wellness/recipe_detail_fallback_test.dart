import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'missing recipe detail language falls back deterministically to English',
    () {
      const summary = RecipeCatalogSummary(
        id: 'fallback-test',
        fingerprint: 'fingerprint',
        shard: 0,
        ordinal: 0,
        primaryLocale: 'ar',
        title: 'English list title',
        localizedTitles: {
          'en': 'English list title',
          'de': 'Deutscher Listentitel',
        },
        totalMinutes: 20,
        mealTypes: ['dinner'],
        dietTags: [],
        allergens: [],
        imageStatus: 'ready',
      );
      const detail = RecipeCatalogDetail(
        summary: summary,
        record: <String, dynamic>{
          'primaryLocale': 'ar',
          'localizations': <String, dynamic>{
            'ar': <String, dynamic>{'title': 'عنوان عربي'},
            'en': <String, dynamic>{'title': 'English detail title'},
          },
        },
      );

      final resolved = detail.resolveLocalization('de');
      expect(resolved.locale, 'en');
      expect(resolved.isFallback, isTrue);
      expect(resolved.value['title'], 'English detail title');
      expect(summary.resolveTitle('de').text, 'Deutscher Listentitel');
    },
  );
}
