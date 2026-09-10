import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/admin/presentation/ai_coach_admin_page.dart';
import 'package:body_intelligence_log/features/admin/services/admin_subscription_service.dart';
import 'package:body_intelligence_log/features/admin/services/ai_coach_admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '00000000-0000-4000-8000-000000000002';

void main() {
  testWidgets(
    'three uncluttered tabs lead to separate functions and preserve the selected tab on back',
    (tester) async {
      await _pump(tester, _Gateway());
      expect(find.byType(Tab), findsNWidgets(3));
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byKey(const Key('admin-action-global')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('admin-ai-coach-global-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-ai-coach-individual-email')),
        findsNothing,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-tab-community')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-action-moderators')), findsOneWidget);
      expect(find.byKey(const Key('admin-action-approvals')), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await _freeTab(tester);
      await tester.tap(find.byKey(const Key('admin-action-ai')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-subscription-email')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-action-ai')), findsOneWidget);
    },
  );
  testWidgets(
    'grant validates the email and requires exact plan/duration confirmation',
    (tester) async {
      final gateway = _Gateway();
      await _pump(tester, gateway);
      await _open(tester, 'ai');
      await tester.tap(find.byKey(const Key('admin-subscription-grant')));
      await tester.pumpAndSettle();
      expect(gateway.grants, isEmpty);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('admin-subscription-email')),
        ' USER@Example.COM ',
      );
      await tester.tap(find.byKey(const Key('admin-subscription-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Until revoked by an admin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-subscription-grant')));
      await tester.pumpAndSettle();
      expect(find.text('user@example.com'), findsOneWidget);
      expect(gateway.grants, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(gateway.grants, isEmpty);
      await _confirm(tester);
      expect(gateway.grants.single['email'], 'user@example.com');
      expect(gateway.grants.single['plan'], 'premium_ai_coach');
      expect(gateway.grants.single['days'], isNull);
      expect(find.text('Subscription granted.'), findsOneWidget);
    },
  );
  testWidgets(
    'ordinary Premium grants are distinct and an absent account is not reported as success',
    (tester) async {
      final gateway = _Gateway()..matched = false;
      await _pump(tester, gateway);
      await _open(tester, 'premium');
      await tester.enterText(
        find.byKey(const Key('admin-subscription-email')),
        'missing@example.com',
      );
      await _confirm(tester);
      expect(gateway.grants.single['plan'], 'premium');
      expect(gateway.grants.single['days'], 30);
      expect(
        find.text('No registered account matches this email.'),
        findsOneWidget,
      );
      expect(find.text('Subscription granted.'), findsNothing);
    },
  );
  testWidgets(
    'uncertain request retry retains idempotency while changed inputs receive a new key',
    (tester) async {
      final gateway = _Gateway()..fail = true;
      await _pump(tester, gateway);
      await _open(tester, 'premium');
      await tester.enterText(
        find.byKey(const Key('admin-subscription-email')),
        'user@example.com',
      );
      await _confirm(tester);
      await _confirm(tester);
      expect(gateway.grants[0]['key'], gateway.grants[1]['key']);
      await tester.enterText(
        find.byKey(const Key('admin-subscription-email')),
        'another@example.com',
      );
      await _confirm(tester);
      expect(gateway.grants[2]['key'], isNot(gateway.grants[0]['key']));
    },
  );
  testWidgets(
    'list shows real statuses and one press revokes only the selected grant',
    (tester) async {
      final gateway = _Gateway();
      await _pump(tester, gateway);
      await _open(tester, 'list');
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.byKey(const Key('admin-revoke-$_id')), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-revoke-$_id')));
      await tester.pumpAndSettle();
      expect(gateway.revokes, [_id]);
      expect(find.byKey(const Key('admin-revoke-$_id')), findsNothing);
      expect(find.textContaining('Revoked'), findsOneWidget);
    },
  );
  testWidgets('ordinary accounts see no administrative functions', (
    tester,
  ) async {
    await _pump(tester, _Gateway(), allowed: false);
    expect(
      find.byKey(const Key('admin-ai-coach-access-denied')),
      findsOneWidget,
    );
    expect(find.byType(Tab), findsNothing);
  });
  for (final locale in ['en', 'ar', 'fr', 'es', 'tr']) {
    testWidgets(
      '$locale compact screen and 160 percent text keep buttons usable',
      (tester) async {
        await _pump(tester, _Gateway(), locale: locale, width: 390, scale: 1.6);
        await _freeTab(tester);
        await tester.tap(find.byKey(const Key('admin-action-premium')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('admin-subscription-grant')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // pageBack() searches the English "Back" tooltip. Assert and press
        // the real Material back button in every supported test locale.
        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('admin-action-list')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('admin-revoke-$_id')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'malformed list and mutation payloads fail closed rather than becoming empty/success',
    () {
      for (final bad in [
        null,
        {},
        {'rows': [], 'has_more': 'false'},
        {
          'rows': [{}],
          'has_more': false,
        },
      ]) {
        expect(
          () => AdminSubscriptionPageResult.fromJson(bad),
          throwsFormatException,
        );
      }
      expect(
        () => AdminSubscriptionReceipt.fromJson({
          'matched': false,
          'changed': true,
        }),
        throwsFormatException,
      );
    },
  );
}

Future<void> _freeTab(WidgetTester tester) async {
  final tab = find.byKey(const Key('admin-tab-free'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String action) async {
  await _freeTab(tester);
  await tester.tap(find.byKey(Key('admin-action-$action')));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  final grant = find.byKey(const Key('admin-subscription-grant'));
  await tester.ensureVisible(grant);
  await tester.tap(grant);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('admin-subscription-confirm')));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  _Gateway gateway, {
  bool allowed = true,
  String locale = 'en',
  double width = 600,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiCoachAdminAccessProvider.overrideWith((_) async => allowed),
        aiCoachAdminSessionProvider.overrideWith((_) => Stream.value('admin')),
        adminSubscriptionGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AiCoachAdminPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Gateway implements AdminSubscriptionGateway {
  final grants = <Map<String, Object?>>[];
  final revokes = <String>[];
  bool matched = true, fail = false;
  @override
  Future<AdminSubscriptionReceipt> grant({
    required String email,
    required String planId,
    required int? durationDays,
    required String reason,
    required String idempotencyKey,
  }) async {
    grants.add({
      'email': email,
      'plan': planId,
      'days': durationDays,
      'key': idempotencyKey,
    });
    if (fail) throw TimeoutException('uncertain');
    return AdminSubscriptionReceipt(matched: matched, changed: matched);
  }

  @override
  Future<AdminSubscriptionReceipt> revoke({
    required String grantId,
    required String idempotencyKey,
  }) async {
    revokes.add(grantId);
    return const AdminSubscriptionReceipt(matched: true, changed: true);
  }

  @override
  Future<AdminSubscriptionPageResult> list(int offset) async =>
      AdminSubscriptionPageResult([
        AdminSubscriptionEntry(
          id: _id,
          email: 'user@example.com',
          planId: 'premium_ai_coach',
          createdAt: DateTime.utc(2026, 9, 10),
          expiresAt: null,
          status: revokes.contains(_id) ? 'revoked' : 'active',
        ),
      ], false);
}
