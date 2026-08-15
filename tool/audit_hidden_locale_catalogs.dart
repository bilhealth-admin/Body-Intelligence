import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/bil_locale_catalog_quality.dart';
import 'package:body_intelligence_log/app/localization/bil_reviewed_locale_catalog.dart';

void main() {
  final report = BilLocaleCatalogQuality.audit(BilDraftLocaleCatalogs.all);
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'catalog_count': report.catalogCount,
      'entry_count': report.entryCount,
      'errors': report.errorCount,
      'warnings': report.warningCount,
      'eligible_for_production': false,
      'findings': [
        for (final finding in report.findings)
          {
            'locale': finding.localeTag,
            'severity': finding.severity.name,
            'code': finding.code,
            'key': finding.key,
          },
      ],
    }),
  );
}
