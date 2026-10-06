part of 'community_notifications_page.dart';

extension _CommunityNotificationsRendering on _CommunityNotificationsPageState {
  Widget buildCommunityNotifications(BuildContext context) => Scaffold(
    bottomNavigationBar: BilReferenceBottomBar(
      selected: 3,
      onSelected: (index) => context.go(BilReferenceBottomBar.routes[index]),
    ),
    appBar: AppBar(
      leading: const CommunityReturnButton(),
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
        final persisted = snapshot.requireData;
        final updates = live?.owner != null && !live!.stale
            ? _CommunityUpdates(
                incomingRequests: live.value.incomingRequests,
                unreadMessages: live.value.unreadMessages,
                communityUpdates: live.value.communityUpdates,
                notifications: persisted.notifications,
              )
            : persisted;
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
        final filteredNotifications = updates.notifications
            .where(_CommunityNotificationsFilters(this).matchesFilter)
            .toList(growable: false);
        return CommunityVisibleActivityScope(
          key: ValueKey(
            'community-visible-read-$_loadedOwnerId-${_filter.name}',
          ),
          ownerId: _loadedOwnerId ?? '',
          unreadIds: {
            for (final row in filteredNotifications)
              if (!row.seen && !_manualReceiptIds.contains(row.id)) row.id,
          },
          enabled: !_loadingFirst && !_loadingMore && !_markingPageSeen,
          retryKey: _loadGeneration,
          onSeen: (ids) => _markVisibleActivityRead(persisted, ids),
          builder: (context, marker) => ListView(
            key: const PageStorageKey('community-activity-list'),
            padding: const EdgeInsets.all(16),
            children: [
              ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _ActivityFilter.values) ...[
                        ChoiceChip(
                          key: Key('community-activity-filter-${filter.name}'),
                          selected: _filter == filter,
                          label: Text(
                            _CommunityNotificationsFilters(
                              this,
                            ).filterLabel(filter),
                          ),
                          onSelected: (_) => _selectFilter(filter),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_loadingFirst &&
                  filteredNotifications.any((item) => !item.seen))
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const Key('community-activity-mark-page-read'),
                    onPressed: _markingPageSeen
                        ? null
                        : () => _markLoadedPageSeen(persisted),
                    icon: _markingPageSeen
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.done_all_rounded),
                    label: Text(
                      communityText(
                        context,
                        'Mark this page read',
                        'تحديد هذه الصفحة كمقروءة',
                      ),
                    ),
                  ),
                ),
              if (_loadingFirst)
                const Center(child: CircularProgressIndicator()),
              if (!_loadingFirst && filteredNotifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    communityText(
                      context,
                      (_filter == _ActivityFilter.all ||
                                  _filter == _ActivityFilter.updates) &&
                              updates.isEmpty
                          ? 'No community updates'
                          : 'No updates in this category yet.',
                      (_filter == _ActivityFilter.all ||
                                  _filter == _ActivityFilter.updates) &&
                              updates.isEmpty
                          ? 'لا توجد تحديثات للمجتمع'
                          : 'لا توجد تحديثات في هذه الفئة بعد.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!_loadingFirst &&
                  (_filter == _ActivityFilter.all ||
                      _filter == _ActivityFilter.updates) &&
                  updates.isEmpty)
                Center(
                  child: FilledButton.icon(
                    onPressed: () => _openAndRefresh('/community/people'),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      communityText(context, 'Find people', 'البحث عن أشخاص'),
                    ),
                  ),
                ),
              for (final notification
                  in _loadingFirst
                      ? const <CommunityNotification>[]
                      : filteredNotifications)
                Card(
                  key: marker(notification.id),
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
                    title: Text(_notificationTitle(notification)),
                    subtitle: Text(
                      notification.seen
                          ? communityText(context, 'Seen', 'تمت المشاهدة')
                          : communityText(context, 'New', 'جديد'),
                    ),
                    trailing: _notificationTrailing(notification),
                    onTap:
                        notification.kind ==
                            CommunityNotificationKind.collaborationInvite
                        ? null
                        : () => _openNotification(notification),
                  ),
                ),
              if (!_loadingFirst && _hasMore)
                TextButton.icon(
                  key: const Key('community-activity-load-more'),
                  onPressed: _loadingMore ? null : () => _loadMore(persisted),
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(
                    communityText(context, 'Load more', 'تحميل المزيد'),
                  ),
                ),
              if (!_loadingFirst &&
                  (_filter == _ActivityFilter.all ||
                      _filter == _ActivityFilter.updates) &&
                  updates.incomingRequests > 0)
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
              if (!_loadingFirst &&
                  (_filter == _ActivityFilter.all ||
                      _filter == _ActivityFilter.updates) &&
                  updates.unreadMessages > 0)
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
          ),
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
    this.communityUpdates = 0,
    this.notifications = const <CommunityNotification>[],
  }) : signedOut = false;

  const _CommunityUpdates.signedOut()
    : incomingRequests = 0,
      unreadMessages = 0,
      communityUpdates = 0,
      notifications = const <CommunityNotification>[],
      signedOut = true;

  final int incomingRequests;
  final int unreadMessages;
  final int communityUpdates;
  final List<CommunityNotification> notifications;
  final bool signedOut;

  bool get isEmpty =>
      incomingRequests == 0 &&
      unreadMessages == 0 &&
      communityUpdates == 0 &&
      notifications.isEmpty;
}
