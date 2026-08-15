import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_health_glossary.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_catalog_quality.dart';
import 'package:body_intelligence_log/app/localization/bil_reviewed_locale_catalog.dart';

void main(List<String> arguments) {
  final requestedTag = arguments
      .where((argument) => argument.startsWith('--locale='))
      .map((argument) => argument.substring('--locale='.length).toLowerCase())
      .firstOrNull;
  final catalogs = BilDraftLocaleCatalogs.all
      .where(
        (catalog) =>
            requestedTag == null ||
            catalog.localeTag.toLowerCase() == requestedTag,
      )
      .toList(growable: false);
  if (catalogs.isEmpty) {
    throw ArgumentError.value(requestedTag, 'locale', 'unknown draft locale');
  }

  final quality = BilLocaleCatalogQuality.audit(catalogs);
  final packet = <String, Object?>{
    'schema': 'bil.locale-review-packet.v1',
    'catalog_count': catalogs.length,
    'entry_count': quality.entryCount,
    'automated_blocking_errors': quality.errorCount,
    'automated_warnings': quality.warningCount,
    'human_approval_required': true,
    'device_smoke_required': true,
    'catalogs': [
      for (final catalog in catalogs)
        {
          'locale': catalog.localeTag,
          'human_reviewed': catalog.humanReviewed,
          'device_smoke_passed': catalog.smokePassed,
          'eligible_for_production': catalog.eligibleForProduction,
          'terms': [
            for (final term in BilHealthGlossary.terms)
              {
                'key': term.key,
                'domain': term.domain.name,
                'source_en': term.english,
                'target': catalog.values[term.key],
              },
          ],
        },
    ],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(packet));
}
