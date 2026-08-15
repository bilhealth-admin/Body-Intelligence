import 'package:body_intelligence_log/app/localization/bil_health_glossary.dart';
import 'package:body_intelligence_log/app/localization/bil_reviewed_locale_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase-one drafts cover every canonical high-risk glossary key', () {
    expect(BilPhaseOneLocaleCatalogs.catalogs, hasLength(4));
    for (final catalog in BilPhaseOneLocaleCatalogs.catalogs) {
      expect(
        catalog.values,
        hasLength(BilHealthGlossary.terms.length),
        reason: catalog.localeTag,
      );
      expect(catalog.glossaryComplete, isTrue, reason: catalog.localeTag);
    }
  });

  test('regional Portuguese terminology stays explicit', () {
    expect(
      BilPhaseOneLocaleCatalogs.forTag('pt_BR')!.values['carbohydrates'],
      'Carboidratos',
    );
    expect(
      BilPhaseOneLocaleCatalogs.forTag('pt-PT')!.values['carbohydrates'],
      'Hidratos de carbono',
    );
  });

  test('draft catalogs remain hidden until human review and smoke pass', () {
    expect(
      BilPhaseOneLocaleCatalogs.catalogs.every((c) => !c.eligibleForProduction),
      isTrue,
    );
  });

  test('runtime-safe lookup never exposes an unapproved draft', () {
    for (final catalog in BilPhaseOneLocaleCatalogs.catalogs) {
      expect(
        BilPhaseOneLocaleCatalogs.productionValuesForTag(catalog.localeTag),
        isNull,
      );
    }
    expect(BilPhaseOneLocaleCatalogs.productionValuesForTag('unknown'), isNull);
  });

  test('mandatory script drafts are complete and remain fail-closed', () {
    expect(BilMandatoryScriptLocaleCatalogs.catalogs, hasLength(8));
    for (final catalog in BilMandatoryScriptLocaleCatalogs.catalogs) {
      expect(catalog.glossaryComplete, isTrue, reason: catalog.localeTag);
      expect(catalog.eligibleForProduction, isFalse, reason: catalog.localeTag);
      expect(
        BilMandatoryScriptLocaleCatalogs.productionValuesForTag(
          catalog.localeTag,
        ),
        isNull,
        reason: catalog.localeTag,
      );
    }
  });

  test('Chinese script catalogs are independently addressable', () {
    expect(
      BilMandatoryScriptLocaleCatalogs.forTag('zh_Hans')!.values['protein'],
      '蛋白质',
    );
    expect(
      BilMandatoryScriptLocaleCatalogs.forTag('zh-Hant')!.values['protein'],
      '蛋白質',
    );
  });

  test('Indonesian and Malay drafts are complete and hidden independently', () {
    expect(BilMandatorySoutheastAsiaLocaleCatalogs.catalogs, hasLength(2));
    for (final catalog in BilMandatorySoutheastAsiaLocaleCatalogs.catalogs) {
      expect(catalog.glossaryComplete, isTrue, reason: catalog.localeTag);
      expect(
        BilMandatorySoutheastAsiaLocaleCatalogs.productionValuesForTag(
          catalog.localeTag,
        ),
        isNull,
      );
    }
    expect(
      BilMandatorySoutheastAsiaLocaleCatalogs.forTag('id')!.values['serving'],
      'Porsi',
    );
    expect(
      BilMandatorySoutheastAsiaLocaleCatalogs.forTag('ms')!.values['serving'],
      'Hidangan',
    );
  });
}
