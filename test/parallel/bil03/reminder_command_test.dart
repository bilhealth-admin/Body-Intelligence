import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_reminder_command.dart';
import 'package:body_intelligence_log/features/intelligence_center/settings_commands/coach_unit_settings_command.dart';
import 'package:body_intelligence_log/features/notifications/domain/daily_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission denial leaves saved reminder unchanged', () async {
    final store = _FakeReminderStore();
    final platform = _FakeReminderPlatform(permissionAllowed: false);
    final service = CoachReminderCommandService(
      store: store,
      platform: platform,
    );

    final result = await service.commit(
      kind: DailyReminderKind.water,
      enabled: true,
      hour: 18,
      minute: 30,
    );

    expect(result.status, CoachReminderCommitStatus.permissionDenied);
    expect(store.saveCount, 0);
    expect(platform.applyCount, 0);
    expect(store.current(DailyReminderKind.water).enabled, isFalse);
  });

  test(
    'successful reminder requires persisted and scheduler readback',
    () async {
      final store = _FakeReminderStore();
      final platform = _FakeReminderPlatform(permissionAllowed: true);
      final service = CoachReminderCommandService(
        store: store,
        platform: platform,
      );

      final result = await service.commit(
        kind: DailyReminderKind.meals,
        enabled: true,
        hour: 13,
        minute: 45,
      );

      expect(result.status, CoachReminderCommitStatus.committed);
      expect(store.current(DailyReminderKind.meals).enabled, isTrue);
      expect(
        result.pendingNotificationIds,
        contains(DailyReminderKind.meals.index + 7100),
      );
    },
  );

  test(
    'missing pending schedule is not reported as enabled and rolls back',
    () async {
      final store = _FakeReminderStore();
      final platform = _FakeReminderPlatform(
        permissionAllowed: true,
        suppressPendingReadback: true,
      );
      final service = CoachReminderCommandService(
        store: store,
        platform: platform,
      );

      final result = await service.commit(
        kind: DailyReminderKind.weight,
        enabled: true,
      );

      expect(result.status, CoachReminderCommitStatus.notScheduled);
      expect(store.current(DailyReminderKind.weight).enabled, isFalse);
      expect(store.saveCount, greaterThanOrEqualTo(2));
    },
  );

  test(
    'partial scheduling exception restores saved reminder snapshot',
    () async {
      final store = _FakeReminderStore();
      final platform = _FakeReminderPlatform(
        permissionAllowed: true,
        throwOnFirstApply: true,
      );
      final service = CoachReminderCommandService(
        store: store,
        platform: platform,
      );

      await expectLater(
        service.commit(kind: DailyReminderKind.sleep, enabled: true, hour: 21),
        throwsStateError,
      );
      expect(store.current(DailyReminderKind.sleep).enabled, isFalse);
      expect(platform.applyCount, 2); // failed attempt + rollback attempt
    },
  );

  test(
    'write permission revoked after preference save rolls back scheduler and store',
    () async {
      final store = _FakeReminderStore();
      final platform = _FakeReminderPlatform(permissionAllowed: true);
      final service = CoachReminderCommandService(
        store: store,
        platform: platform,
      );
      var checks = 0;

      await expectLater(
        service.commit(
          kind: DailyReminderKind.water,
          enabled: true,
          hour: 18,
          minute: 30,
          checkWritePermission: () => ++checks < 4,
        ),
        throwsA(isA<CoachSettingsCommandConflict>()),
      );
      expect(store.current(DailyReminderKind.water).enabled, isFalse);
      expect(
        platform.pending,
        isNot(contains(DailyReminderKind.water.index + 7100)),
      );
      expect(store.saveCount, greaterThanOrEqualTo(2));
    },
  );

  test('owner change is checked before device mutation', () async {
    final store = _FakeReminderStore();
    final platform = _FakeReminderPlatform(permissionAllowed: true);
    final service = CoachReminderCommandService(
      store: store,
      platform: platform,
    );

    await expectLater(
      service.commit(
        kind: DailyReminderKind.fasting,
        enabled: true,
        isCurrentOwner: () => false,
      ),
      throwsA(isA<Exception>()),
    );
    expect(platform.permissionRequests, 0);
    expect(platform.applyCount, 0);
  });
}

class _FakeReminderStore implements CoachReminderStoreGateway {
  _FakeReminderStore() : reminders = [...DailyReminderStoreDefaults.values];

  List<DailyReminder> reminders;
  int saveCount = 0;

  DailyReminder current(DailyReminderKind kind) =>
      reminders.firstWhere((item) => item.kind == kind);

  @override
  Future<List<DailyReminder>> load() async => [...reminders];

  @override
  Future<void> save(List<DailyReminder> next) async {
    saveCount += 1;
    reminders = [...next];
  }
}

class DailyReminderStoreDefaults {
  static const values = <DailyReminder>[
    DailyReminder(kind: DailyReminderKind.weight, hour: 8, minute: 0),
    DailyReminder(kind: DailyReminderKind.meals, hour: 14, minute: 0),
    DailyReminder(kind: DailyReminderKind.water, hour: 17, minute: 0),
    DailyReminder(kind: DailyReminderKind.sleep, hour: 22, minute: 0),
    DailyReminder(kind: DailyReminderKind.fasting, hour: 20, minute: 0),
    DailyReminder(kind: DailyReminderKind.weeklyReview, hour: 19, minute: 0),
    DailyReminder(
      kind: DailyReminderKind.returnAfter24Hours,
      hour: 0,
      minute: 0,
    ),
  ];
}

class _FakeReminderPlatform implements CoachReminderPlatformGateway {
  _FakeReminderPlatform({
    required this.permissionAllowed,
    this.suppressPendingReadback = false,
    this.throwOnFirstApply = false,
  });

  final bool permissionAllowed;
  final bool suppressPendingReadback;
  final bool throwOnFirstApply;
  final Set<int> pending = <int>{};
  int permissionRequests = 0;
  int applyCount = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return permissionAllowed;
  }

  @override
  Future<void> apply({
    required DailyReminder reminder,
    required List<DailyReminder> allReminders,
  }) async {
    applyCount += 1;
    if (throwOnFirstApply && applyCount == 1) {
      throw StateError('synthetic partial scheduler failure');
    }
    if (reminder.enabled &&
        reminder.kind != DailyReminderKind.returnAfter24Hours) {
      pending.add(reminder.notificationId);
    } else {
      pending.remove(reminder.notificationId);
    }
  }

  @override
  Future<Set<int>> pendingNotificationIds() async =>
      suppressPendingReadback ? <int>{} : {...pending};
}
