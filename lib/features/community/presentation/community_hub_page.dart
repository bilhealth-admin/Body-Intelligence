import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_copy.dart';
import 'community_taxonomy_sheet.dart';

class CommunityHubPage extends StatefulWidget {
  const CommunityHubPage({this.repository, super.key});

  final CommunityRepository? repository;

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
                  _FeedTab(repository: repository),
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

class _FeedTab extends StatefulWidget {
  const _FeedTab({required this.repository});
  final CommunityRepository repository;

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _composer = TextEditingController();
  late Future<List<CommunityPost>> _feed = widget.repository.loadFeed();
  bool _publishing = false;
  bool _managingPost = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing || _managingPost) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() => _publishing = true);
    try {
      await widget.repository.publishPost(text);
      final refreshedFeed = widget.repository.loadFeed();
      _composer.clear();
      if (mounted) {
        setState(() {
          _feed = refreshedFeed;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not publish now. Your text is kept so you can retry.',
              'تعذر نشر المشاركة الآن. احتفظنا بالنص لتعيد المحاولة.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _managePost(CommunityPost post, String action) async {
    if (_publishing || _managingPost) return;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(communityText(context, 'Delete post?', 'حذف المشاركة؟')),
          content: Text(
            communityText(
              context,
              'This removes your post from Community.',
              'سيؤدي ذلك إلى إزالة مشاركتك من المجتمع.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(communityText(context, 'Delete', 'حذف')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _managingPost = true);
    try {
      if (action == 'report') {
        await widget.repository.report(
          targetKind: 'post',
          targetId: post.id,
          reason: 'user_reported_from_feed',
        );
      } else if (action == 'delete') {
        await widget.repository.deletePost(post.id);
        final refreshedFeed = widget.repository.loadFeed();
        if (mounted) {
          setState(() {
            _feed = refreshedFeed;
          });
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'report'
                ? communityText(
                    context,
                    'Report sent for review.',
                    'تم إرسال البلاغ للمراجعة.',
                  )
                : communityText(context, 'Post deleted.', 'تم حذف المشاركة.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not complete that action safely. Try again.',
              'تعذر تنفيذ الإجراء بأمان. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _managingPost = false);
    }
  }

  Future<void> _refresh() async {
    if (_publishing || _managingPost) return;
    final refreshedFeed = widget.repository.loadFeed();
    setState(() {
      _feed = refreshedFeed;
    });
    await refreshedFeed;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: OutlinedButton.icon(
          key: const Key('community-browse-topics'),
          onPressed: _publishing || _managingPost
              ? null
              : () => CommunityTaxonomySheet.show(
                  context,
                  onSelectTag: (tag) {
                    _composer.text = '#$tag ';
                    _composer.selection = TextSelection.collapsed(
                      offset: _composer.text.length,
                    );
                  },
                ),
          icon: const Icon(Icons.grid_view_rounded),
          label: Text(CommunityTaxonomySheet.browseLabel(context)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _composer,
          enabled: !_publishing && !_managingPost,
          maxLength: 1200,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: communityText(
              context,
              'Share an experience or win',
              'شارك تجربة أو إنجازًا',
            ),
            helperText: communityText(
              context,
              'Do not share private health data you want to keep private.',
              'لا تشارك بيانات صحية خاصة لا تريد ظهورها.',
            ),
            helperMaxLines: 2,
            suffixIcon: IconButton(
              onPressed: _publishing || _managingPost ? null : _publish,
              icon: _publishing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<CommunityPost>>(
          future: _feed,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _InlineError(onRetry: _refresh);
            }
            final posts = snapshot.data ?? const [];
            if (posts.isEmpty) {
              return Center(
                child: Text(
                  communityText(
                    context,
                    'No posts yet. Start the first conversation.',
                    'لا توجد مشاركات بعد. ابدأ بأول مشاركة.',
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: post.authorAvatarUrl == null
                            ? null
                            : NetworkImage(post.authorAvatarUrl!),
                        child: post.authorAvatarUrl == null
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: _NaturalCommunityText(
                        post.authorName ??
                            communityText(context, 'BIL member', 'عضو BIL'),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          _NaturalCommunityText(post.body),
                          const SizedBox(height: 6),
                          Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatShortDate(post.createdAt.toLocal()),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        key: Key('community-post-actions-${post.id}'),
                        enabled: !_publishing && !_managingPost,
                        onSelected: (value) => _managePost(post, value),
                        itemBuilder: (_) =>
                            post.authorId == widget.repository.currentUserId
                            ? [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    communityText(context, 'Delete', 'حذف'),
                                  ),
                                ),
                              ]
                            : [
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text(
                                    communityText(context, 'Report', 'إبلاغ'),
                                  ),
                                ),
                              ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _NaturalCommunityText extends StatelessWidget {
  const _NaturalCommunityText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final direction = RegExp(r'[\u0600-\u08ff]').hasMatch(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
    return Directionality(
      textDirection: direction,
      child: Text(text, textAlign: TextAlign.start),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.repository});
  final CommunityRepository repository;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: repository.loadFriendshipsWithProfiles(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) return const _InlineError();
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty) {
        return Center(
          child: Text(
            communityText(
              context,
              'No requests or friendships yet.',
              'لا توجد طلبات أو صداقات بعد.',
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final profile = row['profile'] as Map<String, dynamic>?;
          final otherId = row['other_user_id'] as String;
          final name = profile?['display_name'] as String? ?? 'BIL member';
          final accepted = row['status'] == 'accepted';
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: profile?['avatar_url'] == null
                    ? null
                    : NetworkImage(profile!['avatar_url'] as String),
                child: profile?['avatar_url'] == null
                    ? const Icon(Icons.person_rounded)
                    : null,
              ),
              title: Text(name),
              subtitle: Text(row['status'] as String? ?? 'pending'),
              trailing: accepted
                  ? const Icon(Icons.chat_bubble_outline_rounded)
                  : const Icon(Icons.hourglass_top_rounded),
              onTap: accepted
                  ? () => context.push(
                      '/community/chat/$otherId?name=${Uri.encodeQueryComponent(name)}',
                    )
                  : null,
            ),
          );
        },
      );
    },
  );
}

class _CommunityFoodTab extends StatefulWidget {
  const _CommunityFoodTab({required this.repository});
  final CommunityRepository repository;

  @override
  State<_CommunityFoodTab> createState() => _CommunityFoodTabState();
}

class _CommunityFoodTabState extends State<_CommunityFoodTab> {
  final _name = TextEditingController();
  final _serving = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _serving,
      _calories,
      _protein,
      _carbs,
      _fat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final values = [_serving, _calories, _protein, _carbs, _fat]
        .map((controller) => double.tryParse(controller.text.trim()))
        .toList(growable: false);
    if (_name.text.trim().length < 2 || values.any((value) => value == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Complete all required values.',
              'أكمل القيم المطلوبة.',
            ),
          ),
        ),
      );
      return;
    }
    await widget.repository.submitFood(
      CommunityFoodDraft(
        name: _name.text,
        servingGrams: values[0]!,
        calories: values[1]!,
        protein: values[2]!,
        carbohydrate: values[3]!,
        fat: values[4]!,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          communityText(
            context,
            'Food submitted for review. It will not appear as verified before validation.',
            'أُرسل الغذاء للمراجعة. لن يظهر كموثّق قبل التحقق.',
          ),
        ),
      ),
    );
  }

  void _openForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                communityText(
                  context,
                  'Submit community food',
                  'إضافة غذاء مجتمعي',
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Name', 'الاسم'),
                ),
              ),
              TextField(
                controller: _serving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(
                    context,
                    'Serving grams',
                    'الحصة بالغرام',
                  ),
                ),
              ),
              TextField(
                controller: _calories,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Calories', 'السعرات'),
                ),
              ),
              TextField(
                controller: _protein,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Protein', 'البروتين'),
                ),
              ),
              TextField(
                controller: _carbs,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(
                    context,
                    'Carbohydrate',
                    'الكربوهيدرات',
                  ),
                ),
              ),
              TextField(
                controller: _fat,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Fat', 'الدهون'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  communityText(context, 'Send for review', 'إرسال للمراجعة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: widget.repository.loadMyFoodSubmissions(),
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          communityText(
            context,
            'Arabic and Gulf foods are reviewed before approval, and your contribution remains attributed to you.',
            'الأغذية العربية والخليجية تمر بمراجعة قبل اعتمادها، وتظل مساهمتك منسوبة لك.',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openForm,
          icon: const Icon(Icons.add_rounded),
          label: Text(communityText(context, 'Submit food', 'إضافة غذاء')),
        ),
        const SizedBox(height: 16),
        for (final row in snapshot.data ?? const <Map<String, dynamic>>[])
          Card(
            child: ListTile(
              title: Text(row['canonical_name'] as String),
              subtitle: Text(row['status'] as String),
              trailing: const Icon(Icons.verified_outlined),
            ),
          ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          communityText(
            context,
            'Community could not be loaded. No data was lost.',
            'تعذر تحميل المجتمع الآن. لم تُفقد أي بيانات.',
          ),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
          ),
        ],
      ],
    ),
  );
}
