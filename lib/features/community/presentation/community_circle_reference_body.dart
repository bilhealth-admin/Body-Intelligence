part of 'community_hub_page.dart';

class _CommunityCircleReferenceBody extends StatelessWidget {
  const _CommunityCircleReferenceBody({
    required this.circles,
    required this.search,
    required this.myCircles,
    required this.busy,
    required this.onSearch,
    required this.onSelect,
    required this.onRefresh,
    required this.onMembership,
    required this.onOpen,
    required this.onCompose,
    required this.serverSearch,
    required this.serverRows,
    required this.serverLoading,
    required this.serverError,
    required this.serverHasMore,
    required this.onLoadMore,
    required this.searchStarting,
    required this.searchUnavailable,
    required this.onSearchMore,
    required this.onLocalSearch,
    required this.onManage,
  });

  final Future<List<CommunityCircle>> circles;
  final TextEditingController search;
  final bool myCircles;
  final Set<String> busy;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool> onSelect;
  final Future<void> Function() onRefresh;
  final ValueChanged<CommunityCircle> onMembership;
  final ValueChanged<CommunityCircle> onOpen;
  final ValueChanged<CommunityCircle>? onCompose;
  final bool serverSearch;
  final List<ManagedCommunityCircle> serverRows;
  final bool serverLoading;
  final Object? serverError;
  final bool serverHasMore;
  final Future<void> Function() onLoadMore;
  final bool searchStarting;
  final bool searchUnavailable;
  final VoidCallback onSearchMore;
  final VoidCallback onLocalSearch;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: CustomScrollView(
      key: const Key('community-circles-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _CommunityCircleDiscoveryHeader(
            controller: search,
            myCircles: myCircles,
            onSearch: onSearch,
            onSelect: onSelect,
            serverSearch: serverSearch,
            searchStarting: searchStarting,
            searchUnavailable: searchUnavailable,
            onSearchMore: onSearchMore,
            onLocalSearch: onLocalSearch,
            onManage: onManage,
          ),
        ),
        if (serverSearch)
          if (serverLoading && serverRows.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (serverError != null && serverRows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: _serverRetry(context)),
            )
          else
            _results(context, serverRows, filterLocal: false)
        else
          FutureBuilder<List<CommunityCircle>>(
            future: circles,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: FilledButton.icon(
                      key: const Key('community-circles-retry'),
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        communityText(context, 'Retry', 'إعادة المحاولة'),
                      ),
                    ),
                  ),
                );
              }
              return _results(
                context,
                snapshot.data ?? const <CommunityCircle>[],
              );
            },
          ),
        if (serverSearch && serverRows.isNotEmpty && serverError != null)
          SliverToBoxAdapter(child: _serverRetry(context)),
        if (serverSearch &&
            serverRows.isNotEmpty &&
            (serverHasMore || serverLoading))
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  key: const Key('bil06-search-more-results'),
                  onPressed: serverLoading ? null : onLoadMore,
                  icon: serverLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(
                    communityText(context, 'Load more', 'تحميل المزيد'),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _serverRetry(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          circleManagementText(
            context,
            'Could not load circle search results. Try again.',
            'تعذر تحميل نتائج البحث عن الدوائر. حاول مجددًا.',
          ),
        ),
        TextButton.icon(
          key: const Key('bil06-server-search-retry'),
          onPressed: serverLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
        ),
      ],
    ),
  );

  Widget _results(
    BuildContext context,
    List<CommunityCircle> records, {
    bool filterLocal = true,
  }) {
    final query = search.text.trim().toLowerCase();
    final rows = records
        .where((c) {
          if (!filterLocal) return true;
          if (myCircles && !c.activeMember && !c.pending) return false;
          if (query.isEmpty) return true;
          return [
            c.slug,
            _circleRecordTitle(context, c),
            _circleKnownDescription(context, c) ?? '',
          ].any((value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);
    if (rows.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              _emptyText(context, query.isNotEmpty),
              key: const Key('community-circles-empty'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      sliver: SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) => _row(context, rows[index]),
      ),
    );
  }

  String _emptyText(BuildContext context, bool searching) => searching
      ? communityText(
          context,
          'No circles match your search.',
          'لا توجد دوائر تطابق بحثك.',
        )
      : myCircles
      ? communityText(
          context,
          'You have not joined a circle yet.',
          'لم تنضم إلى أي دائرة بعد.',
        )
      : communityText(
          context,
          'No circles are available yet.',
          'لا توجد دوائر متاحة بعد.',
        );

  Widget _row(BuildContext context, CommunityCircle circle) => LayoutBuilder(
    builder: (context, bounds) {
      final headerAction =
          MediaQuery.textScalerOf(context).scale(1) < 1.5 &&
          bounds.maxWidth >= 360;
      final actions = Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: headerAction ? 108 : 240),
            child: OutlinedButton(
              key: Key('community-circle-membership-${circle.slug}'),
              onPressed:
                  busy.contains(circle.slug) ||
                      !_circleCanChangeMembership(circle)
                  ? null
                  : () => onMembership(circle),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(70, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                foregroundColor: circle.activeMember
                    ? CommunitySapphire.ink(context)
                    : CommunitySapphire.blue,
                backgroundColor: Theme.of(context).colorScheme.primary
                    .withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? .14
                          : .045,
                    ),
                side: BorderSide.none,
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: const StadiumBorder(),
              ),
              child: Text(
                _circleMembershipLabel(context, circle),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (circle.activeMember && onCompose != null)
            IconButton(
              tooltip: communityText(
                context,
                'Post in circle',
                'انشر في الدائرة',
              ),
              onPressed: () => onCompose!(circle),
              color: CommunitySapphire.blue,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
        ],
      );
      return InkWell(
        key: Key('community-circle-row-${circle.slug}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpen(circle),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CommunityCircleCover(circle: circle),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _circleRecordTitle(context, circle),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontSize: 14,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: CommunitySapphire.ink(context),
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${MaterialLocalizations.of(context).formatDecimal(circle.memberCount)} ${communityText(context, 'members', 'أعضاء')}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 12,
                                color: CommunitySapphire.muted(context),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (headerAction) ...[const SizedBox(width: 8), actions],
                ],
              ),
              if (!headerAction)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 68, top: 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: actions,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
