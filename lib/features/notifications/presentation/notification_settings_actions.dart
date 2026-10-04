part of 'notification_settings_page.dart';

extension _NotificationSettingsActions on _NotificationSettingsPageState {
  Future<void> _applySavedCategories() async {
    final snapshot = _pushPreferences?.deliveryCategories;
    if (_pushSaving ||
        _saving ||
        !_communityDeliveryActive ||
        snapshot == null ||
        !snapshot.initialized ||
        snapshot.synchronized ||
        snapshot.desired == null) {
      return;
    }
    final desired = _deliveryPreferences!.copyWith(
      enabledCategories: snapshot.desired!,
    );
    _updateState(() => _pushSaving = true);
    try {
      final receipt = await _pushService!.syncDeliveryPreferences(
        desired,
        expectedState: snapshot,
      );
      if (mounted) {
        _updateState(() {
          _pushPreferences = _pushPreferences!.withDeliveryCategories(receipt);
          _pushLoadError = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        _updateState(() => _pushLoadError = true);
        _showPushError();
        if (error is PostgrestException && error.code == '40001') {
          await _loadPushPreferences();
        }
      }
    } finally {
      if (mounted) _updateState(() => _pushSaving = false);
    }
  }

  Future<void> _loadPushPreferences() async {
    if (!mounted || _pushLoading || _pushService == null) return;
    _updateState(() => _pushLoading = true);
    try {
      final preferences = await _pushService!.loadPreferences();
      if (mounted) {
        _updateState(() {
          _pushPreferences = preferences;
          _pushLoadError = false;
        });
      }
    } on Object {
      if (mounted) _updateState(() => _pushLoadError = true);
    } finally {
      if (mounted) _updateState(() => _pushLoading = false);
    }
  }

  Future<void> _setPushEnabled(bool enabled) async {
    if (_pushService == null || _pushSaving) return;
    _updateState(() => _pushSaving = true);
    try {
      await _pushService!.setEnabled(
        enabled,
        deliveryPreferences:
            _deliveryPreferences ?? const NotificationDeliveryPreferences(),
      );
      await _loadPushPreferences();
    } on Object {
      if (mounted) {
        _updateState(() => _pushLoadError = true);
        _showPushError();
      }
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

  Future<void> _saveDelivery(
    NotificationDeliveryPreferences value, {
    NotificationCategory? category,
  }) async {
    if (_saving) return;
    final previous = _deliveryPreferences!;
    final categorySnapshot = _pushPreferences?.deliveryCategories;
    if (category != null &&
        (!_communityDeliveryActive || !(categorySnapshot?.verified ?? false))) {
      return;
    }
    final reminders = _reminders!;
    _updateState(() {
      _savingCategory = category;
      _saving = true;
    });
    try {
      await _deliveryStore.save(value);
      await _reconcile(reminders, value);
      if (mounted) _updateState(() => _deliveryPreferences = value);
      if (category != null && _pushService != null) {
        try {
          final receipt = await _pushService!.syncDeliveryPreferences(
            value,
            expectedState: categorySnapshot!,
          );
          if (mounted) {
            _updateState(() {
              _pushPreferences = _pushPreferences!.withDeliveryCategories(
                receipt,
              );
            });
          }
        } on Object catch (error) {
          if (mounted) {
            _updateState(() => _pushLoadError = true);
            _showPushError();
            if (error is PostgrestException && error.code == '40001') {
              // Another device changed this owner's categories. Refresh truth;
              // never automatically replay a stale full-category snapshot.
              await _loadPushPreferences();
            }
          }
        }
      }
    } on Object {
      if (mounted) _updateState(() => _deliveryPreferences = previous);
      try {
        await _deliveryStore.save(previous);
      } on Object {
        // A persistence failure must not prevent independent OS rollback.
      }
      try {
        await _reconcile(reminders, previous);
      } on Object {
        // Best-effort reconciliation; the visible state remains the last
        // durable preference snapshot and the next edit retries scheduling.
      }
      if (mounted) _showLocalError();
    } finally {
      if (mounted) {
        _updateState(() {
          _saving = false;
          _savingCategory = null;
        });
      }
    }
  }

  Future<void> _reconcile(
    List<DailyReminder> reminders,
    NotificationDeliveryPreferences delivery,
  ) async {
    final language = _languageCode;
    for (final reminder in reminders) {
      await _service.schedule(
        reminder,
        languageCode: language,
        preferences: delivery,
      );
    }
    await _service.scheduleDailyGroupSummary(
      reminders,
      languageCode: language,
      preferences: delivery,
    );
  }

  void _showLocalError() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_copy.permissionError)));

  Future<void> _toggleCategory(
    NotificationCategory category,
    bool enabled,
  ) async {
    if (_saving ||
        !_communityDeliveryActive ||
        !_communityCategoriesVerified ||
        !NotificationDeliveryPreferences.supportedCategories.contains(
          category,
        )) {
      return;
    }
    final current = _deliveryPreferences!;
    final categories = {..._pushPreferences!.deliveryCategories!.desired!};
    enabled ? categories.add(category) : categories.remove(category);
    final next = current.copyWith(enabledCategories: categories);
    await _saveDelivery(next, category: category);
  }

  Future<void> _update(DailyReminder updated) async {
    final current = _reminders;
    if (current == null || _saving) return;
    final next = [
      for (final reminder in current)
        if (reminder.kind == updated.kind) updated else reminder,
    ];
    _updateState(() {
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
      if (mounted) _updateState(() => _reminders = next);
      await _refreshSystemStatus();
    } on Object {
      if (!mounted) return;
      _updateState(() => _reminders = current);
      await _restoreDailyState(current);
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
      if (mounted) _updateState(() => _reminders = next);
      await _refreshSystemStatus();
    } on Object {
      if (!mounted) return;
      _updateState(() => _reminders = previous);
      await _restoreDailyState(previous);
      _showLocalError();
      await _refreshSystemStatus();
    } finally {
      if (mounted) _updateState(() => _saving = false);
    }
  }

  Future<void> _restoreDailyState(List<DailyReminder> previous) async {
    try {
      await _store.save(previous);
    } on Object {
      // Scheduling rollback is independent of platform persistence failure.
    }
    try {
      await _reconcile(
        previous,
        _deliveryPreferences ?? const NotificationDeliveryPreferences(),
      );
    } on Object {
      // The caller reports failure; native delivery is not claimed successful.
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
                leading: BilSemanticIconBadge(
                  kind: _semanticKind(reminder.kind),
                ),
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
