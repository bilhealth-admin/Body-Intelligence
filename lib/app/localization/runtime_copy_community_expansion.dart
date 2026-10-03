import 'bil_locale_policy.dart';

part 'runtime_copy_community_expansion_west_core.dart';
part 'runtime_copy_community_expansion_west.dart';
part 'runtime_copy_community_expansion_west_more.dart';
part 'runtime_copy_community_expansion_south_asia.dart';
part 'runtime_copy_community_expansion_southeast_asia.dart';
part 'runtime_copy_community_expansion_east_asia.dart';
part 'runtime_copy_community_expansion_zh_hant.dart';
part 'runtime_copy_community_expansion_ru.dart';
part 'runtime_copy_community_expansion_uk.dart';
part 'runtime_copy_community_expansion_bn.dart';
part 'runtime_copy_community_expansion_th.dart';

/// Reviewed expansion copy for Community surfaces introduced after the
/// original social catalog. English remains the source string and Arabic is
/// supplied directly by communityText call-sites; this catalog closes every
/// other production locale without falling back to English.
abstract final class CommunityExpansionRuntimeCopy {
  static const sources = <String>[
    "{actor} accepted your friend request",
    "{actor} commented on your post",
    "{actor} followed you",
    "{actor} liked your post",
    "{actor} mentioned you in a post",
    "{actor} replied to your comment",
    "{actor} sent you a friend request",
    "{inviterName} invited you to join BIL",
    "{total} votes",
    "10K Steps",
    "A welcoming place for safe, gradual fitness progress.",
    "AI Coach usage",
    "Accept invitation",
    "Accepted friends will appear here when they publish.",
    "Accepting records who invited you. It does not grant Gold by itself.",
    "Add a poll",
    "Add option",
    "Allow multiple choices",
    "Another invitation is already linked to this account.",
    "Ask one question with 2–6 options.",
    "BIL Gold activity",
    "BIL Rewards",
    "BIL could not verify this invitation safely.",
    "BIL could not verify your reward state safely.",
    "BIL invitation",
    "Balance adjustment",
    "Be respectful, avoid private health details, and follow Community policy.",
    "Beginner Fitness",
    "Better Sleep",
    "Build a consistent walking habit and encourage one another.",
    "Challenge update",
    "Choose one option",
    "Choose one or more",
    "Choose which social sections other members can see. Health data is never included.",
    "Circle — optional",
    "Circles",
    "City or place label",
    "Claimed",
    "Comments & mentions",
    "Community level",
    "Community profile privacy",
    "Community quest",
    "Community quest reward",
    "Community topics",
    "Complete the verified Community action to make progress.",
    "Complete your Community profile",
    "Could not accept this invitation safely. Try again.",
    "Could not claim this reward safely. Try again.",
    "Could not load more history.",
    "Could not record your vote. Try again.",
    "Could not search mentions right now.",
    "Could not update this circle safely. Try again.",
    "Could not update this topic. Try again.",
    "Create a valuable post",
    "Create an account",
    "Daily",
    "Discuss strength training, consistency, and recovery.",
    "Earn",
    "Earned",
    "Earned and used BIL Gold entries will appear here.",
    "Edit profile",
    "Finish the poll: add a question and 2–6 different options.",
    "Follow",
    "Follow members to see their approved posts here.",
    "Followers",
    "Following",
    "For You",
    "Friend requests, accepted connections, and unread messages will appear here.",
    "Go",
    "Grid view",
    "Healthy Eating",
    "Hide replies",
    "Invitation accepted and friendship created. Gold is still gated by new-account and server integrity checks.",
    "Invitation saved.",
    "Invitation unavailable",
    "Invite a friend",
    "Join",
    "Join a Circle to post inside it.",
    "Leave",
    "Likes & saves",
    "List view",
    "Load more comment threads",
    "Load more replies",
    "Location — optional",
    "Mention people — optional",
    "Mention up to 10 discoverable Community members. They are notified only after the post is approved.",
    "New",
    "New badge earned",
    "New comment on your post",
    "New follower",
    "New friend request",
    "New post",
    "New reply to your comment",
    "No Circle",
    "No Gold activity yet",
    "No active quests right now",
    "No approved posts in this circle yet.",
    "No approved posts in this topic yet.",
    "No approved posts yet. Start the first conversation.",
    "No updates in this category yet.",
    "No visible posts yet.",
    "Nothing personalized yet. Follow people, topics, or Circles to shape this feed.",
    "Nothing to show here yet.",
    "Off by default. BIL Gold and Community XP remain separate from your subscription.",
    "Option {index}",
    "Optional text only. BIL does not request GPS for Community posts.",
    "Poll",
    "Poll closed",
    "Poll question",
    "Post in circle",
    "Posts are private on this profile.",
    "Quality, moderation, and meaningful engagement are checked first.",
    "Quest completed",
    "Ramadan & Fasting",
    "Ready to claim",
    "Remove option",
    "Reward already claimed.",
    "Reward claimed.",
    "Reward rules are activated by BIL only after server-side verification and safety checks are ready.",
    "Rewards",
    "Rewards are unavailable",
    "Rewards unlock only after the verified friend relationship qualifies.",
    "Running",
    "Search handle",
    "Seen",
    "Set up your public identity and privacy choices.",
    "Share culturally respectful fasting routines and experiences.",
    "Share practical meal ideas and sustainable eating habits.",
    "Share running progress, routines, and encouragement.",
    "Share sustainable progress and support without comparison pressure.",
    "Show followers",
    "Show following",
    "Show friends",
    "Show membership tier",
    "Show posts on my profile",
    "Sign in to accept",
    "Sign in to view BIL Gold and rewards.",
    "Sign in to view Community profiles.",
    "Someone liked your post",
    "Spendable Community currency",
    "Start a post",
    "Starter",
    "Support better sleep routines without medical claims.",
    "This invitation is invalid or expired.",
    "This invitation is invalid, expired, or already used.",
    "This invitation is unavailable.",
    "This invitation was already used.",
    "This list is unavailable right now.",
    "This reward is not available right now.",
    "Topics are unavailable right now. You can still publish.",
    "Topics — choose up to 3",
    "Tracked BIL invitations are not active yet.",
    "Tracked invitations are not active yet.",
    "Used",
    "View {count} replies",
    "Vote",
    "Weekly",
    "Weight-Loss Journey",
    "You cannot accept your own invitation.",
    "You earned a Community reward",
    "You were mentioned in a post",
    "Your friend request was accepted",
    "Your post was saved",
    "You’re friends — view profile",
    "followers",
    "members",
    "posts",
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
    ..._communityExpansionWestCoreRows,
    ..._communityExpansionWestRows,
    ..._communityExpansionWestMoreRows,
    ..._communityExpansionSouthAsiaRows,
    ..._communityExpansionSoutheastAsiaRows,
    ..._communityExpansionEastAsiaRows,
    ..._communityExpansionZhHantRows,
    ..._communityExpansionRuRows,
    ..._communityExpansionUkRows,
    ..._communityExpansionBnRows,
    ..._communityExpansionThRows,
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = _canonicalTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing Community expansion copy for $tag.');
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
              _protectedTermsMatch(row),
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
      for (final term in const ['BIL']) {
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
}
