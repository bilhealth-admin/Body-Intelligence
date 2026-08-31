part of 'wellness_tools_pages.dart';

extension _FastingTimerActions on _FastingTimerPageState {
  Future<void> _start() async {
    if (busy) return;
    _updateState(() => busy = true);
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
      if (mounted) _updateState(() => session = next);
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
            if (mounted) _updateState(() => notifyAtTarget = false);
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
      if (mounted) _updateState(() => busy = false);
    }
  }

  Future<void> _stop() async {
    if (busy) return;
    final current = session;
    if (current == null) return;
    _updateState(() => busy = true);
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
        _updateState(() {
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
      if (mounted) _updateState(() => busy = false);
    }
  }

  Future<void> _setTargetNotification(bool value) async {
    if (busy) return;
    _updateState(() => busy = true);
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
          if (mounted) _updateState(() => notifyAtTarget = false);
          await _refreshNotificationTruth();
          return;
        }
      }
      await ref
          .read(preferencesRepositoryProvider)
          .set('wellness_fasting_notify_target', '$value');
      if (mounted) _updateState(() => notifyAtTarget = value);
      await _refreshNotificationTruth();
    } catch (_) {
      _message(
        tr(
          'The notification preference could not be saved.',
          'تعذر حفظ تفضيل الإشعار.',
        ),
      );
    } finally {
      if (mounted) _updateState(() => busy = false);
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
      _updateState(() => targetHours = selected);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
