import 'bil_locale_policy.dart';

part 'runtime_copy_community_social_core.dart';
part 'runtime_copy_community_social_europe.dart';
part 'runtime_copy_community_social_asia.dart';
part 'runtime_copy_community_social_east.dart';

/// Reviewed 25-locale copy for Community posts, comments, saved posts, and
/// public BIL friend-code journeys.
///
/// The positional catalog deliberately validates every shipped locale and
/// placeholder. Runtime widgets continue to own presentation and behavior.
abstract final class CommunitySocialRuntimeCopy {
  static const sources = <String>[
    'Add @{handle} on BIL: {uri}',
    'Add Friend',
    'Block',
    'Block this member?',
    'Camera access is denied or restricted. Enable it in system settings and retry.',
    'Cancel reply',
    'Code scanning needs an iOS or Android camera.',
    'Comment was not sent. Your text is kept; retry safely.',
    'Comments',
    'Could not load older posts. Try again.',
    'Could not update saved posts. Try again.',
    'Could not update this reaction. Try again.',
    'Friend request could not be sent. Try again.',
    'Let a friend scan this code. It only identifies your public Community profile; it cannot sign anyone in.',
    'Load more',
    'Load more comments',
    'Load older posts',
    'Member blocked.',
    'My BIL Code',
    'No comments yet. Start a respectful conversation.',
    'Point the camera at a BIL friend code. Nothing is uploaded.',
    'Post',
    'Posts you save are private and appear here.',
    'Remove from saved',
    'Replace code',
    'Replace this code',
    'Replace your BIL Code?',
    'Reply',
    'Replying to {member}',
    'Report sent for human review.',
    'Retry camera',
    'Review request',
    'Save post',
    'Saved posts',
    'Scan Friend Code',
    'Send comment',
    'Share code',
    'Share post',
    'Show less',
    'Show more',
    'This code is invalid, expired, private, or unavailable.',
    'This is not a current BIL friend code.',
    'Write a comment',
    'Write a comment first.',
    'You will no longer see each other in Community or messages.',
    'Your BIL Code is unavailable right now. Try again.',
    'Your BIL Code is unavailable. Sign in, complete your Community profile, and try again.',
    'Your old code will stop working. Friends will need the new one.',
  ];

  static const supported = <String>{
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

  static const rows = <String, List<String>>{
    ..._communitySocialCoreRows,
    ..._communitySocialEuropeRows,
    ..._communitySocialAsiaRows,
    ..._communitySocialEastRows,
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = _canonicalTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing community-social copy for $tag.');
    }
    return row[index];
  }

  static bool get balanced =>
      supported.length == BilLocalePolicy.productionTags.length &&
      supported.containsAll(BilLocalePolicy.productionTags) &&
      BilLocalePolicy.productionTags.containsAll(supported) &&
      supported.containsAll(rows.keys) &&
      rows.keys.toSet().containsAll(supported) &&
      _sameValues(rows['en'], sources) &&
      rows.entries.every(
        (entry) =>
            entry.value.length == sources.length &&
            entry.value.every((value) => value.trim().isNotEmpty) &&
            _placeholdersMatch(entry.value) &&
            _protectedTermsMatch(entry.value) &&
            (entry.key == 'en' || _isTranslated(entry.value)),
      );

  static String? _canonicalTag(String localeTag) {
    final exact = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (exact != null) return exact;
    final language = localeTag
        .trim()
        .replaceAll('_', '-')
        .toLowerCase()
        .split('-')
        .first;
    final matches = supported
        .where((candidate) => candidate.toLowerCase() == language)
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
      for (
        var placeholderIndex = 0;
        placeholderIndex < expected.length;
        placeholderIndex++
      ) {
        if (expected[placeholderIndex] != actual[placeholderIndex]) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _protectedTermsMatch(List<String> translations) {
    for (var index = 0; index < sources.length; index++) {
      for (final term in const ['BIL', 'iOS', 'Android']) {
        if (sources[index].contains(term) &&
            !translations[index].contains(term)) {
          return false;
        }
      }
    }
    return true;
  }

  static List<String> _placeholders(String value) => RegExp(
    r'\{[^}]+\}',
  ).allMatches(value).map((match) => match.group(0)!).toList(growable: false);

  static bool _sameValues(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < right.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
