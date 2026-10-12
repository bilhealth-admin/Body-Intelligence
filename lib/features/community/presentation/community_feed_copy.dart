part of 'community_hub_page.dart';

extension _CommunityFeedCopy on _FeedTabState {
  String _feedModeLabel(CommunityFeedMode mode) =>
      _communityFeedModeLabel(context, mode);

  String _emptyFeedMessage() => switch (_selectedFeedMode) {
    CommunityFeedMode.following => communityText(
      context,
      'Follow members to see their approved posts here.',
      'تابع أعضاءً لتظهر منشوراتهم المعتمدة هنا.',
    ),
    CommunityFeedMode.friends => communityText(
      context,
      'Accepted friends will appear here when they publish.',
      'ستظهر منشورات أصدقائك المقبولين هنا عند النشر.',
    ),
    CommunityFeedMode.forYou => communityText(
      context,
      'Nothing personalized yet. Follow people, topics, or Circles to shape this feed.',
      'لا توجد توصيات مخصصة بعد. تابع أشخاصًا أو مواضيع أو دوائر لتخصيص هذا الموجز.',
    ),
    CommunityFeedMode.explore => communityText(
      context,
      'No approved posts yet. Start the first conversation.',
      'لا توجد منشورات معتمدة بعد. ابدأ أول محادثة.',
    ),
  };
}
