import 'dart:io';
import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_ai_access.dart';
import 'package:body_intelligence_log/features/admin/presentation/ai_coach_admin_page.dart';
import 'package:body_intelligence_log/features/admin/services/ai_coach_admin_service.dart';
import 'package:body_intelligence_log/features/notifications/presentation/ai_coach_reset_notice_coordinator.dart';
import 'package:body_intelligence_log/features/notifications/services/ai_coach_reset_notice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _gift =
    'A gift from BIL 🎁 Your AI Coach usage has been fully reset. You can use your allowance again until the end of your current cycle.';

void main() {
  test('reset gift copy is complete for all 25 production locales', () {
    expect(AiAccessRuntimeCopy.supported, hasLength(25));
    expect(AiAccessRuntimeCopy.balanced, isTrue);
    for (final locale in AiAccessRuntimeCopy.supported) {
      final value = AiAccessRuntimeCopy.resolve(_gift, locale);
      expect(value, isNotNull, reason: locale);
      expect(value!.trim(), isNotEmpty, reason: locale);
      if (locale != 'en') expect(value, isNot(_gift), reason: locale);
    }
    expect(
      AiAccessRuntimeCopy.resolve(_gift, 'ar'),
      'هدية من BIL 🎁 تمت إعادة ضبط استخدام AI Coach بالكامل، ويمكنك الاستفادة من حصتك مجددًا حتى نهاية دورتك الحالية.',
    );
  });

  testWidgets('ordinary account cannot discover the admin deep link', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: false);
    await _pumpAdmin(tester, gateway: gateway, allowed: false);

    expect(
      find.byKey(const Key('admin-ai-coach-access-denied')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('admin-ai-coach-global-reset')), findsNothing);
    expect(
      find.byKey(const Key('admin-ai-coach-individual-reset')),
      findsNothing,
    );
    expect(gateway.globalResetCalls, 0);
    expect(gateway.individualResetCalls, 0);
  });

  testWidgets('global reset requires confirmation before one mutation', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: true);
    await _pumpAdmin(tester, gateway: gateway, allowed: true);

    await tester.tap(find.byKey(const Key('admin-ai-coach-global-reset')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-ai-coach-reset-confirmation')),
      findsOneWidget,
    );
    expect(gateway.globalResetCalls, 0);

    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
    expect(gateway.globalResetCalls, 0);

    await tester.tap(find.byKey(const Key('admin-ai-coach-global-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-ai-coach-reset-confirm')));
    await tester.pump();

    expect(gateway.globalResetCalls, 1);
    expect(gateway.lastGlobalIdempotencyKey, startsWith('admin:'));
  });

  testWidgets('individual reset validates and requires confirmation', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: true);
    await _pumpAdmin(tester, gateway: gateway, allowed: true);
    final button = find.byKey(const Key('admin-ai-coach-individual-reset'));
    await tester.ensureVisible(button);
    await tester.enterText(
      find.byKey(const Key('admin-ai-coach-individual-email')),
      ' Person@Example.COM ',
    );
    await tester.enterText(
      find.byKey(const Key('admin-ai-coach-individual-reason')),
      'compensation',
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-ai-coach-individual-reset-confirmation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('admin-ai-coach-individual-confirm-email')),
      findsOneWidget,
    );
    expect(find.text('person@example.com'), findsOneWidget);
    expect(gateway.individualResetCalls, 0);

    await tester.tap(
      find.byKey(const Key('admin-ai-coach-individual-reset-confirm')),
    );
    await tester.pump();
    expect(gateway.individualResetCalls, 1);
    expect(gateway.lastEmail, 'person@example.com');
    expect(gateway.lastReason, 'compensation');
    expect(gateway.lastIndividualIdempotencyKey, startsWith('individual:'));
  });

  testWidgets('individual no-match gives admin a clear no-change result', (
    tester,
  ) async {
    final gateway = _FakeAdminGateway(allowed: true, individualMatched: false);
    await _pumpAdmin(tester, gateway: gateway, allowed: true);
    await tester.enterText(
      find.byKey(const Key('admin-ai-coach-individual-email')),
      'missing@example.com',
    );
    final button = find.byKey(const Key('admin-ai-coach-individual-reset'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('admin-ai-coach-individual-reset-confirm')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('admin-ai-coach-individual-reset-no-match')),
      findsOneWidget,
    );
    expect(find.text('missing@example.com'), findsWidgets);
  });

  testWidgets('root notice loads after sign-in and dismisses exactly once', (
    tester,
  ) async {
    final gateway = _FakeNoticeGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiCoachResetNoticeGatewayProvider.overrideWithValue(gateway),
        ],
        child: _localizedApp(
          home: const AiCoachResetNoticeCoordinator(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-coach-reset-root-notice')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('ai-coach-reset-root-notice-dismiss')),
    );
    await tester.pumpAndSettle();
    expect(gateway.dismissCalls, 1);
    expect(gateway.dismissedResetId, _FakeNoticeGateway.resetId);
    expect(find.byKey(const Key('ai-coach-reset-root-notice')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-coach-reset-root-notice')), findsNothing);
  });

  testWidgets('account switch cannot surface or dismiss the previous notice', (
    tester,
  ) async {
    final gateway = _SwitchingNoticeGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiCoachResetNoticeGatewayProvider.overrideWithValue(gateway),
        ],
        child: _localizedApp(
          home: const AiCoachResetNoticeCoordinator(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(gateway.hasListener, isTrue);

    gateway.emit('owner-a');
    await tester.pump();
    gateway.emit('owner-b');
    await tester.pump();
    expect(gateway.deliveredOwners, ['owner-a', 'owner-b']);
    expect(gateway.requests, 1);

    await tester.runAsync(() async {
      gateway.complete(
        0,
        const AiCoachResetNotice(ownerId: 'owner-a', resetId: 'reset-shared'),
      );
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(gateway.requests, 2);
    expect(find.byKey(const Key('ai-coach-reset-root-notice')), findsNothing);

    gateway.complete(
      1,
      const AiCoachResetNotice(ownerId: 'owner-b', resetId: 'reset-shared'),
    );
    await tester.pump();
    expect(find.byKey(const Key('ai-coach-reset-root-notice')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('ai-coach-reset-root-notice-dismiss')),
    );
    await tester.pump();
    expect(gateway.dismissedOwnerId, 'owner-b');

    gateway.emit('owner-c');
    await tester.pump();
    expect(gateway.requests, 3);
    gateway.emit(null);
    await tester.pump();
    await tester.runAsync(() async {
      gateway.complete(
        2,
        const AiCoachResetNotice(ownerId: 'owner-c', resetId: 'reset-c'),
      );
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(find.byKey(const Key('ai-coach-reset-root-notice')), findsNothing);
    await gateway.close();
  });

  test('admin visibility is recomputed and hidden on account switch', () async {
    final gateway = _SwitchingAdminGateway();
    final container = ProviderContainer(
      overrides: [aiCoachAdminGatewayProvider.overrideWithValue(gateway)],
    );
    final subscription = container.listen(
      aiCoachAdminAccessProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await gateway.close();
    });

    gateway.emit('admin-owner', allowed: true);
    await pumpEventQueue(times: 5);
    expect(container.read(aiCoachAdminAccessProvider).asData?.value, isTrue);

    gateway.emit('ordinary-owner', allowed: false);
    await pumpEventQueue(times: 5);
    expect(container.read(aiCoachAdminAccessProvider).asData?.value, isFalse);
    expect(gateway.permissionChecks, greaterThanOrEqualTo(2));
  });

  test('migration is atomic, idempotent, audited, and service-only', () {
    final sql = _migration();
    expect(sql, startsWith('begin;'));
    expect(sql.trimRight(), endsWith('commit;'));
    expect(sql, contains('private.bil_ai_coach_admins'));
    expect(sql, contains('private.bil_ai_coach_global_reset_audit'));
    expect(sql, contains('private.bil_ai_coach_individual_reset_audit'));
    expect(sql, contains('public.bil_can_manage_ai_coach()'));
    expect(sql, contains("<> 'service_role'"));
    expect(sql, contains('idempotency_key text not null unique'));
    expect(sql, contains('on conflict (idempotency_key) do nothing'));
    expect(
      sql,
      contains(
        'public.bil_individual_reset_ai_coach(uuid, uuid, text, text)\n  to service_role;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.bil_global_reset_ai_coach(uuid, text)\n  from public, anon, authenticated;',
      ),
    );
    expect(sql, isNot(contains('insert into private.bil_ai_coach_admins')));
  });

  test('audit survives actor and target account deletion', () {
    final sql = _migration();
    expect(
      RegExp(
        r'actor_id uuid references auth\.users\(id\) on delete set null',
      ).allMatches(sql),
      hasLength(2),
    );
    expect(
      sql,
      contains('target_id uuid references auth.users(id) on delete set null'),
    );
    expect(sql, isNot(contains('actor_id uuid not null references')));
    expect(sql, isNot(contains('on delete restrict')));
  });

  test('global and individual reset used only in current week and month', () {
    final sql = _migration();
    final global = _function(sql, 'bil_global_reset_ai_coach', 'bil_resolve');
    final individual = _function(
      sql,
      'bil_individual_reset_ai_coach',
      'revoke all on function public.bil_global_reset_ai_coach',
    );

    for (final mutation in [global, individual]) {
      expect(mutation, contains('update public.bil_ai_credit_weekly_usage u'));
      expect(mutation, contains('update public.bil_ai_credit_monthly_usage u'));
      expect(mutation, contains('update public.bil_ai_weekly_usage u'));
      expect(mutation, contains('set used = 0,'));
      expect(mutation, isNot(contains('reserved = 0')));
      expect(mutation, isNot(contains('set week_start')));
      expect(mutation, isNot(contains('set month_start')));
      expect(mutation, isNot(contains('update public.bil_subscriptions')));
      expect(mutation, isNot(contains('update public.bil_entitlements')));
      expect(mutation, isNot(contains('update public.bil_ai_credit_config')));
      expect(mutation, isNot(contains('update public.bil_ai_credit_balances')));
      const counterLock =
          'lock table public.bil_ai_credit_monthly_usage, public.bil_ai_credit_weekly_usage, public.bil_ai_weekly_usage in share row exclusive mode nowait;';
      expect(mutation, contains(counterLock));
      expect(
        mutation.indexOf(counterLock),
        lessThan(
          mutation.indexOf('update public.bil_ai_credit_monthly_usage u'),
        ),
      );
      expect(
        mutation.indexOf(counterLock),
        greaterThan(mutation.indexOf('returning reset_id into v_reset_id')),
      );
      expect(
        mutation.indexOf('update public.bil_ai_credit_monthly_usage u'),
        lessThan(
          mutation.indexOf('update public.bil_ai_credit_weekly_usage u'),
        ),
      );
    }
    expect(individual, contains('where u.owner_id = p_target_id'));
    expect(global, isNot(contains('where u.owner_id = p_target_id')));
    expect(sql, contains("'monthly_rows_reset'"));
  });

  test('live plan authority preserves trial and closed-test boundaries', () {
    final sql = _migration();
    final weekHelper = _function(
      sql,
      'bil_current_ai_week_start',
      'bil_current_ai_month_start',
    );
    final monthHelper = _function(
      sql,
      'bil_current_ai_month_start',
      'bil_ai_coach_reset_notification_body',
    );
    for (final helper in [weekHelper, monthHelper]) {
      expect(helper, contains('public.bil_resolve_ai_allowance_plan'));
      expect(helper, contains("if v_plan = 'trial' then"));
      expect(helper, contains('public.bil_resolve_ai_trial_anchor'));
      expect(helper, contains("raise exception 'ai_trial_anchor_missing'"));
    }
    expect(weekHelper, contains("date_trunc('week'"));
    expect(monthHelper, contains("date_trunc('month'"));
  });

  test('monthly trigger allows decreases while preserving reservations', () {
    final trigger = _function(
      _migration(),
      'bil_sync_ai_monthly_usage',
      'bil_global_reset_ai_coach',
    );
    expect(trigger, contains('if v_used_delta + v_reserved_delta > 0'));
    expect(trigger, contains('v_total > v_limit'));
    expect(
      trigger,
      contains('reserved = greatest(reserved + v_reserved_delta'),
    );
  });

  test('notice is own-row RLS, DB-time dismissed, and delivered once', () {
    final sql = _migration();
    expect(sql, contains('owner_id = (select auth.uid())'));
    expect(sql, contains('public.bil_dismiss_ai_coach_reset_notice'));
    expect(sql, contains('set seen_at = now()'));
    expect(sql, contains('n.owner_id = v_owner_id'));
    expect(sql, contains('primary key (owner_id, reset_id)'));
    expect(sql, contains('bil_push_outbox_recipient_source_uidx'));
    expect(sql, contains("'ai_coach_reset_gift_v1'"));
    expect(sql, contains("'bil://settings/ai-coach'"));

    final service = File(
      'lib/features/notifications/services/ai_coach_reset_notice_service.dart',
    ).readAsStringSync();
    expect(service, contains(".eq('owner_id', ownerId)"));
    expect(service, contains("'bil_dismiss_ai_coach_reset_notice'"));
    expect(service, isNot(contains('DateTime.now')));
    final settings = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
    ).readAsStringSync();
    expect(settings, contains("'p_owner_id': ownerId"));
    expect(settings, contains("'p_reset_id': resetId"));
  });

  test('AI Coach push keeps gift copy while other previews stay private', () {
    for (final path in [
      'supabase/functions/community-push-dispatch/index.ts',
      'supabase/functions/community_push_dispatch.ts',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains("event.category === 'ai_coach'"), reason: path);
      expect(
        source,
        contains("'You have a new private update.'"),
        reason: path,
      );
    }
  });

  test('trial allowance resets then locks at production 1000 limit', () {
    const before = _QuotaState(
      plan: 'trial',
      weekStart: '2026-08-31',
      monthStart: '2026-08-31',
      weeklyLimit: 1000,
      monthlyLimit: 1000,
      weeklyUsed: 1000,
      monthlyUsed: 1000,
      reserved: 0,
      boostGranted: 0,
    );
    final reset = before.resetConsumed();
    expect(reset.plan, 'trial');
    expect(reset.weekStart, before.weekStart);
    expect(reset.monthStart, before.monthStart);
    expect(reset.weeklyLimit, 1000);
    expect(reset.monthlyLimit, 1000);
    expect(reset.weeklyUsed, 0);
    expect(reset.monthlyUsed, 0);

    final consumed = reset.consumeIncluded(1000);
    expect(consumed.canConsumeIncluded(1), isFalse);
    expect(() => consumed.consumeIncluded(1), throwsStateError);
  });

  test('true Free stays locked and receives no entitlement', () {
    const free = _QuotaState(
      plan: 'free',
      weekStart: '2026-08-31',
      monthStart: '2026-08-01',
      weeklyLimit: 0,
      monthlyLimit: 0,
      weeklyUsed: 0,
      monthlyUsed: 0,
      reserved: 0,
      boostGranted: 0,
    );
    final reset = free.resetConsumed();
    expect(reset.plan, 'free');
    expect(reset.weeklyLimit, 0);
    expect(reset.monthlyLimit, 0);
    expect(reset.canConsumeIncluded(1), isFalse);
  });

  test('prior-week monthly usage resets, reservations and Boost do not', () {
    const state = _QuotaState(
      plan: 'ai_coach',
      weekStart: '2026-08-31',
      monthStart: '2026-08-01',
      weeklyLimit: 2500,
      monthlyLimit: 10000,
      weeklyUsed: 400,
      monthlyUsed: 10000,
      reserved: 120,
      boostGranted: 2500,
    );
    final reset = state.resetConsumed();
    expect(reset.weeklyUsed, 0);
    expect(reset.monthlyUsed, 0);
    expect(reset.reserved, 120);
    expect(reset.boostGranted, 2500);
    expect(reset.weekStart, state.weekStart);
    expect(reset.monthStart, state.monthStart);
    expect(reset.plan, state.plan);
  });

  test('user counter shows both unchanged current-period boundaries', () {
    final page = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_page.dart',
    ).readAsStringSync();
    final usageWidgets = File(
      'lib/features/intelligence_center/presentation/ai_coach_settings_usage_widgets.dart',
    ).readAsStringSync();
    expect(page, contains("weekStart: data['week_start']"));
    expect(page, contains("resetAt: data['reset_at']"));
    expect(usageWidgets, contains("Key('ai-coach-current-period')"));
  });

  test('admin route is gated and gift link opens ordinary AI Coach', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final settings = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final links = File(
      'lib/features/notifications/domain/community_deep_link.dart',
    ).readAsStringSync();
    expect(router, contains("path: '/admin/ai-coach'"));
    expect(router, contains('builder: (_, _) => const AiCoachAdminPage()'));
    expect(settings, contains('if (adminAccess.asData?.value == true)'));
    expect(settings, contains("'/admin/ai-coach'"));
    expect(links, contains("'settings/ai-coach': '/intelligence-center'"));
  });
}

Future<void> _pumpAdmin(
  WidgetTester tester, {
  required _FakeAdminGateway gateway,
  required bool allowed,
}) async {
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
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

String _migration() => File(
  'supabase/migrations/20260831142124_ai_coach_global_reset.sql',
).readAsStringSync();

String _function(String sql, String startName, String endName) {
  final start = sql.indexOf(
    'create or replace function',
    sql.indexOf(startName) - 40,
  );
  final end = sql.indexOf(endName, start + startName.length);
  return sql.substring(start, end);
}

final class _FakeAdminGateway implements AiCoachAdminGateway {
  _FakeAdminGateway({required this.allowed, this.individualMatched = true});

  final bool allowed;
  final bool individualMatched;
  int globalResetCalls = 0;
  int individualResetCalls = 0;
  String? lastGlobalIdempotencyKey;
  String? lastIndividualIdempotencyKey;
  String? lastEmail;
  String? lastReason;

  @override
  Future<bool> canManageAiCoach() async => allowed;

  @override
  Stream<String?> watchSignedInUserId() =>
      Stream<String?>.value(allowed ? 'admin-1' : 'ordinary-1');

  @override
  Future<AiCoachGlobalResetResult> globalReset(String idempotencyKey) async {
    globalResetCalls += 1;
    lastGlobalIdempotencyKey = idempotencyKey;
    return const AiCoachGlobalResetResult(
      resetId: '00000000-0000-4000-8000-000000000010',
      usageRowsReset: 2,
      monthlyRowsReset: 2,
      usersNotified: 4,
      duplicate: false,
    );
  }

  @override
  Future<bool> individualReset({
    required String email,
    required String reason,
    required String idempotencyKey,
  }) async {
    individualResetCalls += 1;
    lastEmail = email;
    lastReason = reason;
    lastIndividualIdempotencyKey = idempotencyKey;
    return individualMatched;
  }
}

final class _FakeNoticeGateway implements AiCoachResetNoticeGateway {
  static const resetId = '00000000-0000-4000-8000-000000000020';

  bool dismissed = false;
  int dismissCalls = 0;
  String? dismissedResetId;

  @override
  Stream<String?> watchSignedInUserId() => Stream<String?>.value('owner-1');

  @override
  Future<AiCoachResetNotice?> newestUnseen() async => dismissed
      ? null
      : const AiCoachResetNotice(ownerId: 'owner-1', resetId: resetId);

  @override
  Future<void> dismiss(AiCoachResetNotice notice) async {
    dismissCalls += 1;
    dismissedResetId = notice.resetId;
    dismissed = true;
  }
}

final class _SwitchingNoticeGateway implements AiCoachResetNoticeGateway {
  final _owners = StreamController<String?>.broadcast(sync: true);
  final _pending = <Completer<AiCoachResetNotice?>>[];
  final deliveredOwners = <String?>[];
  String? dismissedOwnerId;

  int get requests => _pending.length;
  bool get hasListener => _owners.hasListener;

  void emit(String? ownerId) => _owners.add(ownerId);

  void complete(int index, AiCoachResetNotice? notice) {
    _pending[index].complete(notice);
  }

  Future<void> close() => _owners.close();

  @override
  Stream<String?> watchSignedInUserId() => _owners.stream.map((ownerId) {
    deliveredOwners.add(ownerId);
    return ownerId;
  });

  @override
  Future<AiCoachResetNotice?> newestUnseen() {
    final completer = Completer<AiCoachResetNotice?>.sync();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> dismiss(AiCoachResetNotice notice) async {
    dismissedOwnerId = notice.ownerId;
  }
}

final class _SwitchingAdminGateway implements AiCoachAdminGateway {
  final _owners = StreamController<String?>.broadcast(sync: true);
  bool _allowed = false;
  int permissionChecks = 0;

  void emit(String ownerId, {required bool allowed}) {
    _allowed = allowed;
    _owners.add(ownerId);
  }

  Future<void> close() => _owners.close();

  @override
  Stream<String?> watchSignedInUserId() => _owners.stream;

  @override
  Future<bool> canManageAiCoach() async {
    permissionChecks += 1;
    return _allowed;
  }

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
}

final class _QuotaState {
  const _QuotaState({
    required this.plan,
    required this.weekStart,
    required this.monthStart,
    required this.weeklyLimit,
    required this.monthlyLimit,
    required this.weeklyUsed,
    required this.monthlyUsed,
    required this.reserved,
    required this.boostGranted,
  });

  final String plan;
  final String weekStart;
  final String monthStart;
  final int weeklyLimit;
  final int monthlyLimit;
  final int weeklyUsed;
  final int monthlyUsed;
  final int reserved;
  final int boostGranted;

  bool canConsumeIncluded(int units) =>
      units > 0 &&
      weeklyUsed + reserved + units <= weeklyLimit &&
      monthlyUsed + reserved + units <= monthlyLimit;

  _QuotaState resetConsumed() => _copy(weeklyUsed: 0, monthlyUsed: 0);

  _QuotaState consumeIncluded(int units) {
    if (!canConsumeIncluded(units)) throw StateError('ai_usage_exhausted');
    return _copy(
      weeklyUsed: weeklyUsed + units,
      monthlyUsed: monthlyUsed + units,
    );
  }

  _QuotaState _copy({int? weeklyUsed, int? monthlyUsed}) => _QuotaState(
    plan: plan,
    weekStart: weekStart,
    monthStart: monthStart,
    weeklyLimit: weeklyLimit,
    monthlyLimit: monthlyLimit,
    weeklyUsed: weeklyUsed ?? this.weeklyUsed,
    monthlyUsed: monthlyUsed ?? this.monthlyUsed,
    reserved: reserved,
    boostGranted: boostGranted,
  );
}
