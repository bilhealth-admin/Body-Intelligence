import 'community_attention_scope.dart';
import 'community_return_button.dart';
import '../../../shared/widgets/bil_reference_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_attention.dart';
import 'community_copy.dart';

part 'community_notifications_filters.dart';
part 'community_notifications_rendering.dart';

class CommunityNotificationsPage extends StatefulWidget {
  const CommunityNotificationsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityNotificationsPage> createState() =>
      _CommunityNotificationsPageState();
}

enum _ActivityFilter { all, updates, reactions, comments, followers }

class _CommunityNotificationsPageState
    extends State<CommunityNotificationsPage> {
  static const _pageSize = 30;
  CommunityRepository? _repository;
  late Future<_CommunityUpdates> _updates;
  final Set<String> _markingSeen = <String>{};
  final Set<String> _respondingCollaboration = <String>{};
  CommunityAttentionController? _attentionController;
  int? _lastCommunityUpdates;
  _ActivityFilter _filter = _ActivityFilter.all;
  bool _markingPageSeen = false;
  int _loadGeneration = 0;
  bool _loadingFirst = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  DateTime? _before;
  String? _beforeId;

  void _selectFilter(_ActivityFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _updates = _load();
    });
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _updates = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = CommunityAttentionScope.controllerOf(context);
    if (identical(next, _attentionController)) return;
    _attentionController?.removeListener(_onAttentionChanged);
    _attentionController = next;
    _lastCommunityUpdates = next?.value.communityUpdates;
    next?.addListener(_onAttentionChanged);
  }

  void _onAttentionChanged() {
    final next = _attentionController?.value.communityUpdates;
    if (next == null || next == _lastCommunityUpdates) return;
    _lastCommunityUpdates = next;
    if (mounted) _retry();
  }

  @override
  void dispose() {
    _attentionController?.removeListener(_onAttentionChanged);
    super.dispose();
  }

  CommunityRepository? _productionRepository() {
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

  Future<_CommunityUpdates> _load() async {
    final generation = ++_loadGeneration;
    _loadingFirst = true;
    _loadingMore = false;
    _hasMore = false;
    _before = null;
    _beforeId = null;
    final repository = _repository;
    try {
      if (repository == null) return const _CommunityUpdates.signedOut();
      final values = await Future.wait<Object>([
        repository.loadAttention(),
        repository.loadCommunityNotifications(
          kinds: _CommunityNotificationsFilters(this).filterKinds,
          limit: _pageSize,
        ),
      ]);
      final attention = values[0] as CommunityAttention;
      final notifications = values[1] as List<CommunityNotification>;
      if (mounted && generation == _loadGeneration) {
        _setCursor(notifications);
      }
      return _CommunityUpdates(
        incomingRequests: attention.incomingRequests,
        unreadMessages: attention.unreadMessages,
        communityUpdates: attention.communityUpdates,
        notifications: notifications,
      );
    } finally {
      if (generation == _loadGeneration) _loadingFirst = false;
    }
  }

  void _setCursor(List<CommunityNotification> notifications) {
    _hasMore = notifications.length == _pageSize;
    _before = notifications.lastOrNull?.createdAt;
    _beforeId = notifications.lastOrNull?.id;
  }

  Future<void> _loadMore(_CommunityUpdates visible) async {
    final repository = _repository;
    if (repository == null ||
        _loadingFirst ||
        _loadingMore ||
        !_hasMore ||
        _before == null ||
        _beforeId == null) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _loadingMore = true);
    try {
      final page = await repository.loadCommunityNotifications(
        before: _before,
        beforeId: _beforeId,
        kinds: _CommunityNotificationsFilters(this).filterKinds,
        limit: _pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      final known = visible.notifications.map((item) => item.id).toSet();
      setState(() {
        _setCursor(page);
        _updates = Future.value(
          _CommunityUpdates(
            incomingRequests: visible.incomingRequests,
            unreadMessages: visible.unreadMessages,
            communityUpdates: visible.communityUpdates,
            notifications: [
              ...visible.notifications,
              ...page.where((item) => known.add(item.id)),
            ],
          ),
        );
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'BIL could not check your updates safely. Try again.',
              'تعذر على BIL التحقق من تحديثاتك بأمان. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _retry() {
    final retry = _load();
    setState(() {
      _updates = retry;
    });
  }

  Future<void> _openAndRefresh(String route) async {
    await context.push(route);
    if (mounted) {
      await CommunityAttentionScope.refresh(context);
      if (mounted) _retry();
    }
  }

  Future<void> _markLoadedPageSeen(_CommunityUpdates visible) async {
    final repository = _repository;
    if (repository == null || _loadingFirst || _markingPageSeen) return;
    final ids = visible.notifications
        .where(_CommunityNotificationsFilters(this).matchesFilter)
        .where((item) => !item.seen && !_markingSeen.contains(item.id))
        .map((item) => item.id)
        .toSet()
        .take(100)
        .toList(growable: false);
    if (ids.isEmpty) return;
    final generation = _loadGeneration;
    String? ownerAtStart;
    setState(() {
      _markingPageSeen = true;
      _markingSeen.addAll(ids);
    });
    try {
      ownerAtStart = repository.currentUserId;
      await repository.markCommunityNotificationsSeen(ids);
      // The RPC is owner-scoped too. Never refresh an old page into a new
      // account after sign-out, account switching, or a filter change.
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(repository, _repository) ||
          repository.currentUserId != ownerAtStart) {
        return;
      }
      await CommunityAttentionScope.refresh(context);
      if (mounted &&
          generation == _loadGeneration &&
          repository.currentUserId == ownerAtStart) {
        _retry();
      }
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      try {
        if (repository.currentUserId != ownerAtStart) return;
      } on Object {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not confirm these updates as read. Please retry.',
              'تعذر تأكيد قراءة هذه التحديثات. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      _markingSeen.removeAll(ids);
      if (mounted) setState(() => _markingPageSeen = false);
    }
  }

  Future<void> _openNotification(CommunityNotification notification) async {
    final repository = _repository;
    if (repository == null || !_markingSeen.add(notification.id)) return;
    try {
      if (!notification.seen) {
        await repository.markCommunityNotificationsSeen([notification.id]);
        if (mounted) await CommunityAttentionScope.refresh(context);
      }
      if (mounted) await _openAndRefresh(_routeFor(notification));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'BIL could not check your updates safely. Try again.',
              'تعذر على BIL التحقق من تحديثاتك بأمان. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      _markingSeen.remove(notification.id);
    }
  }

  Future<void> _respondCollaboration(
    CommunityNotification notification, {
    required bool accept,
  }) async {
    final repository = _repository;
    if (repository == null ||
        notification.entityKind != 'post' ||
        !_respondingCollaboration.add(notification.id)) {
      return;
    }
    setState(() {});
    try {
      await repository.respondCommunityCollaboration(
        postId: notification.entityId,
        accept: accept,
      );
      if (!notification.seen) {
        await repository.markCommunityNotificationsSeen([notification.id]);
      }
      if (!mounted) return;
      await CommunityAttentionScope.refresh(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? communityText(
                    context,
                    'Collaboration accepted.',
                    'تم قبول التعاون.',
                  )
                : communityText(
                    context,
                    'Collaboration declined.',
                    'تم رفض التعاون.',
                  ),
          ),
        ),
      );
      _retry();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Could not update this collaboration. Try again.',
              'تعذر تحديث هذا التعاون. حاول مجددًا.',
            ),
          ),
        ),
      );
    } finally {
      _respondingCollaboration.remove(notification.id);
      if (mounted) setState(() {});
    }
  }

  Widget _notificationTrailing(CommunityNotification notification) {
    if (notification.kind != CommunityNotificationKind.collaborationInvite) {
      return Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Icons.chevron_left_rounded
            : Icons.chevron_right_rounded,
      );
    }
    final busy = _respondingCollaboration.contains(notification.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('community-collab-decline-${notification.id}'),
          tooltip: communityText(context, 'Decline', 'رفض'),
          onPressed: busy
              ? null
              : () => _respondCollaboration(notification, accept: false),
          icon: const Icon(Icons.close_rounded),
        ),
        IconButton(
          key: Key('community-collab-accept-${notification.id}'),
          tooltip: communityText(context, 'Accept', 'قبول'),
          onPressed: busy
              ? null
              : () => _respondCollaboration(notification, accept: true),
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
        ),
      ],
    );
  }

  String _routeFor(CommunityNotification notification) {
    const liveRoutes = {
      '/community',
      '/community/connections',
      '/community/people',
      '/community/messages',
      '/community/rewards',
    };
    if (liveRoutes.contains(notification.deepLinkPath)) {
      return notification.deepLinkPath;
    }
    return switch (notification.kind) {
      CommunityNotificationKind.friendRequest ||
      CommunityNotificationKind.friendAccepted => '/community/connections',
      CommunityNotificationKind.follow =>
        notification.actorId == null
            ? '/community/people'
            : '/community/profile/${notification.actorId}',
      CommunityNotificationKind.postLike ||
      CommunityNotificationKind.postSave ||
      CommunityNotificationKind.comment ||
      CommunityNotificationKind.reply ||
      CommunityNotificationKind.mention => '/community',
      CommunityNotificationKind.rewardEarned ||
      CommunityNotificationKind.questCompleted => '/community/rewards',
      CommunityNotificationKind.badgeEarned ||
      CommunityNotificationKind.challengeUpdate ||
      CommunityNotificationKind.collaborationInvite ||
      CommunityNotificationKind.collaborationAccepted => '/community',
    };
  }

  String _notificationTitle(CommunityNotification notification) {
    final actor = notification.actorDisplayName;
    return switch (notification.kind) {
      CommunityNotificationKind.friendRequest =>
        actor == null
            ? communityText(context, 'New friend request', 'طلب صداقة جديد')
            : communityText(
                context,
                '{actor} sent you a friend request',
                '{actor} أرسل إليك طلب صداقة',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.friendAccepted =>
        actor == null
            ? communityText(
                context,
                'Your friend request was accepted',
                'تم قبول طلب صداقتك',
              )
            : communityText(
                context,
                '{actor} accepted your friend request',
                '{actor} قبل طلب صداقتك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.postLike =>
        actor == null
            ? communityText(
                context,
                'Someone liked your post',
                'أعجب شخص بمنشورك',
              )
            : communityText(
                context,
                '{actor} liked your post',
                '{actor} أعجب بمنشورك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.postSave => communityText(
        context,
        'Your post was saved',
        'تم حفظ منشورك',
      ),
      CommunityNotificationKind.comment =>
        actor == null
            ? communityText(
                context,
                'New comment on your post',
                'تعليق جديد على منشورك',
              )
            : communityText(
                context,
                '{actor} commented on your post',
                '{actor} علّق على منشورك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.reply =>
        actor == null
            ? communityText(
                context,
                'New reply to your comment',
                'رد جديد على تعليقك',
              )
            : communityText(
                context,
                '{actor} replied to your comment',
                '{actor} رد على تعليقك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.follow =>
        actor == null
            ? communityText(context, 'New follower', 'متابع جديد')
            : communityText(
                context,
                '{actor} followed you',
                '{actor} بدأ بمتابعتك',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.mention =>
        actor == null
            ? communityText(
                context,
                'You were mentioned in a post',
                'تمت الإشارة إليك في منشور',
              )
            : communityText(
                context,
                '{actor} mentioned you in a post',
                '{actor} أشار إليك في منشور',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.rewardEarned => communityText(
        context,
        'You earned a Community reward',
        'حصلت على مكافأة في المجتمع',
      ),
      CommunityNotificationKind.questCompleted => communityText(
        context,
        'Quest completed',
        'اكتملت المهمة',
      ),
      CommunityNotificationKind.badgeEarned => communityText(
        context,
        'New badge earned',
        'حصلت على شارة جديدة',
      ),
      CommunityNotificationKind.challengeUpdate => communityText(
        context,
        'Challenge update',
        'تحديث للتحدي',
      ),
      CommunityNotificationKind.collaborationInvite =>
        actor == null
            ? communityText(context, 'Collaboration invitation', 'دعوة للتعاون')
            : communityText(
                context,
                '{actor} invited you to collaborate on a post',
                '{actor} دعاك للتعاون على منشور',
              ).replaceAll('{actor}', actor),
      CommunityNotificationKind.collaborationAccepted =>
        actor == null
            ? communityText(
                context,
                'Collaboration invitation accepted',
                'تم قبول دعوة التعاون',
              )
            : communityText(
                context,
                '{actor} accepted your collaboration invitation',
                '{actor} قبل دعوة التعاون الخاصة بك',
              ).replaceAll('{actor}', actor),
    };
  }

  @override
  Widget build(BuildContext context) => _CommunityNotificationsRendering(
    this,
  ).buildCommunityNotifications(context);
}
