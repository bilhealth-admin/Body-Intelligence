import 'community_attention_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_repository.dart';
import '../domain/community_attention.dart';
import 'community_copy.dart';

class CommunityNotificationsPage extends StatefulWidget {
  const CommunityNotificationsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityNotificationsPage> createState() =>
      _CommunityNotificationsPageState();
}

class _CommunityNotificationsPageState
    extends State<CommunityNotificationsPage> {
  CommunityRepository? _repository;
  late Future<_CommunityUpdates> _updates;
  final Set<String> _markingSeen = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
    _updates = _load();
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
    final repository = _repository;
    if (repository == null) return const _CommunityUpdates.signedOut();
    final values = await Future.wait<Object>([
      repository.loadAttention(),
      repository.loadCommunityNotifications(),
    ]);
    final attention = values[0] as CommunityAttention;
    final notifications = values[1] as List<CommunityNotification>;
    return _CommunityUpdates(
      incomingRequests: attention.incomingRequests,
      unreadMessages: attention.unreadMessages,
      notifications: notifications,
    );
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

  Future<void> _openNotification(CommunityNotification notification) async {
    final repository = _repository;
    if (repository == null || !_markingSeen.add(notification.id)) return;
    try {
      if (!notification.seen) {
        await repository.markCommunityNotificationsSeen([notification.id]);
        if (mounted) await CommunityAttentionScope.refresh(context);
      }
      if (mounted) await _openAndRefresh('/community/connections');
    } finally {
      _markingSeen.remove(notification.id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        communityText(context, 'Community updates', 'تحديثات المجتمع'),
      ),
      actions: [
        IconButton(
          tooltip: communityText(context, 'Notifications', 'الإشعارات'),
          onPressed: () => context.push('/notification-settings'),
          icon: const Icon(Icons.tune_rounded),
        ),
        if (_repository != null)
          IconButton(
            onPressed: _retry,
            tooltip: communityText(context, 'Refresh', 'تحديث'),
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
    body: FutureBuilder<_CommunityUpdates>(
      future: _updates,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _CenteredUpdatesState(
            icon: Icons.cloud_off_outlined,
            title: communityText(
              context,
              'Community updates are unavailable',
              'تحديثات المجتمع غير متاحة',
            ),
            body: communityText(
              context,
              'BIL could not check your updates safely. Try again.',
              'تعذر على BIL التحقق من تحديثاتك بأمان. حاول مجددًا.',
            ),
            action: FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
            ),
          );
        }
        final live = CommunityAttentionScope.controllerOf(context);
        final updates = live?.owner != null && !live!.stale
            ? _CommunityUpdates(
                incomingRequests: live.value.incomingRequests,
                unreadMessages: live.value.unreadMessages,
              )
            : snapshot.requireData;
        if (updates.signedOut) {
          return _CenteredUpdatesState(
            icon: Icons.lock_person_outlined,
            title: communityText(
              context,
              'Sign in required',
              'تسجيل الدخول مطلوب',
            ),
            body: communityText(
              context,
              'Sign in to check private community updates.',
              'سجّل الدخول للتحقق من تحديثات المجتمع الخاصة.',
            ),
            action: FilledButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login_rounded),
              label: Text(communityText(context, 'Sign in', 'تسجيل الدخول')),
            ),
          );
        }
        if (updates.isEmpty) {
          return _CenteredUpdatesState(
            icon: Icons.notifications_none_rounded,
            title: communityText(
              context,
              'No community updates',
              'لا توجد تحديثات للمجتمع',
            ),
            body: communityText(
              context,
              'Friend requests and unread messages will appear here.',
              'ستظهر طلبات الصداقة والرسائل غير المقروءة هنا.',
            ),
            action: FilledButton.icon(
              onPressed: () => _openAndRefresh('/community/people'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                communityText(context, 'Find people', 'البحث عن أشخاص'),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final notification in updates.notifications)
              Card(
                color: notification.seen
                    ? null
                    : Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: ListTile(
                  leading: BilAccountAvatar(
                    radius: 20,
                    networkUrl: notification.actorAvatarUrl,
                  ),
                  title: Text(
                    notification.actorDisplayName == null
                        ? communityText(
                            context,
                            'Your friend request was accepted',
                            'تم قبول طلب صداقتك',
                          )
                        : communityText(
                            context,
                            '${notification.actorDisplayName} accepted your friend request',
                            '${notification.actorDisplayName} قبل طلب صداقتك',
                          ),
                  ),
                  subtitle: Text(
                    notification.seen
                        ? communityText(context, 'Seen', 'تمت المشاهدة')
                        : communityText(context, 'New', 'جديد'),
                  ),
                  trailing: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                  ),
                  onTap: () => _openNotification(notification),
                ),
              ),
            if (updates.incomingRequests > 0)
              ListTile(
                leading: const BilSemanticIconBadge(
                  kind: BilSemanticIconKind.friends,
                ),
                title: Text(
                  communityText(context, 'Friend requests', 'طلبات الصداقة'),
                ),
                subtitle: Text('${updates.incomingRequests}'),
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
                onTap: () => _openAndRefresh('/community/connections'),
              ),
            if (updates.unreadMessages > 0)
              ListTile(
                leading: const BilSemanticIconBadge(
                  kind: BilSemanticIconKind.messages,
                ),
                title: Text(
                  communityText(
                    context,
                    'Unread messages',
                    'الرسائل غير المقروءة',
                  ),
                ),
                subtitle: Text('${updates.unreadMessages}'),
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
                onTap: () => _openAndRefresh('/community/messages'),
              ),
          ],
        );
      },
    ),
  );
}

class _CenteredUpdatesState extends StatelessWidget {
  const _CenteredUpdatesState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    ),
  );
}

class _CommunityUpdates {
  const _CommunityUpdates({
    this.incomingRequests = 0,
    this.unreadMessages = 0,
    this.notifications = const <CommunityNotification>[],
  }) : signedOut = false;

  const _CommunityUpdates.signedOut()
    : incomingRequests = 0,
      unreadMessages = 0,
      notifications = const <CommunityNotification>[],
      signedOut = true;

  final int incomingRequests;
  final int unreadMessages;
  final List<CommunityNotification> notifications;
  final bool signedOut;

  bool get isEmpty =>
      incomingRequests == 0 && unreadMessages == 0 && notifications.isEmpty;
}
