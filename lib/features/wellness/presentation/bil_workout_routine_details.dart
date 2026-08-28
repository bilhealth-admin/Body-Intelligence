part of 'bil_workout_routines_page.dart';

class BilWorkoutRoutineDetailsPage extends ConsumerStatefulWidget {
  const BilWorkoutRoutineDetailsPage({
    super.key,
    required this.item,
    required this.initiallySaved,
    required this.onToggleSaved,
    required this.mediaCache,
    required this.offline,
    this.onLogWorkout,
  });

  final WellnessContentItem item;
  final bool initiallySaved;
  final Future<void> Function() onToggleSaved;
  final WorkoutLogHandler? onLogWorkout;
  final WellnessMediaCache mediaCache;
  final bool offline;

  @override
  ConsumerState<BilWorkoutRoutineDetailsPage> createState() =>
      _BilWorkoutRoutineDetailsPageState();
}

class _BilWorkoutRoutineDetailsPageState
    extends ConsumerState<BilWorkoutRoutineDetailsPage> {
  late bool _saved = widget.initiallySaved;
  bool _logging = false;

  Future<void> _toggleSaved() async {
    await widget.onToggleSaved();
    if (mounted) setState(() => _saved = !_saved);
  }

  Future<void> _logWorkout() async {
    if (_logging) return;
    final handler = widget.onLogWorkout;
    if (handler == null) {
      context.push('/wellness/workouts/log');
      return;
    }
    setState(() => _logging = true);
    try {
      await handler(widget.item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'Workout added to today.',
              'أُضيف التمرين إلى اليوم.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'Workout was not logged. Existing data was not changed.',
              'لم يُسجّل التمرين. لم تتغير بياناتك الحالية.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _openPlans() async {
    await context.push('/plans');
    if (!mounted) return;
    // Purchase and restore complete at the verified server boundary. Discard
    // the pre-paywall snapshot before deciding whether paid media can render.
    ref.invalidate(verifiedSubscriptionStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final subscription = _usableVerifiedSubscription(
      ref.watch(verifiedSubscriptionStateProvider),
    );
    final locked = !workoutAccessGranted(item.minimumAccess, subscription);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: locked
            ? const []
            : [
                IconButton(
                  key: const ValueKey('details-save-routine'),
                  tooltip: _saved
                      ? _copy(context, 'Remove routine', 'إزالة الروتين')
                      : _copy(context, 'Save routine', 'حفظ الروتين'),
                  onPressed: _toggleSaved,
                  icon: Icon(
                    _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (locked)
            _LockedWorkoutHero(item: item)
          else
            _WorkoutHeroMedia(
              item: item,
              mediaCache: widget.mediaCache,
              online: !widget.offline,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.description),
                const SizedBox(height: 16),
                _RoutineMeta(item: item),
                const SizedBox(height: 24),
                if (locked)
                  _LockedWorkoutPanel(minimumAccess: item.minimumAccess)
                else ...[
                  _DetailsSection(
                    title: _copy(context, 'Equipment', 'المعدات'),
                    child: item.equipment.isEmpty
                        ? Text(_copy(context, 'No equipment', 'دون معدات'))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final equipment in item.equipment)
                                Chip(label: Text(equipment)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                  _DetailsSection(
                    title: _copy(context, 'Workout steps', 'خطوات التمرين'),
                    child: item.segments.isNotEmpty
                        ? _WorkoutSegmentsList(
                            segments: item.segments,
                            mediaCache: widget.mediaCache,
                            online: !widget.offline,
                          )
                        : _TextWorkoutSteps(steps: item.steps),
                  ),
                ],
                const SizedBox(height: 24),
                _SourceAndSafety(item: item),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: locked
            ? FilledButton(
                key: const ValueKey('unlock-workout-cta'),
                onPressed: _openPlans,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PremiumLabelBadge(semanticLabel: item.minimumAccess.name),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _copy(
                          context,
                          'View membership plans',
                          'عرض خطط العضوية',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            : FilledButton.icon(
                key: const ValueKey('log-workout-cta'),
                onPressed: _logging ? null : _logWorkout,
                icon: _logging
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_task_rounded),
                label: Text(_copy(context, 'Log Workout', 'تسجيل التمرين')),
              ),
      ),
    );
  }
}

class _LockedWorkoutHero extends StatelessWidget {
  const _LockedWorkoutHero({required this.item});

  final WellnessContentItem item;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 250,
    child: Stack(
      fit: StackFit.expand,
      children: [
        _WorkoutCoverFallback(item: item),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), Color(0xCC071426)],
            ),
          ),
        ),
        Center(
          child: Semantics(
            label: _copy(
              context,
              'Premium workout. Instructions stay locked until server-verified access is active.',
              'تمرين مميز. تبقى التعليمات مقفلة حتى تفعيل الوصول الموثق من الخادم.',
            ),
            child: PremiumLabelBadge(semanticLabel: item.minimumAccess.name),
          ),
        ),
      ],
    ),
  );
}

class _LockedWorkoutPanel extends StatelessWidget {
  const _LockedWorkoutPanel({required this.minimumAccess});

  final WellnessContentAccess minimumAccess;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: _lockedWorkoutSemantics(context, minimumAccess),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumLabelBadge(semanticLabel: minimumAccess.name),
                  const SizedBox(height: 10),
                  Text(
                    _copy(
                      context,
                      'Unlock this verified routine',
                      'افتح هذا الروتين الموثق',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _copy(
                      context,
                      'BIL will not download or reveal paid instructions without a current server-verified entitlement.',
                      'لن ينزّل BIL تعليمات مدفوعة أو يكشفها دون استحقاق سارٍ وموثق من الخادم.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _lockedWorkoutSemantics(
  BuildContext context,
  WellnessContentAccess minimumAccess,
) {
  final level = minimumAccess.name.toUpperCase();
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => 'تعليمات التمرين مقفلة. يلزم وصول $level موثق من الخادم.',
    'fr' =>
      'Instructions verrouillées. Un accès $level vérifié par le serveur est requis.',
    'es' =>
      'Instrucciones bloqueadas. Se requiere acceso $level verificado por el servidor.',
    'tr' =>
      'Antrenman talimatları kilitli. Sunucu tarafından doğrulanmış $level erişimi gerekir.',
    _ =>
      'Workout instructions locked. Server-verified $level access is required.',
  };
}

class _RoutineMeta extends StatelessWidget {
  const _RoutineMeta({required this.item});
  final WellnessContentItem item;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      if (item.durationSeconds != null)
        Chip(
          avatar: const Icon(Icons.schedule_rounded, size: 18),
          label: Text(_workoutSeconds(context, item.durationSeconds!)),
        )
      else if (item.durationMinutes != null)
        Chip(
          avatar: const Icon(Icons.schedule_rounded, size: 18),
          label: Text(_workoutMinutes(context, item.durationMinutes!)),
        ),
      if (item.difficulty?.isNotEmpty == true)
        Chip(
          avatar: const Icon(Icons.signal_cellular_alt_rounded, size: 18),
          label: Text(item.difficulty!),
        ),
      Chip(
        avatar: const Icon(Icons.verified_rounded, size: 18),
        label: Text(_copy(context, 'Verified', 'موثق')),
      ),
    ],
  );
}

class _TextWorkoutSteps extends StatelessWidget {
  const _TextWorkoutSteps({required this.steps});
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text(
        _copy(
          context,
          'This verified pack does not include step-by-step instructions.',
          'لا تتضمن هذه الحزمة الموثقة تعليمات خطوة بخطوة.',
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(steps[index]),
          ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _SourceAndSafety extends StatelessWidget {
  const _SourceAndSafety({required this.item});
  final WellnessContentItem item;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _copy(context, 'Source and safety', 'المصدر والسلامة'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('${item.publisher} • ${item.licenseName}'),
          if (item.author?.isNotEmpty == true) Text(item.author!),
          if (item.attribution?.isNotEmpty == true) Text(item.attribution!),
          const SizedBox(height: 8),
          Text(
            _copy(
              context,
              'Stop for pain, dizziness, or unusual shortness of breath. BIL records confirmed activity and does not invent calorie burn.',
              'توقف عند الألم أو الدوار أو ضيق التنفس غير المعتاد. يسجل BIL النشاط المؤكد ولا يخترع سعرات محروقة.',
            ),
          ),
        ],
      ),
    ),
  );
}
