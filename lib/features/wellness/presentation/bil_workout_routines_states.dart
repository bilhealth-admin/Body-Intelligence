part of 'bil_workout_routines_page.dart';

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
        asset: StaticWorkoutArtwork.cardio,
        onTap: onCardio,
      ),
      const SizedBox(height: 14),
      _WorkoutMetadataPreviewCard(
        key: const ValueKey('workout-metadata-preview-strength'),
        title: _copy(context, 'Strength', 'تمارين القوة'),
        asset: StaticWorkoutArtwork.strength,
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
