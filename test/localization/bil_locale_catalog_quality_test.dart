import 'package:body_intelligence_log/app/localization/bil_locale_catalog_quality.dart';
import 'package:body_intelligence_log/app/localization/bil_reviewed_locale_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all mandatory drafts pass deterministic pre-review errors', () {
    final report = BilLocaleCatalogQuality.audit(BilDraftLocaleCatalogs.all);
    expect(report.catalogCount, 20);
    expect(report.entryCount, 260);
    expect(report.errorCount, 0);
    expect(report.warningCount, 0);
    expect(report.automatedGatePassed, isTrue);
  });

  test('audit detects malformed Unicode and brand mutation', () {
    const malformed = BilLocaleCatalogReview(
      localeTag: 'de',
      humanReviewed: false,
      smokePassed: false,
      values: {
        'calories': 'Kalorien Ã¼',
        'protein': 'Protein',
        'carbohydrates': 'Kohlenhydrate',
        'fat': 'Fett',
        'sodium': 'Natrium',
        'serving': 'Portion',
        'weight': 'Gewicht',
        'waist': 'Taille',
        'premium': 'Premium',
        'premium_ai_coach': 'Premium AI Coach',
        'ai_boost': 'Boost',
        'uncertain': 'Unsicher',
        'not_medical_diagnosis': 'Keine Diagnose',
      },
    );
    final report = BilLocaleCatalogQuality.audit(const [malformed]);
    expect(report.errorCount, 2);
    expect(
      report.findings.map((finding) => finding.code),
      containsAll(['invalid_unicode', 'brand_token_changed']),
    );
  });

  test('automated pass does not expose catalogs or mark human review', () {
    for (final catalog in BilDraftLocaleCatalogs.all) {
      expect(catalog.humanReviewed, isFalse);
      expect(catalog.smokePassed, isFalse);
      expect(catalog.eligibleForProduction, isFalse);
    }
  });

  test('candidate expansion remains outside mandatory set', () {
    expect(BilDraftLocaleCatalogs.mandatory, hasLength(14));
    expect(BilHighValueCandidateLocaleCatalogs.catalogs, hasLength(6));
    expect(
      BilHighValueCandidateLocaleCatalogs.catalogs.every(
        (catalog) => !catalog.eligibleForProduction,
      ),
      isTrue,
    );
  });
}
