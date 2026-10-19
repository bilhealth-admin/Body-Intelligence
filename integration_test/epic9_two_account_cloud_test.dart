import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/domain/community_content_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> acceptCurrentCommunityPolicyForDisposableAccount(
  SupabaseClient client,
  String userId,
  String accountLabel,
) async {
  final initialRaw = await client.rpc('bil_current_community_policy_status');
  if (initialRaw is! Map) {
    throw const FormatException('Invalid Community policy status payload');
  }
  final initial = CommunityPolicyState.fromServerSnapshot(
    Map<String, dynamic>.from(initialRaw),
  );
  expect(
    initial.status,
    CommunityPolicyStatus.acceptanceRequired,
    reason:
        '$accountLabel must begin as a fresh disposable account that has not '
        'accepted Community policy.',
  );
  final policy = initial.policy;
  if (policy == null) {
    throw const FormatException('Active Community policy is unavailable');
  }

  // These run-scoped identities are created by native_cloud_fixture.ps1 and
  // deleted after this test. Model the explicit consent action through the
  // same authenticated write used by CommunityRepository; never use the
  // service role or fabricate acceptance for a real account.
  await client.from('bil_content_policy_acceptances').upsert({
    'user_id': userId,
    'policy_version': policy.version,
  });

  final verifiedRaw = await client.rpc('bil_current_community_policy_status');
  if (verifiedRaw is! Map) {
    throw const FormatException('Invalid Community policy status payload');
  }
  final verified = CommunityPolicyState.fromServerSnapshot(
    Map<String, dynamic>.from(verifiedRaw),
  );
  expect(
    verified.status,
    CommunityPolicyStatus.accepted,
    reason:
        '$accountLabel must have its current Community policy acceptance '
        'verified by the server before the cloud test continues.',
  );
  expect(verified.acceptedVersion, policy.version);
}

void main() {
  const enabled = bool.fromEnvironment(
    'BIL_RUN_EPIC9_CLOUD_INTEGRATION',
    defaultValue: false,
  );
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const emailA = String.fromEnvironment('BIL_EPIC9_ACCOUNT_A_EMAIL');
  const passwordA = String.fromEnvironment('BIL_EPIC9_ACCOUNT_A_PASSWORD');
  const emailB = String.fromEnvironment('BIL_EPIC9_ACCOUNT_B_EMAIL');
  const passwordB = String.fromEnvironment('BIL_EPIC9_ACCOUNT_B_PASSWORD');
  final configured =
      enabled &&
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      emailA.isNotEmpty &&
      passwordA.isNotEmpty &&
      emailB.isNotEmpty &&
      passwordB.isNotEmpty;

  test(
    'two independent accounts complete friendship messaging report and block',
    () async {
      final clientA = SupabaseClient(url, anonKey);
      final clientB = SupabaseClient(url, anonKey);
      final authA = await clientA.auth.signInWithPassword(
        email: emailA,
        password: passwordA,
      );
      final authB = await clientB.auth.signInWithPassword(
        email: emailB,
        password: passwordB,
      );
      final userA = authA.user!;
      final userB = authB.user!;
      expect(userA.id, isNot(userB.id));
      await acceptCurrentCommunityPolicyForDisposableAccount(
        clientA,
        userA.id,
        'Disposable QA account A',
      );
      await acceptCurrentCommunityPolicyForDisposableAccount(
        clientB,
        userB.id,
        'Disposable QA account B',
      );

      await clientA.from('bil_blocks').delete().eq('blocked_id', userB.id);
      await clientB.from('bil_blocks').delete().eq('blocked_id', userA.id);
      await clientA.from('bil_public_profiles').upsert({
        'user_id': userA.id,
        'display_name': 'BIL QA Account A',
        'locale_code': 'en',
        'discoverable': true,
        'profile_visibility': 'public',
        'allow_friend_requests': true,
        'allow_follows': true,
        'allow_messages_from': 'friends',
      });
      await clientB.from('bil_public_profiles').upsert({
        'user_id': userB.id,
        'display_name': 'BIL QA Account B',
        'locale_code': 'en',
        'discoverable': true,
        'profile_visibility': 'friends',
        'allow_friend_requests': true,
        'allow_follows': true,
        'allow_messages_from': 'friends',
      });

      final existing = await clientA
          .from('bil_friendships')
          .select('id,status,requester_id,addressee_id')
          .or(
            'and(requester_id.eq.${userA.id},addressee_id.eq.${userB.id}),and(requester_id.eq.${userB.id},addressee_id.eq.${userA.id})',
          );
      if (existing.isEmpty) {
        await clientA.rpc(
          'bil_request_friendship',
          params: {'p_addressee_id': userB.id},
        );
      }
      final friendship = await clientB
          .from('bil_friendships')
          .select('id,status,requester_id,addressee_id')
          .or(
            'and(requester_id.eq.${userA.id},addressee_id.eq.${userB.id}),and(requester_id.eq.${userB.id},addressee_id.eq.${userA.id})',
          )
          .single();
      if (friendship['status'] != 'accepted') {
        await clientB
            .from('bil_friendships')
            .update({
              'status': 'accepted',
              'responded_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', friendship['id']);
      }

      final message = await clientA
          .from('bil_messages')
          .insert({
            'sender_id': userA.id,
            'recipient_id': userB.id,
            'body': 'Epic 9 two-account verification',
          })
          .select('id')
          .single();
      final received = await clientB
          .from('bil_messages')
          .select('id,sender_id,recipient_id')
          .eq('id', message['id'])
          .single();
      expect(received['sender_id'], userA.id);

      await clientB.from('bil_community_reports').insert({
        'reporter_id': userB.id,
        'target_kind': 'message',
        'target_id': message['id'],
        'reason': 'Automated Epic 9 safety-path verification',
      });
      await clientB.rpc(
        'bil_block_community_member',
        params: {'p_blocked_id': userA.id},
      );
      final block = await clientB
          .from('bil_blocks')
          .select('blocked_id')
          .eq('blocked_id', userA.id)
          .single();
      expect(block['blocked_id'], userA.id);
    },
    skip: configured
        ? false
        : 'Dedicated Supabase QA credentials are not configured.',
  );
}
