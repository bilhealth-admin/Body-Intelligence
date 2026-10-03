import 'bil_locale_policy.dart';

part 'runtime_copy_community_reference_west.dart';
part 'runtime_copy_community_reference_europe.dart';
part 'runtime_copy_community_reference_south_asia.dart';
part 'runtime_copy_community_reference_southeast_asia.dart';
part 'runtime_copy_community_reference_east_asia.dart';

/// Reviewed copy for the reference-parity Community surfaces: creator profile,
/// persistent drafts, collaboration, profile cover, and reference composer.
///
/// English remains the canonical source string. Arabic stays explicit at the
/// call-site so RTL review remains first-class. Every other production locale
/// is required here and validated for source order and placeholders.
abstract final class CommunityReferenceRuntimeCopy {
  static const sources = <String>[
    'Add hashtag',
    'Add something before saving a draft.',
    'Add up to 10 searchable hashtags.',
    'Appreciated',
    'Approved moments',
    'BIL Community profile',
    'BIL will return to the branded Community cover.',
    'Badges',
    'Certification',
    'Certification revoked',
    'Certified creator',
    'Choose a valid JPEG, PNG, or WebP image up to 5 MB.',
    'Collaboration accepted.',
    'Collaboration declined.',
    'Collaboration invitation',
    'Collaboration invitation accepted',
    'Collaboration — optional',
    'Comments received',
    'Community badges',
    'Community builder',
    'Community home',
    'Connector',
    'Contributor',
    'Conversation starter',
    'Could not delete this draft.',
    'Could not open sharing right now.',
    'Could not open this draft. Try again.',
    'Could not remove the profile cover.',
    'Could not save this draft. Nothing was published.',
    'Could not search collaborators right now.',
    'Could not update follow state.',
    'Could not update the profile cover.',
    'Could not update this collaboration. Try again.',
    'Creator Center',
    'Creator Rewards',
    'Creator tools',
    'Declined',
    'Delete draft',
    'Draft saved securely.',
    'Drafts',
    'First moment',
    'Follows you',
    'Give this moment a clear title',
    'Hashtags — optional',
    'Invite up to 3 Community members. Invitations are sent only after human approval, and a collaborator appears publicly only after accepting.',
    'Likes received',
    'Locked',
    'Moments',
    'Moments are private on this profile.',
    'New followers',
    'No BIL creator certification has been granted to this profile.',
    'No approved reviews yet.',
    'No saved drafts yet.',
    'No visible moments yet.',
    'Not certified',
    'Open',
    'Photo draft',
    'Profile cover updated.',
    'Published',
    'Qualified referrals',
    'Remove profile cover?',
    'Reviews',
    'Reviews are private on this profile.',
    'Save draft',
    'Save unfinished Community posts and continue later.',
    'Saved Community draft',
    'Saved draft',
    'Search by name or @handle',
    'Search collaborators',
    'Share profile',
    'Task Center',
    'The voice transcript would exceed the 1200-character post limit.',
    'This Circle is unavailable right now.',
    'This certification is verified by BIL server authority.',
    'This profile does not currently hold an active certification.',
    'This topic is unavailable right now.',
    'Title',
    'Untitled draft',
    'Update draft',
    'Updates',
    'Use one hashtag without spaces, up to 40 characters.',
    'With',
    'You can add up to 10 hashtags.',
    '{actor} accepted your collaboration invitation',
    '{actor} invited you to collaborate on a post',
    'Highest configured Community level reached',
    '{xp} XP · Next: Lv {level} at {target} XP',
    'Progress toward Lv {level} · {target} XP target',
  ];

  static const supported = <String>{
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

  static const rows = <String, List<String>>{
    ..._communityReferenceWestRows,
    ..._communityReferenceEuropeRows,
    ..._communityReferenceSouthAsiaRows,
    ..._communityReferenceSoutheastAsiaRows,
    ..._communityReferenceEastAsiaRows,
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = _canonicalTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing Community reference copy for $tag.');
    }
    return row[index];
  }

  static bool get balanced {
    final productionExtended = BilLocalePolicy.productionTags
        .where((tag) => tag != 'en' && tag != 'ar')
        .toSet();
    return supported.length == productionExtended.length &&
        supported.containsAll(productionExtended) &&
        productionExtended.containsAll(supported) &&
        rows.keys.toSet().containsAll(supported) &&
        supported.containsAll(rows.keys) &&
        rows.values.every(
          (row) =>
              row.length == sources.length &&
              row.every((value) => value.trim().isNotEmpty) &&
              _placeholdersMatch(row) &&
              _protectedTermsMatch(row) &&
              _isTranslated(row),
        );
  }

  static String? _canonicalTag(String localeTag) {
    final exact = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (exact != null && supported.contains(exact)) return exact;
    final language = localeTag
        .trim()
        .replaceAll('_', '-')
        .toLowerCase()
        .split('-')
        .first;
    final matches = supported
        .where(
          (candidate) =>
              candidate.toLowerCase() == language ||
              candidate.toLowerCase().startsWith('$language-'),
        )
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  static bool _isTranslated(List<String> translations) {
    for (var index = 0; index < sources.length; index++) {
      if (translations[index] == sources[index]) return false;
    }
    return true;
  }

  static bool _placeholdersMatch(List<String> translations) {
    for (var index = 0; index < sources.length; index++) {
      final expected = _placeholders(sources[index]);
      final actual = _placeholders(translations[index]);
      if (expected.length != actual.length) return false;
      for (var p = 0; p < expected.length; p++) {
        if (expected[p] != actual[p]) return false;
      }
    }
    return true;
  }

  static bool _protectedTermsMatch(List<String> translations) {
    for (var index = 0; index < sources.length; index++) {
      if (sources[index].contains('BIL') &&
          !translations[index].contains('BIL')) {
        return false;
      }
    }
    return true;
  }

  static List<String> _placeholders(String value) => RegExp(
    r'\{[^}]+\}',
  ).allMatches(value).map((match) => match.group(0)!).toList(growable: false);
}
