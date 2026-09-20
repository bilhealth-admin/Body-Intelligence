import 'dart:io';

import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'administrator authority never substitutes for customer entitlement',
    () {
      final providers = File(
        'lib/features/commerce/providers/commerce_providers.dart',
      ).readAsStringSync();
      final gate = File(
        'lib/features/commerce/presentation/premium_route_glass_gate.dart',
      ).readAsStringSync();

      expect(providers, contains('verifiedSubscriptionStateProvider'));
      expect(providers, isNot(contains('bil_can_manage_ai_coach')));
      expect(providers, isNot(contains('administrativeOverride')));
      expect(gate, isNot(contains('administrativeOverride')));
    },
  );

  test(
    'a non-zero balance keeps Coach open even when it is below one task',
    () {
      expect(
        aiCoachAccessFromUsageStatus(<String, Object?>{
          'credits': <String, Object?>{'total_remaining': 15},
        }),
        isTrue,
      );
      expect(
        aiCoachAccessFromUsageStatus(<String, Object?>{
          'credits': <String, Object?>{'total_remaining': 0},
        }),
        isFalse,
      );
    },
  );

  test(
    'active paid periods do not expire merely because verification is old',
    () {
      final now = DateTime.utc(2026, 9, 5, 12);
      expect(
        isAcceptableServerVerificationTimestamp(
          verifiedAt: now.subtract(const Duration(days: 20)),
          now: now,
        ),
        isTrue,
      );
      expect(
        isAcceptableServerVerificationTimestamp(verifiedAt: null, now: now),
        isFalse,
      );
      expect(
        isAcceptableServerVerificationTimestamp(
          verifiedAt: now.add(const Duration(minutes: 6)),
          now: now,
        ),
        isFalse,
      );
    },
  );

  test('operational administrator access is a separate expiring grant', () {
    final sql = File(
      'supabase/migrations/20260904030000_community_post_human_moderation.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/commerce/repositories/server_entitlement_repository.dart',
    ).readAsStringSync();

    expect(sql, contains('insert into private.bil_ai_coach_admins'));
    expect(sql, contains('insert into public.bil_ai_closed_test_grants'));
    expect(sql, contains("'operational-admin'"));
    expect(repository, contains("from('bil_ai_closed_test_grants')"));
    expect(repository, contains('CommercePlan.premiumAiCoach'));
  });

  test('review entitlement cannot grant administrative management capability', () {
    final reviewerGrant = File(
      'supabase/migrations/20260822005720_closed_test_full_premium_ai_coach.sql',
    ).readAsStringSync();
    final adminAuthority = File(
      'supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql',
    ).readAsStringSync();
    final adminGateway = File(
      'lib/features/admin/services/ai_coach_admin_service.dart',
    ).readAsStringSync();
    final reviewerLogin = File(
      'lib/features/auth/login_page.dart',
    ).readAsStringSync();

    expect(reviewerGrant, contains('public.bil_ai_closed_test_grants'));
    expect(reviewerGrant, isNot(contains('private.bil_ai_coach_admins')));
    expect(adminAuthority, contains('private.bil_ai_coach_admins'));
    expect(adminGateway, contains("rpc('bil_can_manage_ai_coach')"));
    expect(adminGateway, isNot(contains('bil_ai_closed_test_grants')));
    expect(reviewerLogin, contains('SupabaseAuthService'));
    expect(reviewerLogin, isNot(contains('bil_ai_closed_test_grants')));
    expect(reviewerLogin, isNot(contains('bil_can_manage_ai_coach')));
  });

  test('admin edge operations authorize before parsing mutation input', () {
    final server = File(
      'supabase/functions/ai-coach-global-reset/server.ts',
    ).readAsStringSync();
    final permissionProbe = server.indexOf(
      'c.auth.rpc("bil_can_manage_ai_coach")',
    );
    final bodyParse = server.indexOf('body = await request.json()');

    expect(permissionProbe, greaterThanOrEqualTo(0));
    expect(bodyParse, greaterThan(permissionProbe));
    expect(server, contains('return json({ error: "not_found" }, 404)'));
    expect(server, contains('authResult.data.user.id'));
  });
}
