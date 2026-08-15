import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_translations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all ten pathways have balanced French Spanish and Turkish content', () {
    final ids = nutritionPathways.map((plan) => plan.id).toSet();
    expect(ids, hasLength(10));
    for (final locale in const ['fr', 'es', 'tr']) {
      final localized = nutritionPathwayTranslations[locale]!;
      expect(localized.keys.toSet(), ids, reason: locale);
      for (final value in localized.values) {
        expect(value.title.trim(), isNotEmpty);
        expect(value.subtitle.trim(), isNotEmpty);
        expect(value.tags, hasLength(3));
        expect(value.approach, hasLength(3));
        expect(value.tracking, hasLength(3));
        expect([
          ...value.tags,
          ...value.approach,
          ...value.tracking,
        ], everyElement(isNot(isEmpty)));
      }
    }
  });

  test('representative pathway copy is genuinely localized', () {
    expect(
      nutritionPathwayTranslations['fr']!['cutting']!.title,
      'Perte de graisse intelligente',
    );
    expect(
      nutritionPathwayTranslations['es']!['pregnancy']!.tags,
      contains('Seguridad alimentaria'),
    );
    expect(
      nutritionPathwayTranslations['tr']!['psmf']!.tracking,
      contains('Güvenlik durumu'),
    );
  });
}
