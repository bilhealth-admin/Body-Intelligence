part of 'notification_settings_page.dart';

extension _NotificationSettingsActions on _NotificationSettingsPageState {
  Future<void> _loadPushPreferences() async {
    if (mounted) _updateState(() => _pushLoadError = false);
    try {
      final preferences = await _pushService!.loadPreferences();
      if (mounted) _updateState(() => _pushPreferences = preferences);
    } on Object {
      if (mounted) _updateState(() => _pushLoadError = true);
    }
  }

  Future<void> _setPushEnabled(bool enabled) async {
    if (_pushService == null || _pushSaving) return;
    _updateState(() => _pushSaving = true);
    try {
      await _pushService!.setEnabled(enabled);
      await _loadPushPreferences();
    } on Object {
      if (mounted) _showPushError();
    } finally {
      if (mounted) _updateState(() => _pushSaving = false);
    }
  }

  Future<void> _setSensitivePreview(bool allowed) async {
    if (_pushService == null || _pushSaving) return;
    _updateState(() => _pushSaving = true);
    try {
      await _pushService!.setSensitivePreviewAllowed(allowed);
      await _loadPushPreferences();
    } on Object {
      if (mounted) _showPushError();
    } finally {
      if (mounted) _updateState(() => _pushSaving = false);
    }
  }

  void _showPushError() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _ui(
          'Community notifications could not be updated safely. Try again.',
          'تعذر تحديث إشعارات المجتمع بأمان. حاول مجددًا.',
          'Impossible de mettre à jour les notifications de la communauté.',
          'No se pudieron actualizar las notificaciones de la comunidad.',
          'Topluluk bildirimleri güvenle güncellenemedi.',
        ),
      ),
    ),
  );

  Future<void> _load() async {
    if (mounted) _updateState(() => _loadError = null);
    try {
      final values = await Future.wait([_store.load(), _deliveryStore.load()]);
      if (mounted) {
        _updateState(() {
          _reminders = values[0] as List<DailyReminder>;
          _deliveryPreferences = values[1] as NotificationDeliveryPreferences;
          _loadError = null;
        });
      }
    } on Object catch (error) {
      if (mounted) _updateState(() => _loadError = error);
      return;
    }
    // Device permission/plugin state must never make durable local reminder
    // settings unreadable. Probe it independently and render an actionable
    // unknown/blocked state if the platform channel is unavailable.
    await _refreshSystemStatus();
  }

  Future<void> _refreshSystemStatus() async {
    try {
      final permission = await _service.permissionState();
      Set<int> pending = const {};
      try {
        pending = await _service.pendingNotificationIds();
      } on Object {
        // Permission truth remains useful even if pending-request inspection
        // is unavailable on this platform.
      }
      if (!mounted) return;
      _updateState(() {
        _permissionState = permission;
        _phoneNotificationsEnabled =
            permission == BilNotificationPermissionState.granted;
        _pendingNotificationIds = pending;
        _permissionProbeFailed = false;
      });
    } on Object {
      if (!mounted) return;
      _updateState(() {
        _permissionState = BilNotificationPermissionState.unknown;
        _phoneNotificationsEnabled = null;
        _pendingNotificationIds = const {};
        _permissionProbeFailed = true;
      });
    }
  }

  Future<void> _openSystemNotificationSettings() async {
    await _service.openSystemSettings();
    if (mounted) await _refreshSystemStatus();
  }

  Future<void> _saveDelivery(NotificationDeliveryPreferences value) async {
    if (_saving) return;
    final previous = _deliveryPreferences!;
    final reminders = _reminders!;
    _updateState(() {
      _deliveryPreferences = value;
      _saving = true;
    });
    try {
      await _deliveryStore.save(value);
      await _reconcile(reminders, value);
    } on Object {
      if (mounted) _updateState(() => _deliveryPreferences = previous);
      try {
        await _deliveryStore.save(previous);
        await _reconcile(reminders, previous);
      } on Object {
        // Best-effort reconciliation; the visible state remains the last
        // durable preference snapshot and the next edit retries scheduling.
      }
      if (mounted) _showLocalError();
    } finally {
      if (mounted) _updateState(() => _saving = false);
    }
  }

  Future<void> _reconcile(
    List<DailyReminder> reminders,
    NotificationDeliveryPreferences delivery,
  ) async {
    for (final reminder in reminders) {
      await _service.schedule(
        reminder,
        languageCode: _languageCode,
        preferences: delivery,
      );
    }
    await _service.scheduleDailyGroupSummary(
      reminders,
      languageCode: _languageCode,
      preferences: delivery,
    );
  }

  void _showLocalError() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_copy.permissionError)));

  Future<void> _sendNotificationCheck() async {
    if (_saving) return;
    _updateState(() => _saving = true);
    try {
      final allowed = await _service.requestPermission();
      if (!allowed) throw StateError('notification permission denied');
      await _service.showActivationConfirmation(languageCode: _languageCode);
      await _refreshSystemStatus();
    } on Object {
      if (mounted) _showLocalError();
    } finally {
      if (mounted) _updateState(() => _saving = false);
    }
  }

  Future<void> _toggleCategory(NotificationCategory category, bool enabled) {
    final current = _deliveryPreferences!;
    final categories = {...current.enabledCategories};
    enabled ? categories.add(category) : categories.remove(category);
    return _saveDelivery(current.copyWith(enabledCategories: categories));
  }

  Future<void> _update(DailyReminder updated) async {
    final current = _reminders;
    if (current == null || _saving) return;
    final next = [
      for (final reminder in current)
        if (reminder.kind == updated.kind) updated else reminder,
    ];
    _updateState(() {
      _reminders = next;
      _saving = true;
    });
    try {
      if (updated.enabled) {
        final allowed = await _service.requestPermission();
        if (!allowed) {
          throw StateError('notification permission denied');
        }
      }
      await _service.schedule(
        updated,
        languageCode: _languageCode,
        preferences:
            _deliveryPreferences ?? const NotificationDeliveryPreferences(),
      );
      await _service.scheduleDailyGroupSummary(
        next,
        languageCode: _languageCode,
        preferences:
            _deliveryPreferences ?? const NotificationDeliveryPreferences(),
      );
      await _store.save(next);
      await _refreshSystemStatus();
    } on Object {
      if (!mounted) return;
      _updateState(() => _reminders = current);
      try {
        await _store.save(current);
        await _reconcile(
          current,
          _deliveryPreferences ?? const NotificationDeliveryPreferences(),
        );
      } on Object {
        // Best-effort reconciliation after restoring the durable list.
      }
      _showLocalError();
    } finally {
      if (mounted) _updateState(() => _saving = false);
    }
  }

  Future<void> _setAllDaily(bool enabled) async {
    final current = _reminders;
    if (current == null || _saving) return;
    final previous = current;
    final next = [
      for (final reminder in current)
        if (reminder.kind == DailyReminderKind.returnAfter24Hours)
          reminder
        else
          DailyReminder(
            kind: reminder.kind,
            hour: reminder.hour,
            minute: reminder.minute,
            enabled: enabled,
          ),
    ];
    _updateState(() {
      _reminders = next;
      _saving = true;
    });
    try {
      if (enabled && !await _service.requestPermission()) {
        throw StateError('notification permission denied');
      }
      await _reconcile(
        next,
        _deliveryPreferences ?? const NotificationDeliveryPreferences(),
      );
      await _store.save(next);
      if (enabled) {
        await _service.showActivationConfirmation(languageCode: _languageCode);
      }
      await _refreshSystemStatus();
    } on Object {
      if (!mounted) return;
      _updateState(() => _reminders = previous);
      try {
        await _store.save(previous);
        await _reconcile(
          previous,
          _deliveryPreferences ?? const NotificationDeliveryPreferences(),
        );
      } on Object {
        // Best-effort reconciliation after restoring the durable list.
      }
      _showLocalError();
      await _refreshSystemStatus();
    } finally {
      if (mounted) _updateState(() => _saving = false);
    }
  }

  Future<void> _chooseTime(DailyReminder reminder) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (selected == null) return;
    await _update(
      DailyReminder(
        kind: reminder.kind,
        hour: selected.hour,
        minute: selected.minute,
        enabled: reminder.enabled,
      ),
    );
  }

  Future<void> _addReminder() async {
    final reminders = _reminders;
    if (reminders == null) return;
    final kind = await showModalBottomSheet<DailyReminderKind>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reminder in reminders)
              ListTile(
                leading: Icon(_icon(reminder.kind)),
                title: Text(_copy.label(reminder.kind)),
                trailing: reminder.enabled
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, reminder.kind),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final reminder = reminders.firstWhere((item) => item.kind == kind);
    await _update(
      DailyReminder(
        kind: reminder.kind,
        hour: reminder.hour,
        minute: reminder.minute,
        enabled: true,
      ),
    );
  }
}
