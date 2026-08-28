import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import '../services/community_post_image_picker.dart';
import 'community_copy.dart';
import 'community_taxonomy_sheet.dart';

part 'community_feed_tab.dart';
part 'community_friends_tab.dart';
part 'community_food_tab.dart';

class CommunityHubPage extends StatefulWidget {
  const CommunityHubPage({this.repository, this.postImagePicker, super.key});

  final CommunityRepository? repository;
  final CommunityPostImagePickerContract? postImagePicker;

  @override
  State<CommunityHubPage> createState() => _CommunityHubPageState();
}

class _CommunityHubPageState extends State<CommunityHubPage> {
  CommunityRepository? get _repository {
    if (widget.repository != null) return widget.repository;
    if (!AppEnvironment.cloudConfigured) return null;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return null;
      }
      return CommunityRepository(supabase.client);
    } on AssertionError {
      return null;
    } on StateError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: repository == null
                  ? null
                  : () => context.push('/community/notifications'),
              tooltip: communityText(
                context,
                'Community updates',
                'تحديثات المجتمع',
              ),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            PopupMenuButton<String>(
              enabled: repository != null,
              position: PopupMenuPosition.under,
              tooltip: communityText(
                context,
                'Community actions',
                'إجراءات المجتمع',
              ),
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (route) => context.push(route),
              itemBuilder: (context) => [
                _communityAction(
                  context,
                  '/community/safety',
                  Icons.shield_outlined,
                  'Safety and policy',
                  'الأمان والسياسة',
                ),
                _communityAction(
                  context,
                  '/community/profile',
                  Icons.account_circle_outlined,
                  'Community profile',
                  'ملف المجتمع',
                ),
                _communityAction(
                  context,
                  '/community/connections',
                  Icons.group_outlined,
                  'Friends and requests',
                  'الأصدقاء والطلبات',
                ),
                _communityAction(
                  context,
                  '/community/food-review',
                  Icons.fact_check_outlined,
                  'Review foods',
                  'مراجعة الأغذية',
                ),
                _communityAction(
                  context,
                  '/community/people',
                  Icons.person_search_rounded,
                  'Find people',
                  'البحث عن أصدقاء',
                ),
              ],
            ),
          ],
          title: Text(communityText(context, 'BIL Community', 'مجتمع BIL')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: communityText(context, 'Community', 'المجتمع')),
              Tab(text: communityText(context, 'Friends', 'الأصدقاء')),
              Tab(text: communityText(context, 'Verified food', 'غذاء موثّق')),
            ],
          ),
        ),
        body: repository == null
            ? const _SignInRequired()
            : TabBarView(
                children: [
                  _FeedTab(
                    repository: repository,
                    imagePicker:
                        widget.postImagePicker ?? CommunityPostImagePicker(),
                  ),
                  _FriendsTab(repository: repository),
                  _CommunityFoodTab(repository: repository),
                ],
              ),
      ),
    );
  }
}

PopupMenuItem<String> _communityAction(
  BuildContext context,
  String route,
  IconData icon,
  String english,
  String arabic,
) => PopupMenuItem<String>(
  value: route,
  child: Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Text(communityText(context, english, arabic))),
    ],
  ),
);

class _SignInRequired extends StatelessWidget {
  const _SignInRequired();

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 54),
              const SizedBox(height: 16),
              Text(
                communityText(
                  context,
                  'Sign in to open community, friends, and messages.',
                  'سجّل الدخول لفتح المجتمع والأصدقاء والرسائل.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                communityText(
                  context,
                  'Health logs are never posted automatically. You choose every share.',
                  'لا تُنشر سجلاتك الصحية تلقائيًا. أنت تختار كل مشاركة.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login_rounded),
                label: Text(communityText(context, 'Sign in', 'تسجيل الدخول')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('community-browse-topics-signed-out'),
                onPressed: () => CommunityTaxonomySheet.show(
                  context,
                  onSelectTag: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          communityText(
                            context,
                            'Sign in to start a discussion in this topic.',
                            'سجّل الدخول لبدء نقاش في هذا الموضوع.',
                          ),
                        ),
                      ),
                    );
                  },
                ),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text(CommunityTaxonomySheet.browseLabel(context)),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/trust-support'),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(
                  communityText(
                    context,
                    'Privacy & safety',
                    'الخصوصية والأمان',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
