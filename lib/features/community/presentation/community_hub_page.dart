import 'community_attention_scope.dart';
import 'bil_gold_coin.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../../../shared/widgets/bil_reference_bottom_bar.dart';
import '../../../app/router/bil_quick_add_presenter.dart';
import '../../profile/services/profile_photo_service.dart';
import '../data/community_repository.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_composer_persistence.dart';
import '../domain/community_comment_threads.dart';
import '../domain/community_circles.dart';
import '../domain/community_feed_modes.dart';
import '../domain/community_models.dart';
import '../domain/community_reference_parity.dart';
import '../domain/community_polls.dart';
import '../domain/community_rewards.dart';
import '../domain/community_post_context.dart';
import '../domain/community_text_policy.dart';
import '../domain/community_text_limits.dart';
import '../domain/community_topics.dart';
import '../services/community_post_image_picker.dart';
import '../services/community_composer_voice_input_service.dart';
import '../services/community_entry_coordinator.dart';
import '../services/community_owner_operation.dart';
import '../services/community_publish_operation_service.dart';
import 'community_copy.dart';
import 'community_body_counter.dart';
import 'community_entry_gate.dart';
import 'community_connections_page.dart';
import 'community_food_submission_sheet.dart';
import 'community_policy_notice.dart';
import 'community_return_button.dart';
import 'community_safety_page.dart';
import 'community_taxonomy_sheet.dart';
import 'community_surface.dart';
import 'community_post_gallery_page.dart';
import 'community_welcome.dart';
import 'community_sapphire.dart';

part 'community_feed_tab.dart';
part 'community_feed_reference_suggestions.dart';
part 'community_feed_reference_header.dart';
part 'community_feed_mode_control.dart';

part 'community_post_card.dart';
part 'community_post_owner_scope.dart';
part 'community_poll_panel.dart';
part 'community_feed_pagination.dart';
part 'community_post_composer_page.dart';
part 'community_post_composer_owner_scope.dart';
part 'community_post_composer_reference_actions.dart';
part 'community_post_composer_reference_sections.dart';
part 'community_post_composer_option_fields.dart';
part 'community_post_composer_rendering.dart';
part 'community_post_composer_toolbar.dart';
part 'community_post_composer_switch_row.dart';
part 'community_post_composer_image_preview.dart';
part 'community_post_detail_page.dart';
part 'community_post_detail_reference_actions.dart';
part 'community_post_detail_rendering.dart';
part 'community_post_detail_header.dart';
part 'community_post_detail_comment_tile.dart';
part 'community_post_widgets.dart';
part 'community_post_reference_widgets.dart';
part 'community_post_taxonomy_reference.dart';
part 'community_saved_posts_page.dart';
part 'community_topics_page.dart';
part 'community_circles_page.dart';
part 'community_circle_owner_scope.dart';
part 'community_circle_detail_page.dart';
part 'community_circle_discovery_header.dart';
part 'community_circle_reference_body.dart';
part 'community_circle_copy.dart';
part 'community_browse_view_counts.dart';
part 'community_my_posts_page.dart';
part 'community_member_profile_page.dart';
part 'community_member_profile_owner_scope.dart';
part 'community_member_profile_actions.dart';
part 'community_member_profile_connections.dart';
part 'community_member_profile_creator_widgets.dart';
part 'community_member_profile_header.dart';
part 'community_member_profile_content.dart';
part 'community_member_profile_drafts.dart';
part 'community_drafts_rendering.dart';
part 'community_drafts_preview.dart';
part 'community_account_widgets.dart';
part 'community_navigation_sheet.dart';
part 'community_friends_tab.dart';
part 'community_food_tab.dart';

class CommunityHubPage extends StatefulWidget {
  const CommunityHubPage({
    this.repository,
    this.client,
    this.postImagePicker,
    this.entryWelcomeHandled = false,
    super.key,
  });

  final CommunityRepository? repository;
  final SupabaseClient? client;
  final CommunityPostImagePickerContract? postImagePicker;
  final bool entryWelcomeHandled;

  @override
  State<CommunityHubPage> createState() => _CommunityHubPageState();
}

enum _CommunityHubSection { explore, following, circles }

class _CommunityHubPageState extends State<CommunityHubPage> {
  CommunityRepository? _repository;
  GlobalKey<_FeedTabState> _feedKey = GlobalKey<_FeedTabState>();
  bool _openingNavigation = false;
  _CommunityHubSection _section = _CommunityHubSection.explore;
  CommunityFeedMode _feedMode = CommunityFeedMode.explore;
  StreamSubscription<AuthState>? _authSubscription;
  String? _ownerId;
  Future<CommunityProfileOverview?>? _profilePreview;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _profilePreview = _repository?.loadMyProfileOverview();
    _watchProductionSession();
  }

  @override
  void didUpdateWidget(covariant CommunityHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.client, widget.client)) {
      _repository = widget.repository ?? _productionRepository();
      _profilePreview = _repository?.loadMyProfileOverview();
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
          _profilePreview = _repository?.loadMyProfileOverview();
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
  Widget build(BuildContext context) => CommunitySurface(
    child: LayoutBuilder(
      builder: (context, constraints) =>
          _buildHub(context, constraints.maxWidth),
    ),
  );

  Widget _buildHub(BuildContext context, double width) {
    final repository = _repository;
    final topTabsHeight = _communityHubTopTabsHeight(context, width);
    return Scaffold(
      bottomNavigationBar: repository == null
          ? null
          : BilReferenceBottomBar(
              selected: 3,
              onSelected: (index) {
                if (index == 2) {
                  unawaited(showBilQuickAdd(context, originPath: '/community'));
                } else if (index != 3) {
                  context.go(BilReferenceBottomBar.routes[index]);
                }
              },
            ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          communityText(context, 'BIL Community', 'مجتمع BIL'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 27 * (width / 414).clamp(.78, 1.0),
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('community-search'),
            tooltip: communityText(context, 'Find people', 'البحث عن أشخاص'),
            onPressed: repository == null
                ? null
                : () => context.push('/community/people'),
            icon: const Icon(Icons.search_rounded, size: 32),
          ),
          IconButton(
            key: const Key('community-updates'),
            tooltip: communityText(
              context,
              'Community updates',
              'تحديثات المجتمع',
            ),
            onPressed: repository == null
                ? null
                : () => context.push('/community/notifications'),
            icon: const CommunityUnreadBadge(
              child: Icon(Icons.notifications_none_rounded, size: 32),
            ),
          ),
          FutureBuilder<CommunityProfileOverview?>(
            future: _profilePreview,
            builder: (context, snapshot) => IconButton(
              key: const Key('community-settings'),
              tooltip: communityText(
                context,
                'Community profile and actions',
                'ملف المجتمع وإجراءاته',
              ),
              onPressed: repository == null
                  ? null
                  : () => _openNavigation(context, repository),
              icon: BilAccountAvatar(
                radius: 20.5,
                networkUrl: snapshot.data?.avatarUrl,
              ),
            ),
          ),
        ],
        bottom: repository == null
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(topTabsHeight),
                child: SizedBox(
                  height: topTabsHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _CommunityHubTopTab(
                          key: const Key('community-hub-explore-tab'),
                          label: communityText(context, 'Explore', 'استكشاف'),
                          selected:
                              _section == _CommunityHubSection.explore &&
                              _feedMode == CommunityFeedMode.explore,
                          onTap: () => _showFeedMode(CommunityFeedMode.explore),
                        ),
                      ),
                      Expanded(
                        child: _CommunityHubTopTab(
                          key: const Key('community-hub-following-tab'),
                          label: communityText(
                            context,
                            'Following',
                            'المتابَعون',
                          ),
                          selected: _section == _CommunityHubSection.following,
                          onTap: () =>
                              _showFeedMode(CommunityFeedMode.following),
                        ),
                      ),
                      Expanded(
                        child: _CommunityHubTopTab(
                          key: const Key('community-hub-circles-tab'),
                          label: communityText(context, 'Circles', 'الدوائر'),
                          selected: _section == _CommunityHubSection.circles,
                          onTap: () => setState(
                            () => _section = _CommunityHubSection.circles,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: repository == null
          ? const _SignInRequired()
          : switch (_section) {
              _CommunityHubSection.explore => _FeedTab(
                key: _feedKey,
                repository: repository,
                imagePicker:
                    widget.postImagePicker ?? CommunityPostImagePicker(),
                initialMode: _feedMode,
                entryWelcomeHandled: widget.entryWelcomeHandled,
                onOpenCircles: () =>
                    setState(() => _section = _CommunityHubSection.circles),
              ),
              _CommunityHubSection.following => _FeedTab(
                key: _feedKey,
                repository: repository,
                imagePicker:
                    widget.postImagePicker ?? CommunityPostImagePicker(),
                initialMode: _feedMode,
                entryWelcomeHandled: widget.entryWelcomeHandled,
                onOpenCircles: () =>
                    setState(() => _section = _CommunityHubSection.circles),
              ),
              _CommunityHubSection.circles => CommunityCirclesPage(
                repository: repository,
                embedded: true,
                onComposeCircle: _composeCircleFromHub,
              ),
            },
    );
  }

  void _showFeedMode(CommunityFeedMode mode) {
    final feed = _feedKey.currentState;
    if (feed != null && (feed._openingComposer || feed._managingPost)) return;
    setState(() {
      _feedMode = mode;
      _section = mode == CommunityFeedMode.following
          ? _CommunityHubSection.following
          : _CommunityHubSection.explore;
    });
  }

  Future<void> _composeCircleFromHub(String slug) async {
    if (_section != _CommunityHubSection.explore) {
      setState(() => _section = _CommunityHubSection.explore);
    }
    final ready = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => ready.complete());
    await ready.future;
    if (!mounted) return;
    await _feedKey.currentState?._openComposer(circle: slug);
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
        builder: (_) => _CommunityNavigationSheet(
          repository: repository,
          selectedFeedMode: _feedMode,
        ),
      );
      if (!context.mounted || destination == null) return;
      for (final mode in CommunityFeedMode.values) {
        if (destination == 'feed-mode:${mode.wireValue}') {
          if (identical(_repository, repository)) _showFeedMode(mode);
          return;
        }
      }
      switch (destination) {
        case '/community/connections':
          await pushCommunityPage<void>(
            context,
            CommunityConnectionsPage(repository: repository),
          );
        case 'account':
          await pushCommunityPage<void>(
            context,
            CommunityMemberProfilePage(
              userId: repository.currentUserId,
              repository: repository,
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
          await pushCommunityPage<void>(
            context,
            CommunityTopicsPage(
              repository: repository,
              onComposeTopic: (tag) async {
                if (context.mounted) Navigator.of(context).pop();
                if (!context.mounted) return;
                await _feedKey.currentState?._openComposer(tag: tag);
              },
            ),
          );
        case 'circles':
          await pushCommunityPage<void>(
            context,
            CommunityCirclesPage(
              repository: repository,
              onComposeCircle: (slug) async {
                if (context.mounted) Navigator.of(context).pop();
                if (!context.mounted) return;
                await _feedKey.currentState?._openComposer(circle: slug);
              },
            ),
          );
        default:
          await context.push(destination);
      }
    } finally {
      _openingNavigation = false;
      if (mounted) {
        setState(() {
          _profilePreview = repository.loadMyProfileOverview();
        });
      }
    }
  }
}

double _communityHubTopTabsHeight(BuildContext context, double width) {
  var height = 48.0;
  // Reserve the actual localized line height. A fixed three-line allowance
  // left a large empty band above single-line Arabic/English tabs at 200%.
  for (final label in [
    communityText(context, 'Explore', 'استكشاف'),
    communityText(context, 'Following', 'المتابَعون'),
    communityText(context, 'Circles', 'الدوائر'),
  ]) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: width / 3);
    if (painter.height + 20 > height) height = painter.height + 20;
    painter.dispose();
  }
  return height;
}

class _CommunityHubTopTab extends StatelessWidget {
  const _CommunityHubTopTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(height: 9),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 3,
          width: 56,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    ),
  );
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
