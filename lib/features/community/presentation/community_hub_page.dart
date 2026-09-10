import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_comment_threads.dart';
import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import '../services/community_post_image_picker.dart';
import 'community_copy.dart';
import 'community_food_submission_sheet.dart';
import 'community_policy_notice.dart';
import 'community_safety_page.dart';
import 'community_taxonomy_sheet.dart';
import 'community_surface.dart';

part 'community_feed_tab.dart';

part 'community_post_card.dart';
part 'community_feed_pagination.dart';
part 'community_post_composer_page.dart';
part 'community_post_detail_page.dart';
part 'community_post_detail_comment_tile.dart';
part 'community_post_widgets.dart';
part 'community_saved_posts_page.dart';
part 'community_my_posts_page.dart';
part 'community_account_widgets.dart';
part 'community_navigation_sheet.dart';
part 'community_friends_tab.dart';
part 'community_food_tab.dart';

class CommunityHubPage extends StatefulWidget {
  const CommunityHubPage({
    this.repository,
    this.client,
    this.postImagePicker,
    super.key,
  });

  final CommunityRepository? repository;
  final SupabaseClient? client;
  final CommunityPostImagePickerContract? postImagePicker;

  @override
  State<CommunityHubPage> createState() => _CommunityHubPageState();
}

class _CommunityHubPageState extends State<CommunityHubPage> {
  CommunityRepository? _repository;
  GlobalKey<_FeedTabState> _feedKey = GlobalKey<_FeedTabState>();
  bool _openingNavigation = false;
  StreamSubscription<AuthState>? _authSubscription;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _watchProductionSession();
  }

  @override
  void didUpdateWidget(covariant CommunityHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.client, widget.client)) {
      _repository = widget.repository ?? _productionRepository();
      _feedKey = GlobalKey<_FeedTabState>();
      _watchProductionSession();
    }
  }

  SupabaseClient? _productionClient() {
    if (widget.client != null) return widget.client;
    if (!AppEnvironment.communityConfigured) return null;
    try {
      final supabase = Supabase.instance;
      return supabase.isInitialized ? supabase.client : null;
    } on AssertionError {
      return null;
    } on StateError {
      return null;
    }
  }

  CommunityRepository? _productionRepository() {
    final client = _productionClient();
    return client?.auth.currentUser == null
        ? null
        : CommunityRepository(client!);
  }

  void _watchProductionSession() {
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    if (widget.repository != null) return;
    final client = _productionClient();
    if (client == null) return;
    _ownerId = client.auth.currentUser?.id;
    _authSubscription = client.auth.onAuthStateChange.listen(
      (state) {
        final nextOwner = state.session?.user.id;
        if (!mounted || nextOwner == _ownerId) return;
        setState(() {
          _ownerId = nextOwner;
          _repository = nextOwner == null ? null : CommunityRepository(client);
          // Discard cached member posts, not just the visible sign-in label.
          _feedKey = GlobalKey<_FeedTabState>();
        });
      },
      onError: (Object _, StackTrace _) {
        // Auth owns refresh/recovery. Do not invent a new session on failure.
      },
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CommunitySurface(child: Builder(builder: _buildHub));

  Widget _buildHub(BuildContext context) {
    final repository = _repository;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          communityText(context, 'BIL Community', 'مجتمع BIL'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('community-settings'),
            tooltip: communityText(
              context,
              'Community actions',
              'إجراءات المجتمع',
            ),
            icon: const Icon(Icons.settings_outlined, size: 21),
            onPressed: repository == null
                ? null
                : () => _openNavigation(context, repository),
          ),
        ],
      ),
      body: repository == null
          ? const _SignInRequired()
          : _FeedTab(
              key: _feedKey,
              repository: repository,
              imagePicker: widget.postImagePicker ?? CommunityPostImagePicker(),
            ),
    );
  }

  Future<void> _openNavigation(
    BuildContext context,
    CommunityRepository repository,
  ) async {
    if (_openingNavigation) return;
    _openingNavigation = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final destination = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => _CommunityNavigationSheet(repository: repository),
      );
      if (!context.mounted || destination == null) return;
      switch (destination) {
        case 'account':
          await pushCommunityPage<void>(
            context,
            CommunityMyPostsPage(
              repository: repository,
              showProfileHeader: true,
            ),
          );
        case 'saved':
          await pushCommunityPage<void>(
            context,
            CommunitySavedPostsPage(repository: repository),
          );
        case 'friends':
          await pushCommunityPage<void>(
            context,
            Scaffold(
              appBar: AppBar(
                title: Text(
                  communityText(
                    context,
                    'Friends and requests',
                    'الأصدقاء والطلبات',
                  ),
                ),
              ),
              body: _FriendsTab(repository: repository),
            ),
          );
        case 'foods':
          await pushCommunityPage<void>(
            context,
            Scaffold(
              appBar: AppBar(
                title: Text(
                  communityText(context, 'Verified food', 'غذاء موثّق'),
                ),
              ),
              body: _CommunityFoodTab(repository: repository),
            ),
          );
        case 'topics':
          await CommunityTaxonomySheet.show(
            context,
            onSelectTag: (tag) {
              _feedKey.currentState?._openComposer(tag: tag);
            },
          );
        default:
          await context.push(destination);
      }
    } finally {
      _openingNavigation = false;
    }
  }
}

PopupMenuItem<String> _communityAction(
  BuildContext context,
  String route,
  String english,
  String arabic,
) => PopupMenuItem<String>(
  value: route,
  child: Row(
    children: [
      BilSemanticIconBadge(
        kind: BilSemanticIcons.kindForRoute(route)!,
        size: 34,
        iconSize: 19,
        shape: BoxShape.rectangle,
      ),
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
