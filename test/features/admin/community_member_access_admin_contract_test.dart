import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/admin/presentation/community_member_access_admin_panel.dart';
import 'package:body_intelligence_log/features/admin/services/community_member_access_admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community suspension is server-authoritative, audited, and reversible', () {
    final sql = File(
      'supabase/migrations/20260905160000_admin_community_access_control.sql',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/ai-coach-global-reset/server.ts',
    ).readAsStringSync();
    final adminPage = File(
      'lib/features/admin/presentation/ai_coach_admin_page.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/admin/services/community_member_access_admin_service.dart',
    ).readAsStringSync();

    expect(sql, contains('private.bil_community_member_access'));
    expect(sql, contains('private.bil_community_member_access_audit'));
    expect(
      sql,
      contains("raise exception 'idempotency_key_owned_by_another_admin'"),
    );
    expect(sql, contains('public.bil_can_use_community()'));
    expect(sql, contains("'community_member_state:' || v_actor_id::text"));
    expect(sql, contains("'community_member_state:' || v_target_id::text"));
    expect(sql, contains("'community_member_state:' || p_user_id::text"));
    expect(sql, contains("'community_member_state:' || new.author_id::text"));
    expect(sql, contains("raise exception 'community_access_suspended'"));
    expect(
      sql,
      contains("raise exception 'community_post_update_requires_human_review'"),
    );
    expect(sql, contains("tg_table_name = 'bil_community_posts'"));
    expect(sql, contains('new.author_id = (select auth.uid())'));
    expect(sql, contains('pg_catalog.to_jsonb(new) - array['));
    expect(sql, contains('new.deleted_at is not null'));
    expect(sql, contains('public.bil_suspend_community_member_by_email'));
    expect(sql, contains('public.bil_reinstate_community_member'));
    expect(sql, contains("raise exception 'protected_administrator_member'"));
    expect(sql, contains('bil_ai_coach_single_active_admin_uidx'));
    expect(sql, contains('where active;'));
    expect(
      sql,
      contains(
        'alter table private.bil_ai_coach_admins enable row level security;',
      ),
    );
    expect(
      sql,
      contains("raise exception 'single_owner_administrator_preflight_failed'"),
    );
    expect(
      sql,
      contains("raise exception 'suspended_member_cannot_be_moderator'"),
    );
    expect(sql, contains('bil_00_moderator_member_access'));
    expect(
      sql,
      contains("pg_catalog.hashtextextended('community_moderator_roster', 0)"),
    );
    expect(
      sql,
      contains(
        'before insert or update of user_id on public.bil_community_moderators',
      ),
    );
    expect(
      sql,
      contains("raise exception 'suspended_author_post_approval_forbidden'"),
    );
    expect(sql, contains('bil_02_posts_suspended_author_approval'));
    expect(
      sql,
      contains('drop trigger if exists bil_00_reports_member_access'),
    );
    expect(
      sql,
      isNot(
        contains(
          'create trigger bil_00_reports_member_access\nbefore insert on public.bil_community_reports',
        ),
      ),
    );
    expect(
      sql,
      contains(
        "bucket_id = 'community-post-images'\n  and public.bil_can_use_community()",
      ),
    );
    expect(
      sql,
      contains('public.bil_list_suspended_community_members_for_admin(uuid)'),
    );
    expect(sql, contains('to service_role;'));
    expect(
      sql,
      contains('before insert or update on public.bil_community_posts'),
    );
    expect(sql, contains('before insert on public.bil_messages'));
    expect(sql, isNot(contains('bilhealth.app@gmail.com')));

    expect(edge, contains('operation === "community_member_list"'));
    expect(edge, contains('operation === "community_member_suspend"'));
    expect(edge, contains('operation === "community_member_reinstate"'));
    expect(edge, contains('admin.community.members.suspend'));
    expect(edge, contains('admin.community.members.reinstate'));
    expect(adminPage, contains('const CommunityMemberAccessAdminPanel()'));
    expect(gateway, isNot(contains('.whereType<Map>()')));
    expect(gateway, contains('if (row is! Map)'));
  });

  testWidgets('administrator can suspend and reinstate a Community account', (
    tester,
  ) async {
    final gateway = _FakeCommunityMemberAccessAdminGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityMemberAccessAdminGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityMemberAccessAdminPanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('suspended@example.com'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('admin-community-suspend-email')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('admin-community-suspend-reason')),
      'Repeated Community policy violations',
    );
    await tester.tap(find.byKey(const Key('admin-community-suspend-member')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-community-suspend-confirmation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('admin-community-suspend-confirm')));
    await tester.pumpAndSettle();
    expect(gateway.suspendedEmails, ['person@example.com']);
    expect(gateway.suspensionReasons, ['Repeated Community policy violations']);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'admin-community-reinstate-00000000-0000-4000-8000-000000000003',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-community-reinstate-confirmation')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('admin-community-reinstate-confirm')),
    );
    await tester.pumpAndSettle();
    expect(gateway.reinstatedIds, ['00000000-0000-4000-8000-000000000003']);
  });
}

final class _FakeCommunityMemberAccessAdminGateway
    implements CommunityMemberAccessAdminGateway {
  final suspendedEmails = <String>[];
  final suspensionReasons = <String>[];
  final reinstatedIds = <String>[];

  @override
  Future<List<CommunitySuspendedMemberEntry>> listSuspendedMembers() async => [
    CommunitySuspendedMemberEntry(
      userId: '00000000-0000-4000-8000-000000000003',
      email: 'suspended@example.com',
      reason: 'Repeated Community policy violations',
      suspendedAt: DateTime.utc(2026, 9, 5),
    ),
  ];

  @override
  Future<bool> reinstateMember(String userId) async {
    reinstatedIds.add(userId);
    return true;
  }

  @override
  Future<CommunityMemberSuspendResult> suspendMember({
    required String email,
    required String reason,
  }) async {
    suspendedEmails.add(email);
    suspensionReasons.add(reason.trim());
    return const CommunityMemberSuspendResult(
      matched: true,
      active: true,
      changed: true,
      moderatorRemoved: false,
    );
  }
}
