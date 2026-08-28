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
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
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

  Future<void> _start() async {
    if (busy) return;
    setState(() => busy = true);
    final now = DateTime.now();
    final languageCode = Localizations.localeOf(context).languageCode;
    final prefs = ref.read(preferencesRepositoryProvider);
    final next = FastingSession(startedAt: now, targetHours: targetHours);
    try {
      await prefs.mutate(
        set: {
          'wellness_fasting_session_v2': jsonEncode(next.toJson()),
          'wellness_fasting_started_at': now.toIso8601String(),
          'wellness_fasting_target_hours': '$targetHours',
        },
      );
      if (mounted) setState(() => session = next);
      try {
        final notifications = ref.read(fastingNotificationServiceProvider);
        final allowed = await notifications.requestPermission();
        final target = next.targetNotificationAt(DateTime.now());
        if (!allowed) {
          _message(
            tr(
              'The fast started, but notifications are not permitted on this device.',
              'بدأ الصيام المتقطع، لكن الإشعارات غير مسموح بها على هذا الجهاز.',
            ),
          );
          if (notifyAtTarget) {
            await prefs.set('wellness_fasting_notify_target', 'false');
            if (mounted) setState(() => notifyAtTarget = false);
          }
        } else if (target != null) {
          await notifications.showFastingOngoing(
            target: target,
            languageCode: languageCode,
          );
          await notifications.scheduleFastingHydration(
            startedAt: next.startedAt,
            target: target,
            languageCode: languageCode,
          );
          if (notifyAtTarget) {
            await notifications.scheduleFastingTarget(
              target: target,
              languageCode: languageCode,
            );
          }
          await _refreshNotificationTruth();
        }
      } catch (_) {
        _message(
          tr(
            'The fast started, but its notification could not be scheduled.',
            'بدأ الصيام المتقطع، لكن تعذر جدولة الإشعار.',
          ),
        );
      }
      try {
        await ref
            .read(lifeContextRepositoryProvider)
            .add(
              occurredAt: now,
              type: 'fasting',
              details: 'User started a $targetHours-hour fasting timer.',
              useInInsights: true,
            );
      } catch (_) {
        // The durable session is authoritative; optional insight context must
        // never make a committed timer appear to have failed.
      }
    } catch (_) {
      _message(
        tr(
          'The fast could not be started. Your previous state was preserved.',
          'تعذر بدء الصيام المتقطع. تم الاحتفاظ بحالتك السابقة.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _stop() async {
    if (busy) return;
    final current = session;
    if (current == null) return;
    setState(() => busy = true);
    final entry = FastingHistoryEntry(
      startedAt: current.startedAt,
      endedAt: DateTime.now(),
      targetHours: current.targetHours,
    );
    final nextHistory = FastingHistoryCodec.prepend(entry, history);
    final prefs = ref.read(preferencesRepositoryProvider);
    try {
      await prefs.mutate(
        set: {
          'wellness_fasting_history_v1': FastingHistoryCodec.encode(
            nextHistory,
          ),
          'wellness_fasting_last_minutes': '${entry.duration.inMinutes}',
        },
        remove: const [
          'wellness_fasting_session_v2',
          'wellness_fasting_started_at',
        ],
      );
      if (mounted) {
        setState(() {
          history = nextHistory;
          session = null;
        });
      }
      try {
        await ref
            .read(fastingNotificationServiceProvider)
            .cancelFastingSessionNotifications();
        await _refreshNotificationTruth();
      } catch (_) {
        _message(
          tr(
            'The fast ended, but its notification could not be cleared.',
            'انتهى الصيام المتقطع، لكن تعذر إلغاء إشعاره.',
          ),
        );
      }
    } catch (_) {
      _message(
        tr(
          'The fast could not be ended. The active timer was preserved.',
          'تعذر إنهاء الصيام المتقطع. تم الاحتفاظ بالمؤقت النشط.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _setTargetNotification(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (value) {
        final allowed = await ref
            .read(fastingNotificationServiceProvider)
            .requestPermission();
        if (!allowed) {
          _message(
            tr(
              'Notification permission is off. You can enable it in phone settings.',
              'إذن الإشعارات متوقف. يمكنك تفعيله من إعدادات الهاتف.',
            ),
          );
          await ref
              .read(preferencesRepositoryProvider)
              .set('wellness_fasting_notify_target', 'false');
          if (mounted) setState(() => notifyAtTarget = false);
          await _refreshNotificationTruth();
          return;
        }
      }
      await ref
          .read(preferencesRepositoryProvider)
          .set('wellness_fasting_notify_target', '$value');
      if (mounted) setState(() => notifyAtTarget = value);
      await _refreshNotificationTruth();
    } catch (_) {
      _message(
        tr(
          'The notification preference could not be saved.',
          'تعذر حفظ تفضيل الإشعار.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await ref.read(fastingNotificationServiceProvider).openSystemSettings();
      await _refreshNotificationTruth();
    } on Object {
      _message(
        tr(
          'Phone notification settings could not be opened.',
          'تعذّر فتح إعدادات إشعارات الهاتف.',
        ),
      );
    }
  }

  Future<void> _chooseCustomWindow() async {
    final controller = TextEditingController(text: '$targetHours');
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Custom fasting window', 'نافذة صيام مخصصة')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('Fasting hours', 'ساعات الصيام'),
            helperText: '1–23',
          ),
          onSubmitted: (value) {
            final hours = int.tryParse(value.trim());
            if (hours != null && hours >= 1 && hours <= 23) {
              Navigator.pop(dialogContext, hours);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () {
              final hours = int.tryParse(controller.text.trim());
              if (hours != null && hours >= 1 && hours <= 23) {
                Navigator.pop(dialogContext, hours);
              }
            },
            child: Text(tr('Apply', 'تطبيق')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (selected != null && mounted) {
      setState(() => targetHours = selected);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _FastingBenefit extends StatelessWidget {
  const _FastingBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 7),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Fasting-specific hero that keeps long translated titles away from the
/// circular icon instead of squeezing either element into an unreadable row.
class _FastingStatusPanel extends StatelessWidget {
  const _FastingStatusPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('fasting-status-panel'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF071829), Color(0xFF123B54)],
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackContent = constraints.maxWidth < 330 || textScale > 1.25;
        final iconWidget = CircleAvatar(
          key: const Key('fasting-status-icon'),
          radius: 28,
          backgroundColor: const Color(0xFF19C6DF),
          child: Icon(icon, color: const Color(0xFF071829)),
        );
        final copy = Column(
          key: const Key('fasting-status-copy'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              key: const Key('fasting-status-title'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFC7D9E6),
                height: 1.45,
              ),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: stackContent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconWidget, const SizedBox(height: 16), copy],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(width: 16),
                    Expanded(child: copy),
                  ],
                ),
        );
      },
    ),
  );
}
