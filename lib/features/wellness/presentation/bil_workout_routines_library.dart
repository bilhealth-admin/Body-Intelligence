part of 'bil_workout_routines_page.dart';

extension _WorkoutLibrarySurface on _BilWorkoutRoutinesPageState {
  Widget _buildLibrary(
    List<WellnessContentItem> items,
    GymSixMonthPlan gymPlan,
  ) {
    final subscription = _usableVerifiedSubscription(
      ref.watch(verifiedSubscriptionStateProvider),
    );
    final premiumUnlocked =
        subscription != null && subscription.plan != CommercePlan.free;
    final storefrontPlan = ref.watch(storefrontTargetPlanProvider).value;
    const premiumTier = 'Premium';
    void openPremium() => context.push(
      storefrontPlan == CommercePlan.premiumAiCoach
          ? '/plans?focus=boost'
          : '/plans?focus=subscription',
    );
    final selectedItems = switch (_tabs.index) {
      0 => items,
      1 => items.where((item) => item.releaseBundleId != 'home-training'),
      2 => items.where((item) => item.releaseBundleId == 'home-training'),
      _ => items.where((item) => _routineIds.contains(item.stableId)),
    };
    final categoryOrders = <String, int>{};
    for (final item in selectedItems) {
      final category = item.category?.trim();
      if (category == null || category.isEmpty) continue;
      final order = item.categoryOrder ?? 1 << 30;
      final current = categoryOrders[category];
      if (current == null || order < current) categoryOrders[category] = order;
    }
    final categories = categoryOrders.keys.toList()
      ..sort((left, right) {
        final order = categoryOrders[left]!.compareTo(categoryOrders[right]!);
        return order == 0 ? left.compareTo(right) : order;
      });
    if (_category != null && !categories.contains(_category)) {
      _category = null;
    }
    final query = _query.trim().toLowerCase();
    final visible = selectedItems
        .where((item) {
          if (_tabs.index != 0 &&
              _category != null &&
              item.category?.trim() != _category) {
            return false;
          }
          if (!_matchesWorkoutPresenter(item, _presenterFilter)) return false;
          if (query.isEmpty) return true;
          return workoutDiscoveryMatchesQuery(item, query);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: CustomScrollView(
        key: ValueKey('workout-library-tab-${_tabs.index}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.offline) ...[
                    const _OfflineInstalledBanner(),
                    const SizedBox(height: 14),
                  ],
                  LayoutBuilder(
                    key: const ValueKey('workout-video-library-header'),
                    builder: (context, constraints) {
                      final verifiedVideoCount = items
                          .where((item) => item.videoMedia != null)
                          .length;
                      Widget titleBlock() => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            verifiedVideoCount == 0
                                ? _copy(
                                    context,
                                    'Verified workout video library',
                                    'مكتبة فيديوهات تمارين موثّقة',
                                  )
                                : wellnessVerifiedWorkoutVideoCount(
                                    context,
                                    verifiedVideoCount,
                                  ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _copy(
                              context,
                              'Explore 10 training categories with clear movement guidance and reusable routines.',
                              'فيديوهات موثقة وبرامج تدريب قابلة لإعادة الاستخدام في مكان واحد.',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );

                      final programsButton = FilledButton.tonalIcon(
                        key: const ValueKey('workout-programs-inline-action'),
                        onPressed: () => context.push('/wellness/workouts/log'),
                        icon: const Icon(Icons.playlist_play_rounded),
                        label: Text(
                          _copy(context, 'Wellness programs', 'برامج العافية'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                      final programsActions = Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [programsButton],
                      );

                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleBlock(),
                            const SizedBox(height: 10),
                            programsActions,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: titleBlock()),
                          const SizedBox(width: 12),
                          Flexible(child: programsActions),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        _mutateWorkoutLibrary(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: _copy(
                        context,
                        'Search verified workouts',
                        'ابحث في التمارين الموثقة',
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: _copy(context, 'Clear', 'مسح'),
                              onPressed: () {
                                _searchController.clear();
                                _mutateWorkoutLibrary(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WorkoutPresenterFilterPanel(
                    value: _presenterFilter,
                    onChanged: (value) =>
                        _mutateWorkoutLibrary(() => _presenterFilter = value),
                  ),
                  if (_tabs.index != 0 && categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        key: const ValueKey('workout-category-list'),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: _copy(context, 'All', 'الكل'),
                            selected: _category == null,
                            onSelected: () =>
                                _mutateWorkoutLibrary(() => _category = null),
                          ),
                          for (final category in categories)
                            _CategoryChip(
                              label: _workoutCategoryFilterLabel(
                                context,
                                category,
                              ),
                              selected: _category == category,
                              onSelected: () => _mutateWorkoutLibrary(
                                () => _category = category,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (visible.isEmpty && _tabs.index != 3 && items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverToBoxAdapter(
                child: _WorkoutMetadataPreviews(
                  offline: widget.offline,
                  onCardio: () =>
                      context.push('/wellness/workouts/log?category=Cardio'),
                  onStrength: () =>
                      context.push('/wellness/workouts/log?category=Strength'),
                  onManagePacks: () => context.push('/wellness/content-packs'),
                ),
              ),
            )
          else if (visible.isEmpty && _tabs.index != 3)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _WorkoutLibraryEmpty(
                myRoutines: false,
                offline: widget.offline,
                hasInstalledItems: true,
                onExplore: () => _tabs.animateTo(0),
                onManagePacks: () => context.push('/wellness/content-packs'),
              ),
            )
          else if (_tabs.index == 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 0, 40),
              sliver: _WorkoutVideosWall(
                plan: gymPlan,
                catalogItems: items,
                visibleItems: visible,
                savedIds: _routineIds,
                mediaCache: _mediaCache,
                online: !widget.offline,
                premiumUnlocked: premiumUnlocked,
                premiumTier: premiumTier,
                isLocked: _isLocked,
                onUpgrade: openPremium,
                onOpen: _openDetails,
                onToggleSaved: _toggleRoutine,
              ),
            )
          else if (_tabs.index != 3)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 0, 40),
              sliver: SliverToBoxAdapter(
                child: _WorkoutExploreSections(
                  items: visible,
                  savedIds: _routineIds,
                  mediaCache: _mediaCache,
                  online: !widget.offline,
                  premiumUnlocked: premiumUnlocked,
                  premiumTier: premiumTier,
                  isLocked: _isLocked,
                  onUpgrade: openPremium,
                  onOpen: _openDetails,
                  onToggleSaved: _toggleRoutine,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverToBoxAdapter(
                child: _MyWorkoutRoutinesView(
                  items: items,
                  savedItems: visible,
                  routines: _customRoutines,
                  mediaCache: _mediaCache,
                  online: !widget.offline,
                  isLocked: _isLocked,
                  onOpen: _openDetails,
                  onToggleSaved: _toggleRoutine,
                  onCreate: () => _showCustomRoutineBuilder(items),
                  onDelete: _customMutationBusy ? null : _deleteCustomRoutine,
                  onComplete: _logCustomRoutine,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _workoutCategoryFilterLabel(BuildContext context, String category) {
  if (workoutVideoGroupIds.contains(category)) {
    return workoutVideoGroupTitle(context, category);
  }
  final arabic = switch (category) {
    'Strength' => 'تمارين القوة',
    'Cardio' => 'تمارين القلب',
    'Recovery' => 'التعافي',
    _ => category,
  };
  return wellnessCopy(context, category, arabic);
}

/// Shared production matcher for workout discovery cards.
///
/// Arabic titles intentionally contain both the reviewed phonetic form and the
/// canonical English name, so incremental input in either script follows this
/// same substring path.
bool workoutDiscoveryMatchesQuery(WellnessContentItem item, String rawQuery) {
  final query = _normalizeWorkoutDiscoverySearch(rawQuery);
  if (query.isEmpty) return true;
  final searchable = _normalizeWorkoutDiscoverySearch(
    <String>[
      item.title,
      item.description,
      item.category ?? '',
      item.difficulty ?? '',
      ...item.equipment,
      ...item.tags,
    ].join(' '),
  );
  return searchable.contains(query);
}

String _normalizeWorkoutDiscoverySearch(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(
      RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'),
      '',
    )
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي');
