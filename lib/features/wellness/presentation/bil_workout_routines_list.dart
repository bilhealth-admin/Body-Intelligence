part of 'bil_workout_routines_page.dart';

class _WorkoutExploreSections extends StatefulWidget {
  const _WorkoutExploreSections({
    required this.items,
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

  final List<WellnessContentItem> items;
  final Set<String> savedIds;
  final WellnessMediaCache mediaCache;
  final bool online;
  final bool premiumUnlocked;
  final String premiumTier;
  final bool Function(WellnessContentItem item) isLocked;
  final VoidCallback onUpgrade;
  final ValueChanged<WellnessContentItem> onOpen, onToggleSaved;

  @override
  State<_WorkoutExploreSections> createState() =>
      _WorkoutExploreSectionsState();
}

class _WorkoutExploreSectionsState extends State<_WorkoutExploreSections> {
  final Set<String> _expandedGroups = {};

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<WellnessContentItem>>{};
    final orderedItems = [...widget.items]
      ..sort((left, right) => left.title.compareTo(right.title));
    for (final item in orderedItems) {
      final memberships = item.releaseBundleId == 'gym-six-month'
          ? item.planGroupIds
          : <String>[
              if (item.primaryPlanGroupId?.isNotEmpty == true)
                item.primaryPlanGroupId!
              else
                item.category ?? 'more-routines',
            ];
      for (final groupId in memberships) {
        groups.putIfAbsent(groupId, () => []).add(item);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          _WorkoutCategorySection(
            title: _workoutPlanGroupTitle(context, entry.key),
            items: _expandedGroups.contains(entry.key)
                ? entry.value
                : entry.value.take(5).toList(growable: false),
            totalCount: entry.value.length,
            expanded: _expandedGroups.contains(entry.key),
            onToggleExpanded: () => setState(() {
              if (!_expandedGroups.remove(entry.key)) {
                _expandedGroups.add(entry.key);
              }
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
          const SizedBox(height: 28),
        ],
      ],
    );
  }
}

class _WorkoutCategorySection extends StatelessWidget {
  const _WorkoutCategorySection({
    required this.title,
    required this.items,
    required this.totalCount,
    required this.expanded,
    required this.onToggleExpanded,
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

  final String title;
  final List<WellnessContentItem> items;
  final int totalCount;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final Set<String> savedIds;
  final WellnessMediaCache mediaCache;
  final bool online;
  final bool premiumUnlocked;
  final String premiumTier;
  final bool Function(WellnessContentItem item) isLocked;
  final VoidCallback onUpgrade;
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
            TextButton(
              onPressed: totalCount > 5 ? onToggleExpanded : null,
              child: Text(
                totalCount > 5
                    ? expanded
                          ? _workoutHubCopy(context, 'Show less')
                          : _workoutHubCopy(context, 'See all')
                    : _routineCount(context, totalCount),
              ),
            ),
          ],
        ),
      ),
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
            final contentLocked = isLocked(item);
            final collectionLocked = index > 0 && !premiumUnlocked;
            return SizedBox(
              width: 304,
              child: PremiumCollectionItemGate(
                key: ValueKey('workout-premium-gate-${item.stableId}'),
                locked: collectionLocked,
                tier: premiumTier,
                onUpgrade: onUpgrade,
                child: _WorkoutRoutineCard(
                  item: item,
                  saved: savedIds.contains(item.stableId),
                  locked: contentLocked,
                  mediaCache: mediaCache,
                  online: online,
                  onOpen: () => onOpen(item),
                  onToggleSaved: () => onToggleSaved(item),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

String _workoutPlanGroupTitle(BuildContext context, String groupId) =>
    switch (groupId) {
      'gym-push' => _copy(context, 'Push', 'الدفع'),
      'gym-pull' => _copy(context, 'Pull', 'السحب'),
      'gym-legs' => _copy(context, 'Legs', 'الأرجل'),
      'gym-warm-up-mobility' => _copy(
        context,
        'Warm-up & mobility',
        'الإحماء والحركة',
      ),
      'gym-full-body' => _copy(context, 'Full body', 'كامل الجسم'),
      'gym-upper-lower' => _copy(context, 'Upper / Lower', 'علوي / سفلي'),
      'gym-muscle-pair-split' => _copy(
        context,
        'Muscle pair split',
        'تقسيم العضلات المزدوج',
      ),
      'gym-arnold-split' => _copy(context, 'Arnold split', 'تقسيم أرنولد'),
      'gym-powerbuilding' => _copy(
        context,
        'Strength + hypertrophy',
        'القوة والتضخيم',
      ),
      'gym-exercise-technique' => _copy(
        context,
        'Exercise technique',
        'تقنية التمرين',
      ),
      _ =>
        groupId
            .replaceFirst(RegExp(r'^home-'), '')
            .split('-')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' '),
    };

String _workoutHubCopy(BuildContext context, String key) {
  const copy = <String, Map<String, String>>{
    'Gym': {
      'ar': 'النادي',
      'en': 'Gym',
      'fr': 'Salle',
      'es': 'Gimnasio',
      'tr': 'Spor salonu',
      'de': 'Fitnessstudio',
      'it': 'Palestra',
      'pt': 'Ginásio',
      'ur': 'جم',
      'fa': 'باشگاه',
      'hi': 'जिम',
      'id': 'Gym',
      'ms': 'Gim',
      'ja': 'ジム',
      'ko': '헬스장',
      'zh': '健身房',
      'ru': 'Зал',
      'bn': 'জিম',
      'vi': 'Phòng tập',
      'th': 'ยิม',
      'pl': 'Siłownia',
      'nl': 'Sportschool',
      'uk': 'Тренажерний зал',
    },
    'Home': {
      'ar': 'المنزل',
      'en': 'Home',
      'fr': 'Maison',
      'es': 'Casa',
      'tr': 'Ev',
      'de': 'Zuhause',
      'it': 'Casa',
      'pt': 'Casa',
      'ur': 'گھر',
      'fa': 'خانه',
      'hi': 'घर',
      'id': 'Rumah',
      'ms': 'Rumah',
      'ja': '自宅',
      'ko': '홈',
      'zh': '居家',
      'ru': 'Дом',
      'bn': 'বাড়ি',
      'vi': 'Tại nhà',
      'th': 'ที่บ้าน',
      'pl': 'Dom',
      'nl': 'Thuis',
      'uk': 'Дім',
    },
    'My plans': {
      'ar': 'خططي',
      'en': 'My plans',
      'fr': 'Mes plans',
      'es': 'Mis planes',
      'tr': 'Planlarım',
      'de': 'Meine Pläne',
      'it': 'I miei piani',
      'pt': 'Os meus planos',
      'ur': 'میرے منصوبے',
      'fa': 'برنامه‌های من',
      'hi': 'मेरी योजनाएँ',
      'id': 'Rencana saya',
      'ms': 'Pelan saya',
      'ja': 'マイプラン',
      'ko': '내 플랜',
      'zh': '我的计划',
      'ru': 'Мои планы',
      'bn': 'আমার পরিকল্পনা',
      'vi': 'Kế hoạch của tôi',
      'th': 'แผนของฉัน',
      'pl': 'Moje plany',
      'nl': 'Mijn plannen',
      'uk': 'Мої плани',
    },
    'See all': {
      'ar': 'عرض الكل',
      'en': 'See all',
      'fr': 'Tout voir',
      'es': 'Ver todo',
      'tr': 'Tümünü gör',
      'de': 'Alle anzeigen',
      'it': 'Vedi tutto',
      'pt': 'Ver tudo',
      'ur': 'سب دیکھیں',
      'fa': 'مشاهده همه',
      'hi': 'सभी देखें',
      'id': 'Lihat semua',
      'ms': 'Lihat semua',
      'ja': 'すべて表示',
      'ko': '모두 보기',
      'zh': '查看全部',
      'ru': 'Все',
      'bn': 'সব দেখুন',
      'vi': 'Xem tất cả',
      'th': 'ดูทั้งหมด',
      'pl': 'Zobacz wszystko',
      'nl': 'Alles bekijken',
      'uk': 'Переглянути все',
    },
    'Show less': {
      'ar': 'عرض أقل',
      'en': 'Show less',
      'fr': 'Réduire',
      'es': 'Ver menos',
      'tr': 'Daha az göster',
      'de': 'Weniger anzeigen',
      'it': 'Mostra meno',
      'pt': 'Ver menos',
      'ur': 'کم دکھائیں',
      'fa': 'نمایش کمتر',
      'hi': 'कम दिखाएँ',
      'id': 'Tampilkan lebih sedikit',
      'ms': 'Tunjuk kurang',
      'ja': '表示を減らす',
      'ko': '간단히 보기',
      'zh': '收起',
      'ru': 'Свернуть',
      'bn': 'কম দেখুন',
      'vi': 'Thu gọn',
      'th': 'แสดงน้อยลง',
      'pl': 'Pokaż mniej',
      'nl': 'Minder tonen',
      'uk': 'Згорнути',
    },
  };
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  return copy[key]?[code] ?? copy[key]?['en'] ?? key;
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
          key: ValueKey('workout-card-${item.stableId}'),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    locked
                        ? _WorkoutCoverFallback(item: item)
                        : _WorkoutCover(
                            item: item,
                            mediaCache: mediaCache,
                            online: online,
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
                          if (!locked)
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
  Widget build(BuildContext context) => PremiumLabelBadge(
    key: const ValueKey('locked-workout-badge'),
    semanticLabel: minimumAccess.name,
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
