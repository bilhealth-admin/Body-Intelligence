import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/admin/presentation/community_moderator_admin_panel.dart';
import 'package:body_intelligence_log/features/admin/services/community_moderator_admin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moderator roster is admin-only, audited, and fail-safe', () {
    final sql = File(
      'supabase/migrations/20260904030000_community_post_human_moderation.sql',
    ).readAsStringSync();

    expect(sql, contains('private.bil_community_moderator_admin_audit'));
    expect(
      sql,
      contains(
        'public.bil_list_community_moderators_for_admin(\n  p_actor_id uuid',
      ),
    );
    expect(sql, contains('public.bil_add_community_moderator_by_email'));
    expect(sql, contains('public.bil_remove_community_moderator'));
    expect(sql, contains("auth.jwt()->>'role'), '') <> 'service_role'"));
    expect(sql, contains('administrator.user_id = p_actor_id'));
    expect(
      sql,
      contains("raise exception 'protected_administrator_moderator'"),
    );
    expect(sql, contains('from public, anon, authenticated, service_role'));
    expect(
      sql,
      contains(
        'grant execute on function public.bil_list_community_moderators_for_admin(uuid)',
      ),
    );
    expect(sql, contains('to service_role;'));
    expect(
      sql,
      contains("pg_catalog.hashtextextended('community_moderator_roster', 0)"),
    );
    expect(sql, contains("pg_catalog.lower('kademcom@yahoo.com')"));
    expect(sql, contains('insert into private.bil_ai_coach_admins'));
    expect(sql, contains('insert into public.bil_ai_closed_test_grants'));
    expect(sql, contains("'operational-admin'"));
    expect(
      sql,
      isNot(contains(RegExp(r"values\s*\(\s*'[0-9a-f-]{36}'::uuid"))),
    );

    final gateway = File(
      'lib/features/admin/services/community_moderator_admin_service.dart',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/ai-coach-global-reset/server.ts',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(gateway, contains("'ai-coach-global-reset'"));
    expect(gateway, contains('BilMobileIntegrityService.instance'));
    expect(gateway, contains('.protect('));
    expect(gateway, isNot(contains("_client.rpc('bil_list_community")));
    expect(gateway, isNot(contains('.whereType<Map>()')));
    expect(gateway, contains('if (row is! Map)'));
    expect(edge, contains('operation === "moderator_list"'));
    expect(edge, contains('operation === "moderator_add"'));
    expect(edge, contains('operation === "moderator_remove"'));
    // Assert the actual route boundary, not the position of its explanation.
    // A presentation-only wrapper must not turn a moderator role into a purchase.
    final moderationRoute = RegExp(
      r"GoRoute\(\s*path: '/community/moderation',([\s\S]*?)\n      \),",
    ).firstMatch(router)?.group(1);
    expect(moderationRoute, isNotNull);
    expect(moderationRoute, contains('CommunityPostModerationPage()'));
    expect(moderationRoute, contains('CommunitySurface('));
    expect(moderationRoute, isNot(contains('PremiumRouteGlassGate')));
  });

  test('owner-approved second administrator is enrolled by auth identity', () {
    final sql = File(
      'supabase/migrations/20260906120000_owner_approved_second_administrator.sql',
    ).readAsStringSync();

    expect(sql, contains("lower('bilhealth.app@gmail.com')"));
    expect(
      sql,
      contains(
        'drop index if exists private.bil_ai_coach_single_active_admin_uidx',
      ),
    );
    expect(sql, contains('insert into private.bil_ai_coach_admins'));
    expect(sql, contains('insert into public.bil_community_moderators'));
    expect(sql, contains('owner_approved_secondary_administrator'));
    expect(sql, contains('v_owner_id'));
    expect(sql, contains('v_secondary_id'));
  });

  testWidgets('administrator can add and remove roster entries by account', (
    tester,
  ) async {
    final gateway = _FakeModeratorAdminGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityModeratorAdminGatewayProvider.overrideWithValue(gateway),
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
            body: SingleChildScrollView(child: CommunityModeratorAdminPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('moderator@example.com'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(
              const ValueKey(
                'admin-community-moderator-remove-00000000-0000-4000-8000-000000000001',
              ),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('admin-community-moderator-email')),
      'new@example.com',
    );
    await tester.tap(find.byKey(const Key('admin-community-moderator-add')));
    await tester.pumpAndSettle();
    expect(gateway.addedEmails, ['new@example.com']);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'admin-community-moderator-remove-00000000-0000-4000-8000-000000000002',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('admin-community-moderator-remove-confirmation')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('admin-community-moderator-remove-confirm')),
    );
    await tester.pumpAndSettle();
    expect(gateway.removedIds, ['00000000-0000-4000-8000-000000000002']);
  });
}

final class _FakeModeratorAdminGateway
    implements CommunityModeratorAdminGateway {
  final addedEmails = <String>[];
  final removedIds = <String>[];

  @override
  Future<CommunityModeratorAddResult> addModerator(String email) async {
    addedEmails.add(email);
    return const CommunityModeratorAddResult(matched: true, added: true);
  }

  @override
  Future<List<CommunityModeratorAdminEntry>> listModerators() async => [
    CommunityModeratorAdminEntry(
      userId: '00000000-0000-4000-8000-000000000001',
      email: 'owner@example.com',
      createdAt: DateTime.utc(2026),
      protectedAdministrator: true,
    ),
    CommunityModeratorAdminEntry(
      userId: '00000000-0000-4000-8000-000000000002',
      email: 'moderator@example.com',
      createdAt: DateTime.utc(2026),
      protectedAdministrator: false,
    ),
  ];

  @override
  Future<bool> removeModerator(String userId) async {
    removedIds.add(userId);
    return true;
  }
}
