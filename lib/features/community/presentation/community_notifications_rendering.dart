part of 'community_notifications_page.dart';

extension _CommunityNotificationsRendering on _CommunityNotificationsPageState {
  Widget buildCommunityNotifications(BuildContext context) => Scaffold(
    bottomNavigationBar: BilReferenceBottomBar(
      selected: 3,
      onSelected: (index) => context.go(BilReferenceBottomBar.routes[index]),
    ),
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      centerTitle: true,
      title: Text(
        communityText(context, 'Notifications', 'الإشعارات'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      actions: [
        IconButton(
          tooltip: communityText(
            context,
            'Notification settings',
            'إعدادات الإشعارات',
          ),
          onPressed: () => context.push('/notification-settings'),
          icon: const Icon(Icons.settings_outlined),
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
              'Notifications are unavailable',
              'الإشعارات غير متاحة',
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
        final newNotifications = filteredNotifications
            .where((row) => _newActivityIds.contains(row.id))
            .toList(growable: false);
        final earlierNotifications = filteredNotifications
            .where((row) => !_newActivityIds.contains(row.id))
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
          builder: (context, marker) => RefreshIndicator(
            onRefresh: () async {
              _retry();
              try {
                await _updates;
              } on Object {
                // The FutureBuilder presents the retry state.
              }
            },
            child: ListView(
              key: const PageStorageKey('community-activity-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _referenceActivityFilters) ...[
                        ChoiceChip(
                          key: Key('community-activity-filter-${filter.name}'),
                          selected: _filter == filter,
                          showCheckmark: filter == _ActivityFilter.all,
                          side: BorderSide(
                            color: _filter == filter
                                ? Colors.transparent
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: _filter == filter
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
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
                if (!_loadingFirst &&
                    (updates.incomingRequests > 0 ||
                        updates.unreadMessages > 0))
                  _CommunityNotificationsReferenceWidgets(
                    this,
                  )._attentionActions(context, updates),
                if (_loadingFirst) ...[
                  const SizedBox(height: 28),
                  const Center(child: CircularProgressIndicator()),
                ] else if (filteredNotifications.isEmpty &&
                    updates.isEmpty) ...[
                  const SizedBox(height: 72),
                  _CenteredUpdatesState(
                    icon: Icons.notifications_none_rounded,
                    title: communityText(
                      context,
                      'You are all caught up',
                      'أنت مطّلع على كل جديد',
                    ),
                    body: communityText(
                      context,
                      'New approvals, mentions and comments will appear here.',
                      'ستظهر الموافقات والإشارات والتعليقات الجديدة هنا.',
                    ),
                  ),
                ] else ...[
                  if (newNotifications.isNotEmpty)
                    _CommunityNotificationsReferenceWidgets(
                      this,
                    )._activitySectionLabel(
                      context,
                      'New',
                      'جديد',
                      trailing: IconButton(
                        key: const Key('community-activity-mark-page-read'),
                        onPressed:
                            _markingPageSeen ||
                                !filteredNotifications.any((row) => !row.seen)
                            ? null
                            : () => _markLoadedPageSeen(persisted),
                        tooltip: communityText(
                          context,
                          'Mark this page read',
                          'تحديد هذه الصفحة كمقروءة',
                        ),
                        icon: _markingPageSeen
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.more_horiz_rounded, size: 20),
                      ),
                    ),
                  for (final notification in newNotifications)
                    _CommunityNotificationsReferenceWidgets(
                      this,
                    )._referenceActivityRow(
                      context,
                      notification,
                      marker(notification.id),
                    ),
                  if (earlierNotifications.isNotEmpty)
                    _CommunityNotificationsReferenceWidgets(
                      this,
                    )._activitySectionLabel(context, 'Earlier', 'سابقًا'),
                  for (final notification in earlierNotifications)
                    _CommunityNotificationsReferenceWidgets(
                      this,
                    )._referenceActivityRow(
                      context,
                      notification,
                      marker(notification.id),
                    ),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        key: const Key('community-activity-load-more'),
                        onPressed: _loadingMore
                            ? null
                            : () => _loadMore(persisted),
                        icon: _loadingMore
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          communityText(context, 'Load more', 'تحميل المزيد'),
                        ),
                      ),
                    ),
                ],
              ],
            ),
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
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
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
