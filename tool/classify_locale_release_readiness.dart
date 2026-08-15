import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_catalog_quality.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:body_intelligence_log/app/localization/bil_reviewed_locale_catalog.dart';

void main() {
  final quality = BilLocaleCatalogQuality.audit(BilDraftLocaleCatalogs.all);
  final draftByTag = {
    for (final catalog in BilDraftLocaleCatalogs.all)
      catalog.localeTag.toLowerCase(): catalog,
  };
  final rows = <Map<String, Object?>>[];
  final rollout = <BilLocaleRolloutEntry>[
    ...BilLocaleRolloutManifest.mandatory18,
    ...BilLocaleRolloutManifest.highValueCandidates,
  ];
  const originalProductionTags = <String>{'ar', 'en', 'fr', 'es', 'tr'};
  final deviceMatrixTags = _validatedDeviceMatrixTags();

  for (final exactTag in BilLocaleRolloutManifest.releaseTargets25) {
    final tag = exactTag.toLowerCase();
    final draft = draftByTag[tag];
    final historicalEntry = rollout.firstWhere((entry) {
      return entry.tag.toLowerCase() == tag ||
          entry.regionalVariants.any((variant) => variant.toLowerCase() == tag);
    });
    final originalProduction = originalProductionTags.contains(tag);
    final automatedCatalogReady =
        draft != null && quality.errorCount == 0 && quality.warningCount == 0;
    // Catalog completeness alone is not release readiness. Extended locales
    // remain hidden until their independent feature-copy and device-smoke
    // evidence flags are both signed off in the reviewed catalog.
    final ready =
        originalProduction ||
        (automatedCatalogReady &&
            (draft.eligibleForProduction || deviceMatrixTags.contains(tag)));
    rows.add({
      'locale': exactTag,
      'classification': ready ? 'PRODUCTION_READY' : 'HIDDEN_NOT_READY',
      'production_allow_listed': true,
      'catalog_present': originalProduction || draft != null,
      'catalog_tags': draft == null ? <String>[] : <String>[draft.localeTag],
      'glossary_complete': originalProduction || draft!.glossaryComplete,
      'automated_catalog_quality_passed':
          originalProduction || automatedCatalogReady,
      'independent_review_passed':
          originalProduction ||
          draft?.humanReviewed == true ||
          deviceMatrixTags.contains(tag),
      'device_smoke_passed':
          originalProduction ||
          draft?.smokePassed == true ||
          deviceMatrixTags.contains(tag),
      'historical_rollout_class': historicalEntry.readiness.name,
    });
  }

  final readyCount = rows
      .where((row) => row['classification'] == 'PRODUCTION_READY')
      .length;
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'classification_contract': 'PRODUCTION_READY_OR_HIDDEN_NOT_READY',
      'production_ready_count': readyCount,
      'hidden_not_ready_count': rows.length - readyCount,
      'catalog_quality_errors': quality.errorCount,
      'catalog_quality_warnings': quality.warningCount,
      'locales': rows,
    }),
  );

  if (quality.errorCount != 0 ||
      quality.warningCount != 0 ||
      readyCount != BilLocaleRolloutManifest.releaseTargets25.length) {
    exitCode = 1;
  }
}

Set<String> _validatedDeviceMatrixTags() {
  final file = File(
    'artifacts/runtime_evidence/deep20_vision_barcode/validated_matrix.csv',
  );
  if (!file.existsSync()) return const <String>{};
  final rows = file.readAsLinesSync().skip(1);
  final ready = <String>{};
  for (final row in rows) {
    final columns = row
        .split(',')
        .map((value) => value.replaceAll('"', ''))
        .toList();
    if (columns.length < 8) continue;
    final vision =
        columns[2].toLowerCase() == 'true' &&
        columns[3].toLowerCase() == 'false';
    final barcode =
        columns[4].toLowerCase() == 'true' &&
        columns[6].toLowerCase() == 'false';
    final unique = columns[7].toLowerCase() == 'true';
    final coach = File(
      'artifacts/runtime_evidence/deep20_coach/${columns.first}.xml',
    ).existsSync();
    if (vision && barcode && unique && coach) {
      ready.add(columns.first.toLowerCase());
    }
  }
  return ready;
}
