import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_fasting_commands.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/wellness/domain/fasting_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late PreferencesRepository preferences;
  late _FakeFastingNotifications notifications;
  late CoachFastingNotificationSync sync;
  final now = DateTime.utc(2026, 10, 7, 8);
  final start = now.subtract(const Duration(hours: 2));

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    notifications = _FakeFastingNotifications(now);
    sync = CoachFastingNotificationSync(
      preferences: preferences,
      notifications: notifications,
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  test(
    'idle notification queue can be reused across independent visit zones',
    () {
      CoachFastingNotificationResult? visit(String locale) {
        final microtasks = <void Function()>[];
        CoachFastingNotificationResult? completed;
        // Like separate widget FakeAsync visits, each visit owns its scheduler.
        // A completed queue Future must not retain the previous scheduler.
        runZoned<void>(
          () {
            CoachFastingNotificationSync(
              preferences: _EmptyFastingPreferences(database),
              notifications: notifications,
              clock: () => now,
            ).syncLatest(languageCode: locale, checkAccess: _allow).then((
              value,
            ) {
              completed = value;
            });
            while (microtasks.isNotEmpty) {
              microtasks.removeAt(0)();
            }
          },
          zoneSpecification: ZoneSpecification(
            scheduleMicrotask: (self, parent, zone, callback) {
              microtasks.add(() => zone.runGuarded(callback));
            },
          ),
        );
        return completed;
      }

      expect(visit('ar')?.status, CoachFastingNotificationStatus.cancelled);
      expect(visit('en')?.status, CoachFastingNotificationStatus.cancelled);
      expect(
        notifications.calls.where((call) => call == 'cancel'),
        hasLength(2),
      );
    },
  );

  test(
    'independent instances still serialize while a platform call is pending',
    () async {
      await _saveSession(preferences, start);
      final entered = Completer<void>();
      final release = Completer<void>();
      notifications.afterCancel = () async {
        notifications.afterCancel = null;
        entered.complete();
        await release.future;
      };
      final first = sync.syncLatest(languageCode: 'ar', checkAccess: _allow);
      await entered.future;
      var secondCompleted = false;
      final second =
          CoachFastingNotificationSync(
            preferences: preferences,
            notifications: notifications,
            clock: () => now,
          ).syncLatest(languageCode: 'en', checkAccess: _allow).then((value) {
            secondCompleted = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(notifications.calls, ['cancel']);
      expect(secondCompleted, isFalse);
      release.complete();
      final outcomes = await Future.wait([first, second]);
      expect(outcomes.map((value) => value.status), [
        CoachFastingNotificationStatus.synchronized,
        CoachFastingNotificationStatus.synchronized,
      ]);
      expect(
        notifications.calls.where((call) => call == 'cancel'),
        hasLength(2),
      );
      expect(outcomes.first.pendingFastingIds, outcomes.last.pendingFastingIds);
    },
  );

  test(
    'restart sync reads persisted session and repeated calls retain stable IDs',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      notifications.pending.add(999); // Unrelated reminder must survive.
      final before = await _allFastingPreferences(preferences);
      final first = await sync.syncLatest(
        languageCode: 'ar',
        checkAccess: _allow,
      );
      expect(first.status, CoachFastingNotificationStatus.synchronized);
      expect(first.targetReminderScheduled, isTrue);
      expect(first.hydrationRemindersScheduled, isTrue);
      expect(first.permission, BilNotificationPermissionState.granted);
      final restarted = CoachFastingNotificationSync(
        preferences: PreferencesRepository(database),
        notifications: notifications,
        clock: () => now,
      );
      final second = await restarted.syncLatest(
        languageCode: 'ar',
        checkAccess: _allow,
      );
      expect(second.pendingFastingIds, first.pendingFastingIds);
      expect(notifications.pending, contains(999));
      expect(notifications.requestPermissionCalls, 0);
      expect(await _allFastingPreferences(preferences), before);
    },
  );

  test(
    'notification opt-out is preserved while active timer state is refreshed',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(
        CoachFastingCommandAdapter.notifyTargetKey,
        'false',
      );
      notifications.pending.add(
        BilNotificationService.fastingTargetNotificationId,
      );
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.synchronized);
      expect(result.targetReminderRequested, isFalse);
      expect(result.targetReminderScheduled, isFalse);
      expect(notifications.calls, isNot(contains('target')));
      expect(
        await preferences.get(CoachFastingCommandAdapter.notifyTargetKey),
        'false',
      );
      expect(notifications.requestPermissionCalls, 0);
    },
  );

  test(
    'denied permission is separate from saved session and never changes opt-in',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      notifications.permission = BilNotificationPermissionState.denied;
      final before = await _allFastingPreferences(preferences);
      final result = await sync.syncLatest(
        languageCode: 'ar',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.permissionDenied);
      expect(result.sessionActive, isTrue);
      expect(result.targetReminderRequested, isTrue);
      expect(result.targetReminderScheduled, isFalse);
      expect(notifications.calls, isNot(contains('ongoing')));
      expect(notifications.calls, isNot(contains('target')));
      expect(notifications.requestPermissionCalls, 0);
      expect(await _allFastingPreferences(preferences), before);
    },
  );

  test(
    'unknown permission is unavailable rather than a false denied fact',
    () async {
      await _saveSession(preferences, start);
      notifications.permission = BilNotificationPermissionState.unknown;
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.unavailable);
      expect(result.permission, BilNotificationPermissionState.unknown);
      expect(result.failedStage, 'permission');
    },
  );

  test(
    'target scheduling failure leaves durable session saved and readback unknown',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      notifications.failStage = 'target';
      final before = await _allFastingPreferences(preferences);
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.unavailable);
      expect(result.failedStage, 'target');
      expect(result.sessionActive, isTrue);
      expect(result.ongoingRefreshCompleted, isTrue);
      expect(result.targetReminderScheduled, isNull);
      expect(result.hydrationRemindersScheduled, isNull);
      expect(await _allFastingPreferences(preferences), before);
      notifications.failStage = null;
      final retry = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(retry.status, CoachFastingNotificationStatus.synchronized);
      expect(await _allFastingPreferences(preferences), before);
    },
  );

  test('silent scheduling loss is detected by pending-ID readback', () async {
    await _saveSession(preferences, start);
    await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
    notifications.dropTarget = true;
    final result = await sync.syncLatest(
      languageCode: 'en',
      checkAccess: _allow,
    );
    expect(result.status, CoachFastingNotificationStatus.unavailable);
    expect(result.failedStage, 'schedule_readback');
    expect(result.targetReminderScheduled, isFalse);
    expect(result.hydrationRemindersScheduled, isTrue);
  });

  test(
    'pending readback failure is unknown, never success with false totals',
    () async {
      await _saveSession(preferences, start);
      notifications.failStage = 'pending';
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.unavailable);
      expect(result.failedStage, 'pending_readback');
      expect(result.pendingFastingIds, isNull);
      expect(result.targetReminderScheduled, isNull);
    },
  );

  test(
    'stop or Undo start cancels previous fasting IDs using latest empty state',
    () async {
      notifications.pending.addAll({
        BilNotificationService.fastingTargetNotificationId,
        BilNotificationService.fastingHydrationNotificationIdBase,
        999,
      });
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.cancelled);
      expect(result.sessionActive, isFalse);
      expect(result.pendingFastingIds, isEmpty);
      expect(notifications.pending, {999});
      expect(notifications.calls, isNot(contains('permission')));
    },
  );

  test(
    'a failed cancellation does not imply rollback of the stopped session',
    () async {
      notifications.pending.add(
        BilNotificationService.fastingTargetNotificationId,
      );
      notifications.failStage = 'cancel';
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.unavailable);
      expect(result.sessionActive, isFalse);
      expect(result.cancellationCompleted, isFalse);
      expect(result.failedStage, 'cancel');
      expect(
        await preferences.get(CoachFastingCommandAdapter.sessionKey),
        isNull,
      );
    },
  );

  test(
    'cancellation failure detected by readback remains a partial device error',
    () async {
      notifications.pending.add(
        BilNotificationService.fastingTargetNotificationId,
      );
      notifications.dropCancel = true;
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.unavailable);
      expect(result.failedStage, 'cancel_readback');
      expect(result.targetReminderScheduled, isTrue);
    },
  );

  test(
    'elapsed target is never rolled into a new day or auto-ended in storage',
    () async {
      await _saveSession(preferences, now.subtract(const Duration(hours: 20)));
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      notifications.pending.add(
        BilNotificationService.fastingTargetNotificationId,
      );
      final before = await _allFastingPreferences(preferences);
      final result = await sync.syncLatest(
        languageCode: 'ar',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.targetElapsed);
      expect(result.sessionActive, isTrue);
      expect(result.pendingFastingIds, isEmpty);
      expect(notifications.calls, isNot(contains('target')));
      expect(await _allFastingPreferences(preferences), before);
    },
  );

  test(
    'latest stop during device await prevents an obsolete target reschedule',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      notifications.afterHydration = () async {
        notifications.afterHydration = null;
        await preferences.removeMany(const [
          CoachFastingCommandAdapter.sessionKey,
          CoachFastingCommandAdapter.startedAtKey,
        ]);
      };
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.cancelled);
      expect(notifications.calls, isNot(contains('target')));
      expect(result.pendingFastingIds, isEmpty);
    },
  );

  test(
    'latest adjustment during scheduling wins over an old request',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      notifications.afterTarget = () async {
        notifications.afterTarget = null;
        await _saveSession(preferences, start, hours: 18);
      };
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.synchronized);
      expect(notifications.target, start.add(const Duration(hours: 18)));
      expect(result.targetReminderScheduled, isTrue);
    },
  );

  test(
    'latest opt-out during cancellation prevents target re-enablement',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      notifications.afterCancel = () async {
        notifications.afterCancel = null;
        await preferences.set(
          CoachFastingCommandAdapter.notifyTargetKey,
          'false',
        );
      };
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.synchronized);
      expect(result.targetReminderRequested, isFalse);
      expect(result.targetReminderScheduled, isFalse);
      expect(notifications.calls, isNot(contains('target')));
    },
  );

  test(
    'owner A to B to A during async device work is a rejected attempt',
    () async {
      await _saveSession(preferences, start);
      var epoch = 0;
      void checkAccess() {
        if (epoch != 0) throw StateError('Synthetic owner epoch revoked');
      }

      notifications.afterCancel = () async {
        epoch += 2;
      };
      await expectLater(
        sync.syncLatest(languageCode: 'ar', checkAccess: checkAccess),
        throwsStateError,
      );
      expect(notifications.calls, isNot(contains('permission')));
      expect(notifications.calls, isNot(contains('ongoing')));
      expect(notifications.calls, isNot(contains('target')));
    },
  );

  test(
    'device exception cannot swallow access revocation after its await',
    () async {
      await _saveSession(preferences, start);
      var allowed = true;
      notifications.beforeFailure = () {
        allowed = false;
      };
      notifications.failStage = 'permission';
      void checkAccess() {
        if (!allowed) throw StateError('Synthetic permission revoked');
      }

      await expectLater(
        sync.syncLatest(languageCode: 'ar', checkAccess: checkAccess),
        throwsStateError,
      );
      expect(notifications.calls, isNot(contains('ongoing')));
    },
  );

  test(
    'fresh-owner reconciliation clears a platform effect completed before revocation',
    () async {
      await _saveSession(preferences, start);
      await preferences.set(CoachFastingCommandAdapter.notifyTargetKey, 'true');
      var epoch = 0;
      void checkAccess() {
        if (epoch != 0) throw StateError('Synthetic owner epoch revoked');
      }

      notifications.afterTarget = () async {
        notifications.afterTarget = null;
        epoch += 2;
      };
      await expectLater(
        sync.syncLatest(languageCode: 'ar', checkAccess: checkAccess),
        throwsStateError,
      );
      // A platform side effect may precede the post-await rejection. The
      // rejection must never be reported as proof that no OS effect happened.
      expect(
        notifications.pending,
        contains(BilNotificationService.fastingTargetNotificationId),
      );
      final nextDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final nextOwner = CoachFastingNotificationSync(
          preferences: PreferencesRepository(nextDatabase),
          notifications: notifications,
          clock: () => now,
        );
        final next = await nextOwner.syncLatest(
          languageCode: 'en',
          checkAccess: _allow,
        );
        expect(next.status, CoachFastingNotificationStatus.cancelled);
        expect(next.pendingFastingIds, isEmpty);
      } finally {
        await nextDatabase.close();
      }
    },
  );

  test(
    'repeated concurrent edits remain bounded and clear stale schedules',
    () async {
      var hours = 16;
      await _saveSession(preferences, start, hours: hours);
      notifications.afterCancel = () async {
        hours = hours == 16 ? 17 : 16;
        await _saveSession(preferences, start, hours: hours);
      };
      final result = await sync.syncLatest(
        languageCode: 'en',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.superseded);
      expect(result.pendingFastingIds, isEmpty);
      expect(notifications.calls, isNot(contains('target')));
      expect(
        notifications.calls.where((call) => call == 'cancel').length,
        lessThanOrEqualTo(4),
      );
    },
  );

  test(
    'invalid saved session yields unavailable without modifying data or device',
    () async {
      await preferences.set(CoachFastingCommandAdapter.sessionKey, '{invalid');
      final result = await sync.syncLatest(
        languageCode: 'ar',
        checkAccess: _allow,
      );
      expect(result.status, CoachFastingNotificationStatus.unavailable);
      expect(result.failedStage, 'stored_session');
      expect(result.sessionActive, isNull);
      expect(notifications.calls, isEmpty);
      expect(
        await preferences.get(CoachFastingCommandAdapter.sessionKey),
        '{invalid',
      );
    },
  );
}

void _allow() {}

class _EmptyFastingPreferences extends PreferencesRepository {
  _EmptyFastingPreferences(super.database);

  @override
  Future<String?> get(String key) => Future.value();
}

Future<void> _saveSession(
  PreferencesRepository preferences,
  DateTime start, {
  int hours = 16,
}) => preferences.setMany({
  CoachFastingCommandAdapter.sessionKey: jsonEncode(
    FastingSession(startedAt: start, targetHours: hours).toJson(),
  ),
  CoachFastingCommandAdapter.startedAtKey: start.toIso8601String(),
  CoachFastingCommandAdapter.targetHoursKey: '$hours',
});

Future<Map<String, String?>> _allFastingPreferences(
  PreferencesRepository preferences,
) async => {
  for (final key in [
    ...CoachFastingCommandAdapter.dataKeys,
    CoachFastingCommandAdapter.notifyTargetKey,
  ])
    key: await preferences.get(key),
};

class _FakeFastingNotifications extends BilNotificationService {
  _FakeFastingNotifications(this.now)
    : super(FlutterLocalNotificationsPlugin());

  final DateTime now;
  BilNotificationPermissionState permission =
      BilNotificationPermissionState.granted;
  final Set<int> pending = {};
  final List<String> calls = [];
  String? failStage;
  bool dropTarget = false;
  bool dropCancel = false;
  int requestPermissionCalls = 0;
  DateTime? target;
  Future<void> Function()? afterCancel;
  Future<void> Function()? afterHydration;
  Future<void> Function()? afterTarget;
  void Function()? beforeFailure;

  void _check(String stage) {
    calls.add(stage);
    if (failStage == stage) {
      beforeFailure?.call();
      throw StateError('Synthetic notification failure');
    }
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return permission == BilNotificationPermissionState.granted;
  }

  @override
  Future<BilNotificationPermissionState> permissionState() async {
    _check('permission');
    return permission;
  }

  @override
  Future<void> cancelFastingSessionNotifications() async {
    _check('cancel');
    if (!dropCancel) {
      pending.removeWhere(
        (id) =>
            id == BilNotificationService.fastingTargetNotificationId ||
            id == BilNotificationService.fastingOngoingNotificationId ||
            id >= BilNotificationService.fastingHydrationNotificationIdBase &&
                id <
                    BilNotificationService.fastingHydrationNotificationIdBase +
                        BilNotificationService
                            .fastingHydrationNotificationSlots,
      );
      target = null;
    }
    await afterCancel?.call();
  }

  @override
  Future<void> showFastingOngoing({
    required DateTime target,
    required String languageCode,
  }) async {
    _check('ongoing');
  }

  @override
  Future<void> scheduleFastingHydration({
    required DateTime startedAt,
    required DateTime target,
    required String languageCode,
  }) async {
    _check('hydration');
    for (
      var slot = 0;
      slot < BilNotificationService.fastingHydrationNotificationSlots;
      slot += 1
    ) {
      final at = startedAt.add(Duration(hours: (slot + 1) * 4));
      if (at.isBefore(target) && at.isAfter(now)) {
        pending.add(
          BilNotificationService.fastingHydrationNotificationIdBase + slot,
        );
      }
    }
    await afterHydration?.call();
  }

  @override
  Future<void> scheduleFastingTarget({
    required DateTime target,
    required String languageCode,
  }) async {
    _check('target');
    if (!dropTarget && target.isAfter(now)) {
      pending.add(BilNotificationService.fastingTargetNotificationId);
      this.target = target;
    }
    await afterTarget?.call();
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    _check('pending');
    return Set.of(pending);
  }
}
