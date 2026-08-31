part of 'wellness_tools_pages.dart';

class FastingTimerPage extends ConsumerStatefulWidget {
  const FastingTimerPage({super.key});

  @override
  ConsumerState<FastingTimerPage> createState() => _FastingTimerPageState();
}

class _FastingTimerPageState extends ConsumerState<FastingTimerPage>
    with _WellnessCopy {
  Timer? timer;
  FastingSession? session;
  int targetHours = 16;
  List<FastingHistoryEntry> history = const [];
  bool notifyAtTarget = false;
  BilNotificationPermissionState notificationPermission =
      BilNotificationPermissionState.unknown;
  bool fastingNotificationScheduled = false;
  bool loading = true;
  bool busy = false;
  Object? loadError;

  void _updateState(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && session != null) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final prefs = ref.read(preferencesRepositoryProvider);
      final values = await Future.wait([
        prefs.get('wellness_fasting_session_v2'),
        prefs.get('wellness_fasting_started_at'),
        prefs.get('wellness_fasting_target_hours'),
        prefs.get('wellness_fasting_history_v1'),
        prefs.get('wellness_fasting_notify_target'),
      ]);
      final encodedSession = values[0];
      final legacyStart = values[1];
      final target = values[2];
      final encodedHistory = values[3];
      final notify = values[4];
      var restored = FastingSession.tryParse(encodedSession);
      if (encodedSession == null && restored == null && legacyStart != null) {
        final parsed = DateTime.tryParse(legacyStart);
        final hours = int.tryParse(target ?? '');
        if (parsed != null &&
            hours != null &&
            hours >= 1 &&
            hours <= 48 &&
            !parsed.toUtc().isAfter(DateTime.now().toUtc())) {
          restored = FastingSession(startedAt: parsed, targetHours: hours);
        }
      }
      if (!mounted) return;
      setState(() {
        session = restored;
        final savedTarget = int.tryParse(target ?? '');
        targetHours =
            restored?.targetHours ??
            (savedTarget != null && savedTarget >= 1 && savedTarget <= 48
                ? savedTarget
                : 16);
        history = FastingHistoryCodec.decode(encodedHistory);
        notifyAtTarget = notify == 'true';
        loading = false;
      });
      await _refreshNotificationTruth();
      await _restoreActiveNotificationState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = error;
      });
    }
  }

  Future<void> _refreshNotificationTruth() async {
    try {
      final service = ref.read(fastingNotificationServiceProvider);
      final permission = await service.permissionState();
      final pending = await service.pendingNotificationIds();
      if (!mounted) return;
      setState(() {
        notificationPermission = permission;
        fastingNotificationScheduled = pending.contains(
          BilNotificationService.fastingTargetNotificationId,
        );
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        notificationPermission = BilNotificationPermissionState.unknown;
        fastingNotificationScheduled = false;
      });
    }
  }

  Future<void> _restoreActiveNotificationState() async {
    final current = session;
    if (current == null ||
        notificationPermission != BilNotificationPermissionState.granted) {
      return;
    }
    final target = current.targetNotificationAt(DateTime.now());
    if (target == null) return;
    try {
      final service = ref.read(fastingNotificationServiceProvider);
      final languageCode = Localizations.localeOf(context).languageCode;
      await service.showFastingOngoing(
        target: target,
        languageCode: languageCode,
      );
      await service.scheduleFastingHydration(
        startedAt: current.startedAt,
        target: target,
        languageCode: languageCode,
      );
      if (notifyAtTarget) {
        await service.scheduleFastingTarget(
          target: target,
          languageCode: languageCode,
        );
      }
      await _refreshNotificationTruth();
    } on Object {
      // The active local timer stays authoritative. The visible permission
      // state and explicit start message report delivery failures.
    }
  }

  bool get _notificationNeedsSettings =>
      notificationPermission ==
          BilNotificationPermissionState.permanentlyDenied ||
      notificationPermission == BilNotificationPermissionState.restricted ||
      notificationPermission == BilNotificationPermissionState.unknown;

  Duration get elapsed => session?.elapsedAt(DateTime.now()) ?? Duration.zero;
  String clock(Duration value) {
    final h = value.inHours.toString().padLeft(2, '0');
    final m = (value.inMinutes % 60).toString().padLeft(2, '0');
    final s = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = session != null;
    final progress = session?.progressAt(DateTime.now()) ?? 0.0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          // Give translated and accessibility-scaled titles real vertical
          // room. A wrapping AppBar title must never paint over the timer.
          toolbarHeight: (64 * textScale).clamp(64, 112).toDouble(),
          leading: IconButton(
            onPressed: busy
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            tr('Intermittent fasting', 'الصيام المتقطع'),
            key: const Key('fasting-page-title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
            ? Center(
                child: FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('Retry', 'إعادة المحاولة')),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  Card(
                    key: const Key('fasting-reference-introduction'),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 190,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: ExcludeSemantics(
                                child: Image.asset(
                                  'assets/images/brand/generated/intermittent_fasting_meal_window_v3.png',
                                  fit: BoxFit.cover,
                                  cacheWidth: 960,
                                  matchTextDirection: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            tr(
                              'Intermittent fasting with BIL',
                              'الصيام المتقطع مع BIL',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          _FastingBenefit(
                            text: tr(
                              'Choose a standard or custom intermittent fasting window',
                              'اختر نافذة صيام متقطع قياسية أو مخصصة',
                            ),
                          ),
                          _FastingBenefit(
                            text: tr(
                              'The local timer survives app restarts',
                              'يستمر المؤقت المحلي بعد إعادة تشغيل التطبيق',
                            ),
                          ),
                          _FastingBenefit(
                            text: tr(
                              'Review completed intermittent fasting sessions here',
                              'راجع جلسات الصيام المتقطع المكتملة هنا',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => context.push('/wellness/learn'),
                            icon: const Icon(Icons.help_outline_rounded),
                            label: Text(
                              tr(
                                'What is intermittent fasting, and is it right for you?',
                                'ما الصيام المتقطع، وهل يناسبك؟',
                              ),
                            ),
                          ),
                          const Divider(height: 28),
                          Text(
                            tr(
                              'Check with your clinician before significant dietary changes.',
                              'استشر مختصك الصحي قبل إجراء تغييرات غذائية كبيرة.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FastingStatusPanel(
                    icon: Icons.timelapse_rounded,
                    title: active
                        ? tr(
                            'Intermittent fast in progress',
                            'الصيام المتقطع مستمر',
                          )
                        : tr('Choose your window', 'اختر نافذتك'),
                    subtitle: active
                        ? tr(
                            'Started ${session!.startedAt.toLocal().hour.toString().padLeft(2, '0')}:${session!.startedAt.toLocal().minute.toString().padLeft(2, '0')}',
                            'بدأ ${session!.startedAt.toLocal().hour.toString().padLeft(2, '0')}:${session!.startedAt.toLocal().minute.toString().padLeft(2, '0')}',
                          )
                        : tr(
                            'A local intermittent fasting timer. You remain in control.',
                            'مؤقت محلي للصيام المتقطع، وأنت صاحب القرار.',
                          ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Semantics(
                            label: active
                                ? '${tr('Intermittent fast in progress', 'الصيام المتقطع مستمر')}. '
                                      '${clock(elapsed)}. ${tr('Target', 'الهدف')} $targetHours ${tr('hours', 'ساعة')}.'
                                : '${tr('No active fast', 'لا يوجد صيام نشط')}. '
                                      '${tr('Target', 'الهدف')} $targetHours ${tr('hours', 'ساعة')}.',
                            value: active
                                ? '${(progress * 100).round()}%'
                                : '0%',
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final diameter = constraints.maxWidth < 220
                                    ? constraints.maxWidth
                                    : 220.0;
                                return SizedBox(
                                  key: const Key('fasting-timer-ring'),
                                  width: diameter,
                                  height: diameter,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox.expand(
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 14,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              clock(elapsed),
                                              maxLines: 1,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              tr(
                                                'of $targetHours hours',
                                                'من $targetHours ساعة',
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            key: const Key('fasting-window-options'),
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final option in const [
                                (13, '13:11'),
                                (14, '14:10'),
                                (16, '16:8'),
                                (18, '18:6'),
                                (20, '20:4'),
                              ])
                                ChoiceChip(
                                  label: Text(option.$2),
                                  selected: targetHours == option.$1,
                                  onSelected: active || busy
                                      ? null
                                      : (_) => setState(
                                          () => targetHours = option.$1,
                                        ),
                                ),
                              ActionChip(
                                key: const Key('fasting-custom-window'),
                                avatar: const Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                ),
                                label: Text(tr('Custom', 'مخصص')),
                                onPressed: active || busy
                                    ? null
                                    : _chooseCustomWindow,
                              ),
                            ],
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              tr(
                                'Notify me at my target',
                                'نبّهني عند بلوغ هدفي',
                              ),
                            ),
                            subtitle: Text(
                              fastingNotificationScheduled
                                  ? tr(
                                      'Scheduled on this phone',
                                      'مجدول على هذا الهاتف',
                                    )
                                  : notificationPermission ==
                                        BilNotificationPermissionState.granted
                                  ? tr(
                                      'Allowed; starts when you begin a fast',
                                      'مسموح؛ يُجدول عند بدء الصيام',
                                    )
                                  : tr(
                                      'Notification permission is not active',
                                      'إذن الإشعارات غير مفعّل',
                                    ),
                            ),
                            value: notifyAtTarget,
                            onChanged: active || busy
                                ? null
                                : _setTargetNotification,
                          ),
                          if (notifyAtTarget && _notificationNeedsSettings)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                key: const Key(
                                  'fasting-open-notification-settings',
                                ),
                                onPressed: busy
                                    ? null
                                    : _openNotificationSettings,
                                icon: const Icon(Icons.settings_outlined),
                                label: Text(
                                  tr(
                                    'Open notification settings',
                                    'فتح إعدادات الإشعارات',
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: active
                                  ? FilledButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    )
                                  : null,
                              onPressed: busy
                                  ? null
                                  : (active ? _stop : _start),
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      active
                                          ? Icons.stop_rounded
                                          : Icons.play_arrow_rounded,
                                    ),
                              label: Text(
                                active
                                    ? tr(
                                        'End intermittent fast',
                                        'إنهاء الصيام المتقطع',
                                      )
                                    : tr(
                                        'Start intermittent fast',
                                        'بدء الصيام المتقطع',
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      tr('Intermittent fasting history', 'سجل الصيام المتقطع'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final entry in history.take(10))
                      ListTile(
                        leading: Icon(
                          entry.reachedTarget
                              ? Icons.check_circle_outline_rounded
                              : Icons.history_rounded,
                        ),
                        title: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(clock(entry.duration)),
                        ),
                        subtitle: Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(entry.startedAt.toLocal())} · '
                          '${tr('Target', 'الهدف')} ${entry.targetHours}h · '
                          '${entry.reachedTarget ? tr('Reached', 'تم بلوغه') : tr('Ended early', 'انتهى مبكرًا')}',
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  _SafetyNote(
                    text: tr(
                      'Fasting is optional and is not medical advice. Do not fast if it conflicts with pregnancy, medication, an eating-disorder history, diabetes care, or clinician guidance.',
                      'الصيام اختياري وليس نصيحة طبية. لا تصم إذا تعارض مع الحمل أو الدواء أو تاريخ اضطراب الأكل أو رعاية السكري أو إرشادات طبيبك.',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
