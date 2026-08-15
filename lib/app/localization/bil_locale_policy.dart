import 'package:flutter/widgets.dart';

import 'bil_locale_rollout_manifest.dart';

abstract final class BilLocalePolicy {
  static const productionTags = BilLocaleRolloutManifest.releaseTargets25;
  static const rtlLanguages = <String>{'ar', 'ur', 'fa'};

  static String canonicalTag(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final script = locale.scriptCode;
    final country = locale.countryCode;
    if (language == 'zh' && script != null) {
      return 'zh-$script';
    }
    if (language == 'pt' && country != null) {
      return 'pt-${country.toUpperCase()}';
    }
    return language;
  }

  static String? canonicalSupportedTag(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().replaceAll('_', '-').toLowerCase();
    for (final tag in BilLocaleRolloutManifest.releaseTargets25) {
      if (tag.toLowerCase() == normalized) return tag;
    }
    return null;
  }

  static Locale localeFromTag(String tag) {
    final canonical = canonicalSupportedTag(tag) ?? 'en';
    final parts = canonical.split('-');
    if (parts.length == 1) return Locale(parts.first);
    if (parts[1].length == 4) {
      return Locale.fromSubtags(
        languageCode: parts.first,
        scriptCode: parts[1],
      );
    }
    return Locale(parts.first, parts[1]);
  }

  static bool isRtlTag(String tag) =>
      rtlLanguages.contains(tag.toLowerCase().split(RegExp('[-_]')).first);

  static TextDirection directionFor(Locale locale) =>
      isRtlTag(canonicalTag(locale)) ? TextDirection.rtl : TextDirection.ltr;

  static bool isProduction(Locale locale) =>
      productionTags.contains(canonicalTag(locale));

  static BilLocaleReadiness? readinessForTag(String tag) {
    final canonical = canonicalSupportedTag(tag);
    if (canonical != null && productionTags.contains(canonical)) {
      return BilLocaleReadiness.production;
    }
    final normalized = tag.replaceAll('_', '-').toLowerCase();
    for (final entry in <BilLocaleRolloutEntry>[
      ...BilLocaleRolloutManifest.mandatory18,
      ...BilLocaleRolloutManifest.highValueCandidates,
    ]) {
      if (entry.tag.toLowerCase() == normalized ||
          entry.regionalVariants.any((v) => v.toLowerCase() == normalized)) {
        return entry.readiness;
      }
    }
    return null;
  }
}
