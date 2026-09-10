part of 'community_hub_page.dart';

/// A single, discoverable entry point keeps the landing screen devoted to posts.
class _CommunityNavigationSheet extends StatefulWidget {
  const _CommunityNavigationSheet({required this.repository});
  final CommunityRepository repository;

  @override
  State<_CommunityNavigationSheet> createState() =>
      _CommunityNavigationSheetState();
}

class _CommunityNavigationSheetState extends State<_CommunityNavigationSheet> {
  late final Future<bool> _moderator = widget.repository.isCommunityModerator();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      child: FutureBuilder<bool>(
        future: _moderator,
        builder: (context, snapshot) => ListView(
          key: const Key('community-navigation-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: Text(
                communityText(context, 'Community actions', 'إجراءات المجتمع'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _item(
              'account',
              Icons.account_circle_outlined,
              'Community profile',
              'ملف المجتمع',
              subtitle: communityText(context, 'My posts', 'منشوراتي'),
            ),
            _item(
              'friends',
              Icons.people_outline_rounded,
              'Friends and requests',
              'الأصدقاء والطلبات',
            ),
            _item(
              '/community/code',
              Icons.qr_code_2_rounded,
              'My BIL Code',
              'رمز BIL الخاص بي',
              key: 'community-my-bil-code',
            ),
            _item(
              '/community/people',
              Icons.person_search_outlined,
              'Find people',
              'البحث عن أصدقاء',
            ),
            _item(
              'saved',
              Icons.bookmark_border_rounded,
              'Saved posts',
              'المنشورات المحفوظة',
              key: 'community-saved-posts',
            ),
            _item(
              '/community/notifications',
              Icons.notifications_none_rounded,
              'Community updates',
              'تحديثات المجتمع',
            ),
            const Divider(indent: 20, endIndent: 20, height: 20),
            _item(
              'foods',
              Icons.fact_check_outlined,
              'Verified food',
              'غذاء موثّق',
            ),
            _item(
              'topics',
              Icons.grid_view_rounded,
              CommunityTaxonomySheet.browseLabel(context),
              CommunityTaxonomySheet.browseLabel(context),
              key: 'community-browse-topics',
            ),
            _item(
              '/community/safety',
              Icons.shield_outlined,
              'Safety and policy',
              'الأمان والسياسة',
            ),
            _item(
              '/community/food-review',
              Icons.fact_check_outlined,
              'Review foods',
              'مراجعة الأغذية',
            ),
            if (snapshot.data == true)
              _item(
                '/community/moderation',
                Icons.admin_panel_settings_outlined,
                'Community moderation',
                'مراجعة المجتمع',
              ),
          ],
        ),
      ),
    ),
  );

  Widget _item(
    String value,
    IconData icon,
    String english,
    String arabic, {
    String? key,
    String? subtitle,
  }) => ListTile(
    key: Key(key ?? 'community-nav-$value'),
    minTileHeight: 52,
    contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 16, 4),
    leading: Icon(
      icon,
      size: 21,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    title: Text(communityText(context, english, arabic)),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: Icon(
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left_rounded
          : Icons.chevron_right_rounded,
      size: 20,
    ),
    onTap: () => Navigator.pop(context, value),
  );
}
