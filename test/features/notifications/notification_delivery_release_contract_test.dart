import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/notifications/domain/daily_reminder.dart';
import 'package:body_intelligence_log/features/notifications/domain/notification_delivery_preferences.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_push_preferences.dart';
import 'package:body_intelligence_log/features/notifications/domain/community_push_delivery_categories.dart';
import 'package:body_intelligence_log/features/notifications/presentation/notification_settings_page.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/notifications/services/daily_reminder_store.dart';
import 'package:body_intelligence_log/features/notifications/services/community_push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'notification_delivery_release_gateway_fixtures.dart';
part 'notification_delivery_master_contract_tests.dart';

// Real preference repository and SharedPreferences SDK/platform boundary.
// Native notification delivery is an explicitly isolated host gateway, not
// evidence that FCM/APNs/OS scheduling actually delivered a notification.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    // Construct the unused SDK dependency outside the widget fake clock.
    // The controlled gateway overrides every exercised cloud operation.
    _hostCloudClient = SupabaseClient(
      'https://notification.invalid',
      'host-fixture-public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() => _hostCloudClient.dispose());
  _addMasterContractTests();

  test(
    'delivery explicit friendAccepted OFF survives real save and reload',
    () async {
      _installPlatform();
      final repository = NotificationDeliveryPreferencesStore();
      await repository.save(
        const NotificationDeliveryPreferences(
          enabledCategories: {
            NotificationCategory.newMessage,
            NotificationCategory.friendRequest,
          },
        ),
      );
      SharedPreferences.resetStatic();
      final reloaded = await NotificationDeliveryPreferencesStore().load();
      expect(reloaded.allows(NotificationCategory.friendAccepted), isFalse);
      expect(reloaded.allows(NotificationCategory.newMessage), isTrue);
      expect(reloaded.allows(NotificationCategory.friendRequest), isTrue);
      expect(reloaded.pushCategoryParameters, {
        'p_message_enabled': true,
        'p_friend_request_enabled': true,
        'p_friend_accepted_enabled': false,
      });
    },
  );

  test(
    'delivery legacy missing category never infers friendAccepted opt-in',
    () async {
      final platform = _installPlatform();
      await platform.setValue(
        'String',
        _platformKey,
        jsonEncode({
          'enabledCategories': ['newMessage', 'friendRequest'],
          'quietHoursEnabled': false,
        }),
      );
      final reloaded = await NotificationDeliveryPreferencesStore().load();
      expect(reloaded.allows(NotificationCategory.friendAccepted), isFalse);
      expect(reloaded.allows(NotificationCategory.newMessage), isTrue);
    },
  );

  test(
    'delivery missing record enables only three implemented categories',
    () async {
      _installPlatform();
      final reloaded = await NotificationDeliveryPreferencesStore().load();
      expect(reloaded.enabledCategories, const {
        NotificationCategory.newMessage,
        NotificationCategory.friendRequest,
        NotificationCategory.friendAccepted,
      });
    },
  );

  for (final corrupt in [
    '{broken',
    'null',
    '{}',
    '{"enabledCategories":["unrecognized"]}',
  ]) {
    test('delivery corrupt persisted record fails closed $corrupt', () async {
      final platform = _installPlatform();
      await platform.setValue('String', _platformKey, corrupt);
      final reloaded = await NotificationDeliveryPreferencesStore().load();
      expect(reloaded.enabledCategories, isEmpty);
      for (final category in NotificationCategory.values) {
        expect(reloaded.allows(category), isFalse);
      }
      expect(
        (await platform.getAll())[_platformKey],
        corrupt,
        reason: 'Do not overwrite unexplained corrupt user state',
      );
    });
  }

  test(
    'delivery failed platform setString is not an acknowledged preference save',
    () async {
      final platform = _installPlatform();
      final repository = NotificationDeliveryPreferencesStore();
      await repository.save(
        const NotificationDeliveryPreferences(enabledCategories: {}),
      );
      final prior = (await platform.getAll())[_platformKey];
      platform.rejectWrites = true;
      await expectLater(
        repository.save(const NotificationDeliveryPreferences()),
        throwsStateError,
      );
      expect((await platform.getAll())[_platformKey], prior);
      // Do not reset the SDK's cache here: real resume/re-entry must reload
      // durable state even though the failed setString changed that cache.
      expect((await repository.load()).enabledCategories, isEmpty);
      SharedPreferences.resetStatic();
      expect((await repository.load()).enabledCategories, isEmpty);
    },
  );

  test(
    'daily reminder store never acknowledges failed platform save',
    () async {
      final platform = _installPlatform();
      await DailyReminderStore().save(DailyReminderStore.defaults);
      platform.rejectWrites = true;
      await expectLater(
        DailyReminderStore().save([
          const DailyReminder(
            kind: DailyReminderKind.weight,
            hour: 8,
            minute: 0,
            enabled: true,
          ),
        ]),
        throwsStateError,
      );
    },
  );

  for (final language in ['en', 'ar']) {
    _settingsTestWidgets(
      'delivery absent cloud provider has no active category checks $language',
      (tester) async {
        _installPlatform();
        await _mountSettings(tester, language: language);
        final row = _categoryRow(NotificationCategory.newMessage, language);
        await _reachSettingsRow(tester, row);
        expect(tester.widget<CheckboxListTile>(row).value, isFalse);
        expect(tester.widget<CheckboxListTile>(row).onChanged, isNull);
        expect(
          (await NotificationDeliveryPreferencesStore().load()).allows(
            NotificationCategory.newMessage,
          ),
          isTrue,
          reason: 'Unavailable delivery preserves selected preferences',
        );
      },
    );

    _settingsTestWidgets(
      'delivery daily permission pending never claims enabled $language',
      (tester) async {
        _installPlatform();
        final permission = Completer<bool>();
        final gateway = _HostNotificationGateway(permission: permission.future);
        await _mountSettings(tester, language: language, gateway: gateway);
        final master = find.byKey(const Key('all-daily-reminders'));
        await _reachSettingsRow(tester, master);
        final body = tester.renderObject(find.byType(ListView));
        await tester.tap(_toggleTarget(master));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(tester.widget<SwitchListTile>(master).value, isFalse);
        expect(tester.renderObject(find.byType(ListView)), same(body));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(gateway.permissionRequests, 1);
        permission.complete(false);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(master).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery ordinary daily master change never displays activation notification $language',
      (tester) async {
        _installPlatform();
        final gateway = _HostNotificationGateway();
        await _mountSettings(tester, language: language, gateway: gateway);
        final master = find.byKey(const Key('all-daily-reminders'));
        await _reachSettingsRow(tester, master);
        final body = tester.renderObject(find.byType(ListView));
        await tester.tap(_toggleTarget(master));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<SwitchListTile>(master).value, isTrue);
        expect(
          (await DailyReminderStore().load())
              .where((r) => r.kind != DailyReminderKind.returnAfter24Hours)
              .every((r) => r.enabled),
          isTrue,
        );
        expect(tester.renderObject(find.byType(ListView)), same(body));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          gateway.activationNotifications,
          0,
          reason:
              'Ordinary settings saves must not trigger high-priority test alerts',
        );
      },
    );

    _settingsTestWidgets(
      'delivery unsupported categories cannot write via real gestures $language 200%',
      (tester) async {
        final platform = _installPlatform();
        await _mountSettings(tester, language: language);
        final initialWrites = platform.deliveryWrites;
        for (final category in _unsupportedLabels.keys) {
          final row = _categoryRow(category, language);
          await _reachSettingsRow(tester, row);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            platform.deliveryWrites,
            initialWrites,
            reason:
                'Unsupported $category must not offer a pretend preference mutation',
          );
          final widget = tester.widget<CheckboxListTile>(row);
          expect(widget.value, isFalse);
          expect(widget.onChanged, isNull);
          expect(widget.enabled, isFalse);
          expect(
            find.descendant(
              of: row,
              matching: find.text(
                language == 'ar' ? 'غير متاح' : 'Unavailable',
              ),
            ),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    _settingsTestWidgets(
      'delivery supported gestures retain OFF through repository and page re-entry $language',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true);
        await _mountSettings(tester, language: language, push: push);
        for (final category in _supportedLabels.keys) {
          final row = _categoryRow(category, language);
          await _reachSettingsRow(tester, row);
          expect(tester.widget<CheckboxListTile>(row).value, isTrue);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.widget<CheckboxListTile>(row).value, isFalse);
          expect(
            (await NotificationDeliveryPreferencesStore().load()).allows(
              category,
            ),
            isFalse,
          );
          final persisted = await NotificationDeliveryPreferencesStore().load();
          expect(
            persisted.pushCategoryParameters,
            {
              'p_message_enabled': persisted.allows(
                NotificationCategory.newMessage,
              ),
              'p_friend_request_enabled': persisted.allows(
                NotificationCategory.friendRequest,
              ),
              'p_friend_accepted_enabled': persisted.allows(
                NotificationCategory.friendAccepted,
              ),
            },
            reason:
                'Both production token RPCs use this exact three-category contract',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        SharedPreferences.resetStatic();
        await _mountSettings(tester, language: language, push: push);
        for (final category in _supportedLabels.keys) {
          final row = _categoryRow(category, language);
          await _reachSettingsRow(tester, row);
          expect(tester.widget<CheckboxListTile>(row).value, isFalse);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );

    _settingsTestWidgets(
      'delivery quiet hours explicitly scope daily reminders $language 200%',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true);
        await _mountSettings(tester, language: language, push: push);
        final label = language == 'ar'
            ? 'ساعات الهدوء للتذكيرات اليومية'
            : 'Quiet hours for daily reminders';
        final row = find.widgetWithText(SwitchListTile, label);
        await _reachSettingsRow(tester, row);
        expect(tester.widget<SwitchListTile>(row).value, isFalse);
        await tester.tap(_toggleTarget(row));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final persisted = await NotificationDeliveryPreferencesStore().load();
        expect(persisted.quietHoursEnabled, isTrue);
        expect(persisted.isQuietAt(23, 0), isTrue);
        expect(persisted.isQuietAt(12, 0), isFalse);
        expect(
          push.syncCalls,
          0,
          reason:
              'Local reminder quiet hours must not issue cloud category writes',
        );
        expect(
          persisted.pushCategoryParameters.keys,
          unorderedEquals([
            'p_message_enabled',
            'p_friend_request_enabled',
            'p_friend_accepted_enabled',
          ]),
        );
        // Background community push has no server quiet-hours contract.
        // This host assertion intentionally claims only the local preference.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}

const _platformKey = 'flutter.${NotificationDeliveryPreferencesStore.key}';
const _unsupportedLabels = <NotificationCategory, (String, String)>{
  NotificationCategory.friendWorkout: (
    'One of my friends logs a workout',
    'عندما يسجل أحد أصدقائي تمرينًا',
  ),
  NotificationCategory.friendStreak: (
    'One of my friends hits a login streak',
    'عندما يحقق أحد أصدقائي سلسلة دخول',
  ),
  NotificationCategory.stepGoal: (
    'I reach my step goal',
    'عندما أصل إلى هدف الخطوات',
  ),
};
const _supportedLabels = <NotificationCategory, (String, String)>{
  NotificationCategory.newMessage: (
    'I receive a new message',
    'عندما أتلقى رسالة جديدة',
  ),
  NotificationCategory.friendRequest: (
    'I receive a new friend request',
    'عندما أتلقى طلب صداقة جديدًا',
  ),
  NotificationCategory.friendAccepted: (
    'Someone accepts my friend request',
    'عندما يقبل شخص طلب صداقتي',
  ),
};

Finder _categoryRow(NotificationCategory category, String language) {
  final labels = (_unsupportedLabels[category] ?? _supportedLabels[category])!;
  return find.widgetWithText(
    CheckboxListTile,
    language == 'ar' ? labels.$2 : labels.$1,
  );
}

Future<void> _reachSettingsRow(WidgetTester tester, Finder row) async {
  final scrollable = find.byWidgetPredicate(
    (widget) => widget is Scrollable && widget.axis == Axis.vertical,
  );
  expect(scrollable, findsOneWidget);
  final target = _toggleTarget(row);
  final initialPosition = tester.state<ScrollableState>(scrollable).position;
  // The 200% English content exceeds the former 60-gesture cap. Derive a
  // finite allowance from the actual scroll geometry; keep real gestures,
  // reachability, and hit testing, not controller jumps or raised app budgets.
  final gestureBudget =
      60 +
      ((initialPosition.maxScrollExtent + initialPosition.viewportDimension) /
              140)
          .ceil();
  for (var gesture = 0; gesture < gestureBudget; gesture++) {
    if (target.evaluate().isNotEmpty) {
      final position = tester.getRect(target);
      final viewport = tester.getRect(scrollable);
      if (viewport.contains(position.center) &&
          target.hitTestable().evaluate().length == 1) {
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        return;
      }
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.top + 40),
        Offset(0, position.center.dy < viewport.top ? 160 : -160),
      );
    } else {
      final viewport = tester.getRect(scrollable);
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.top + 40),
        const Offset(0, -160),
      );
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }
  fail(
    'Notification control not reachable with bounded real pointer drags: $row; '
    'offset=${tester.state<ScrollableState>(scrollable).position.pixels}; '
    'extent=${tester.state<ScrollableState>(scrollable).position.maxScrollExtent}; '
    'quiet=${find.byType(SwitchListTile).evaluate().map((element) => (element.widget as SwitchListTile).title).toList()}',
  );
}

Finder _toggleTarget(Finder row) {
  final control = find.descendant(
    of: row,
    matching: find.byWidgetPredicate(
      (widget) => widget is Switch || widget is Checkbox,
    ),
  );
  return control;
}

Future<void> _mountSettings(
  WidgetTester tester, {
  required String language,
  _HostNotificationGateway? gateway,
  CommunityPushService? push,
}) async {
  // An explicit iOS host rendering fixture avoids Android's grouped native
  // shade API. The fake gateway above never claims actual OS delivery.
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: BilFlagshipTheme.light(isArabic: language == 'ar'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: NotificationSettingsPage(
          notificationService: gateway ?? _HostNotificationGateway(),
          communityPushService: push,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void _settingsTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(
    description,
    callback,
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}

class _DeliveryPlatform extends InMemorySharedPreferencesStore {
  _DeliveryPlatform() : super.empty();
  bool rejectWrites = false;
  int deliveryWrites = 0;
  Future<void>? pendingWrite;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == _platformKey) {
      deliveryWrites++;
    }
    if (rejectWrites) {
      return Future.value(false);
    }
    if (key == _platformKey && pendingWrite != null) {
      return pendingWrite!.then((_) => super.setValue(valueType, key, value));
    }
    return super.setValue(valueType, key, value);
  }
}

_DeliveryPlatform _installPlatform() {
  final original = SharedPreferencesStorePlatform.instance;
  final platform = _DeliveryPlatform();
  SharedPreferences.resetStatic();
  SharedPreferencesStorePlatform.instance = platform;
  addTearDown(() {
    SharedPreferencesStorePlatform.instance = original;
    SharedPreferences.resetStatic();
  });
  return platform;
}

class _HostNotificationGateway extends BilNotificationService {
  _HostNotificationGateway({
    this.permission,
    this.permissionStateValue = BilNotificationPermissionState.granted,
  }) : super(FlutterLocalNotificationsPlugin());
  final Future<bool>? permission;
  final BilNotificationPermissionState permissionStateValue;
  int permissionRequests = 0;
  int activationNotifications = 0;
  final scheduled = <DailyReminderKind, bool>{};

  @override
  Future<bool> requestPermission() {
    permissionRequests++;
    return permission ?? Future.value(true);
  }

  @override
  Future<void> showActivationConfirmation({
    required String languageCode,
  }) async {
    activationNotifications++;
  }

  @override
  Future<BilNotificationPermissionState> permissionState() async =>
      permissionStateValue;

  @override
  Future<Set<int>> pendingNotificationIds() async => {};

  @override
  Future<void> schedule(
    DailyReminder reminder, {
    required String languageCode,
    NotificationDeliveryPreferences preferences =
        const NotificationDeliveryPreferences(),
  }) async {
    scheduled[reminder.kind] = reminder.enabled;
  }
}
