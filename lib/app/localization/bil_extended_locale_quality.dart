import 'runtime_copy_extended.dart';

class BilExtendedLocaleQualityReport {
  const BilExtendedLocaleQualityReport({
    required this.catalogCount,
    required this.keyCount,
    required this.errors,
    required this.warnings,
  });
  final int catalogCount;
  final int keyCount;
  final List<String> errors;
  final List<String> warnings;
  bool get passed => errors.isEmpty;
}

/// Reproducible release gate for the twenty full generated runtime catalogs.
abstract final class BilExtendedLocaleQuality {
  static final _control = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\uFFFD]',
  );
  static final _scripts = <String, RegExp>{
    'ur': RegExp(r'[\u0600-\u06FF]'),
    'fa': RegExp(r'[\u0600-\u06FF]'),
    'hi': RegExp(r'[\u0900-\u097F]'),
    'ja': RegExp(r'[\u3040-\u30FF\u3400-\u9FFF]'),
    'ko': RegExp(r'[\uAC00-\uD7AF]'),
    'zh-Hans': RegExp(r'[\u3400-\u9FFF]'),
    'zh-Hant': RegExp(r'[\u3400-\u9FFF]'),
    'ru': RegExp(r'[\u0400-\u04FF]'),
    'uk': RegExp(r'[\u0400-\u04FF]'),
    'bn': RegExp(r'[\u0980-\u09FF]'),
    'th': RegExp(r'[\u0E00-\u0E7F]'),
  };

  static BilExtendedLocaleQualityReport audit() {
    final errors = <String>[];
    final warnings = <String>[];
    final expectedTags = ExtendedRuntimeCopy.supported;
    final sources = ExtendedRuntimeCopy.values.keys.toSet();
    if (expectedTags.length != 20) errors.add('catalog_count');
    if (sources.length < 270) errors.add('insufficient_full_surface_keys');
    for (final entry in ExtendedRuntimeCopy.values.entries) {
      if (entry.value.keys.length != expectedTags.length ||
          !entry.value.keys.toSet().containsAll(expectedTags)) {
        errors.add('key_set:${entry.key}');
        continue;
      }
      for (final translation in entry.value.entries) {
        final value = translation.value.trim();
        if (value.isEmpty) errors.add('blank:${translation.key}:${entry.key}');
        if (_control.hasMatch(value)) {
          errors.add('invalid_unicode:${translation.key}:${entry.key}');
        }
        if (entry.key.contains('BIL') && !value.contains('BIL')) {
          errors.add('bil_brand:${translation.key}:${entry.key}');
        }
        if (entry.key.contains('AI Coach') && !value.contains('AI Coach')) {
          errors.add('coach_brand:${translation.key}:${entry.key}');
        }
        if (entry.key.isNotEmpty && value.length > entry.key.length * 5) {
          warnings.add('layout_ratio:${translation.key}:${entry.key}');
        }
      }
    }
    for (final tag in expectedTags) {
      var sourceIdentities = 0;
      var scriptHits = 0;
      final script = _scripts[tag];
      for (final entry in ExtendedRuntimeCopy.values.entries) {
        final translated = entry.value[tag]!;
        if (translated.toLowerCase() == entry.key.toLowerCase()) {
          sourceIdentities += 1;
        }
        if (script?.hasMatch(translated) ?? false) scriptHits += 1;
      }
      if (sourceIdentities > sources.length * .18) {
        errors.add('source_leakage:$tag:$sourceIdentities');
      }
      if (script != null && scriptHits < sources.length * .45) {
        errors.add('target_script:$tag:$scriptHits');
      }
    }
    int pairDifferences(String left, String right) => ExtendedRuntimeCopy
        .values
        .values
        .where((values) => values[left] != values[right])
        .length;
    if (pairDifferences('pt-BR', 'pt-PT') < 3) {
      errors.add('portuguese_variants_not_independent');
    }
    if (pairDifferences('zh-Hans', 'zh-Hant') < 3) {
      errors.add('chinese_scripts_not_independent');
    }
    return BilExtendedLocaleQualityReport(
      catalogCount: expectedTags.length,
      keyCount: sources.length,
      errors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
    );
  }
}
