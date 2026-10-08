part of 'coach_fasting_commands.dart';

enum CoachFastingNotificationStatus {
  synchronized,
  cancelled,
  targetElapsed,
  permissionDenied,
  unavailable,
  superseded,
}

/// Device scheduling is a separate outcome from the committed fasting data.
/// Nullable fields mean the device readback was unavailable, never false/zero.
/// A completed ongoing refresh reports the API call, not visible OS delivery.
final class CoachFastingNotificationResult {
  CoachFastingNotificationResult({
    required this.status,
    this.sessionActive,
    this.targetReminderRequested,
    this.permission,
    this.cancellationCompleted = false,
    this.ongoingRefreshCompleted = false,
    Set<int>? pendingFastingIds,
    this.failedStage,
  }) : pendingFastingIds = pendingFastingIds == null
           ? null
           : Set.unmodifiable(pendingFastingIds);

  final CoachFastingNotificationStatus status;
  final bool? sessionActive;
  final bool? targetReminderRequested;
  final BilNotificationPermissionState? permission;
  final bool cancellationCompleted;
  final bool ongoingRefreshCompleted;
  final Set<int>? pendingFastingIds;
  final String? failedStage;

  bool? get targetReminderScheduled => pendingFastingIds?.contains(
    BilNotificationService.fastingTargetNotificationId,
  );

  bool? get hydrationRemindersScheduled =>
      pendingFastingIds?.any(_isFastingHydrationId);

  Map<String, Object?> toJson() => {
    'status': status.name,
    'sessionActive': sessionActive,
    'targetReminderRequested': targetReminderRequested,
    'permission': permission?.name,
    'cancellationCompleted': cancellationCompleted,
    'ongoingRefreshCompleted': ongoingRefreshCompleted,
    'targetReminderScheduled': targetReminderScheduled,
    'hydrationRemindersScheduled': hydrationRemindersScheduled,
    'pendingFastingIds': pendingFastingIds == null
        ? null
        : (pendingFastingIds!.toList()..sort()),
    'failedStage': failedStage,
  };
}

/// Call only after a native commit/readback or native Undo/readback, or when
/// resuming a persisted session. No saved proposal is used for device effects:
/// every attempt reads the latest preferences and preserves notification opt-in.
final class CoachFastingNotificationSync {
  CoachFastingNotificationSync({
    required this.preferences,
    required this.notifications,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PreferencesRepository preferences;
  final BilNotificationService notifications;
  final DateTime Function() _clock;
  // Fasting IDs are device-global. A fresh owner/resume instance must wait for
  // an older platform await to settle before reconciling those same IDs.
  static Future<void>? _tail;

  static const _keys = [
    CoachFastingCommandAdapter.sessionKey,
    CoachFastingCommandAdapter.startedAtKey,
    CoachFastingCommandAdapter.targetHoursKey,
    CoachFastingCommandAdapter.notifyTargetKey,
  ];

  Future<CoachFastingNotificationResult> syncLatest({
    required String languageCode,
    required void Function() checkAccess,
  }) {
    // This queue is process-local scheduling coordination, not an operation
    // journal. Fixed service IDs make replay and restart reconciliation safe.
    final pending = _tail;
    final result = pending == null
        ? _syncLatest(languageCode, checkAccess)
        : pending.then((_) => _syncLatest(languageCode, checkAccess));
    late final Future<void> tail;
    void release() {
      // A completed Future retains its creation zone. Drop an idle tail so a
      // later visit starts in its own scheduler, while keeping a newer queued
      // attempt attached until that attempt actually completes.
      if (identical(_tail, tail)) _tail = null;
    }

    tail = result.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    _tail = tail;
    return result;
  }

  Future<CoachFastingNotificationResult> _syncLatest(
    String languageCode,
    void Function() checkAccess,
  ) async {
    bool? sessionActive;
    bool? requested;
    BilNotificationPermissionState? permission;
    var cancelled = false;
    var ongoing = false;
    Set<int>? pending;

    CoachFastingNotificationResult result(
      CoachFastingNotificationStatus status, {
      String? failedStage,
    }) => CoachFastingNotificationResult(
      status: status,
      sessionActive: sessionActive,
      targetReminderRequested: requested,
      permission: permission,
      cancellationCompleted: cancelled,
      ongoingRefreshCompleted: ongoing,
      pendingFastingIds: pending,
      failedStage: failedStage,
    );

    try {
      for (var attempt = 0; attempt < 3; attempt += 1) {
        checkAccess();
        sessionActive = null;
        requested = null;
        cancelled = false;
        ongoing = false;
        pending = null;
        permission = null;
        final values = await _readLatest(checkAccess);
        late final FastingSession? session;
        try {
          session = _readFastingSession(values, notAfter: _clock());
        } on FormatException {
          throw const _FastingNotificationFailure('stored_session');
        }
        sessionActive = session != null;
        requested =
            values[CoachFastingCommandAdapter.notifyTargetKey] == 'true';

        await _deviceAwait(
          notifications.cancelFastingSessionNotifications,
          checkAccess,
          'cancel',
        );
        cancelled = true;
        if (!await _stillLatest(values, checkAccess)) continue;

        final target = session?.targetNotificationAt(_clock());
        if (session == null || target == null) {
          pending = await _readPending(checkAccess);
          if (!await _stillLatest(values, checkAccess)) continue;
          if (pending.isNotEmpty) {
            return result(
              CoachFastingNotificationStatus.unavailable,
              failedStage: 'cancel_readback',
            );
          }
          return result(
            session == null
                ? CoachFastingNotificationStatus.cancelled
                : CoachFastingNotificationStatus.targetElapsed,
          );
        }
        final activeSession = session;

        permission = await _deviceAwait(
          notifications.permissionState,
          checkAccess,
          'permission',
        );
        if (!await _stillLatest(values, checkAccess)) continue;
        if (permission != BilNotificationPermissionState.granted) {
          pending = await _readPending(checkAccess);
          if (!await _stillLatest(values, checkAccess)) continue;
          if (pending.isNotEmpty) {
            return result(
              CoachFastingNotificationStatus.unavailable,
              failedStage: 'cancel_readback',
            );
          }
          return result(
            permission == BilNotificationPermissionState.unknown
                ? CoachFastingNotificationStatus.unavailable
                : CoachFastingNotificationStatus.permissionDenied,
            failedStage: permission == BilNotificationPermissionState.unknown
                ? 'permission'
                : null,
          );
        }

        await _deviceAwait(
          () => notifications.showFastingOngoing(
            target: target,
            languageCode: languageCode,
          ),
          checkAccess,
          'ongoing',
        );
        ongoing = true;
        if (!await _stillLatest(values, checkAccess)) continue;
        await _deviceAwait(
          () => notifications.scheduleFastingHydration(
            startedAt: activeSession.startedAt,
            target: target,
            languageCode: languageCode,
          ),
          checkAccess,
          'hydration',
        );
        if (!await _stillLatest(values, checkAccess)) continue;
        if (requested) {
          await _deviceAwait(
            () => notifications.scheduleFastingTarget(
              target: target,
              languageCode: languageCode,
            ),
            checkAccess,
            'target',
          );
        }
        pending = await _readPending(checkAccess);
        if (!await _stillLatest(values, checkAccess)) continue;
        final now = _clock();
        final expected = _expectedFastingPendingIds(
          activeSession,
          now,
          notifyTarget: requested,
        );
        if (!pending.containsAll(expected) ||
            pending.length != expected.length) {
          return result(
            CoachFastingNotificationStatus.unavailable,
            failedStage: 'schedule_readback',
          );
        }
        return result(
          activeSession.targetNotificationAt(now) == null
              ? CoachFastingNotificationStatus.targetElapsed
              : CoachFastingNotificationStatus.synchronized,
        );
      }

      // Repeated changes cannot leave the last stale proposal scheduled. A
      // later explicit retry/resume will reconcile the then-current session.
      await _deviceAwait(
        notifications.cancelFastingSessionNotifications,
        checkAccess,
        'cancel_superseded',
      );
      cancelled = true;
      ongoing = false;
      pending = await _readPending(checkAccess);
      if (pending.isNotEmpty) {
        return result(
          CoachFastingNotificationStatus.unavailable,
          failedStage: 'cancel_readback',
        );
      }
      return result(CoachFastingNotificationStatus.superseded);
    } on _FastingNotificationFailure catch (failure) {
      return result(
        CoachFastingNotificationStatus.unavailable,
        failedStage: failure.stage,
      );
    }
  }

  Future<Map<String, String?>> _readLatest(void Function() checkAccess) async {
    final values = <String, String?>{};
    for (final key in _keys) {
      values[key] = await _deviceAwait(
        () => preferences.get(key),
        checkAccess,
        'session_readback',
      );
    }
    return values;
  }

  Future<bool> _stillLatest(
    Map<String, String?> expected,
    void Function() checkAccess,
  ) async {
    final latest = await _readLatest(checkAccess);
    return _keys.every((key) => latest[key] == expected[key]);
  }

  Future<Set<int>> _readPending(void Function() checkAccess) async {
    final ids = await _deviceAwait(
      notifications.pendingNotificationIds,
      checkAccess,
      'pending_readback',
    );
    return ids.where(_isFastingNotificationId).toSet();
  }

  Future<T> _deviceAwait<T>(
    Future<T> Function() action,
    void Function() checkAccess,
    String stage,
  ) async {
    checkAccess();
    late final T value;
    try {
      value = await action();
    } on Object {
      // Access revocation is a caller-level rejection, never a soft device
      // error. It escapes the result conversion and prevents later effects.
      checkAccess();
      throw _FastingNotificationFailure(stage);
    }
    checkAccess();
    return value;
  }
}

final class _FastingNotificationFailure implements Exception {
  const _FastingNotificationFailure(this.stage);
  final String stage;
}

bool _isFastingHydrationId(int id) =>
    id >= BilNotificationService.fastingHydrationNotificationIdBase &&
    id <
        BilNotificationService.fastingHydrationNotificationIdBase +
            BilNotificationService.fastingHydrationNotificationSlots;

bool _isFastingNotificationId(int id) =>
    id == BilNotificationService.fastingTargetNotificationId ||
    id == BilNotificationService.fastingOngoingNotificationId ||
    _isFastingHydrationId(id);

Set<int> _expectedFastingPendingIds(
  FastingSession session,
  DateTime now, {
  required bool notifyTarget,
}) {
  final target = session.targetReachedAt.toUtc();
  final ids = <int>{};
  if (notifyTarget && target.isAfter(now.toUtc())) {
    ids.add(BilNotificationService.fastingTargetNotificationId);
  }
  for (
    var slot = 0;
    slot < BilNotificationService.fastingHydrationNotificationSlots;
    slot += 1
  ) {
    final at = session.startedAt.toUtc().add(Duration(hours: 4 * (slot + 1)));
    if (at.isBefore(target) && at.isAfter(now.toUtc())) {
      ids.add(BilNotificationService.fastingHydrationNotificationIdBase + slot);
    }
  }
  return ids;
}
