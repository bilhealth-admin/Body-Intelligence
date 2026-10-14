import '../../../shared/widgets/bil_striped_progress.dart';
import '../../../shared/widgets/bil_glass_press_feedback.dart';
import 'community_attention_scope.dart';
import 'bil_gold_coin.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widgets/bil_persistent_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_written_language_resolver.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../app/theme/bil_flat_icon.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../../../shared/widgets/bil_media_review_sheet.dart';
import '../../../shared/widgets/bil_reference_bottom_bar.dart';
import '../../../app/router/bil_quick_add_presenter.dart';
import '../../profile/services/profile_photo_service.dart';
import '../circle_management/circle_management.dart';
import '../circle_management/presentation/circle_management_surfaces.dart';
import '../data/community_repository.dart';
import '../data/community_post_cloud_store.dart';
import '../data/community_notification_content_loader.dart';
import '../../notifications/domain/community_deep_link.dart';
import 'community_account_visit.dart';
import '../channels/presentation/community_channels_copy.dart';
import '../home_profile/community_profile_activity_repository.dart';
import '../domain/community_content_policy.dart';
import '../domain/community_composer_persistence.dart';
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
import 'community_translation_content.dart';
import 'community_ai_reward_notice.dart';
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
import 'community_feed_refresh_notice.dart';
import 'community_post_review_reason.dart';
import '../../../app/theme/bil_pearl_finish.dart';

part '../home_profile/community_home_owner_scope.dart';
part '../home_profile/community_feed_owner_scope.dart';
part '../home_profile/community_profile_activity_slivers.dart';
part '../home_profile/community_profile_activity_media.dart';
part 'community_feed_tab.dart';
part 'community_feed_rendering.dart';
part 'community_feed_visit_preview.dart';
part 'community_hub_top_tabs.dart';
part 'community_feed_copy.dart';
part 'community_feed_reference_suggestions.dart';
part 'community_feed_reference_header.dart';
part 'community_feed_mode_control.dart';

part 'community_post_card.dart';
part 'community_post_owner_scope.dart';
part 'community_poll_panel.dart';
part 'community_feed_pagination.dart';
part 'community_post_composer_page.dart';
part 'community_compose_entry_page.dart';
part 'community_post_composer_owner_scope.dart';
part 'community_post_composer_reference_actions.dart';
part 'community_post_composer_reference_sections.dart';
part 'community_post_composer_option_fields.dart';
part 'community_post_composer_rendering.dart';
part 'community_post_composer_toolbar.dart';
part 'community_post_composer_switch_row.dart';
part 'community_post_composer_image_preview.dart';
part 'community_post_detail_page.dart';
part 'community_notification_content_page.dart';
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
part 'community_hub_sign_in_required.dart';
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
  String? _deliveredOwnerId;
  int _homeVisitEpoch = 0;
  int _homeAuthBinding = 0;
  // Do not re-expose an injected repository's cached feed after queued ABA.
  bool _suspendReboundFeed = false;
  final _homeOwnerChanges = ValueNotifier<int>(0);
  bool _homeSignalDisposed = false;
  Future<CommunityProfileOverview?>? _profilePreview;
  _CommunityFeedVisitPreview? _feedPreview;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _ownerId = _readHomeRepositoryOwner(_repository);
    _profilePreview = _repository?.loadMyProfileOverview();
    _watchProductionSession();
  }

  @override
  void didUpdateWidget(covariant CommunityHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.client, widget.client)) {
      _invalidateHomeVisit();
      _homeAuthBinding++;
      _suspendReboundFeed = false;
      _repository = widget.repository ?? _productionRepository();
      _ownerId = _readHomeRepositoryOwner(_repository);
      _deliveredOwnerId = _ownerId;
      _profilePreview = _repository?.loadMyProfileOverview();
      _feedKey = GlobalKey<_FeedTabState>();
      _watchProductionSession();
      _prepareFeedPreview();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareFeedPreview();
  }

  void _prepareFeedPreview() {
    final repository = _repository;
    final visit = repository == null ? null : _captureHomeVisit(repository);
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (visit != null &&
        (_feedPreview == null ||
            _feedPreview!.visit.epoch != visit.epoch ||
            _feedPreview!.locale != locale)) {
      _feedPreview = _CommunityFeedVisitPreview(visit, locale, _profilePreview);
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

  void _watchProductionSession() => _bindHomeOwnerSession();

  @override
  void dispose() {
    _homeAuthBinding++;
    unawaited(_authSubscription?.cancel());
    _notifyHomeVisitChanged(dispose: true);
    super.dispose();
  }

  void _setHomeState(VoidCallback action) => setState(action);

  @override
  Widget build(BuildContext context) => CommunitySurface(
    child: LayoutBuilder(
      builder: (context, constraints) =>
          _buildHub(context, constraints.maxWidth),
    ),
  );

  Widget _buildHub(BuildContext context, double width) {
    final repository = _repository;
    final visit = repository == null ? null : _captureHomeVisit(repository);
    final back = Navigator.of(context).canPop();
    final title = communityText(context, 'BIL Community', 'مجتمع BIL');
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w900,
    );
    final titleMeasure = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: (width - 32 - (back ? 56 : 0) - 144).clamp(1, width));
    final stackedTitle = titleMeasure.computeLineMetrics().length > 1;
    if (stackedTitle) {
      titleMeasure.layout(
        maxWidth: (width - 32 - (back ? 56 : 0)).clamp(1, width),
      );
    }
    final titleHeight = titleMeasure.height;
    titleMeasure.dispose();
    final actions = <Widget>[
      IconButton(
        key: const Key('community-search'),
        tooltip: communityText(context, 'Find people', 'البحث عن أشخاص'),
        onPressed: visit == null
            ? null
            : () {
                if (visit.isCurrent()) context.push('/community/people');
              },
        icon: const Icon(Icons.search_rounded, size: 32),
      ),
      IconButton(
        key: const Key('community-updates'),
        tooltip: communityText(context, 'Community updates', 'تحديثات المجتمع'),
        onPressed: visit == null
            ? null
            : () {
                if (visit.isCurrent()) {
                  context.push('/community/notifications');
                }
              },
        icon: const CommunityUnreadBadge(
          child: Icon(Icons.notifications_none_rounded, size: 32),
        ),
      ),
      FutureBuilder<CommunityProfileOverview?>(
        key: ValueKey(_homeVisitEpoch),
        future: _profilePreview,
        builder: (context, snapshot) => IconButton(
          key: const Key('community-settings'),
          tooltip: communityText(
            context,
            'Community profile and actions',
            'ملف المجتمع وإجراءاته',
          ),
          onPressed: visit == null
              ? null
              : () => _openNavigation(context, visit),
          padding: const EdgeInsets.all(3.5),
          icon: BilAccountAvatar(
            radius: 20.5,
            networkUrl: snapshot.data?.avatarUrl,
          ),
        ),
      ),
    ].map((action) => SizedBox(width: 48, height: 48, child: action)).toList();
    final topTabsHeight = _communityHubTopTabsHeight(context, width);
    return Scaffold(
      bottomNavigationBar: visit == null
          ? null
          : BilReferenceBottomBar(
              selected: 3,
              dark: Theme.of(context).brightness == Brightness.dark,
              onSelected: (index) {
                if (!visit.isCurrent()) return;
                if (index == 2) {
                  unawaited(showBilQuickAdd(context, originPath: '/community'));
                } else if (index != 3) {
                  context.go(BilReferenceBottomBar.routes[index]);
                }
              },
            ),
      appBar: AppBar(
        // Community is normally a bottom tab (no Back). If a notification
        // pushed it above an existing screen, expose the real previous route.
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? const CommunityReturnButton()
            : null,
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: stackedTitle ? titleHeight + 64 : 56,
        title: stackedTitle
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: const Key('community-full-title'),
                    maxLines: 10,
                    softWrap: true,
                    style: titleStyle,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ],
              )
            : Text(
                title,
                key: const Key('community-full-title'),
                maxLines: 10,
                softWrap: true,
                style: titleStyle,
              ),
        actions: stackedTitle ? const [] : actions,
        bottom: visit == null
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
                          onTap: () {
                            if (visit.isCurrent()) {
                              _showFeedMode(CommunityFeedMode.explore);
                            }
                          },
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
                          onTap: () {
                            if (visit.isCurrent()) {
                              _showFeedMode(CommunityFeedMode.following);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: _CommunityHubTopTab(
                          key: const Key('community-hub-circles-tab'),
                          label: communityText(context, 'Circles', 'الدوائر'),
                          selected: _section == _CommunityHubSection.circles,
                          onTap: () {
                            if (visit.isCurrent()) {
                              setState(() {
                                _feedPreview?.refreshIfExpired();
                                _section = _CommunityHubSection.circles;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: repository == null
          ? const _SignInRequired()
          : visit == null
          ? const _CommunityProfileOwnerChangedBody()
          : switch (_section) {
              _CommunityHubSection.explore => _FeedTab(
                key: _feedKey,
                repository: repository,
                imagePicker:
                    widget.postImagePicker ?? CommunityPostImagePicker(),
                initialMode: _feedMode,
                entryWelcomeHandled: widget.entryWelcomeHandled,
                suspendAfterOwnerChange: _suspendReboundFeed,
                ownerIsCurrent: visit.isCurrent,
                ownerChanges: visit.changes,
                preview: _feedPreview!,
                onOpenCircles: () {
                  if (visit.isCurrent()) {
                    setState(() => _section = _CommunityHubSection.circles);
                  }
                },
              ),
              _CommunityHubSection.following => _FeedTab(
                key: _feedKey,
                repository: repository,
                imagePicker:
                    widget.postImagePicker ?? CommunityPostImagePicker(),
                initialMode: _feedMode,
                entryWelcomeHandled: widget.entryWelcomeHandled,
                suspendAfterOwnerChange: _suspendReboundFeed,
                ownerIsCurrent: visit.isCurrent,
                ownerChanges: visit.changes,
                preview: _feedPreview!,
                onOpenCircles: () {
                  if (visit.isCurrent()) {
                    setState(() => _section = _CommunityHubSection.circles);
                  }
                },
              ),
              _CommunityHubSection.circles => CommunityCirclesPage(
                repository: repository,
                embedded: true,
                onComposeCircle: (slug) async {
                  if (!visit.isCurrent()) return;
                  await _composeCircleFromHub(slug);
                },
              ),
            },
    );
  }

  void _showFeedMode(CommunityFeedMode mode) {
    final feed = _feedKey.currentState;
    if (feed != null && (feed._openingComposer || feed._managingPost)) return;
    _feedPreview?.refreshIfExpired();
    setState(() {
      _feedMode = mode;
      _section = mode == CommunityFeedMode.following
          ? _CommunityHubSection.following
          : _CommunityHubSection.explore;
    });
  }

  Future<void> _composeCircleFromHub(String slug) async {
    final repository = _repository;
    final visit = repository == null ? null : _captureHomeVisit(repository);
    if (visit == null) return;
    if (_section != _CommunityHubSection.explore) {
      setState(() => _section = _CommunityHubSection.explore);
    }
    final ready = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => ready.complete());
    await ready.future;
    if (!visit.isCurrent()) return;
    await _feedKey.currentState?._openComposer(circle: slug);
  }

  Future<void> _openNavigation(
    BuildContext context,
    _CommunityHomeVisit visit,
  ) async {
    if (_openingNavigation || !visit.isCurrent()) return;
    final repository = visit.repository;
    _openingNavigation = true;
    var refreshProfile = false;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final destination = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => visit.guard(
          _CommunityNavigationSheet(
            repository: repository,
            selectedFeedMode: _feedMode,
          ),
        ),
      );
      if (!context.mounted || destination == null) return;
      visit.check();
      for (final mode in CommunityFeedMode.values) {
        if (destination == 'feed-mode:${mode.wireValue}') {
          if (visit.isCurrent()) _showFeedMode(mode);
          return;
        }
      }
      refreshProfile =
          destination == 'account' || destination == '/community/profile/edit';
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
              userId: visit.ownerId,
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
                leading: const CommunityReturnButton(),
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
                leading: const CommunityReturnButton(),
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
                if (!visit.isCurrent()) return;
                if (context.mounted) Navigator.of(context).pop();
                if (!context.mounted || !visit.isCurrent()) return;
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
                if (!visit.isCurrent()) return;
                if (context.mounted) Navigator.of(context).pop();
                if (!context.mounted || !visit.isCurrent()) return;
                await _feedKey.currentState?._openComposer(circle: slug);
              },
            ),
          );
        default:
          if (visit.isCurrent()) await context.push(destination);
      }
    } on CommunityOwnerOperationCancelled {
      // A menu captured by an old owner never becomes a route for a later one.
    } finally {
      _openingNavigation = false;
      if (mounted && visit.isCurrent() && refreshProfile) {
        setState(() {
          _profilePreview = repository.loadMyProfileOverview();
          _feedPreview?.profile = _profilePreview;
        });
      }
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
      BilFlatIcon(
        kind: BilSemanticIcons.kindForRoute(route)!,
        size: 34,
        iconSize: 19,
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(communityText(context, english, arabic))),
    ],
  ),
);
