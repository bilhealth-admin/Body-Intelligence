import 'coach_unit_settings_command.dart';
import '../../notifications/domain/daily_reminder.dart';
import '../../notifications/domain/notification_delivery_preferences.dart';
import '../../notifications/services/bil_notification_service.dart';
import '../../notifications/services/daily_reminder_store.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class CoachReminderStoreGateway {
  Future<List<DailyReminder>> load();
  Future<void> save(List<DailyReminder> reminders);
}

class DailyReminderStoreGateway implements CoachReminderStoreGateway {
  const DailyReminderStoreGateway(this.store);
  final DailyReminderStore store;

  @override
  Future<List<DailyReminder>> load() => store.load();

  @override
  Future<void> save(List<DailyReminder> reminders) => store.save(reminders);
}

abstract interface class CoachReminderPlatformGateway {
  Future<bool> requestPermission();
  Future<void> apply({
    required DailyReminder reminder,
    required List<DailyReminder> allReminders,
  });
  Future<Set<int>> pendingNotificationIds();
}

class BilReminderPlatformGateway implements CoachReminderPlatformGateway {
  const BilReminderPlatformGateway({
    required this.service,
    required this.languageCode,
    this.preferences = const NotificationDeliveryPreferences(),
  });

  final BilNotificationService service;
  final String languageCode;
  final NotificationDeliveryPreferences preferences;

  @override
  Future<bool> requestPermission() => service.requestPermission();

  @override
  Future<void> apply({
    required DailyReminder reminder,
    required List<DailyReminder> allReminders,
  }) async {
    await service.schedule(
      reminder,
      languageCode: languageCode,
      preferences: preferences,
    );
    await service.scheduleDailyGroupSummary(
      allReminders,
      languageCode: languageCode,
      preferences: preferences,
    );
  }

  @override
  Future<Set<int>> pendingNotificationIds() => service.pendingNotificationIds();
}

enum CoachReminderCommitStatus { committed, permissionDenied, notScheduled }

class CoachReminderCommitResult {
  const CoachReminderCommitResult({
    required this.status,
    required this.before,
    required this.requested,
    required this.persisted,
    required this.pendingNotificationIds,
  });

  final CoachReminderCommitStatus status;
  final DailyReminder before;
  final DailyReminder requested;
  final DailyReminder persisted;
  final Set<int> pendingNotificationIds;

  bool get committed => status == CoachReminderCommitStatus.committed;
}

/// Applies an existing BIL daily reminder and verifies both durable preference
/// state and the OS scheduler. Permission denial or partial scheduling is never
/// described as a successful reminder activation.
class CoachReminderCommandService {
  const CoachReminderCommandService({
    required this.store,
    required this.platform,
  });

  final CoachReminderStoreGateway store;
  final CoachReminderPlatformGateway platform;

  static Future<CoachReminderCommandService> production({
    required String languageCode,
  }) async {
    final delivery = await NotificationDeliveryPreferencesStore().load();
    return CoachReminderCommandService(
      store: DailyReminderStoreGateway(DailyReminderStore()),
      platform: BilReminderPlatformGateway(
        service: BilNotificationService(FlutterLocalNotificationsPlugin()),
        languageCode: languageCode,
        preferences: delivery,
      ),
    );
  }

  Future<CoachReminderCommitResult> commit({
    required DailyReminderKind kind,
    required bool enabled,
    int? hour,
    int? minute,
    bool Function()? isCurrentOwner,
    bool Function()? checkWritePermission,
  }) async {
    _checkOwner(isCurrentOwner);
    _checkPermission(checkWritePermission);
    final beforeAll = await store.load();
    _checkOwner(isCurrentOwner);
    final before = beforeAll.firstWhere((item) => item.kind == kind);
    final requested = DailyReminder(
      kind: kind,
      hour: hour ?? before.hour,
      minute: minute ?? before.minute,
      enabled: enabled,
    );
    if (requested.hour < 0 || requested.hour > 23) {
      throw ArgumentError.value(requested.hour, 'hour');
    }
    if (requested.minute < 0 || requested.minute > 59) {
      throw ArgumentError.value(requested.minute, 'minute');
    }

    if (enabled) {
      final allowed = await platform.requestPermission();
      _checkOwner(isCurrentOwner);
      _checkPermission(checkWritePermission);
      if (!allowed) {
        return CoachReminderCommitResult(
          status: CoachReminderCommitStatus.permissionDenied,
          before: before,
          requested: requested,
          persisted: before,
          pendingNotificationIds: await _safePending(),
        );
      }
    }

    final next = [
      for (final item in beforeAll)
        if (item.kind == kind) requested else item,
    ];
    try {
      _checkOwner(isCurrentOwner);
      await platform.apply(reminder: requested, allReminders: next);
      _checkOwner(isCurrentOwner);
      _checkPermission(checkWritePermission);
      await store.save(next);
      _checkOwner(isCurrentOwner);
      _checkPermission(checkWritePermission);
      final persistedAll = await store.load();
      final persisted = persistedAll.firstWhere((item) => item.kind == kind);
      final pending = await platform.pendingNotificationIds();
      _checkOwner(isCurrentOwner);
      _checkPermission(checkWritePermission);
      final schedulerMatches = kind == DailyReminderKind.returnAfter24Hours
          ? !enabled || !pending.contains(requested.notificationId)
          : enabled
          ? pending.contains(requested.notificationId)
          : !pending.contains(requested.notificationId);
      if (!_sameReminder(persisted, requested) || !schedulerMatches) {
        await _rollback(beforeAll, before);
        return CoachReminderCommitResult(
          status: CoachReminderCommitStatus.notScheduled,
          before: before,
          requested: requested,
          persisted: before,
          pendingNotificationIds: await _safePending(),
        );
      }
      return CoachReminderCommitResult(
        status: CoachReminderCommitStatus.committed,
        before: before,
        requested: requested,
        persisted: persisted,
        pendingNotificationIds: pending,
      );
    } on Object {
      await _rollback(beforeAll, before);
      rethrow;
    }
  }

  Future<void> _rollback(
    List<DailyReminder> beforeAll,
    DailyReminder before,
  ) async {
    try {
      await store.save(beforeAll);
    } on Object {
      // The caller reports failure; do not manufacture a successful receipt.
    }
    try {
      await platform.apply(reminder: before, allReminders: beforeAll);
    } on Object {
      // Best effort only. A failed rollback remains a failed operation.
    }
  }

  Future<Set<int>> _safePending() async {
    try {
      return await platform.pendingNotificationIds();
    } on Object {
      return const <int>{};
    }
  }

  static bool _sameReminder(DailyReminder left, DailyReminder right) =>
      left.kind == right.kind &&
      left.hour == right.hour &&
      left.minute == right.minute &&
      left.enabled == right.enabled;

  static void _checkPermission(bool Function()? checkWritePermission) {
    if (checkWritePermission?.call() == false) {
      throw const CoachSettingsCommandConflict('write_permission_revoked');
    }
  }

  static void _checkOwner(bool Function()? isCurrentOwner) {
    if (isCurrentOwner?.call() == false) {
      throw const CoachSettingsCommandConflict('owner_changed');
    }
  }
}
