part of 'bil_workout_routines_page.dart';

class _WorkoutVideosWall extends StatefulWidget {
  const _WorkoutVideosWall({
    required this.plan,
    required this.catalogItems,
    required this.visibleItems,
    required this.savedIds,
    required this.mediaCache,
    required this.online,
    required this.premiumUnlocked,
    required this.premiumTier,
    required this.isLocked,
    required this.onUpgrade,
    required this.onOpen,
    required this.onToggleSaved,
  });

  final GymSixMonthPlan plan;
  final List<WellnessContentItem> catalogItems;
  final List<WellnessContentItem> visibleItems;
  final Set<String> savedIds;
  final WellnessMediaCache mediaCache;
  final bool online;
  final bool premiumUnlocked;
  final String premiumTier;
  final bool Function(WellnessContentItem item) isLocked;
  final VoidCallback onUpgrade;
  final ValueChanged<WellnessContentItem> onOpen, onToggleSaved;

  @override
  State<_WorkoutVideosWall> createState() => _WorkoutVideosWallState();
}

class _WorkoutVideosWallState extends State<_WorkoutVideosWall> {
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final visibleIds = widget.visibleItems.map((item) => item.stableId).toSet();
    final sections = _sections()
        .map((section) => section.onlyVisible(visibleIds))
        .where((section) => section.items.isNotEmpty)
        .toList(growable: false);
    return SliverList(
      key: const ValueKey('workout-videos-wall'),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final section = sections[index];
          return Padding(
            key: ValueKey('workout-video-section-${section.id}'),
            padding: const EdgeInsets.only(bottom: 28),
            child: _WorkoutCategorySection(
              title: section.title,
              subtitle: section.subtitle,
              items: _expanded.contains(section.id)
                  ? section.items
                  : section.items.take(5).toList(growable: false),
              totalCount: section.items.length,
              expanded: _expanded.contains(section.id),
              freePreviewStableId: section.freePreviewStableId,
              onToggleExpanded: () => setState(() {
                if (!_expanded.remove(section.id)) _expanded.add(section.id);
              }),
              savedIds: widget.savedIds,
              mediaCache: widget.mediaCache,
              online: widget.online,
              premiumUnlocked: widget.premiumUnlocked,
              premiumTier: widget.premiumTier,
              isLocked: widget.isLocked,
              onUpgrade: widget.onUpgrade,
              onOpen: widget.onOpen,
              onToggleSaved: widget.onToggleSaved,
            ),
          );
        },
        childCount: sections.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }

  List<_WorkoutVideoSection> _sections() {
    final byId = <String, WellnessContentItem>{
      for (final item in widget.catalogItems)
        if (item.releaseBundleId == 'gym-six-month') item.id: item,
    };
    final sessions = <String, GymPlanSession>{
      for (final session in widget.plan.sessions) session.id: session,
    };
    final result = <_WorkoutVideoSection>[];

    for (final month in widget.plan.months) {
      final ids = <String>[];
      for (final sessionId in month.sessionIds) {
        final session = sessions[sessionId];
        if (session == null) continue;
        for (final id in session.exerciseIds) {
          if (!ids.contains(id)) ids.add(id);
        }
      }
      final monthItems = _itemsForIds(ids, byId);
      WellnessContentItem? preview;
      for (final item in monthItems) {
        if (WorkoutFreePreviewPolicy.isPreview(item)) {
          preview = item;
          break;
        }
      }
      if (monthItems.isNotEmpty) {
        result.add(
          _WorkoutVideoSection.withOptionalPreview(
            id: 'month-${month.month}',
            title: workoutVideoMonthTitle(context, month.month),
            subtitle: _workoutMonthSchedule(context, month, sessions),
            items: _previewFirst(monthItems, preview?.releaseKey),
          ),
        );
      }
    }

    final warmupItems = _itemsForIds(widget.plan.warmups.exerciseIds, byId);
    if (warmupItems.isNotEmpty) {
      result.add(
        _WorkoutVideoSection.withOptionalPreview(
          id: 'warm-up-mobility',
          title: _workoutPlanGroupTitle(context, 'gym-warm-up-mobility'),
          subtitle: _verifiedMovementCount(context, warmupItems.length),
          items: _previewFirst(
            warmupItems,
            WorkoutFreePreviewPolicy.releaseKeyForGroup('gym-warm-up-mobility'),
          ),
        ),
      );
    }

    const functionalGroups = <String>[
      'gym-muscle-pair-split',
      'gym-upper-lower',
      'gym-full-body',
      'gym-arnold-split',
      'gym-powerbuilding',
      'gym-exercise-technique',
    ];
    for (final groupId in functionalGroups) {
      _appendGroupSection(result, groupId);
    }

    const homeGroups = <String>[
      'home-resistance-upper-body',
      'home-resistance-lower-body',
      'home-resistance-full-body',
      'home-cardio-conditioning',
      'home-cardio-low-impact',
      'home-home-bodyweight',
      'home-core-stability',
      'home-mobility-flexibility',
      'home-recovery-beginner',
      'home-balance-coordination',
    ];
    for (final groupId in homeGroups) {
      _appendGroupSection(result, groupId);
    }
    final categorizedIds = result
        .expand((section) => section.items)
        .map((item) => item.stableId)
        .toSet();
    final remaining =
        widget.catalogItems
            .where((item) => !categorizedIds.contains(item.stableId))
            .toList(growable: false)
          ..sort((left, right) => left.title.compareTo(right.title));
    if (remaining.isNotEmpty) {
      result.add(
        _WorkoutVideoSection.ungrouped(
          id: 'more-routines',
          title: _copy(context, 'More routines', 'روتينات إضافية'),
          subtitle: _verifiedMovementCount(context, remaining.length),
          items: remaining,
        ),
      );
    }
    return result;
  }

  void _appendGroupSection(List<_WorkoutVideoSection> result, String groupId) {
    final items = widget.catalogItems
        .where((item) => item.planGroupIds.contains(groupId))
        .toList(growable: false);
    if (items.isEmpty) return;
    result.add(
      _WorkoutVideoSection.withOptionalPreview(
        id: groupId,
        title: workoutVideoGroupTitle(context, groupId),
        subtitle: _verifiedMovementCount(context, items.length),
        items: _previewFirst(
          items,
          WorkoutFreePreviewPolicy.releaseKeyForGroup(groupId),
        ),
      ),
    );
  }
}

class _WorkoutVideoSection {
  const _WorkoutVideoSection._({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.freePreviewStableId,
  });

  final String id, title, subtitle;
  final List<WellnessContentItem> items;
  final String? freePreviewStableId;

  factory _WorkoutVideoSection.withOptionalPreview({
    required String id,
    required String title,
    required String subtitle,
    required List<WellnessContentItem> items,
  }) {
    final first = items.isEmpty ? null : items.first;
    final previewId = first != null && WorkoutFreePreviewPolicy.isPreview(first)
        ? first.stableId
        : '';
    return _WorkoutVideoSection._(
      id: id,
      title: title,
      subtitle: subtitle,
      items: items,
      // Empty means the catalog omitted the pinned preview. The section stays
      // renderable, but every card remains fail-closed for Free members.
      freePreviewStableId: previewId,
    );
  }

  factory _WorkoutVideoSection.ungrouped({
    required String id,
    required String title,
    required String subtitle,
    required List<WellnessContentItem> items,
  }) => _WorkoutVideoSection._(
    id: id,
    title: title,
    subtitle: subtitle,
    items: items,
    freePreviewStableId: null,
  );

  _WorkoutVideoSection onlyVisible(Set<String> visibleIds) =>
      _WorkoutVideoSection._(
        id: id,
        title: title,
        subtitle: subtitle,
        items: items
            .where((item) => visibleIds.contains(item.stableId))
            .toList(growable: false),
        freePreviewStableId: freePreviewStableId,
      );
}

List<WellnessContentItem> _itemsForIds(
  Iterable<String> ids,
  Map<String, WellnessContentItem> byId,
) {
  final result = <WellnessContentItem>[];
  final seen = <String>{};
  for (final id in ids) {
    final item = byId[id];
    if (item != null && seen.add(item.stableId)) result.add(item);
  }
  return result;
}

List<WellnessContentItem> _previewFirst(
  Iterable<WellnessContentItem> source,
  String? preferredReleaseKey,
) {
  final items = source.toList(growable: false);
  items.sort((left, right) {
    final leftPreferred = left.releaseKey == preferredReleaseKey;
    final rightPreferred = right.releaseKey == preferredReleaseKey;
    if (leftPreferred != rightPreferred) return leftPreferred ? -1 : 1;
    final leftPreview = WorkoutFreePreviewPolicy.isPreview(left);
    final rightPreview = WorkoutFreePreviewPolicy.isPreview(right);
    if (leftPreview != rightPreview) return leftPreview ? -1 : 1;
    return left.title.compareTo(right.title);
  });
  return items;
}

String _workoutMonthSchedule(
  BuildContext context,
  GymPlanMonth month,
  Map<String, GymPlanSession> sessions,
) {
  final phase = Localizations.localeOf(context).languageCode == 'en'
      ? month.phase
      : workoutVideoPhaseTitle(context, month.month);
  final schedule = month.sessionIds
      .where(sessions.containsKey)
      .map((id) => _localizedSessionName(context, id))
      .join(' • ');
  return '$phase · $schedule';
}

String _localizedSessionName(BuildContext context, String id) {
  return workoutVideoSessionName(context, id);
}

String _verifiedMovementCount(BuildContext context, int count) =>
    workoutVerifiedMovementCount(context, count);
