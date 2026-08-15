import 'bil_health_glossary.dart';
import 'bil_locale_rollout_manifest.dart';
import 'bil_reviewed_locale_catalog.dart';

enum BilCatalogFindingSeverity { error, warning }

class BilCatalogFinding {
  const BilCatalogFinding({
    required this.localeTag,
    required this.code,
    required this.severity,
    this.key,
  });

  final String localeTag;
  final String code;
  final BilCatalogFindingSeverity severity;
  final String? key;
}

class BilCatalogQualityReport {
  const BilCatalogQualityReport({
    required this.catalogCount,
    required this.entryCount,
    required this.findings,
  });

  final int catalogCount;
  final int entryCount;
  final List<BilCatalogFinding> findings;

  int get errorCount => findings
      .where((finding) => finding.severity == BilCatalogFindingSeverity.error)
      .length;
  int get warningCount => findings.length - errorCount;
  bool get automatedGatePassed => errorCount == 0;
}

/// Deterministic pre-review checks only. Passing this audit never substitutes
/// for professional linguistic review or visual/device smoke approval.
abstract final class BilLocaleCatalogQuality {
  static final _controlCharacters = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]',
  );
  static final _mojibakeSignals = <String>[
    'Ã',
    'Â',
    'â€',
    'ï¿½',
    String.fromCharCode(0xFFFD),
  ];

  static BilCatalogQualityReport audit(
    Iterable<BilLocaleCatalogReview> catalogs,
  ) {
    final findings = <BilCatalogFinding>[];
    final required = BilHealthGlossary.terms.map((term) => term.key).toSet();
    var entries = 0;

    for (final catalog in catalogs) {
      entries += catalog.values.length;
      final keys = catalog.values.keys.toSet();
      for (final key in required.difference(keys)) {
        findings.add(_error(catalog.localeTag, 'missing_key', key));
      }
      for (final key in keys.difference(required)) {
        findings.add(_error(catalog.localeTag, 'unknown_key', key));
      }
      for (final entry in catalog.values.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) {
          findings.add(_error(catalog.localeTag, 'blank_value', entry.key));
        }
        if (_controlCharacters.hasMatch(value) ||
            _mojibakeSignals.any(value.contains)) {
          findings.add(_error(catalog.localeTag, 'invalid_unicode', entry.key));
        }
        if (entry.key == 'ai_boost' && !value.contains('BIL AI')) {
          findings.add(
            _error(catalog.localeTag, 'brand_token_changed', entry.key),
          );
        }

        final source = BilHealthGlossary.terms
            .firstWhere((term) => term.key == entry.key)
            .english;
        final ratio = value.length / source.length;
        if (ratio > 3.5) {
          findings.add(
            _warning(catalog.localeTag, 'layout_length_risk', entry.key),
          );
        }
        if (!_isEnglishTag(catalog.localeTag) &&
            value.toLowerCase() == source.toLowerCase() &&
            !_approvedSourceIdentity(catalog.localeTag, entry.key)) {
          findings.add(
            _warning(catalog.localeTag, 'source_copy_review', entry.key),
          );
        }
      }

      final language = catalog.localeTag
          .toLowerCase()
          .split(RegExp('[-_]'))
          .first;
      final manifestEntries = [
        ...BilLocaleRolloutManifest.mandatory18,
        ...BilLocaleRolloutManifest.highValueCandidates,
      ];
      BilLocaleRolloutEntry? manifestEntry;
      for (final entry in manifestEntries) {
        if (entry.tag.toLowerCase() == catalog.localeTag.toLowerCase() ||
            entry.regionalVariants.any(
              (variant) =>
                  variant.toLowerCase() == catalog.localeTag.toLowerCase(),
            )) {
          manifestEntry = entry;
          break;
        }
      }
      final expectedRtl = manifestEntry?.textDirection == 'rtl';
      final actualRtl = const {'ur', 'fa', 'ar'}.contains(language);
      if (manifestEntry == null) {
        findings.add(_error(catalog.localeTag, 'missing_manifest_entry', null));
      } else if (actualRtl != expectedRtl) {
        findings.add(_error(catalog.localeTag, 'direction_mismatch', null));
      }
    }

    return BilCatalogQualityReport(
      catalogCount: catalogs.length,
      entryCount: entries,
      findings: List<BilCatalogFinding>.unmodifiable(findings),
    );
  }

  static bool _isEnglishTag(String tag) =>
      tag.toLowerCase().split(RegExp('[-_]')).first == 'en';

  /// Reviewed invariants are not blind translations: commercial brand names
  /// remain unchanged, while "Protein" is the standard target-language term
  /// in German, Indonesian and Malay.
  static bool _approvedSourceIdentity(String localeTag, String key) {
    if (const {'premium', 'premium_ai_coach', 'ai_boost'}.contains(key)) {
      return true;
    }
    final language = localeTag.toLowerCase().split(RegExp('[-_]')).first;
    return key == 'protein' && const {'de', 'id', 'ms'}.contains(language);
  }

  static BilCatalogFinding _error(String locale, String code, String? key) =>
      BilCatalogFinding(
        localeTag: locale,
        code: code,
        severity: BilCatalogFindingSeverity.error,
        key: key,
      );

  static BilCatalogFinding _warning(String locale, String code, String? key) =>
      BilCatalogFinding(
        localeTag: locale,
        code: code,
        severity: BilCatalogFindingSeverity.warning,
        key: key,
      );
}
