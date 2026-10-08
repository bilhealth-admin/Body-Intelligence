import 'bil_locale_policy.dart';

part 'runtime_copy_integration_gap_europe.dart';
part 'runtime_copy_integration_gap_south.dart';
part 'runtime_copy_integration_gap_east.dart';

/// BIL-01..08 integration copy. Values are authored for each production
/// locale; incomplete production rows fail closed rather than silently showing English.
abstract final class IntegrationRuntimeCopy {
  static const sources = <String>[
    "+5 AI tokens confirmed by the server receipt",
    "An eligible approved post may earn +5 AI tokens only when the server reward receipt confirms the grant. Approval alone does not guarantee a token award; daily limits may apply. AI tokens are not BIL Gold and cannot be cashed out. Opening or saving a draft earns nothing.",
    "Approved · no AI token grant was confirmed",
    "Cancel — do not save",
    "Display units updated.",
    "Forget this memory?",
    "Hidden",
    "Liked post",
    "Likes are private. Only this member can view them.",
    "Load more likes",
    "Load more media",
    "Media is private on this profile.",
    "Multiple choice",
    "No visible liked posts yet.",
    "No visible media yet.",
    "No visible replies yet.",
    "Notification permission was not granted, so the reminder was not changed.",
    "Only the memory you selected will be deleted.",
    "Open the post to review the moderation result",
    "Post approved. No AI token grant was confirmed for this decision.",
    "Post review result",
    "Read-only mode. No food was logged.",
    "Reminder updated and verified.",
    "Replies are private on this profile.",
    "Retry this review to read its saved result.",
    "Single choice",
    "The reminder could not be verified in the device scheduler. The previous setting was restored.",
    "This memory changed after review. Refresh and select it again.",
    "This post could not be loaded for the current account.",
    "Write permission changed during this action. Review the shield setting and prepare the action again.",
    "Your post needs changes",
    "Your post was approved",
    "Your post was approved · +5 AI tokens",
  ];

  static const rows = <String, List<String>>{
    'en': sources,
    ..._integrationEurope,
    ..._integrationSouth,
    ..._integrationEast,
  };

  static String? resolve(String english, String localeTag) {
    final index = sources.indexOf(english);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing integrated copy for locale $tag');
    }
    return row[index];
  }

  static bool get balanced {
    if (rows.keys.toSet().length != BilLocalePolicy.productionTags.length ||
        !rows.keys.toSet().containsAll(BilLocalePolicy.productionTags)) {
      return false;
    }
    for (final localeTag in BilLocalePolicy.productionTags) {
      final row = rows[localeTag];
      if (row == null || row.length != sources.length) return false;
      for (var i = 0; i < sources.length; i++) {
        final translation = row[i];
        if (translation.trim().isEmpty ||
            (localeTag != 'en' && translation == sources[i])) {
          return false;
        }
        final expected = RegExp(
          r'\{[^}]+\}',
        ).allMatches(sources[i]).map((m) => m.group(0)).toList();
        final actual = RegExp(
          r'\{[^}]+\}',
        ).allMatches(translation).map((m) => m.group(0)).toList();
        if (expected.join('|') != actual.join('|')) return false;
      }
    }
    return true;
  }
}
