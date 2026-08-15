enum BilLocaleReadiness { production, mandatoryPlanned, candidate }

class BilLocaleRolloutEntry {
  const BilLocaleRolloutEntry({
    required this.tag,
    required this.readiness,
    required this.textDirection,
    this.regionalVariants = const <String>[],
  });

  final String tag;
  final BilLocaleReadiness readiness;
  final String textDirection;
  final List<String> regionalVariants;
}

/// Historical rollout grouping plus the exact production target set.
/// Runtime promotion is authoritative in [releaseTargets25]; the original
/// readiness values remain as provenance for the staged rollout plan.
abstract final class BilLocaleRolloutManifest {
  static const mandatory18 = <BilLocaleRolloutEntry>[
    BilLocaleRolloutEntry(
      tag: 'ar',
      readiness: BilLocaleReadiness.production,
      textDirection: 'rtl',
    ),
    BilLocaleRolloutEntry(
      tag: 'en',
      readiness: BilLocaleReadiness.production,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'fr',
      readiness: BilLocaleReadiness.production,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'es',
      readiness: BilLocaleReadiness.production,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'tr',
      readiness: BilLocaleReadiness.production,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'de',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'it',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'pt',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
      regionalVariants: ['pt-BR', 'pt-PT'],
    ),
    BilLocaleRolloutEntry(
      tag: 'ur',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'rtl',
    ),
    BilLocaleRolloutEntry(
      tag: 'fa',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'rtl',
    ),
    BilLocaleRolloutEntry(
      tag: 'hi',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'id',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'ms',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'ja',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'ko',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'zh-Hans',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'zh-Hant',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'ru',
      readiness: BilLocaleReadiness.mandatoryPlanned,
      textDirection: 'ltr',
    ),
  ];

  static const highValueCandidates = <BilLocaleRolloutEntry>[
    BilLocaleRolloutEntry(
      tag: 'bn',
      readiness: BilLocaleReadiness.candidate,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'vi',
      readiness: BilLocaleReadiness.candidate,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'th',
      readiness: BilLocaleReadiness.candidate,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'pl',
      readiness: BilLocaleReadiness.candidate,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'nl',
      readiness: BilLocaleReadiness.candidate,
      textDirection: 'ltr',
    ),
    BilLocaleRolloutEntry(
      tag: 'uk',
      readiness: BilLocaleReadiness.candidate,
      textDirection: 'ltr',
    ),
  ];

  /// Exact BCP-47 release targets. Portuguese regional catalogs and Chinese
  /// script catalogs are independent QA/release units; a generic `pt` or `zh`
  /// must never be treated as evidence for both variants.
  static const releaseTargets25 = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };
}
