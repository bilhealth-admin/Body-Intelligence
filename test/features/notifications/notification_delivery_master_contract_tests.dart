part of 'notification_delivery_release_contract_test.dart';

void _addMasterContractTests() {
  for (final language in ['en', 'ar']) {
    _settingsTestWidgets(
      'delivery denied phone permission still allows saved cloud opt-out $language',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true);
        final gateway = _HostNotificationGateway(
          permissionStateValue: BilNotificationPermissionState.denied,
        );
        await _mountSettings(
          tester,
          language: language,
          gateway: gateway,
          push: push,
        );
        final cloud = find.byKey(const Key('community-cloud-push'));
        await _reachSettingsRow(tester, cloud);
        expect(
          tester.widget<SwitchListTile>(cloud).value,
          isTrue,
          reason:
              'Saved cloud opt-in is distinct from blocked phone delivery; '
              'the user must be able to turn the actual cloud master OFF',
        );
        final category = _categoryRow(
          NotificationCategory.newMessage,
          language,
        );
        await _reachSettingsRow(tester, category);
        expect(tester.widget<CheckboxListTile>(category).value, isFalse);
        expect(tester.widget<CheckboxListTile>(category).onChanged, isNull);
        await _reachSettingsRow(tester, cloud);
        await tester.tap(_toggleTarget(cloud));
        await tester.pumpAndSettle();
        expect(push.setCalls, 1);
        expect(push.enabled, isFalse);
        expect(tester.widget<SwitchListTile>(cloud).value, isFalse);
        expect(push.syncCalls, 0);
        expect(
          (await NotificationDeliveryPreferencesStore().load())
              .enabledCategories,
          NotificationDeliveryPreferences.supportedCategories,
          reason: 'Do not erase category choices when opting out of the master',
        );
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery explicit saved-category recovery verifies same-revision server state $language',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true)
          ..synchronized = false;
        await _mountSettings(tester, language: language, push: push);
        final category = _categoryRow(
          NotificationCategory.newMessage,
          language,
        );
        await _reachSettingsRow(tester, category);
        expect(tester.widget<CheckboxListTile>(category).value, isFalse);
        expect(tester.widget<CheckboxListTile>(category).onChanged, isNull);
        expect(
          push.syncCalls,
          0,
          reason: 'Readback must never silently write or opt in',
        );
        final recovery = find.byKey(
          const Key('apply-saved-notification-categories'),
        );
        await _reachSettingsAction(tester, recovery);
        expect(
          find.descendant(
            of: recovery,
            matching: find.text(
              language == 'ar'
                  ? 'تطبيق الفئات المحفوظة'
                  : 'Apply saved categories',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(recovery);
        await tester.pumpAndSettle();
        expect(push.syncCalls, 1);
        expect(
          push.revision,
          1,
          reason: 'An exact no-op desired snapshot retains its revision',
        );
        expect(push.synchronized, isTrue);
        await _reachSettingsRow(tester, category);
        expect(tester.widget<CheckboxListTile>(category).value, isTrue);
        expect(tester.widget<CheckboxListTile>(category).onChanged, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery saved-category recovery conflict refreshes without replay $language',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true)
          ..synchronized = false;
        await _mountSettings(tester, language: language, push: push);
        final recovery = find.byKey(
          const Key('apply-saved-notification-categories'),
        );
        await _reachSettingsAction(tester, recovery);
        push.revision++;
        push.desired.remove(NotificationCategory.friendRequest);
        await tester.tap(recovery);
        await tester.pumpAndSettle();
        expect(push.syncCalls, 1);
        expect(push.revision, 2);
        expect(
          push.desired.contains(NotificationCategory.friendRequest),
          isFalse,
        );
        expect(push.synchronized, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery failed daily persistence rolls back scheduled native state $language',
      (tester) async {
        final platform = _installPlatform();
        final gateway = _HostNotificationGateway();
        await DailyReminderStore().save(DailyReminderStore.defaults);
        await _mountSettings(tester, language: language, gateway: gateway);
        final master = find.byKey(const Key('all-daily-reminders'));
        await _reachSettingsRow(tester, master);
        platform.rejectWrites = true;
        await tester.tap(_toggleTarget(master));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(master).value, isFalse);
        expect(
          (await DailyReminderStore().load()).every((r) => !r.enabled),
          isTrue,
        );
        expect(
          gateway.scheduled.values.any((enabled) => enabled),
          isFalse,
          reason:
              'A failed storage rollback must not skip native scheduling rollback',
        );
        expect(gateway.activationNotifications, 0);
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery pending category keeps other controls stable and no page flash $language',
      (tester) async {
        final platform = _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true);
        await _mountSettings(tester, language: language, push: push);
        final row = _categoryRow(NotificationCategory.newMessage, language);
        await _reachSettingsRow(tester, row);
        final pending = Completer<void>();
        platform.pendingWrite = pending.future;
        final body = tester.renderObject(find.byType(ListView));
        final sibling = _categoryRow(
          NotificationCategory.friendRequest,
          language,
        );
        expect(tester.widget<CheckboxListTile>(sibling).enabled, isTrue);
        await tester.tap(_toggleTarget(row));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.widget<CheckboxListTile>(row).enabled, isFalse);
        expect(
          tester.widget<CheckboxListTile>(row).value,
          isTrue,
          reason:
              'No unverified optimistic cloud OFF before persistence/receipt',
        );
        expect(
          tester.widget<CheckboxListTile>(sibling).enabled,
          isTrue,
          reason: 'An unchanged category must not flash to its disabled colors',
        );
        expect(tester.widget<CheckboxListTile>(sibling).value, isTrue);
        expect(tester.renderObject(find.byType(ListView)), same(body));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(_toggleTarget(row));
        await tester.pump(const Duration(milliseconds: 50));
        expect(push.syncCalls, 0);
        pending.complete();
        await tester.pumpAndSettle();
        expect(push.syncCalls, 1);
        expect(tester.widget<CheckboxListTile>(row).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery stale device cannot replay over another category opt-out $language',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true);
        await _mountSettings(tester, language: language, push: push);
        final row = _categoryRow(NotificationCategory.newMessage, language);
        await _reachSettingsRow(tester, row);
        // Explicit other-device server fixture mutation, not a production write.
        push.revision++;
        push.desired.remove(NotificationCategory.friendRequest);
        await tester.tap(_toggleTarget(row));
        await tester.pumpAndSettle();
        expect(
          push.syncCalls,
          1,
          reason: 'Never automatically replay stale desired flags',
        );
        expect(
          tester.widget<CheckboxListTile>(row).value,
          isTrue,
          reason:
              'Show authoritative unchanged message state, not attempted OFF',
        );
        final friend = _categoryRow(
          NotificationCategory.friendRequest,
          language,
        );
        await _reachSettingsRow(tester, friend);
        expect(tester.widget<CheckboxListTile>(friend).value, isFalse);
        expect(
          push.desired.contains(NotificationCategory.friendRequest),
          isFalse,
        );
        expect(push.revision, 2);
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery distinct masters retain category selections $language',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true);
        await _mountSettings(tester, language: language, push: push);
        final cloud = find.byKey(const Key('community-cloud-push'));
        final pageBody = tester.renderObject(find.byType(ListView));
        await _reachSettingsRow(tester, cloud);
        expect(tester.widget<SwitchListTile>(cloud).value, isTrue);
        await tester.tap(_toggleTarget(cloud));
        await tester.pumpAndSettle();
        expect(push.setCalls, 1);
        expect(tester.widget<SwitchListTile>(cloud).value, isFalse);
        for (final category in _supportedLabels.keys) {
          final row = _categoryRow(category, language);
          await _reachSettingsRow(tester, row);
          expect(tester.widget<CheckboxListTile>(row).value, isFalse);
          expect(tester.widget<CheckboxListTile>(row).onChanged, isNull);
          expect(
            (await NotificationDeliveryPreferencesStore().load()).allows(
              category,
            ),
            isTrue,
          );
          expect(
            find.ancestor(
              of: row,
              matching: find.byKey(
                const Key('community-notification-settings'),
              ),
            ),
            findsOneWidget,
          );
        }
        await _reachSettingsRow(tester, cloud);
        await tester.tap(_toggleTarget(cloud));
        await tester.pumpAndSettle();
        for (final category in _supportedLabels.keys) {
          final row = _categoryRow(category, language);
          await _reachSettingsRow(tester, row);
          expect(tester.widget<CheckboxListTile>(row).value, isTrue);
        }
        final daily = find.byKey(const Key('all-daily-reminders'));
        await _reachSettingsRow(tester, daily);
        expect(tester.widget<SwitchListTile>(daily).value, isFalse);
        await tester.tap(_toggleTarget(daily));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(daily).value, isTrue);
        await tester.tap(_toggleTarget(daily));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(daily).value, isFalse);
        expect(
          push.setCalls,
          2,
          reason: 'Daily changes must not change cloud consent',
        );
        expect(
          push.syncCalls,
          0,
          reason: 'Daily changes must not issue cloud-category writes',
        );
        expect(tester.renderObject(find.byType(ListView)), same(pageBody));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        SharedPreferences.resetStatic();
        expect(
          (await NotificationDeliveryPreferencesStore().load())
              .enabledCategories,
          NotificationDeliveryPreferences.supportedCategories,
        );
      },
    );

    for (final failure in ['provider', 'permission', 'load']) {
      _settingsTestWidgets(
        'delivery inactive $failure cannot claim category delivery $language',
        (tester) async {
          _installPlatform();
          final push = _HostCommunityPushGateway(
            enabled: true,
            providerReady: failure != 'provider',
          );
          push.throwLoad = failure == 'load';
          final gateway = _HostNotificationGateway(
            permissionStateValue: failure == 'permission'
                ? BilNotificationPermissionState.denied
                : BilNotificationPermissionState.granted,
          );
          await _mountSettings(
            tester,
            language: language,
            gateway: gateway,
            push: push,
          );
          final row = _categoryRow(NotificationCategory.newMessage, language);
          await _reachSettingsRow(tester, row);
          expect(tester.widget<CheckboxListTile>(row).value, isFalse);
          expect(tester.widget<CheckboxListTile>(row).onChanged, isNull);
          final writesBefore = push.syncCalls;
          await tester.tap(_toggleTarget(row));
          await tester.pumpAndSettle();
          expect(push.syncCalls, writesBefore);
          expect(
            (await NotificationDeliveryPreferencesStore().load()).allows(
              NotificationCategory.newMessage,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    _settingsTestWidgets(
      'delivery cloud double tap is single flight and failed readback stays inactive $language',
      (tester) async {
        _installPlatform();
        final completed = Completer<void>();
        final push = _HostCommunityPushGateway(enabled: true);
        await _mountSettings(tester, language: language, push: push);
        final cloud = find.byKey(const Key('community-cloud-push'));
        await _reachSettingsRow(tester, cloud);
        final body = tester.renderObject(find.byType(ListView));
        push.pendingSet = completed.future;
        push.throwLoad = true;
        await tester.tap(_toggleTarget(cloud));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(_toggleTarget(cloud));
        await tester.pump(const Duration(milliseconds: 50));
        expect(push.setCalls, 1);
        expect(tester.renderObject(find.byType(ListView)), same(body));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        completed.complete();
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(cloud).value, isFalse);
        expect(tester.widget<SwitchListTile>(cloud).onChanged, isNull);
        final row = _categoryRow(NotificationCategory.newMessage, language);
        await _reachSettingsRow(tester, row);
        expect(tester.widget<CheckboxListTile>(row).value, isFalse);
        expect(tester.widget<CheckboxListTile>(row).onChanged, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    _settingsTestWidgets(
      'delivery failed cloud category sync never claims active update $language',
      (tester) async {
        _installPlatform();
        final push = _HostCommunityPushGateway(enabled: true)..throwSync = true;
        await _mountSettings(tester, language: language, push: push);
        final row = _categoryRow(NotificationCategory.newMessage, language);
        await _reachSettingsRow(tester, row);
        final body = tester.renderObject(find.byType(ListView));
        expect(tester.widget<CheckboxListTile>(row).value, isTrue);
        await tester.tap(_toggleTarget(row));
        await tester.pumpAndSettle();
        expect(push.syncCalls, 1);
        expect(push.categoryParameters.single['p_message_enabled'], isFalse);
        expect(tester.widget<CheckboxListTile>(row).value, isFalse);
        expect(tester.widget<CheckboxListTile>(row).onChanged, isNull);
        expect(tester.renderObject(find.byType(ListView)), same(body));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          (await NotificationDeliveryPreferencesStore().load()).allows(
            NotificationCategory.newMessage,
          ),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _reachSettingsAction(WidgetTester tester, Finder target) async {
  final scrollable = find.byWidgetPredicate(
    (widget) => widget is Scrollable && widget.axis == Axis.vertical,
  );
  for (var gesture = 0; gesture < 60; gesture++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target);
      final viewport = tester.getRect(scrollable);
      if (viewport.contains(rect.center) &&
          target.hitTestable().evaluate().length == 1) {
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.width, greaterThanOrEqualTo(48));
        return;
      }
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.top + 40),
        Offset(0, rect.center.dy < viewport.top ? 160 : -160),
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
  fail('Recovery action not reachable through bounded actual pointer drags');
}
