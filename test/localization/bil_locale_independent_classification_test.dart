import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_rollout_manifest.dart';
import 'package:body_intelligence_log/app/localization/bil_reviewed_locale_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 25 exact runtime catalogs classify production ready', () {
    final rollout = <BilLocaleRolloutEntry>[
      ...BilLocaleRolloutManifest.mandatory18,
      ...BilLocaleRolloutManifest.highValueCandidates,
    ];
    final drafts = {
      for (final catalog in BilDraftLocaleCatalogs.all)
        catalog.localeTag.toLowerCase(): catalog,
    };
    final ready = <String>[];
    final hidden = <String>[];

    for (final entry in rollout) {
      final tag = entry.tag.toLowerCase();
      final relatedDrafts = [
        ?drafts[tag],
        for (final variant in entry.regionalVariants)
          ?drafts[variant.toLowerCase()],
      ];
      final canonicalTargets = entry.regionalVariants.isEmpty
          ? <String>{entry.tag}
          : entry.regionalVariants.toSet();
      final isReady = canonicalTargets.every(
        BilLocalePolicy.productionTags.contains,
      ) ||
          (relatedDrafts.isNotEmpty &&
              relatedDrafts.every((draft) => draft.eligibleForProduction));
      (isReady ? ready : hidden).add(entry.tag);
    }

    expect(ready, hasLength(24));
    expect(hidden, isEmpty);
    expect(BilLocalePolicy.productionTags, hasLength(25));
    expect(
      BilDraftLocaleCatalogs.all.every(
        (catalog) => !catalog.eligibleForProduction,
      ),
      isTrue,
    );
  });
}
