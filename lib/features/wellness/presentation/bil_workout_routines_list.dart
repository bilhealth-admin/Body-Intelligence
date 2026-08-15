part of 'bil_workout_routines_page.dart';

class _WorkoutExploreSections extends StatelessWidget {
  const _WorkoutExploreSections({
    required this.items,
    required this.savedIds,
    required this.mediaCache,
    required this.online,
    required this.isLocked,
    required this.onOpen,
    required this.onToggleSaved,
  });

  final List<WellnessContentItem> items;
  final Set<String> savedIds;
  final WellnessMediaCache mediaCache;
  final bool online;
  final bool Function(WellnessContentItem item) isLocked;
  final ValueChanged<WellnessContentItem> onOpen, onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<WellnessContentItem>>{};
    final descriptions = <String, String?>{};
    final orderedItems = [...items]
      ..sort((left, right) {
        final order = (left.categoryOrder ?? 1 << 30).compareTo(
          right.categoryOrder ?? 1 << 30,
        );
        if (order != 0) return order;
        final category = (left.category ?? '').compareTo(right.category ?? '');
        if (category != 0) return category;
        return left.title.compareTo(right.title);
      });
    for (final item in orderedItems) {
      final category = item.category?.trim();
      final title = category == null || category.isEmpty
          ? _copy(context, 'More routines', 'روتينات إضافية')
          : category;
      groups.putIfAbsent(title, () => []).add(item);
      descriptions.putIfAbsent(title, () => item.categoryDescription?.trim());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          _WorkoutCategorySection(
            title: entry.key,
            description: descriptions[entry.key],
            items: entry.value,
            savedIds: savedIds,
            mediaCache: mediaCache,
            online: online,
            isLocked: isLocked,
            onOpen: onOpen,
            onToggleSaved: onToggleSaved,
          ),
          const SizedBox(height: 28),
        ],
      ],
    );
  }
}

class _WorkoutCategorySection extends StatelessWidget {
  const _WorkoutCategorySection({
    required this.title,
    required this.description,
    required this.items,
    required this.savedIds,
    required this.mediaCache,
    required this.online,
    required this.isLocked,
    required this.onOpen,
    required this.onToggleSaved,
  });

  final String title;
  final String? description;
  final List<WellnessContentItem> items;
  final Set<String> savedIds;
  final WellnessMediaCache mediaCache;
  final bool online;
  final bool Function(WellnessContentItem item) isLocked;
  final ValueChanged<WellnessContentItem> onOpen, onToggleSaved;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              _routineCount(context, items.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
      if (description?.isNotEmpty == true) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 20),
          child: Text(
            description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
      const SizedBox(height: 12),
      SizedBox(
        height: 352,
        child: ListView.separated(
          key: ValueKey('workout-category-$title'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.only(end: 20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 304,
              child: _WorkoutRoutineCard(
                item: item,
                saved: savedIds.contains(item.id),
                locked: isLocked(item),
                mediaCache: mediaCache,
                online: online,
                onOpen: () => onOpen(item),
                onToggleSaved: () => onToggleSaved(item),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class _WorkoutRoutineCard extends StatelessWidget {
  const _WorkoutRoutineCard({
    required this.item,
    required this.saved,
    required this.locked,
    required this.mediaCache,
    required this.online,
    required this.onToggleSaved,
    required this.onOpen,
  });

  final WellnessContentItem item;
  final bool saved;
  final bool locked;
  final WellnessMediaCache mediaCache;
  final bool online;
  final VoidCallback onToggleSaved, onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 352,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          key: ValueKey('workout-card-${item.id}'),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: locked ? 5 : 0,
                        sigmaY: locked ? 5 : 0,
                      ),
                      child: locked
                          ? _WorkoutCoverFallback(item: item)
                          : _WorkoutCover(
                              item: item,
                              mediaCache: mediaCache,
                              online: online,
                            ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB0000000)],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 12,
                      end: 10,
                      top: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          locked
                              ? _LockedBadge(minimumAccess: item.minimumAccess)
                              : _VerifiedBadge(item: item),
                          if (locked)
                            const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 28,
                            )
                          else
                            IconButton.filledTonal(
                              key: ValueKey('save-routine-${item.id}'),
                              tooltip: saved
                                  ? _copy(
                                      context,
                                      'Remove routine',
                                      'إزالة الروتين',
                                    )
                                  : _copy(
                                      context,
                                      'Save routine',
                                      'حفظ الروتين',
                                    ),
                              onPressed: onToggleSaved,
                              icon: Icon(
                                saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      start: 16,
                      end: 16,
                      bottom: 15,
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 9,
                      runSpacing: 7,
                      children: [
                        if (item.durationSeconds != null)
                          _MetaLabel(
                            icon: Icons.schedule_rounded,
                            text: _workoutSeconds(
                              context,
                              item.durationSeconds!,
                            ),
                          )
                        else if (item.durationMinutes != null)
                          _MetaLabel(
                            icon: Icons.schedule_rounded,
                            text: _workoutMinutes(
                              context,
                              item.durationMinutes!,
                            ),
                          ),
                        if (item.difficulty?.isNotEmpty == true)
                          _MetaLabel(
                            icon: Icons.signal_cellular_alt_rounded,
                            text: item.difficulty!,
                          ),
                        for (final metadata in _workoutPresenterMetadata(
                          context,
                          item,
                        ))
                          _MetaLabel(icon: metadata.icon, text: metadata.text),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.fitness_center_rounded, size: 17),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.equipment.isEmpty
                                ? _copy(context, 'No equipment', 'دون معدات')
                                : item.equipment.join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutCover extends StatelessWidget {
  const _WorkoutCover({
    required this.item,
    required this.mediaCache,
    required this.online,
  });
  final WellnessContentItem item;
  final WellnessMediaCache mediaCache;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final asset = item.imageMedia;
    if (asset != null) {
      return _VerifiedCachedImage(
        asset: asset,
        mediaCache: mediaCache,
        online: online,
        fit: BoxFit.cover,
        fallback: _WorkoutCoverFallback(item: item),
      );
    }
    return _WorkoutCoverFallback(item: item);
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge({required this.minimumAccess});

  final WellnessContentAccess minimumAccess;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('locked-workout-badge'),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xE1122943),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF9ED8FF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.workspace_premium_rounded,
          size: 15,
          color: Colors.white,
        ),
        const SizedBox(width: 4),
        Text(
          minimumAccess.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.item});
  final WellnessContentItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xD9111720),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified_rounded, size: 15, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          item.videoMedia == null
              ? _copy(context, 'Verified', 'موثق')
              : _copy(context, 'Video', 'فيديو'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 270),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}

class _OfflineInstalledBanner extends StatelessWidget {
  const _OfflineInstalledBanner();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const Icon(Icons.offline_bolt_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _copy(
                context,
                'Offline — showing verified workouts installed on this device.',
                'دون اتصال — تظهر التمارين الموثقة المثبتة على هذا الجهاز.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WorkoutLibraryLoading extends StatelessWidget {
  const _WorkoutLibraryLoading();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      LinearProgressIndicator(),
      SizedBox(height: 20),
      _LoadingCard(),
      SizedBox(height: 18),
      _LoadingCard(),
    ],
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => Container(
    height: 300,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
  );
}

class _WorkoutLibraryError extends StatelessWidget {
  const _WorkoutLibraryError({required this.offline, required this.onRetry});
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _CenteredLibraryState(
    icon: offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
    title: _copy(
      context,
      'The installed workout library could not be opened.',
      'تعذّر فتح مكتبة التمارين المثبتة.',
    ),
    message: _copy(
      context,
      'Nothing was changed. Retry when device storage is available.',
      'لم يتغير شيء. حاول مجددًا عندما يصبح تخزين الجهاز متاحًا.',
    ),
    action: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(_copy(context, 'Retry', 'إعادة المحاولة')),
    ),
  );
}

class _WorkoutLibraryEmpty extends StatelessWidget {
  const _WorkoutLibraryEmpty({
    required this.myRoutines,
    required this.offline,
    required this.hasInstalledItems,
    required this.onExplore,
    required this.onManagePacks,
  });

  final bool myRoutines, offline, hasInstalledItems;
  final VoidCallback onExplore, onManagePacks;

  @override
  Widget build(BuildContext context) {
    final filtered = hasInstalledItems && !myRoutines;
    return _CenteredLibraryState(
      icon: myRoutines
          ? Icons.bookmark_border_rounded
          : Icons.fitness_center_rounded,
      title: myRoutines
          ? _copy(
              context,
              'No saved routines yet',
              'لا توجد روتينات محفوظة بعد',
            )
          : filtered
          ? _copy(context, 'No matching workouts', 'لا توجد تمارين مطابقة')
          : offline
          ? _copy(
              context,
              'No workouts are installed for offline use',
              'لا توجد تمارين مثبتة للاستخدام دون اتصال',
            )
          : _copy(
              context,
              'No verified workout pack is installed',
              'لا توجد حزمة تمارين موثقة مثبتة',
            ),
      message: myRoutines
          ? _copy(
              context,
              'Save a verified workout from Explore to find it here.',
              'احفظ تمرينًا موثقًا من «استكشف» ليظهر هنا.',
            )
          : _copy(
              context,
              'BIL does not bundle unlicensed videos. Install a verified pack to browse trusted routines.',
              'لا يضمّن BIL فيديوهات غير مرخصة. ثبّت حزمة موثقة لتصفح روتينات موثوقة.',
            ),
      action: myRoutines
          ? FilledButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.explore_outlined),
              label: Text(
                _copy(context, 'Explore workouts', 'استكشف التمارين'),
              ),
            )
          : filtered
          ? null
          : FilledButton.icon(
              onPressed: onManagePacks,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(_copy(context, 'Manage packs', 'إدارة الحزم')),
            ),
    );
  }
}

/// Honest, non-playable discovery cards shown when no reviewed content pack is
/// installed. They reuse BIL-owned cover art and lead only to the manual log;
/// they never manufacture routine instructions or expose a video control.
class _WorkoutMetadataPreviews extends StatelessWidget {
  const _WorkoutMetadataPreviews({
    required this.offline,
    required this.onCardio,
    required this.onStrength,
    required this.onManagePacks,
  });

  final bool offline;
  final VoidCallback onCardio, onStrength, onManagePacks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _copy(context, 'Explore workout styles', 'استكشف أنماط التمارين'),
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        _copy(
          context,
          'Original BIL previews. Log an activity now, or install a reviewed pack for guided routines. No video is available from a preview.',
          'معاينات أصلية من BIL. سجّل نشاطًا الآن، أو ثبّت حزمة مراجعة للروتينات الموجّهة. لا يتوفر فيديو من المعاينة.',
        ),
      ),
      const SizedBox(height: 16),
      _WorkoutMetadataPreviewCard(
        key: const ValueKey('workout-metadata-preview-cardio'),
        title: _copy(context, 'Cardio', 'تمارين القلب'),
        asset: 'assets/images/workouts/workout_cardio_cover_v1.png',
        onTap: onCardio,
      ),
      const SizedBox(height: 14),
      _WorkoutMetadataPreviewCard(
        key: const ValueKey('workout-metadata-preview-strength'),
        title: _copy(context, 'Strength', 'تمارين القوة'),
        asset: 'assets/images/workouts/workout_strength_cover_v1.png',
        onTap: onStrength,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const ValueKey('workout-preview-manage-packs'),
        onPressed: onManagePacks,
        icon: const Icon(Icons.verified_outlined),
        label: Text(
          _copy(context, 'Manage reviewed packs', 'إدارة الحزم المراجعة'),
        ),
      ),
      if (offline) ...[
        const SizedBox(height: 10),
        Text(
          _copy(
            context,
            'Offline: only previously installed reviewed packs can provide guided routines.',
            'دون اتصال: لا توفر الروتينات الموجّهة إلا الحزم المراجعة المثبتة مسبقًا.',
          ),
        ),
      ],
    ],
  );
}

class _WorkoutMetadataPreviewCard extends StatelessWidget {
  const _WorkoutMetadataPreviewCard({
    super.key,
    required this.title,
    required this.asset,
    required this.onTap,
  });

  final String title, asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '$title. ${_copy(context, 'Metadata preview; no playable video', 'معاينة بيانات؛ لا يوجد فيديو قابل للتشغيل')}',
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 156,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(asset, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
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

class _CenteredLibraryState extends StatelessWidget {
  const _CenteredLibraryState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title, message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

String _copy(BuildContext context, String english, String arabic) =>
    wellnessCopy(context, english, arabic);

String _routineCount(BuildContext context, int count) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' => '$count روتين',
      'fr' => '$count routines',
      'es' => '$count rutinas',
      'tr' => '$count rutin',
      _ => '$count routines',
    };

String _workoutMinutes(BuildContext context, int minutes) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' => '$minutes دقيقة',
      'fr' => '$minutes min',
      'es' => '$minutes min',
      'tr' => '$minutes dk',
      _ => '$minutes min',
    };

String _workoutRepetitions(BuildContext context, int repetitions) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' => '$repetitions تكرار',
      'fr' => '$repetitions répétitions',
      'es' => '$repetitions repeticiones',
      'tr' => '$repetitions tekrar',
      _ => '$repetitions reps',
    };

String _workoutSeconds(BuildContext context, int seconds) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' => '$seconds ثانية',
      'fr' => '$seconds s',
      'es' => '$seconds s',
      'tr' => '$seconds sn',
      _ => '$seconds sec',
    };

String _workoutRestSeconds(BuildContext context, int seconds) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' => 'راحة $seconds ثانية',
      'fr' => '$seconds s de repos',
      'es' => '$seconds s de descanso',
      'tr' => '$seconds sn dinlenme',
      _ => '$seconds sec rest',
    };
