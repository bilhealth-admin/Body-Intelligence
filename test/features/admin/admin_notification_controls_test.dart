import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_admin_notifications.dart';
import 'package:body_intelligence_log/features/admin/presentation/ai_coach_admin_page.dart';
import 'package:body_intelligence_log/features/admin/services/ai_coach_admin_service.dart';
import 'package:body_intelligence_log/features/notifications/presentation/ai_coach_reset_notice_coordinator.dart';
import 'package:body_intelligence_log/features/notifications/services/ai_coach_reset_notice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin notification copy is complete across all 25 locales', () {
    expect(AdminNotificationRuntimeCopy.supported, hasLength(25));
    expect(AdminNotificationRuntimeCopy.balanced, isTrue);
    expect(AdminNotificationRuntimeCopy.values, hasLength(26));
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = locale.toLanguageTag();
      for (final entry in AdminNotificationRuntimeCopy.values.entries) {
        final localized = AdminNotificationRuntimeCopy.resolve(entry.key, tag);
        expect(localized.trim(), isNotEmpty, reason: '$tag: ${entry.key}');
        if (locale.languageCode != 'en') {
          expect(localized, isNot(entry.key), reason: '$tag: ${entry.key}');
        }
      }
    }
  });

  test('every authored admin notification string is in the 25-locale map', () {
    final source = File(
      'lib/features/admin/presentation/admin_notification_controls.dart',
    ).readAsStringSync();
    final authored = RegExp(
      r"_copy\(\s*'((?:\\.|[^'])*)',\s*ar:\s*'((?:\\.|[^'])*)',\s*fr:\s*'((?:\\.|[^'])*)',\s*es:\s*'((?:\\.|[^'])*)',\s*tr:\s*'((?:\\.|[^'])*)',\s*\)",
      dotAll: true,
    ).allMatches(source).map((match) => match.group(1)!).toSet();
    expect(authored, isNotEmpty);
    expect(authored, AdminNotificationRuntimeCopy.values.keys.toSet());
  });

  testWidgets('non-admin cannot discover notification controls', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: false);
    await _pumpAdmin(tester, gateway, allowed: false);
    expect(find.byKey(const Key('admin-notification-controls')), findsNothing);
    expect(
      find.byKey(const Key('admin-notification-compensation')),
      findsNothing,
    );
    expect(gateway.sendCalls, 0);
  });

  testWidgets('targeted compensation validates, confirms, and sends once', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: true);
    await _pumpAdmin(tester, gateway, allowed: true);
    final action = find.byKey(const Key('admin-notification-compensation'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Specific email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-notification-email')),
      ' Person@Example.COM ',
    );
    await tester.tap(find.byKey(const Key('admin-notification-review')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('admin-notification-confirmation')),
      findsOneWidget,
    );
    expect(find.text('person@example.com'), findsOneWidget);
    expect(gateway.sendCalls, 0);

    await tester.tap(find.byKey(const Key('admin-notification-confirm-send')));
    await tester.pumpAndSettle();
    expect(gateway.sendCalls, 1);
    expect(gateway.lastKind, AiCoachAdminNotificationKind.compensation);
    expect(gateway.lastAudience, AiCoachAdminNotificationAudience.email);
    expect(gateway.lastEmail, 'person@example.com');
    expect(gateway.lastMessage, isNull);
    expect(gateway.lastIdempotencyKey, startsWith('notification:'));
  });

  testWidgets('custom notification requires text and strips controls', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: true);
    await _pumpAdmin(tester, gateway, allowed: true);
    final action = find.byKey(const Key('admin-notification-custom'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    final review = find.byKey(const Key('admin-notification-review'));
    expect(tester.widget<FilledButton>(review).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('admin-notification-custom-message')),
      'A careful\n\tmessage',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(review).onPressed, isNotNull);

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('admin-notification-custom-message')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.controller.text, 'A carefulmessage');

    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-notification-confirmation')),
      findsOneWidget,
    );
    expect(find.text('Everyone'), findsWidgets);
    expect(gateway.sendCalls, 0);

    await tester.tap(find.byKey(const Key('admin-notification-confirm-send')));
    await tester.pumpAndSettle();
    expect(gateway.sendCalls, 1);
    expect(gateway.lastKind, AiCoachAdminNotificationKind.custom);
    expect(gateway.lastAudience, AiCoachAdminNotificationAudience.all);
    expect(gateway.lastEmail, isNull);
    expect(gateway.lastMessage, 'A carefulmessage');
  });

  testWidgets('unknown targeted account reports that nothing was sent', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: true, matched: false);
    await _pumpAdmin(tester, gateway, allowed: true);
    final action = find.byKey(const Key('admin-notification-gift'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Specific email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-notification-email')),
      'missing@example.com',
    );
    await tester.tap(find.byKey(const Key('admin-notification-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-notification-confirm-send')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-notification-no-match')),
      findsOneWidget,
    );
  });

  testWidgets('durable custom notice renders exact body and acknowledges', (
    tester,
  ) async {
    const body = 'Important custom notice — exactly as authored.';
    final resetGateway = _FakeResetNoticeGateway();
    final adminNoticeGateway = _FakeBilAdminNoticeGateway(body: body);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiCoachResetNoticeGatewayProvider.overrideWithValue(resetGateway),
          bilAdminNoticeGatewayProvider.overrideWithValue(adminNoticeGateway),
        ],
        child: _localizedApp(
          home: const AiCoachResetNoticeCoordinator(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bil-admin-root-notice')), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    expect(find.text('BIL'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bil-admin-root-notice-dismiss')));
    await tester.pumpAndSettle();
    expect(adminNoticeGateway.dismissCalls, 1);
    expect(find.byKey(const Key('bil-admin-root-notice')), findsNothing);
  });

  test('notification result rejects malformed server payloads', () {
    expect(
      () => AiCoachAdminNotificationResult.fromJson({
        'matched': true,
        'duplicate': false,
        'recipients_enqueued': -1,
      }),
      throwsFormatException,
    );
  });
}

Future<void> _pumpAdmin(
  WidgetTester tester,
  _FakeAdminGateway gateway, {
  required bool allowed,
}) async {
  tester.view.physicalSize = const Size(500, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiCoachAdminGatewayProvider.overrideWithValue(gateway),
        aiCoachAdminAccessProvider.overrideWith((_) async => allowed),
      ],
      child: _localizedApp(home: const AiCoachAdminPage()),
    ),
  );
  await tester.pumpAndSettle();
}

MaterialApp _localizedApp({required Widget home}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

final class _FakeAdminGateway implements AiCoachAdminGateway {
  _FakeAdminGateway({required this.allowed, this.matched = true});

  final bool allowed;
  final bool matched;
  int sendCalls = 0;
  AiCoachAdminNotificationKind? lastKind;
  AiCoachAdminNotificationAudience? lastAudience;
  String? lastEmail;
  String? lastMessage;
  String? lastIdempotencyKey;

  @override
  Future<bool> canManageAiCoach() async => allowed;

  @override
  Stream<String?> watchSignedInUserId() =>
      Stream.value(allowed ? 'admin-1' : 'ordinary-1');

  @override
  Future<AiCoachGlobalResetResult> globalReset(String idempotencyKey) {
    throw UnimplementedError();
  }

  @override
  Future<bool> individualReset({
    required String email,
    required String reason,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AiCoachAdminNotificationResult> sendNotification({
    required AiCoachAdminNotificationKind kind,
    required AiCoachAdminNotificationAudience audience,
    String? email,
    String? message,
    required String idempotencyKey,
  }) async {
    sendCalls += 1;
    lastKind = kind;
    lastAudience = audience;
    lastEmail = email;
    lastMessage = message;
    lastIdempotencyKey = idempotencyKey;
    return AiCoachAdminNotificationResult(
      matched: matched,
      duplicate: false,
      recipientsEnqueued: matched ? 1 : 0,
    );
  }
}

final class _FakeResetNoticeGateway implements AiCoachResetNoticeGateway {
  @override
  Future<void> dismiss(AiCoachResetNotice notice) async {}

  @override
  Future<AiCoachResetNotice?> newestUnseen() async => null;

  @override
  Stream<String?> watchSignedInUserId() => Stream.value('owner-1');
}

final class _FakeBilAdminNoticeGateway implements BilAdminNoticeGateway {
  _FakeBilAdminNoticeGateway({required this.body});

  final String body;
  bool dismissed = false;
  int dismissCalls = 0;

  @override
  Future<BilAdminNotice?> newestUnseen() async => dismissed
      ? null
      : BilAdminNotice(
          ownerId: 'owner-1',
          notificationId: '00000000-0000-4000-8000-000000000040',
          kind: BilAdminNoticeKind.custom,
          title: 'BIL',
          body: body,
          createdAt: DateTime.utc(2026, 8, 31),
        );

  @override
  Future<void> dismiss(BilAdminNotice notice) async {
    dismissCalls += 1;
    dismissed = true;
  }
}
